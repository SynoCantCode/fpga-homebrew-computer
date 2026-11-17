//Timer: rings the interrupt controller 100 times a second, counts the rings since reset
//270,000 ticks of the 27 MHz clock = 10 ms
//0xFFFF_8024 read: ticks, hundredths of a second since reset
//0xFFFF_8024 write (any value): stops the ringing until the next tick

module timer #(
    parameter CLOCKS_PER_TICK = 270000 //small in tests
) (
    input wire clk,
    input wire rst,
    input wire acknowledge, //CPU wrote to the timer
    output reg [31:0] ticks,
    output reg ringing
);

//counts 0 up to CLOCKS_PER_TICK - 1, 19 bits
reg [18:0] count;

always @(posedge clk) begin
    if (rst) begin
        count <= 19'd0;
        ticks <= 32'd0;
        ringing <= 1'b0;
    end else begin
        //CPU heard the ring, stop ringing
        if (acknowledge)
            ringing <= 1'b0;

        //10 ms passed, count it and ring
        //new ring wins over acknowledge
        if (count == CLOCKS_PER_TICK - 1) begin
            count <= 19'd0;
            ticks <= ticks + 32'd1;
            ringing <= 1'b1;
        end else begin
            count <= count + 19'd1;
        end
    end
end

endmodule
