//SPI controller: swaps bytes with the SD card or the ENC28J60 Ethernet chip
//FPGA makes the SPI clock, no interrupt or queue needed
//every exchange is a swap, 8 clock ticks = 1 byte out and 1 byte in
//to only receive send 0xFF
//spi_clock: 0 while resting, bits read on rising edge, changed on falling edge
//spi_mosi: FPGA's bits, highest bit first
//spi_miso: device's bits, highest bit first
//sd_select_n: 0 = SD card selected
//SD card on pins 81-84, Ethernet chip on 56 clock, 54 MOSI, 51 MISO, 48 select
//SD card is the default, its wake up needs clock ticks with nothing selected
//eth_reset_n: 0 = held in reset
//eth_interrupt_n: 0 = packet arrived
//0xFFFF_8028 - 0xFFFF_8034
//SPI_DATA: write = swap this byte, read = byte from the last swap
//SPI_STATUS: bit 0 = busy, bit 1 = Ethernet chip wants attention
//SPI_SELECT: bit 0 = SD card, bit 1 = Ethernet chip, bit 7 = hold Ethernet chip in reset
//SPI_SPEED: 27 MHz ticks per half SPI clock tick
//34 = 397 kHz (reset value, SD wake up needs under 400 kHz), 3 = 4.5 MHz, smallest 2

module spi (
    input wire clk, //27 MHz
    input wire rst,

    //from the bus
    input wire start, //1 for one tick, swap byte_to_send
    input wire [7:0] byte_to_send,
    input wire select_write, //write to SPI_SELECT
    input wire speed_write, //write to SPI_SPEED
    input wire [7:0] write_data, //value for SPI_SELECT and SPI_SPEED

    //to the bus
    output reg [7:0] received_byte, //byte from the last swap
    output wire busy,
    output reg [7:0] selects, //bit 0 = SD card selected
    output reg [7:0] speed,

    //the wires
    output wire spi_clock, //SD card
    output wire spi_mosi,
    input wire spi_miso,
    output wire sd_select_n,
    output wire eth_clock, //Ethernet chip
    output wire eth_mosi,
    input wire eth_miso,
    output wire eth_select_n,
    output wire eth_reset_n,
    input wire eth_interrupt_n,
    output wire eth_waiting //1 = it wants attention
);

//catch twice, both MISOs and the Ethernet INT
reg miso_caught = 1'b1;
reg miso_safe = 1'b1;
reg eth_miso_caught = 1'b1;
reg eth_miso_safe = 1'b1;
reg eth_int_caught = 1'b1;
reg eth_int_safe = 1'b1;
always @(posedge clk) begin
    miso_caught <= spi_miso;
    miso_safe <= miso_caught;
    eth_miso_caught <= eth_miso;
    eth_miso_safe <= eth_miso_caught;
    eth_int_caught <= eth_interrupt_n;
    eth_int_safe <= eth_int_caught;
end
wire use_eth = selects[1]; //Ethernet chip's wires in use
wire miso_now = use_eth ? eth_miso_safe : miso_safe;
reg clock_now; //SPI clock before it goes to a device
wire mosi_now;

reg [7:0] shift_out; //bits to send, next one at bit 7
reg [7:0] shift_in; //bits received, coming in at the bottom
reg [3:0] bits_left; //SPI clock ticks left in this swap
reg [7:0] half_count; //clk ticks left in this half

assign busy = (bits_left != 4'd0);
assign mosi_now = busy ? shift_out[7] : 1'b1; //MOSI high while resting
assign spi_clock = use_eth ? 1'b0 : clock_now; //SD card pins
assign spi_mosi = use_eth ? 1'b1 : mosi_now;
assign sd_select_n = ~selects[0];
assign eth_clock = use_eth ? clock_now : 1'b0; //Ethernet pins, only while selected
assign eth_mosi = use_eth ? mosi_now : 1'b1;
assign eth_select_n = ~selects[1];
assign eth_reset_n = ~selects[7];
assign eth_waiting = ~eth_int_safe;

always @(posedge clk) begin
    if (rst) begin
        clock_now <= 1'b0;
        shift_out <= 8'hFF;
        shift_in <= 8'h00;
        bits_left <= 4'd0;
        half_count <= 8'd0;
        received_byte <= 8'hFF;
        selects <= 8'h00; //nothing selected
        speed <= 8'd34; //slow, 397 kHz
    end else begin
        if (select_write)
            selects <= write_data;
        if (speed_write)
            speed <= (write_data < 8'd2) ? 8'd2 : write_data; //never faster than 2

        if (!busy) begin
            //resting: start a swap when asked
            if (start) begin
                shift_out <= byte_to_send;
                bits_left <= 4'd8;
                half_count <= speed;
                clock_now <= 1'b0;
            end
        end else if (half_count != 8'd1) begin
            half_count <= half_count - 8'd1; //wait out this half
        end else begin
            half_count <= speed;
            if (!clock_now) begin
                //clock rises, read MISO
                clock_now <= 1'b1;
                shift_in <= {shift_in[6:0], miso_now};
            end else begin
                //clock falls, next bit goes out
                clock_now <= 1'b0;
                bits_left <= bits_left - 4'd1;
                shift_out <= {shift_out[6:0], 1'b1};
                if (bits_left == 4'd1)
                    received_byte <= shift_in; //all 8 bits in
            end
        end
    end
end

endmodule
