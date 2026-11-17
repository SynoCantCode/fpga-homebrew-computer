//LEDs: 6 lights on board, used for status by kernel
//CPU writes to 0xFFFF_8000, the low 6 bits say which LEDs are on (1 = on)
//They are active low, so this flips bits

module leds (
    input wire clk,
    input wire rst,
    input wire write,
    input wire [5:0] write_data,
    output reg [5:0] value,
    output wire [5:0] led_pins
);

//remember what CPU wrote, all off after reset

always @(posedge clk) begin
    if (rst) begin
        value <= 6'b00_0000;
    end else if (write) begin
        value <= write_data;
    end
end

//flip for real pins: value 1 on becomes pin 0 (lights the LED)

assign led_pins = ~value;

endmodule