//Two-door RAM, write door on one clock, read door on another
//hands data between the 27MHz system clock and the 25.2MHz pixel clock
//used 3 times (WIDTH x 2^ADDRESS_BITS)
//line buffer 32 x 512, two rows of pixels
//palette 24 x 256, colour number to rgb
//pointer picture 32 x 16, 2 bits a dot
//read takes one tick

module two_door_ram #(
    parameter WIDTH = 32,
    parameter ADDRESS_BITS = 9
) (
    //the write door
    input wire write_clk,
    input wire write_enable,
    input wire [ADDRESS_BITS-1:0] write_address,
    input wire [WIDTH-1:0] write_data,

    //the read door
    input wire read_clk,
    input wire [ADDRESS_BITS-1:0] read_address,
    output reg [WIDTH-1:0] read_data
);

reg [WIDTH-1:0] cells [0:(1 << ADDRESS_BITS) - 1];

//every cell starts at 0
integer i;
initial begin
    for (i = 0; i < (1 << ADDRESS_BITS); i = i + 1)
        cells[i] = {WIDTH{1'b0}};
    read_data = {WIDTH{1'b0}};
end

always @(posedge write_clk) begin
    if (write_enable)
        cells[write_address] <= write_data;
end

always @(posedge read_clk) begin
    read_data <= cells[read_address];
end

endmodule
