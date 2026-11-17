//CPU's ALU 32bit
//a and b, outputs result and flags
//NZCV : Recalculates every time

module alu (
    input wire [31:0] a, //First input from Hidden Reg A
    input wire [31:0] b, //Second input, from hidden Reg B
    input wire [3:0] operation, //which job
    input wire carry_in, //carry in, 1 = add one more, or no borrow for sub

    output reg [31:0] result,
    output wire flag_n,//neg from top bit
    output wire flag_z,//zero result
    output reg flag_c,//carry
    output reg flag_v//overflow, didnt fit

);

`include "cpu_defines.vh"


//33 bit helper
reg[32:0] wide;

always@(*) begin
    case(operation)

    OP_ADD: begin
        //a with a 0 glued on top, 33 bits
        wide = {1'b0, a} + {1'b0, b} + {32'h0000_0000, carry_in};
        result = wide[31:0];
        //C = a 1 carried out of the top
        flag_c = wide[32];
        //V = both inputs had same sign but results sign is different
        flag_v = (a[31] == b[31]) && (result[31] != a[31]);
end

OP_SUB: begin
    //sub = a + flipped b + carry_in
    wide = {1'b0, a} + {1'b0, ~b} + {32'h0000_0000, carry_in};
    result = wide[31:0];
    //bit 32 = 1 means no borrow, same as C
    flag_c = wide[32];
    //V = inputs had dif signs and results sign is different from a
    flag_v = (a[31] != b[31]) && (result[31] != a[31]);
end

//Logic jobs, bit by bit, no carry
//C and V are just 0
OP_AND: begin
    wide = 33'h0_0000_0000;
    result = a & b; //1 where both bits are 1
    flag_c = 1'b0;
    flag_v = 1'b0;
end

OP_OR: begin
    wide = 33'h0_0000_0000;
    result = a | b; //1 where either bit is 1
    flag_c = 1'b0;
    flag_v = 1'b0;
end

OP_XOR: begin
    wide = 33'h0_0000_0000;
    result = a ^ b; //1 where bits are different
    flag_c = 1'b0;
    flag_v = 1'b0;
end

OP_NOT: begin
    wide = 33'h0_0000_0000;
    result = ~a; //flips a, b not used
    flag_c = 1'b0;
    flag_v = 1'b0;
end

OP_NAND: begin
    wide = 33'h0_0000_0000;
    result = ~(a & b); //AND then flip
    flag_c = 1'b0;
    flag_v = 1'b0;
end

OP_NOR: begin
    wide = 33'h0_0000_0000;
    result = ~(a | b); //OR then flip
    flag_c = 1'b0;
    flag_v = 1'b0;
end

OP_XNOR: begin
    wide = 33'h0_0000_0000;
    result = ~(a ^ b); //XOR then flip, 1 where bits are the same
    flag_c = 1'b0;
    flag_v = 1'b0;
end

default: begin
    //unknown job, output zeros? makes most sense to me
    wide = 33'h0_0000_0000;
    result = 32'h0000_0000;
    flag_c=1'b0;
    flag_v=1'b0;
end
    endcase
end


assign flag_n = result[31]; //sign bit
assign flag_z = (result == 32'h0000_0000);

endmodule