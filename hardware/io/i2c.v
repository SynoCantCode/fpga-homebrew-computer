//I2C pins: 2 shared wires to the DS3231 clock (0x68) and the MCP23017 (0x20)
//SCL (pin 41) clock, always made by us
//SDA (pin 42) data, both ways
//bit banged, the kernel does the protocol by wiggling the wires
//open drain: pull low or let go, never driven high
//write 0xFFFF_8038: bit 0 = SCL, bit 1 = SDA (1 = let go, 0 = pull low), both let go after reset
//read 0xFFFF_8038: bit 0 = SCL, bit 1 = SDA as they are on the wires

module i2c_pins (
    input wire clk,
    input wire rst,
    input wire write,
    input wire [1:0] write_data,
    output wire [1:0] wires_now,
    inout wire i2c_scl,
    inout wire i2c_sda
);

//what the CPU last said: 1 = let go, 0 = pull low

reg [1:0] let_go;
always @(posedge clk) begin
    if (rst) begin
        let_go <= 2'b11;
    end else if (write) begin
        let_go <= write_data;
    end
end

assign i2c_scl = let_go[0] ? 1'bz : 1'b0;
assign i2c_sda = let_go[1] ? 1'bz : 1'b0;

//read back, catch twice

reg [1:0] first_look;
reg [1:0] settled;
always @(posedge clk) begin
    first_look <= {i2c_sda, i2c_scl};
    settled <= first_look;
end

assign wires_now = settled;

endmodule
