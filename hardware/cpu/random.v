//Random number generator for RAND, 32 bit LFSR
//shifts left every tick, new bit = XOR of bits 31, 21, 1, 0
//goes through every value except 0, about 159 seconds at 27 MHz
//can never be all zeros, reset gives a seed

module random (
    input  wire        clk,
    input  wire        rst,
    output reg  [31:0] random_number //changes every tick
);

    //new bit coming in on the right
    wire new_bit;
    assign new_bit = random_number[31] ^ random_number[21] ^ random_number[1] ^ random_number[0];

    always @(posedge clk) begin
        if (rst)
            random_number <= 32'hACE1_2345; //any non-zero start works
        else
            random_number <= {random_number[30:0], new_bit}; //shift left, new bit on the right
    end

endmodule
