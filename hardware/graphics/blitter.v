//Blitter, the graphics card's painter, 27MHz system clock
//draws into the SDRAM itself, 4 jobs
//FILL = a box in one colour
//COPY = a box from one place to another
//SEE-THROUGH COPY = copy that skips dots of the key colour
//LETTER = one 8 x 16 letter from the font
//every picture is page shaped, dot (x, y) at base + y x 1024 + x
//one row of a box = one SDRAM row, done as one burst
//FILL: one write burst per row, byte mask cuts the edges
//COPY: read burst into the row buffer (256 words), then a write burst
//source and dest can be off by any dots, funnel shift lines them up
//whole source row is read before writing, so a box can copy onto itself
//dest later in memory than source = rows go bottom to top
//LETTER: 16 short write bursts, 1 = letter colour, 0 = background or skipped
//Registers, writes at 0xFFFF_9200-0xFFFF_921C, cpu_address = offset
//0x200 BLIT_DEST dest base address
//0x204 BLIT_DEST_POINT x | (y << 16)
//0x208 BLIT_SIZE width | (height << 16), letters always 8 x 16
//0x20C BLIT_SOURCE source base address
//0x210 BLIT_SOURCE_POINT x | (y << 16)
//0x214 BLIT_COLOURS bits 7-0 colour, bits 15-8 second colour (letter background or copy key)
//0x218 BLIT_LETTER the letter 0-255
//0x21C BLIT_GO write: 1 FILL, 2 COPY, 3 SEE-THROUGH COPY, 4 LETTER, 5 SEE-THROUGH LETTER
//read: bit 0 = busy, wait for 0 before the next job
//no clipping, box must have x + width <= 1024

module blitter #(
    parameter FONT_FILE = "hw/graphics/font.hex"
) (
    input wire clk, //27MHz system clock
    input wire rst,

    //CPU side
    input wire [11:0] cpu_address,
    input wire cpu_write,
    input wire [31:0] cpu_write_data,
    output wire busy,

    //SDRAM third door
    output reg blit_request,
    output reg blit_write,
    output reg [22:0] blit_address,
    output reg [8:0] blit_count,
    input wire blit_word_valid,
    input wire [7:0] blit_word_index,
    input wire [31:0] blit_word,
    input wire [8:0] blit_index,
    output reg [31:0] blit_write_data,
    output reg [3:0] blit_write_mask,
    input wire blit_done
);

localparam JOB_FILL = 3'd1;
localparam JOB_COPY = 3'd2;
localparam JOB_COPY_SEE_THROUGH = 3'd3;
localparam JOB_LETTER = 3'd4;
localparam JOB_LETTER_SEE_THROUGH = 3'd5;

//registers
reg [12:0] dest_base; //dest base, SDRAM row number (address bits 22-10)
reg [9:0] dest_x;
reg [9:0] dest_y;
reg [10:0] width; //1-1024
reg [9:0] height;
reg [12:0] source_base;
reg [9:0] source_x;
reg [9:0] source_y;
reg [7:0] colour;
reg [7:0] colour_2;
reg [7:0] letter;

wire is_go = cpu_write && (cpu_address == 12'h21C);

always @(posedge clk) begin
    if (rst) begin
        dest_base <= 13'd0;
        dest_x <= 10'd0;
        dest_y <= 10'd0;
        width <= 11'd0;
        height <= 10'd0;
        source_base <= 13'd0;
        source_x <= 10'd0;
        source_y <= 10'd0;
        colour <= 8'd0;
        colour_2 <= 8'd0;
        letter <= 8'd0;
    end else if (cpu_write && !busy) begin
        case (cpu_address)
            12'h200: dest_base <= cpu_write_data[22:10];
            12'h204: begin dest_x <= cpu_write_data[9:0]; dest_y <= cpu_write_data[25:16]; end
            12'h208: begin width <= cpu_write_data[10:0]; height <= cpu_write_data[25:16]; end
            12'h20C: source_base <= cpu_write_data[22:10];
            12'h210: begin source_x <= cpu_write_data[9:0]; source_y <= cpu_write_data[25:16]; end
            12'h214: begin colour <= cpu_write_data[7:0]; colour_2 <= cpu_write_data[15:8]; end
            12'h218: letter <= cpu_write_data[7:0];
            default: ;
        endcase
    end
end

//the job
localparam STATE_IDLE = 3'd0;
localparam STATE_ROW = 3'd1; //work out row addresses, start first burst
localparam STATE_READ = 3'd2; //COPY, source row coming into the row buffer
localparam STATE_FONT = 3'd3; //LETTER, reading the font row
localparam STATE_WRITE = 3'd4; //writing the row
localparam STATE_NEXT = 3'd5; //next row or finished

reg [2:0] state;
reg [2:0] job;
reg [9:0] row; //which row of the box, 0 = top
reg [9:0] rows; //how many rows
reg upwards; //COPY, rows bottom to top
assign busy = (state != STATE_IDLE);

//row being worked on
wire [9:0] box_row = upwards ? (rows - 10'd1 - row) : row;

//dest row words, left edge word to right edge word
wire [10:0] job_width = ((job == JOB_LETTER) || (job == JOB_LETTER_SEE_THROUGH)) ? 11'd8 : width;
wire [10:0] right_edge = {1'b0, dest_x} + job_width - 11'd1; //last dot of the row
wire [8:0] first_word = {1'b0, dest_x[9:2]};
wire [8:0] words = right_edge[10:2] - first_word + 9'd1; //how many words the row touches
wire [1:0] lead = dest_x[1:0]; //dots before the box in the first word
wire [22:0] dest_row_address = {dest_base + {3'b000, dest_y + box_row}, 10'd0} + {12'd0, first_word, 2'b00};

//COPY: dest word k needs the 4 source dots starting at 4k + shift
//shift = source_x - lead, can be -1 to -3
//shift = 4 x shift_word + shift_byte
wire signed [11:0] shift = $signed({2'b00, source_x}) - $signed({10'd0, lead});
wire signed [11:0] shift_word = shift >>> 2; //source word with dest word 0's first dot
wire [1:0] shift_byte = shift[1:0];
wire [8:0] read_start = shift_word[11] ? 9'd0 : shift_word[8:0]; //no source word -1, start at 0
wire [9:0] read_end_wanted = shift_word[11] ? {1'b0, words} : ({1'b0, shift_word[8:0]} + {1'b0, words} + 10'd1);
wire [9:0] read_words = (read_end_wanted > 10'd256 - {1'b0, read_start}) ? (10'd256 - {1'b0, read_start})
                        : read_end_wanted; //not past the end of the 1KB row
wire [22:0] source_row_address = {source_base + {3'b000, source_y + box_row}, 10'd0} + {12'd0, read_start, 2'b00};

//COPY row buffer, words already lined up for writing
reg [31:0] previous_word; //source word before this one, 0 before the first
reg row_buffer_write;
reg [7:0] row_buffer_write_address;
reg [31:0] row_buffer_write_data;
wire [31:0] row_buffer_word;

two_door_ram #(.WIDTH(32), .ADDRESS_BITS(8)) row_buffer (
    .write_clk(clk),
    .write_enable(row_buffer_write),
    .write_address(row_buffer_write_address),
    .write_data(row_buffer_write_data),
    .read_clk(clk),
    .read_address(blit_index[7:0]), //word the next write needs, ready a tick later
    .read_data(row_buffer_word)
);

//funnel shift, 4 bytes starting at byte shift_byte of {current, previous}
function [31:0] funnel(input [31:0] previous, input [31:0] current, input [1:0] start);
    reg [63:0] pair;
    begin
        pair = {current, previous};
        funnel = pair >> {start, 3'b000};
    end
endfunction

//which word of the source row is arriving, and which dest word it completes
wire [9:0] arriving_word = {1'b0, read_start} + {2'b00, blit_word_index};
wire signed [11:0] completes = $signed({2'b00, arriving_word}) - shift_word - 12'sd1;

//LETTER: the letter's row from the font
wire [7:0] font_dots;
reg [7:0] letter_dots;
font_rom #(.FONT_FILE(FONT_FILE)) font (
    .clk(clk),
    .address({letter, box_row[3:0]}),
    .dots(font_dots)
);

//word the SDRAM writes next, asked a tick ahead with blit_index
reg [8:0] write_word; //dest word being prepared, blit_index one tick later
always @(posedge clk) write_word <= blit_index;

integer b;
reg signed [12:0] dot; //byte's dot number in the row, negative = before the left edge
reg [7:0] byte_value;
always @(*) begin
    blit_write_data = 32'd0;
    blit_write_mask = 4'b0000;
    for (b = 0; b < 4; b = b + 1) begin
        dot = $signed({2'b00, write_word, 2'b00}) + b - $signed({11'd0, lead});
        case (job)
            JOB_FILL: byte_value = colour;
            JOB_COPY, JOB_COPY_SEE_THROUGH: byte_value = row_buffer_word[8*b +: 8];
            default: byte_value = (dot >= 0 && dot < 8 && letter_dots[7 - dot[2:0]]) ? colour : colour_2;
        endcase
        blit_write_data[8*b +: 8] = byte_value;
        //written if inside the row and not see-through
        if (dot >= 0 && dot < $signed({2'b00, job_width})) begin
            if (job == JOB_COPY_SEE_THROUGH)
                blit_write_mask[b] = (byte_value != colour_2);
            else if (job == JOB_LETTER_SEE_THROUGH)
                blit_write_mask[b] = letter_dots[7 - dot[2:0]];
            else
                blit_write_mask[b] = 1'b1;
        end
    end
end

//the steps
always @(posedge clk) begin
    if (rst) begin
        state <= STATE_IDLE;
        job <= 3'd0;
        row <= 10'd0;
        rows <= 10'd0;
        upwards <= 1'b0;
        blit_request <= 1'b0;
        blit_write <= 1'b0;
        blit_address <= 23'd0;
        blit_count <= 9'd0;
        previous_word <= 32'd0;
        row_buffer_write <= 1'b0;
        row_buffer_write_address <= 8'd0;
        row_buffer_write_data <= 32'd0;
        letter_dots <= 8'd0;
    end else begin
        row_buffer_write <= 1'b0;
        case (state)
            STATE_IDLE: begin
                if (is_go && (cpu_write_data[2:0] >= JOB_FILL) && (cpu_write_data[2:0] <= JOB_LETTER_SEE_THROUGH)) begin
                    job <= cpu_write_data[2:0];
                    row <= 10'd0;
                    if ((cpu_write_data[2:0] == JOB_LETTER) || (cpu_write_data[2:0] == JOB_LETTER_SEE_THROUGH)) begin
                        rows <= 10'd16;
                        upwards <= 1'b0;
                        state <= STATE_ROW;
                    end else if ((width == 11'd0) || (height == 10'd0)) begin
                        state <= STATE_IDLE; //empty box
                    end else begin
                        rows <= height;
                        //dest later in memory = bottom to top
                        upwards <= ({dest_base, dest_y, dest_x} > {source_base, source_y, source_x});
                        state <= STATE_ROW;
                    end
                end
            end
            STATE_ROW: begin
                if ((job == JOB_COPY) || (job == JOB_COPY_SEE_THROUGH)) begin
                    previous_word <= 32'd0;
                    blit_write <= 1'b0;
                    blit_address <= source_row_address;
                    blit_count <= read_words[8:0];
                    blit_request <= 1'b1;
                    state <= STATE_READ;
                end else if (job == JOB_FILL) begin
                    blit_write <= 1'b1;
                    blit_address <= dest_row_address;
                    blit_count <= words;
                    blit_request <= 1'b1;
                    state <= STATE_WRITE;
                end else begin
                    state <= STATE_FONT; //font row read on this tick
                end
            end
            STATE_FONT: begin
                letter_dots <= font_dots;
                blit_write <= 1'b1;
                blit_address <= dest_row_address;
                blit_count <= words;
                blit_request <= 1'b1;
                state <= STATE_WRITE;
            end
            STATE_READ: begin
                if (blit_word_valid) begin
                    previous_word <= blit_word;
                    if (!completes[11]) begin //completes a dest word, line it up and keep it
                        row_buffer_write <= 1'b1;
                        row_buffer_write_address <= completes[7:0];
                        row_buffer_write_data <= funnel(previous_word, blit_word, shift_byte);
                    end
                end
                if (blit_done) begin
                    //last dest word has no source word after it, glue to 0
                    row_buffer_write <= 1'b1;
                    row_buffer_write_address <= completes[7:0] + 8'd1;
                    row_buffer_write_data <= funnel(previous_word, 32'd0, shift_byte);
                    //straight on to writing, request stays up as a write burst
                    state <= STATE_WRITE;
                    blit_write <= 1'b1;
                    blit_address <= dest_row_address;
                    blit_count <= words;
                end
            end
            STATE_WRITE: begin
                if (blit_done) begin
                    blit_request <= 1'b0;
                    state <= STATE_NEXT;
                end
            end
            STATE_NEXT: begin
                if (row == rows - 10'd1)
                    state <= STATE_IDLE; //last row, finished
                else begin
                    row <= row + 10'd1;
                    state <= STATE_ROW;
                end
            end
            default: state <= STATE_IDLE;
        endcase
    end
end

endmodule
