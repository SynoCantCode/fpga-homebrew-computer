//UART rx:
//same concept as tx

module uart_rx #(
    parameter CLOCKS_PER_BIT = 234
) (

    input wire clk,
    input wire rst,
    input wire rx,
    input wire take_byte,
    output reg [7:0] received_byte,
    output reg byte_waiting

);

//catch twice
reg rx_caught = 1'b1;
reg rx_safe = 1'b1;
always @(posedge clk) begin
    rx_caught <= rx;
    rx_safe <= rx_caught;
end

//4 steps

localparam STATE_IDLE = 2'd0;
localparam STATE_START = 2'd1;
localparam STATE_DATA = 2'd2;
localparam STATE_STOP = 2'd3;

reg [1:0] state;
reg [15:0] tick_count;
reg [2:0] bit_index;
reg [7:0] bits_so_far;

always @(posedge clk) begin
    if (rst) begin
        state <= STATE_IDLE;
        tick_count <= 16'd0;
        bit_index <= 3'd0;
        bits_so_far <= 8'h00;
        received_byte <= 8'h00;
        byte_waiting <= 1'b0;
    end else begin
        //read byte, no longer waiting
        if (take_byte)
            byte_waiting <= 1'b0;

        case (state)
            STATE_IDLE: begin
                if (rx_safe == 1'b0) begin
                    state <= STATE_START;
                    tick_count <= 16'd0;
                end
            end

        STATE_START: begin
            if (tick_count == ((CLOCKS_PER_BIT / 2) - 1)) begin
                tick_count <= 16'd0;
                if (rx_safe == 1'b0) begin
                    state <= STATE_DATA;
                    bit_index <= 3'd0;
                end else begin
                    state <= STATE_IDLE; //blip
                end
            end else begin
                tick_count <= tick_count + 16'd1;
            end
        end

        STATE_DATA: begin
             if (tick_count == (CLOCKS_PER_BIT - 1)) begin
                    tick_count <= 16'd0;
                    //lowest bit first, new bit goes in on the left
                    bits_so_far <= {rx_safe, bits_so_far[7:1]};
                    if (bit_index == 3'd7)
                        state <= STATE_STOP;
                    else
                        bit_index <= bit_index + 3'd1;
                end else begin
                    tick_count <= tick_count + 16'd1;
                end
            end

            STATE_STOP: begin
                if (tick_count == (CLOCKS_PER_BIT - 1)) begin
                    tick_count <= 16'd0;
                    state <= STATE_IDLE;
                    //good byte ends with a 1, if not throw it away
                    if (rx_safe == 1'b1) begin
                        received_byte <= bits_so_far;
                        byte_waiting <= 1'b1;
                    end
                end else begin
                    tick_count <= tick_count + 16'd1;
                end
            end
        endcase
    end
end

endmodule