//UART tx: send one byte at a time to the PC, through board's USB chip
//One byte = 10 bits on the wire
//start bit
//8 data bits
//stop bit

module uart_tx #(
    parameter CLOCKS_PER_BIT = 234
) (

    input wire clk,
    input wire rst,
    input wire send,
    input wire [7:0] byte_to_send,
    output wire busy,
    output wire tx

);

    reg [9:0] bits_left_to_send;
    reg [3:0] bit_count;
    reg [15:0] tick_count;

    //busy while bits
assign busy = (bit_count != 4'd0);

//The wire: the current bit while sending, 1 while resting
assign tx = busy ? bits_left_to_send[0] : 1'b1;

always @(posedge clk) begin
    if (rst) begin
        bits_left_to_send <= 10'b11_1111_1111;
        bit_count <= 4'd0;
        tick_count <= 16'd0;
    end else if (!busy) begin
        //resting: start byte when asked
        if (send) begin
            bits_left_to_send <= {1'b1, byte_to_send, 1'b0}; //stop | byte | start, start bit goes out first
            bit_count <= 4'd10;
            tick_count <= 16'd0;
        end
    end else begin
        //sending: hold each bit for CLOCKS_PER_BIT ticks, then move to next one
        if (tick_count == (CLOCKS_PER_BIT - 1)) begin
            tick_count <= 16'd0;
            bits_left_to_send <= {1'b1, bits_left_to_send[9:1]}; //shift right to next bit
            bit_count <= bit_count - 4'd1;
        end else begin
            tick_count <= tick_count + 16'd1;
        end
    end
end
//lot of ends
endmodule