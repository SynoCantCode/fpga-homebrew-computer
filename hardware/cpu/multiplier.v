//Multiplier 32 x 32 = 64 bits, no clock
//* uses the FPGA's multiplier blocks
//unsigned and signed product, low 32 bits are the same
//only high 32 differ (MULHU vs MULH)

module multiplier (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [63:0] product_unsigned, //both unsigned
    output wire [63:0] product_signed //both signed
);

    //zeros glued on top, 64 bit multiply
    assign product_unsigned = {32'h0000_0000, a} * {32'h0000_0000, b};

    //$signed = two's complement
    assign product_signed = $signed(a) * $signed(b);

endmodule
