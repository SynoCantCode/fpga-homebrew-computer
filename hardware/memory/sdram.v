//SDRAM controller, 8 MB chip inside the FPGA package
//CPU side: address, read or write, done when finished
//chip: 4 banks x 2048 rows x 256 columns of 32 bit words
//address bits 22-21 = bank, 20-10 = row, 9-2 = column, 1-0 = byte
//commands on cs, ras, cas, we (0 = active)
//NOP 0111, ACTIVATE 0011, READ 0101, WRITE 0100, PRECHARGE 0010, AUTO REFRESH 0001, MODE REGISTER SET 0000
//27 MHz system clock, 37 ns a tick, chip clock is inverted
//chip waits: ~20 ns to open a row, ~20 ns to close, ~70 ns refresh
//auto precharge (address bit 10 = 1), chip closes the row itself
//read = 7 ticks, write = 6, a refresh can add up to 5
//graphics card door: burst of VIDEO_WORDS words from the start of a row, one READ per tick
//160 words take ~166 ticks
//priority: refresh, graphics card, then CPU and blitter take turns
//chip can go at most ~421 ticks (15.6 us) without a refresh, so one is done early before a burst if needed
//blitter door: bursts of 1-256 words inside one row, read or write
//blit_index says which word the next WRITE sends
//line door: burst of 8 words for the instruction cache, counts as the CPU's turn

module sdram #(
    parameter POWER_UP_TICKS = 5600, //chip needs 200 us after power-up, 5400 ticks at 27 MHz plus spare
    parameter REFRESH_TICKS = 400, //400 ticks = 14.8 us, chip needs one every 15.6 us
    parameter VIDEO_WORDS = 160 //words in one graphics burst, one row of pixels (640 bytes)
) (
    input wire clk, //27 MHz system clock
    input wire rst,

    //CPU side, through the bus
    input wire request, //1 = CPU wants a read or write, held until done
    input wire write, //1 = write, 0 = read
    input wire [22:0] address, //byte address inside the SDRAM
    input wire [31:0] write_data,
    input wire [3:0] byte_enable, //which bytes to write, 1111 = all
    output reg [31:0] read_data, //word read, stays until the next read
    output wire done, //1 for one tick when finished
    output wire is_ready, //1 once power-up is over

    //graphics card door, burst of VIDEO_WORDS words
    input wire video_request, //1 = wants a burst, held until video_done
    input wire [22:0] video_address, //byte address of the first word, start of a row
    output reg video_word_valid, //1 for one tick, video_word is the next word
    output reg [7:0] video_word_index, //which word, 0 = first
    output reg [31:0] video_word,
    output wire video_done, //1 for one tick, burst over

    //blitter door, burst of blit_count words
    input wire blit_request, //1 = wants a burst, held until blit_done
    input wire blit_write, //1 = write, 0 = read
    input wire [22:0] blit_address, //byte address of the first word, burst stays in its row
    input wire [8:0] blit_count, //how many words, 1-256
    output wire blit_word_valid, //read: 1 for one tick, blit_word is the next word
    output wire [7:0] blit_word_index, //read: which word, 0 = first
    output wire [31:0] blit_word,
    output wire [8:0] blit_index, //write: word the next tick's WRITE sends
    input wire [31:0] blit_write_data,
    input wire [3:0] blit_write_mask, //1 = write this byte
    output wire blit_done, //1 for one tick, burst over

    //instruction cache door, 8 words from line_address (multiple of 32)
    input wire line_request, //1 = cache wants a line, held until line_done
    input wire [22:0] line_address,
    output wire line_word_valid, //1 for one tick, line_word is the next word
    output wire [7:0] line_word_index, //which word, 0-7
    output wire [31:0] line_word,
    output wire line_done, //1 for one tick, line is in

    //chip side
    output wire sdram_clk,
    output wire sdram_cke, //clock enable, 1 = awake
    output wire sdram_cs_n, //4 command wires: chip select, row strobe, column strobe, write enable
    output wire sdram_ras_n,
    output wire sdram_cas_n,
    output wire sdram_we_n,
    output reg [1:0] sdram_ba, //bank
    output reg [10:0] sdram_addr, //row with ACTIVATE, column with READ / WRITE
    output reg [3:0] sdram_dqm, //byte masks, 1 = don't write this byte
    inout wire [31:0] sdram_dq //data, two-way
);

//commands as {cs_n, ras_n, cas_n, we_n}
localparam COMMAND_NOP          = 4'b0111;
localparam COMMAND_ACTIVATE     = 4'b0011;
localparam COMMAND_READ         = 4'b0101;
localparam COMMAND_WRITE        = 4'b0100;
localparam COMMAND_PRECHARGE    = 4'b0010;
localparam COMMAND_REFRESH      = 4'b0001;
localparam COMMAND_MODE         = 4'b0000;

//mode: burst length 1, CAS latency 2
//bits 2-0 burst length (000 = 1), 3 burst type, 6-4 CAS latency (010 = 2)
localparam MODE_SETTINGS = 11'b000_0_010_0_000;

reg [3:0] command;
assign {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} = command;
assign sdram_cke = 1'b1;
assign sdram_clk = ~clk; //inverted, chip takes the command mid tick

//data wires, driven only while writing
reg is_driving_data;
reg [31:0] data_out;
assign sdram_dq = is_driving_data ? data_out : 32'bz;

//the steps
localparam STEP_POWER_UP      = 5'd0; //waiting out the 200 us
localparam STEP_PRECHARGE_ALL = 5'd1; //close every row
localparam STEP_REFRESH_1     = 5'd2; //two refreshes
localparam STEP_REFRESH_2     = 5'd3;
localparam STEP_SET_MODE      = 5'd4; //set the chip's mode
localparam STEP_IDLE          = 5'd5; //waiting for work
localparam STEP_REFRESH       = 5'd6; //regular refresh
localparam STEP_OPEN_ROW      = 5'd7; //ACTIVATE the CPU's row
localparam STEP_READ          = 5'd8; //READ the column, chip closes the row after
localparam STEP_WRITE         = 5'd9; //WRITE the column
localparam STEP_WAIT          = 5'd10; //wait, then go to next_step
localparam STEP_DONE          = 5'd11; //tell the CPU, finished
localparam STEP_VIDEO_OPEN    = 5'd12; //graphics burst, ACTIVATE its row
localparam STEP_VIDEO_READ    = 5'd13; //a READ every tick
localparam STEP_VIDEO_FINISH  = 5'd14; //last words coming out
localparam STEP_VIDEO_DONE    = 5'd15; //tell the graphics card, finished
localparam STEP_BLIT_OPEN     = 5'd16; //blitter burst, ACTIVATE its row
localparam STEP_BLIT_READ     = 5'd17; //a READ every tick
localparam STEP_BLIT_WRITE    = 5'd18; //a WRITE every tick
localparam STEP_BLIT_FINISH   = 5'd19; //last words come out, row closes
localparam STEP_BLIT_DONE     = 5'd20; //tell the blitter, finished
localparam STEP_LINE_OPEN     = 5'd21; //cache line, ACTIVATE its row
localparam STEP_LINE_READ     = 5'd22; //8 READs, one per tick
localparam STEP_LINE_FINISH   = 5'd23; //last words come out
localparam STEP_LINE_DONE     = 5'd24; //tell the cache, finished
localparam LINE_WORDS = 8;

//no burst if a refresh would come due during it, refresh goes first
localparam VIDEO_GUARD = 180;
localparam BLIT_GUARD = 280; //blitter bursts can be 256 words

reg [4:0] step;
reg [4:0] next_step; //where STEP_WAIT goes next
reg cpu_went_last; //1 = CPU was served last, blitter's turn
reg [12:0] wait_count; //ticks left to wait, 5600 fits in 13 bits
reg [8:0] refresh_count; //ticks since the last refresh
reg is_refresh_due; //1 = time for a refresh
reg is_powered_up;
reg is_reading; //1 while a read is in progress

//burst pipeline, carries word coming + its number
reg video_coming_0, video_coming_1, video_coming_2;
reg [7:0] video_index_0, video_index_1, video_index_2;
reg [8:0] video_count; //READs or WRITEs sent so far in this burst
reg [2:0] video_finish_count; //ticks left for the last words
reg for_blitter_0, for_blitter_1, for_blitter_2; //which door the word in the pipeline is for
reg blit_valid; //1 for one tick, word caught is the blitter's
reg for_line_0, for_line_1, for_line_2; //same for the cache line
reg line_valid;

assign done = (step == STEP_DONE);
assign video_done = (step == STEP_VIDEO_DONE);
assign blit_done = (step == STEP_BLIT_DONE);
assign line_done = (step == STEP_LINE_DONE);
assign line_word = video_word;
assign line_word_index = video_word_index;
assign line_word_valid = line_valid;
//caught words go to both doors, valid says whose
assign blit_word = video_word;
assign blit_word_index = video_word_index;
assign blit_word_valid = blit_valid;
//word the next WRITE sends, 0 while the row opens
assign blit_index = (step == STEP_BLIT_OPEN) ? 9'd0 : video_count + 9'd1;
assign is_ready = is_powered_up;

always @(posedge clk) begin
    if (rst) begin
        step <= STEP_POWER_UP;
        next_step <= STEP_POWER_UP;
        wait_count <= POWER_UP_TICKS;
        command <= COMMAND_NOP;
        sdram_ba <= 2'b00;
        sdram_addr <= 11'd0;
        sdram_dqm <= 4'b1111;
        is_driving_data <= 1'b0;
        data_out <= 32'd0;
        read_data <= 32'd0;
        refresh_count <= 9'd0;
        is_refresh_due <= 1'b0;
        is_powered_up <= 1'b0;
        is_reading <= 1'b0;
        video_coming_0 <= 1'b0;
        video_coming_1 <= 1'b0;
        video_coming_2 <= 1'b0;
        video_index_0 <= 8'd0;
        video_index_1 <= 8'd0;
        video_index_2 <= 8'd0;
        video_word_valid <= 1'b0;
        video_word_index <= 8'd0;
        video_word <= 32'd0;
        video_count <= 9'd0;
        video_finish_count <= 3'd0;
        for_blitter_0 <= 1'b0;
        for_blitter_1 <= 1'b0;
        for_blitter_2 <= 1'b0;
        blit_valid <= 1'b0;
        for_line_0 <= 1'b0;
        for_line_1 <= 1'b0;
        for_line_2 <= 1'b0;
        line_valid <= 1'b0;
        cpu_went_last <= 1'b0;
    end else begin
        //NOP unless a step sends something, data wires let go
        command <= COMMAND_NOP;
        is_driving_data <= 1'b0;

        //refresh is due REFRESH_TICKS after the last one
        if (is_powered_up) begin
            if (refresh_count == REFRESH_TICKS - 1)
                is_refresh_due <= 1'b1;
            else
                refresh_count <= refresh_count + 9'd1;
        end

        //pipeline moves one stage
        video_coming_1 <= video_coming_0;
        video_coming_2 <= video_coming_1;
        video_index_1 <= video_index_0;
        video_index_2 <= video_index_1;
        video_coming_0 <= 1'b0;
        for_blitter_1 <= for_blitter_0;
        for_blitter_2 <= for_blitter_1;
        for_line_1 <= for_line_0;
        for_line_2 <= for_line_1;
        //word is caught 2 ticks after its READ
        video_word_valid <= video_coming_1 && !for_blitter_1 && !for_line_1; //screen's words only
        blit_valid <= video_coming_1 && for_blitter_1;
        line_valid <= video_coming_1 && for_line_1;
        if (video_coming_1) begin
            video_word <= sdram_dq; //word the chip is putting out
            video_word_index <= video_index_1;
        end

        case (step)
            //power-up
            STEP_POWER_UP: begin
                sdram_dqm <= 4'b1111;
                if (wait_count == 0)
                    step <= STEP_PRECHARGE_ALL;
                else
                    wait_count <= wait_count - 13'd1;
            end
            STEP_PRECHARGE_ALL: begin
                command <= COMMAND_PRECHARGE;
                sdram_addr <= 11'b100_0000_0000; //bit 10 = 1, close rows in all banks
                wait_count <= 13'd2;
                next_step <= STEP_REFRESH_1;
                step <= STEP_WAIT;
            end
            STEP_REFRESH_1: begin
                command <= COMMAND_REFRESH;
                wait_count <= 13'd3;
                next_step <= STEP_REFRESH_2;
                step <= STEP_WAIT;
            end
            STEP_REFRESH_2: begin
                command <= COMMAND_REFRESH;
                wait_count <= 13'd3;
                next_step <= STEP_SET_MODE;
                step <= STEP_WAIT;
            end
            STEP_SET_MODE: begin
                command <= COMMAND_MODE;
                sdram_ba <= 2'b00;
                sdram_addr <= MODE_SETTINGS;
                wait_count <= 13'd2;
                next_step <= STEP_IDLE;
                step <= STEP_WAIT;
                is_powered_up <= 1'b1;
            end

            //idle: refresh first, then graphics card, then CPU
            STEP_IDLE: begin
                sdram_dqm <= 4'b0000;
                if (is_refresh_due)
                    step <= STEP_REFRESH;
                else if (video_request && (refresh_count >= REFRESH_TICKS - VIDEO_GUARD))
                    step <= STEP_REFRESH; //refresh would land inside the burst, do it early
                else if (video_request)
                    step <= STEP_VIDEO_OPEN;
                else if (blit_request && (!(request || line_request) || cpu_went_last)) begin
                    //blitter's turn
                    if (refresh_count >= REFRESH_TICKS - BLIT_GUARD)
                        step <= STEP_REFRESH; //same, refresh early
                    else begin
                        step <= STEP_BLIT_OPEN;
                        cpu_went_last <= 1'b0;
                    end
                end else if (line_request) begin
                    step <= STEP_LINE_OPEN; //CPU fetch through the cache
                    cpu_went_last <= 1'b1;
                end else if (request) begin
                    step <= STEP_OPEN_ROW;
                    cpu_went_last <= 1'b1;
                end
            end
            STEP_REFRESH: begin
                command <= COMMAND_REFRESH;
                is_refresh_due <= 1'b0;
                refresh_count <= 9'd0; //count starts again
                wait_count <= 13'd3; //3 ticks = 111 ns, chip needs ~70 ns
                next_step <= STEP_IDLE;
                step <= STEP_WAIT;
            end

            //read or write: open the row, then the column
            STEP_OPEN_ROW: begin
                command <= COMMAND_ACTIVATE;
                sdram_ba <= address[22:21];
                sdram_addr <= address[20:10]; //row
                step <= write ? STEP_WRITE : STEP_READ; //1 tick (37 ns) is more than the ~20 ns needed
            end
            STEP_READ: begin
                command <= COMMAND_READ;
                sdram_addr <= {3'b100, address[9:2]}; //bit 10 = 1 closes the row after, bits 7-0 = column
                sdram_dqm <= 4'b0000;
                is_reading <= 1'b1;
                //CAS latency 2, word is caught 2 ticks from now
                wait_count <= 13'd1;
                next_step <= STEP_DONE;
                step <= STEP_WAIT;
            end
            STEP_WRITE: begin
                command <= COMMAND_WRITE;
                sdram_addr <= {3'b100, address[9:2]};
                sdram_dqm <= ~byte_enable; //1 = don't write that byte
                data_out <= write_data;
                is_driving_data <= 1'b1; //data goes out with the WRITE
                wait_count <= 13'd2; //chip writes then closes the row itself
                next_step <= STEP_DONE;
                step <= STEP_WAIT;
            end

            //waiting
            STEP_WAIT: begin
                if (wait_count == 0) begin
                    if (is_reading) begin
                        read_data <= sdram_dq; //word the chip is putting out
                        is_reading <= 1'b0;
                    end
                    step <= next_step;
                end else begin
                    wait_count <= wait_count - 13'd1;
                end
            end

            //done = 1 for this one tick
            STEP_DONE: begin
                step <= STEP_IDLE;
            end

            //graphics card burst
            STEP_VIDEO_OPEN: begin
                command <= COMMAND_ACTIVATE;
                sdram_ba <= video_address[22:21];
                sdram_addr <= video_address[20:10]; //row
                video_count <= 9'd0;
                step <= STEP_VIDEO_READ; //1 tick is enough
            end
            STEP_VIDEO_READ: begin
                command <= COMMAND_READ;
                sdram_dqm <= 4'b0000;
                video_coming_0 <= 1'b1; //a word is coming
                for_blitter_0 <= 1'b0;
                for_line_0 <= 1'b0;
                video_index_0 <= video_count[7:0];
                video_count <= video_count + 9'd1;
                if (video_count == VIDEO_WORDS - 1) begin
                    //last one, bit 10 = 1 closes the row
                    sdram_addr <= {3'b100, video_address[9:2] + video_count[7:0]};
                    video_finish_count <= 3'd4;
                    step <= STEP_VIDEO_FINISH;
                end else begin
                    //bit 10 = 0, row stays open
                    sdram_addr <= {3'b000, video_address[9:2] + video_count[7:0]};
                end
            end
            STEP_VIDEO_FINISH: begin //last words come out, row closes
                if (video_finish_count == 0)
                    step <= STEP_VIDEO_DONE;
                else
                    video_finish_count <= video_finish_count - 3'd1;
            end
            STEP_VIDEO_DONE: begin //video_done = 1 for this one tick
                step <= STEP_IDLE;
            end

            //blitter burst
            STEP_BLIT_OPEN: begin
                command <= COMMAND_ACTIVATE;
                sdram_ba <= blit_address[22:21];
                sdram_addr <= blit_address[20:10]; //row
                video_count <= 9'd0;
                step <= blit_write ? STEP_BLIT_WRITE : STEP_BLIT_READ;
            end
            STEP_BLIT_READ: begin
                command <= COMMAND_READ;
                sdram_dqm <= 4'b0000;
                video_coming_0 <= 1'b1;
                for_blitter_0 <= 1'b1;
                for_line_0 <= 1'b0;
                video_index_0 <= video_count[7:0];
                video_count <= video_count + 9'd1;
                if (video_count == blit_count - 9'd1) begin
                    sdram_addr <= {3'b100, blit_address[9:2] + video_count[7:0]}; //last one, close the row
                    video_finish_count <= 3'd4;
                    step <= STEP_BLIT_FINISH;
                end else begin
                    sdram_addr <= {3'b000, blit_address[9:2] + video_count[7:0]};
                end
            end
            STEP_BLIT_WRITE: begin
                command <= COMMAND_WRITE;
                sdram_dqm <= ~blit_write_mask; //1 = don't write that byte
                data_out <= blit_write_data; //blitter put the word here a tick ahead
                is_driving_data <= 1'b1;
                video_count <= video_count + 9'd1;
                if (video_count == blit_count - 9'd1) begin
                    sdram_addr <= {3'b100, blit_address[9:2] + video_count[7:0]}; //last one, close the row
                    video_finish_count <= 3'd3; //chip writes then closes the row itself
                    step <= STEP_BLIT_FINISH;
                end else begin
                    sdram_addr <= {3'b000, blit_address[9:2] + video_count[7:0]};
                end
            end
            STEP_BLIT_FINISH: begin
                if (video_finish_count == 0)
                    step <= STEP_BLIT_DONE;
                else
                    video_finish_count <= video_finish_count - 3'd1;
            end
            STEP_BLIT_DONE: begin //blit_done = 1 for this one tick
                step <= STEP_IDLE;
            end

            //cache line, 8 READs
            STEP_LINE_OPEN: begin
                command <= COMMAND_ACTIVATE;
                sdram_ba <= line_address[22:21];
                sdram_addr <= line_address[20:10];
                video_count <= 9'd0;
                step <= STEP_LINE_READ;
            end
            STEP_LINE_READ: begin
                command <= COMMAND_READ;
                sdram_dqm <= 4'b0000;
                video_coming_0 <= 1'b1;
                for_blitter_0 <= 1'b0;
                for_line_0 <= 1'b1;
                video_index_0 <= video_count[7:0];
                video_count <= video_count + 9'd1;
                if (video_count == LINE_WORDS - 1) begin
                    sdram_addr <= {3'b100, line_address[9:2] + video_count[7:0]}; //last one, close the row
                    video_finish_count <= 3'd4;
                    step <= STEP_LINE_FINISH;
                end else begin
                    sdram_addr <= {3'b000, line_address[9:2] + video_count[7:0]};
                end
            end
            STEP_LINE_FINISH: begin
                if (video_finish_count == 0)
                    step <= STEP_LINE_DONE;
                else
                    video_finish_count <= video_finish_count - 3'd1;
            end
            STEP_LINE_DONE: begin //line_done = 1 for this one tick
                step <= STEP_IDLE;
            end

            default: step <= STEP_IDLE;
        endcase
    end
end

endmodule
