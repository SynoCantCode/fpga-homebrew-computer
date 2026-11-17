//Divider, long division, 1 answer bit per tick, 32 ticks
//signed: divide the sizes, fix signs at the end
//quotient negative if only one input was negative
//remainder gets the dividend's sign

module divider (
    input  wire        clk,
    input  wire        rst,
    input  wire        start, //1 for one tick = begin a divide
    input  wire        is_signed, //1 = signed (DIV/MOD), 0 = unsigned
    input  wire [31:0] dividend, //number being divided
    input  wire [31:0] divisor, //number dividing it

    output wire        busy, //1 while working
    output wire [31:0] quotient, //the answer
    output wire [31:0] remainder //what's left over
);

    reg  [5:0]  count; //answer bits left, 32 down to 0
    reg  [31:0] quo; //starts as dividend, turns into quotient
    reg  [32:0] rem; //running remainder, 1 bit wider
    reg  [31:0] div_size; //divisor without sign
    reg         negate_quotient; //flip sign at the end
    reg         negate_remainder;

    assign busy = (count != 6'd0);

    //sizes of the inputs, negatives flipped positive
    wire dividend_negative = is_signed && dividend[31];
    wire divisor_negative  = is_signed && divisor[31];
    wire [31:0] dividend_size = dividend_negative ? (~dividend + 32'h0000_0001) : dividend;
    wire [31:0] divisor_size  = divisor_negative  ? (~divisor  + 32'h0000_0001) : divisor;

    //one step, bring down next bit, check if divisor fits
    wire [32:0] rem_shifted = {rem[31:0], quo[31]};
    wire        fits        = (rem_shifted >= {1'b0, div_size});

    always @(posedge clk) begin
        if (rst) begin
            count <= 6'd0;
            quo <= 32'h0000_0000;
            rem <= 33'h0_0000_0000;
            div_size <= 32'h0000_0000;
            negate_quotient <= 1'b0;
            negate_remainder <= 1'b0;
        end else if (start) begin
            //set up, remember the signs
            count <= 6'd32;
            quo <= dividend_size;
            rem <= 33'h0_0000_0000;
            div_size <= divisor_size;
            negate_quotient <= dividend_negative ^ divisor_negative;
            negate_remainder <= dividend_negative;
        end else if (busy) begin
            //one answer bit per tick
            if (fits) begin
                rem <= rem_shifted - {1'b0, div_size}; //fits, subtract, bit = 1
                quo <= {quo[30:0], 1'b1};
            end else begin
                rem <= rem_shifted; //no fit, bit = 0
                quo <= {quo[30:0], 1'b0};
            end
            count <= count - 6'd1;
        end
    end

    //put the signs back
    assign quotient  = negate_quotient  ? (~quo + 32'h0000_0001) : quo;
    assign remainder = negate_remainder ? (~rem[31:0] + 32'h0000_0001) : rem[31:0];

endmodule
