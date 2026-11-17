//TMDS encoder, 8 bit colour to the 10-bit code for one wire pair
//visible time sends the colour in 2 steps
//1. fewer flips: each bit XOR or XNOR with the one before, bit 8 says which
//2. balance: keep 1s and 0s even, flip the 8 bits if leaning, bit 9 says so
//blank time sends one of 4 control codes for the 2 control bits
//hsync and vsync on blue, 0 on the others
//standard DVI 1.0 encoding

module tmds_encoder (
    input wire pixel_clk,
    input wire rst,
    input wire [7:0] colour, //red, green or blue
    input wire [1:0] control, //blank time: {vsync, hsync} on blue, 2'b00 on the others
    input wire is_visible, //1 = send colour, 0 = send control code
    output reg [9:0] code //10 bits, ready one tick later
);

//how many 1s in the colour
wire [3:0] ones_in_colour = colour[0] + colour[1] + colour[2] + colour[3] + colour[4] + colour[5] + colour[6] + colour[7];

//step 1: XNOR if more than 4 ones, or 4 with bit 0 = 0, else XOR
wire is_xnor = (ones_in_colour > 4'd4) || ((ones_in_colour == 4'd4) && (colour[0] == 1'b0));

//chain, each bit with the one made before it
wire [8:0] chained;
assign chained[0] = colour[0];
assign chained[1] = is_xnor ? ~(chained[0] ^ colour[1]) : (chained[0] ^ colour[1]);
assign chained[2] = is_xnor ? ~(chained[1] ^ colour[2]) : (chained[1] ^ colour[2]);
assign chained[3] = is_xnor ? ~(chained[2] ^ colour[3]) : (chained[2] ^ colour[3]);
assign chained[4] = is_xnor ? ~(chained[3] ^ colour[4]) : (chained[3] ^ colour[4]);
assign chained[5] = is_xnor ? ~(chained[4] ^ colour[5]) : (chained[4] ^ colour[5]);
assign chained[6] = is_xnor ? ~(chained[5] ^ colour[6]) : (chained[5] ^ colour[6]);
assign chained[7] = is_xnor ? ~(chained[6] ^ colour[7]) : (chained[6] ^ colour[7]);
assign chained[8] = is_xnor ? 1'b0 : 1'b1; //bit 8: 1 = XOR, 0 = XNOR

//1s and 0s in the chained bits 7-0
wire [3:0] ones_in_chained = chained[0] + chained[1] + chained[2] + chained[3] + chained[4] + chained[5] + chained[6] + chained[7];
wire [3:0] zeros_in_chained = 4'd8 - ones_in_chained;

//step 2: running count of 1s - 0s sent, can be negative
reg signed [4:0] balance;

//ones - zeros of the chained bits, -8 to +8
wire signed [4:0] difference = $signed({1'b0, ones_in_chained}) - $signed({1'b0, zeros_in_chained});

always @(posedge pixel_clk) begin
    if (rst) begin
        code <= 10'b11_0101_0100;
        balance <= 5'sd0;
    end else if (!is_visible) begin
        //blank time: control code, balance starts over
        case (control)
            2'b00: code <= 10'b11_0101_0100;
            2'b01: code <= 10'b00_1010_1011;
            2'b10: code <= 10'b01_0101_0100;
            default: code <= 10'b10_1010_1011;
        endcase
        balance <= 5'sd0;
    end else if ((balance == 5'sd0) || (ones_in_chained == zeros_in_chained)) begin
        //balance 0 or code is even: flip the 8 bits only if bit 8 is 0
        code[9] <= ~chained[8];
        code[8] <= chained[8];
        code[7:0] <= chained[8] ? chained[7:0] : ~chained[7:0];
        if (chained[8] == 1'b0)
            balance <= balance - difference; //flipped, 1s and 0s swap
        else
            balance <= balance + difference;
    end else if (((balance > 5'sd0) && (ones_in_chained > zeros_in_chained)) ||
                 ((balance < 5'sd0) && (zeros_in_chained > ones_in_chained))) begin
        //leaning the same way as the code: flip, bit 9 = 1
        code[9] <= 1'b1;
        code[8] <= chained[8];
        code[7:0] <= ~chained[7:0];
        balance <= balance + $signed({3'b000, chained[8], 1'b0}) - difference;
    end else begin
        //code pushes the right way, send as is, bit 9 = 0
        code[9] <= 1'b0;
        code[8] <= chained[8];
        code[7:0] <= chained[7:0];
        balance <= balance - $signed({3'b000, ~chained[8], 1'b0}) + difference;
    end
end

endmodule
