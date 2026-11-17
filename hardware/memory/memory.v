module memory #(
    parameter INIT_FILE = "program.hex",
    parameter ADDRESS_BITS = 16 //16 = 64 KB for the CPU tests, the computer uses 15 = 32 KB
) (
    input wire clk,
    input wire we,
    input wire [3:0] byte_enable, //which bytes to write, 1111 = whole word, 0001 = only byte 0
    input wire [31:0] address,
    input wire [31:0] write_data,
    output reg [31:0] read_data
);

//16384 words = 64 KB, 8192 words = 32 KB
//32 bit words
reg[31:0] mem [0:(1 << (ADDRESS_BITS - 2)) - 1];

wire [ADDRESS_BITS-3:0] word_index;
assign word_index = address[ADDRESS_BITS-1:2];

//fill in .hex
initial begin
    $readmemh(INIT_FILE, mem);
end

always @(posedge clk) begin
    //only write the enabled bytes
    //byte 0 = bits [7:0], lowest address (little-endian)
    if (we) begin
        if (byte_enable[0]) mem[word_index][7:0]   <= write_data[7:0];
        if (byte_enable[1]) mem[word_index][15:8]  <= write_data[15:8];
        if (byte_enable[2]) mem[word_index][23:16] <= write_data[23:16];
        if (byte_enable[3]) mem[word_index][31:24] <= write_data[31:24];
    end
    //Read every tick, the CPU ignores it when it doesnt need it
    read_data <= mem[word_index];

end

endmodule