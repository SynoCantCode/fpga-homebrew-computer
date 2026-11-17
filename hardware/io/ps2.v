//PS/2 port: keyboard or mouse, one of these per device
//2 wires, CLOCK and DATA, both open drain
//device makes the clock, no baud rate
//receiving: 11 bits, one per falling edge of CLOCK
//start (0), 8 data bits lowest first, odd parity, stop (1)
//sending: hold CLOCK low over 100 us, pull DATA low, let CLOCK go
//then 8 data bits, parity, stop, device pulls DATA low to ack
//mouse needs 0xF4 before it sends anything
//byte waits in received_byte, byte_waiting = 1 until CPU takes it

module ps2 (
    input wire clk, //27 MHz
    input wire rst,

    //the two wires
    input wire ps2_clock_in, //CLOCK wire
    input wire ps2_data_in, //DATA wire
    output reg pull_clock_low, //1 = pull CLOCK low, 0 = let go
    output reg pull_data_low, //1 = pull DATA low, 0 = let go

    //receiving
    input wire take_byte, //CPU read the byte
    output reg [7:0] received_byte,
    output reg byte_waiting,

    //sending
    input wire send, //send byte_to_send
    input wire [7:0] byte_to_send,
    output wire is_sending //1 while a byte is going out
);

//catch twice
reg clock_caught = 1'b1;
reg clock_safe = 1'b1;
reg data_caught = 1'b1;
reg data_safe = 1'b1;
always @(posedge clk) begin
    clock_caught <= ps2_clock_in;
    clock_safe <= clock_caught;
    data_caught <= ps2_data_in;
    data_safe <= data_caught;
end

//falling edges of CLOCK, must stay changed 16 ticks (0.6 us) to count
reg clock_steady = 1'b1; //cleaned up clock
reg [3:0] steady_count = 4'd0;
reg is_falling_edge = 1'b0; //1 for one tick on 1 to 0
always @(posedge clk) begin
    is_falling_edge <= 1'b0;
    if (clock_safe == clock_steady) begin
        steady_count <= 4'd0;
    end else if (steady_count == 4'd15) begin
        steady_count <= 4'd0;
        clock_steady <= clock_safe;
        if (clock_safe == 1'b0)
            is_falling_edge <= 1'b1;
    end else begin
        steady_count <= steady_count + 4'd1;
    end
end

//sending steps
localparam SEND_IDLE = 2'd0; //not sending
localparam SEND_HOLD_CLOCK = 2'd1; //holding CLOCK low
localparam SEND_BITS = 2'd2; //device clocks our bits out
localparam SEND_ACK = 2'd3; //waiting for ack

reg [1:0] send_state;
assign is_sending = (send_state != SEND_IDLE);

localparam HOLD_TICKS = 13'd4050; //150 us at 27 MHz
localparam TIMEOUT_TICKS = 19'd405000; //15 ms no clock edge, give up

reg [12:0] hold_count;
reg [18:0] silence_count; //ticks since last falling edge
reg [9:0] bits_to_send; //8 data, parity, stop, sent from bit 0 up
reg [3:0] bit_count; //bits received or sent

//receiving, 11 bits, new bit goes in on the left
reg [10:0] bits_so_far;
wire [10:0] frame = {data_safe, bits_so_far[10:1]}; //all 11 bits
wire is_odd_parity = ^frame[9:1]; //1 when data + parity has odd count of 1s
wire is_good_frame = (frame[0] == 1'b0) && (frame[10] == 1'b1) && is_odd_parity;

always @(posedge clk) begin
    if (rst) begin
        send_state <= SEND_IDLE;
        pull_clock_low <= 1'b0;
        pull_data_low <= 1'b0;
        bit_count <= 4'd0;
        bits_so_far <= 11'd0;
        bits_to_send <= 10'd0;
        received_byte <= 8'h00;
        byte_waiting <= 1'b0;
        silence_count <= 19'd0;
        hold_count <= 13'd0;
    end else begin
        //read byte, no longer waiting
        if (take_byte)
            byte_waiting <= 1'b0;

        //silence since last clock edge
        if (is_falling_edge)
            silence_count <= 19'd0;
        else if (silence_count != TIMEOUT_TICKS)
            silence_count <= silence_count + 19'd1;

        case (send_state)
            SEND_IDLE: begin
                if (send) begin
                    //grab the line, hold CLOCK low
                    //odd parity, parity bit 1 when byte has even 1s
                    bits_to_send <= {1'b1, ~^byte_to_send, byte_to_send};
                    pull_clock_low <= 1'b1;
                    hold_count <= 13'd0;
                    bit_count <= 4'd0;
                    send_state <= SEND_HOLD_CLOCK;
                end else begin
                    //long silence, half byte lost, start fresh
                    if (silence_count == TIMEOUT_TICKS)
                        bit_count <= 4'd0;
                    if (is_falling_edge) begin
                        bits_so_far <= frame;
                        if (bit_count == 4'd10) begin
                            //11th bit, keep byte only if frame is good
                            bit_count <= 4'd0;
                            if (is_good_frame) begin
                                received_byte <= frame[8:1];
                                byte_waiting <= 1'b1;
                            end
                        end else begin
                            bit_count <= bit_count + 4'd1;
                        end
                    end
                end
            end

            SEND_HOLD_CLOCK: begin
                //after 150 us pull DATA low (start bit), let go of CLOCK
                if (hold_count == HOLD_TICKS) begin
                    pull_data_low <= 1'b1;
                    pull_clock_low <= 1'b0;
                    silence_count <= 19'd0;
                    send_state <= SEND_BITS;
                end else begin
                    hold_count <= hold_count + 13'd1;
                end
            end

            SEND_BITS: begin
                //next bit on each falling edge
                //0 = pull DATA low, 1 = let go, 10th bit is the stop bit
                if (is_falling_edge) begin
                    pull_data_low <= ~bits_to_send[0];
                    bits_to_send <= {1'b1, bits_to_send[9:1]};
                    if (bit_count == 4'd9)
                        send_state <= SEND_ACK;
                    bit_count <= bit_count + 4'd1;
                end else if (silence_count == TIMEOUT_TICKS) begin
                    //no answer, let go and give up
                    pull_data_low <= 1'b0;
                    send_state <= SEND_IDLE;
                    bit_count <= 4'd0;
                end
            end

            SEND_ACK: begin
                //one more falling edge for the ack, then back to listening
                if (is_falling_edge || (silence_count == TIMEOUT_TICKS)) begin
                    pull_data_low <= 1'b0;
                    send_state <= SEND_IDLE;
                    bit_count <= 4'd0;
                end
            end
        endcase
    end
end

endmodule
