//Shifter for SHIFT, SHIFTI, ROT, ROTI
//no clock, like the ALU
//type = D00V, D = direction (0 left, 1 right), V = variant
//shifts: 0000 left, 1000 right, 1001 right arithmetic
//rotates: 0000 left, 1000 right, 1001 right through carry, 0001 left through carry
//carry_out = last bit that fell off
//amount 0 changes nothing, C stays
//through carry always moves 1 bit

module shifter (
    input  wire [31:0] value, //what to shift
    input  wire [4:0]  amount, //how many places, 0 to 31
    input  wire [3:0]  type, //D00V
    input  wire        is_rotate, //1 = ROT/ROTI, 0 = SHIFT/SHIFTI
    input  wire        carry_in, //C flag coming in

    output reg  [31:0] result,
    output reg         carry_out
);

    //1 bit wider to catch the bit that falls off
    reg [32:0] left_wide; //left: fallen bit lands in bit 32
    reg [32:0] right_wide; //right: fallen bit lands in bit 0

    always @(*) begin
        left_wide  = {1'b0, value} << amount;
        right_wide = {value, 1'b0} >> amount;

        case (type)
            4'b0000: begin
                if (is_rotate) begin
                    //rotate left
                    result    = (value << amount) | (value >> (6'd32 - amount));
                    carry_out = (amount == 5'd0) ? carry_in : result[0];
                end else begin
                    //shift left, 0s come in
                    result    = left_wide[31:0];
                    carry_out = (amount == 5'd0) ? carry_in : left_wide[32];
                end
            end

            4'b1000: begin
                if (is_rotate) begin
                    //rotate right
                    result    = (value >> amount) | (value << (6'd32 - amount));
                    carry_out = (amount == 5'd0) ? carry_in : result[31];
                end else begin
                    //shift right, 0s come in at the top
                    result    = value >> amount;
                    carry_out = (amount == 5'd0) ? carry_in : right_wide[0];
                end
            end

            4'b1001: begin
                if (is_rotate) begin
                    //rotate right through carry, C in at top, bit 0 into C
                    result    = {carry_in, value[31:1]};
                    carry_out = value[0];
                end else begin
                    //arithmetic shift right, sign bit comes in
                    result    = $signed(value) >>> amount;
                    carry_out = (amount == 5'd0) ? carry_in : right_wide[0];
                end
            end

            4'b0001: begin
                //rotate left through carry, C in at bottom, bit 31 into C
                //rotates only, CPU halts on SHIFT with this type
                result    = {value[30:0], carry_in};
                carry_out = value[31];
            end

            default: begin
                //not a real type, change nothing
                result    = value;
                carry_out = carry_in;
            end
        endcase
    end

endmodule
