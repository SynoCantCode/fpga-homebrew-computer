//Font ROM, 256 letters x 16 lines, one byte per line (bit 7 = left dot)
//address = {letter, line} = letter x 16 + line
//loaded from font.hex, never written

module font_rom #(
    parameter FONT_FILE = "hw/graphics/font.hex"
) (
    input wire clk,
    input wire [11:0] address, //{letter, line}
    output reg [7:0] dots //that line of the letter, one tick later
);

reg [7:0] lines [0:4095];

initial begin
    $readmemh(FONT_FILE, lines);
end

always @(posedge clk) begin
    dots <= lines[address];
end

endmodule
