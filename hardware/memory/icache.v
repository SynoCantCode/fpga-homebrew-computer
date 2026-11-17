//Instruction cache, keeps recently fetched SDRAM instructions in block RAM
//27 MHz system clock
//2 KB = 64 lines of 8 instructions (32 bytes), direct mapped
//address bits 22-11 = tag, 10-5 = line (0-63), 4-2 = instruction in the line (0-7)
//hit = answers in one tick like the ROM
//miss = whole line fetched from the SDRAM in one burst of 8 words
//a CPU write to a cached line throws that line out
//FLUSH and reset throw everything out
//blitter writes are not watched, FLUSH after blitting code

module icache (
    input wire clk, //27 MHz system clock
    input wire rst,

    //CPU side, through the bus
    input wire fetch, //1 = CPU is fetching an instruction from the SDRAM
    input wire [22:0] fetch_address, //SDRAM byte address
    output wire hit, //1 = cache has it
    output wire [31:0] instruction, //instruction for last tick's address
    input wire write_seen, //1 = CPU is writing to the SDRAM
    input wire [22:0] write_address,
    input wire flush, //1 = FLUSH, forget everything

    //SDRAM controller's line door
    output reg line_request,
    output reg [22:0] line_address,
    input wire line_word_valid,
    input wire [7:0] line_word_index,
    input wire [31:0] line_word,
    input wire line_done
);

reg [11:0] tags [0:63];
reg [63:0] valid;

wire [5:0] line = fetch_address[10:5];
wire [11:0] tag = fetch_address[22:11];
assign hit = valid[line] && (tags[line] == tag);

wire [5:0] write_line = write_address[10:5];
wire is_write_cached = write_seen && valid[write_line] && (tags[write_line] == write_address[22:11]);

reg [5:0] fill_line; //line being filled
reg [11:0] fill_tag;

two_door_ram #(.WIDTH(32), .ADDRESS_BITS(9)) instructions (
    .write_clk(clk),
    .write_enable(line_word_valid),
    .write_address({fill_line, line_word_index[2:0]}),
    .write_data(line_word),
    .read_clk(clk),
    .read_address(fetch_address[10:2]),
    .read_data(instruction)
);

integer i;
initial begin
    for (i = 0; i < 64; i = i + 1) tags[i] = 12'd0;
end

always @(posedge clk) begin
    if (rst || flush) begin
        valid <= 64'd0;
        if (rst) begin
            line_request <= 1'b0;
            line_address <= 23'd0;
            fill_line <= 6'd0;
            fill_tag <= 12'd0;
        end
    end else begin
        if (is_write_cached)
            valid[write_line] <= 1'b0; //CPU wrote into this line, throw it out
        if (line_request) begin
            if (line_done) begin //line is in, valid
                line_request <= 1'b0;
                tags[fill_line] <= fill_tag;
                valid[fill_line] <= 1'b1;
            end
        end else if (fetch && !hit) begin //miss, fetch the whole line
            line_request <= 1'b1;
            line_address <= {fetch_address[22:5], 5'b00000};
            fill_line <= line;
            fill_tag <= tag;
            valid[line] <= 1'b0; //old contents get replaced
        end
    end
end

endmodule
