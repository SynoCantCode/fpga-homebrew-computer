/*
Current Map:
RAM 0x0000_0000 - 0x0000_7FFF (first 16 KB is the boot ROM, read only)
LEDs 0xFFFF_8000
UART data 0xFFFF_8004 (write = send a byte, read = take the received byte)
UART status 0xFFFF_8008 (bit 0 = busy sending, bit 1 = byte waiting)
Keyboard data 0xFFFF_800C, status 0xFFFF_8010 (same as the UART)
Mouse data 0xFFFF_8014, status 0xFFFF_8018 (same as the UART)
Interrupt pending 0xFFFF_801C (bit 0 timer, 1 keyboard, 2 mouse, 3 UART)
Interrupt enabled 0xFFFF_8020
Timer 0xFFFF_8024 (read = ticks, hundredths of a second, write = acknowledge)
SPI data 0xFFFF_8028 (write = swap a byte, read = the byte that came back)
SPI status 0xFFFF_802C (bit 0 = busy), select 0xFFFF_8030 (bit 0 = SD card), speed 0xFFFF_8034
SDRAM 0x1000_0000 - 0x107F_FFFF (8 MB, slow, CPU waits)
Text screen 0x2000_0000 - 0x2000_3FFF (one word per cell, cell N at 0x2000_0000 + N x 4)
Graphics card 0xFFFF_9000 - 0xFFFF_9FFF
*/
module bus #(
    parameter USE_CACHE = 1 //1 = SDRAM instruction fetches go through the cache
) (
    input wire clk,
    input wire rst,

    //From CPU
    input wire [31:0] mem_address,
    input wire [31:0] mem_write_data,
    input wire mem_we,
    input wire mem_valid, //1 = CPU is asking, FETCH or MEMORY step
    input wire mem_is_fetch, //1 = asking for an instruction
    output wire mem_wait, //1 = not ready, CPU stays in its step

    //back to the CPU
    output reg [31:0] mem_read_data,

    //SDRAM controller, request held until done
    output wire sdram_request,
    input wire sdram_done,
    input wire [31:0] sdram_read_data,

    //instruction cache, answers SDRAM instruction fetches
    output wire cache_fetch, //1 = CPU is fetching an instruction from the SDRAM
    input wire cache_hit, //1 = cache has it
    input wire [31:0] cache_instruction,
    output wire cache_write_seen, //1 = CPU is writing to the SDRAM

    //RAM
    output wire ram_we,
    input wire [31:0] ram_read_data,

    //LEDs
    output wire leds_write,
    input wire [5:0] leds_value,

    //UART TX
    output wire uart_send,
    input wire uart_busy,

    //UART RX
    output wire uart_take_byte,
    input wire [7:0] uart_received_byte,
    input wire uart_byte_waiting,

    //PS/2 keyboard, same kind of pins as the UART
    output wire keyboard_send,
    output wire keyboard_take_byte,
    input wire [7:0] keyboard_received_byte,
    input wire keyboard_byte_waiting,
    input wire keyboard_is_sending,

    //PS/2 mouse
    output wire mouse_send,
    output wire mouse_take_byte,
    input wire [7:0] mouse_received_byte,
    input wire mouse_byte_waiting,
    input wire mouse_is_sending,

    //interrupt controller
    output wire interrupts_enabled_write,
    input wire [3:0] interrupts_pending,
    input wire [3:0] interrupts_enabled,

    //timer
    output wire timer_acknowledge,
    input wire [31:0] timer_ticks,

    //SPI controller, SD card and Ethernet
    output wire spi_start,
    output wire spi_select_write,
    output wire spi_speed_write,
    input wire [7:0] spi_received_byte,
    input wire spi_busy,
    input wire [7:0] spi_selects,
    input wire [7:0] spi_speed,
    input wire spi_eth_waiting,

    //I2C pins, CPU sets the two wires and reads them back
    output wire i2c_write,
    input wire [1:0] i2c_wires,

    //text screen
    output wire text_write,
    output wire [11:0] text_cell,
    input wire [15:0] text_read_data,

    //graphics card registers, 4 KB window, offset = bottom 12 bits
    output wire graphics_write,
    output wire [11:0] graphics_address,
    input wire [31:0] graphics_read_data

);

//addressing

//32 KB, 0x0000_0000 - 0x0000_7FFF
wire is_ram = (mem_address[31:15] == 17'h0_0000);
//boot ROM = first 16 KB of the same block RAM
wire is_rom = (mem_address[31:14] == 18'h0_0000);
wire is_leds = (mem_address == 32'hFFFF_8000);
wire is_uart_data = (mem_address == 32'hFFFF_8004);
wire is_uart_status = (mem_address == 32'hFFFF_8008);
wire is_keyboard_data = (mem_address == 32'hFFFF_800C);
wire is_keyboard_status = (mem_address == 32'hFFFF_8010);
wire is_mouse_data = (mem_address == 32'hFFFF_8014);
wire is_mouse_status = (mem_address == 32'hFFFF_8018);
wire is_interrupts_pending = (mem_address == 32'hFFFF_801C);
wire is_interrupts_enabled = (mem_address == 32'hFFFF_8020);
wire is_timer = (mem_address == 32'hFFFF_8024);
wire is_spi_data = (mem_address == 32'hFFFF_8028);
wire is_spi_status = (mem_address == 32'hFFFF_802C);
wire is_spi_select = (mem_address == 32'hFFFF_8030);
wire is_spi_speed = (mem_address == 32'hFFFF_8034);
wire is_i2c = (mem_address == 32'hFFFF_8038);
//text screen 0x2000_0000 - 0x2000_3FFF
wire is_text = (mem_address[31:14] == 18'h0_8000);
//SDRAM 0x1000_0000 - 0x107F_FFFF, 8 MB
wire is_sdram = (mem_address[31:23] == 9'h020);
//graphics card 0xFFFF_9000 - 0xFFFF_9FFF
wire is_graphics = (mem_address[31:12] == 20'hF_FFF9);

//writes: the part's address AND the CPU is writing

//ROM part is never written
assign ram_we = is_ram && !is_rom && mem_we;
assign leds_write = is_leds && mem_we;
assign uart_send = is_uart_data && mem_we;

//text screen, one cell per word, bottom 16 bits = background, letter colour, letter
//0x2000_0008 is cell 2, use STORE not STOREB
assign text_write = is_text && mem_we;
assign text_cell = mem_address[13:2];

//graphics card, offset picks the register
assign graphics_write = is_graphics && mem_we;
assign graphics_address = mem_address[11:0];

//reading UART data takes the received byte
assign uart_take_byte = is_uart_data && !mem_we;

//keyboard and mouse work like the UART
assign keyboard_send = is_keyboard_data && mem_we;
assign keyboard_take_byte = is_keyboard_data && !mem_we;
assign mouse_send = is_mouse_data && mem_we;
assign mouse_take_byte = is_mouse_data && !mem_we;

//interrupt enable switches, pending is read only
assign interrupts_enabled_write = is_interrupts_enabled && mem_we;

//timer, any write = acknowledge
assign timer_acknowledge = is_timer && mem_we;

//SPI, write data = swap a byte
assign spi_start = is_spi_data && mem_we;
assign spi_select_write = is_spi_select && mem_we;
assign spi_speed_write = is_spi_speed && mem_we;
//I2C, bit 0 SCL, bit 1 SDA, 1 = let go
assign i2c_write = is_i2c && mem_we;

//SDRAM is slow, CPU waits until done
//instruction fetches go to the cache, CPU waits until a hit
//USE_CACHE = 0 leaves the cache out
wire fetch_to_cache = mem_is_fetch && (USE_CACHE != 0);
assign cache_fetch = is_sdram && mem_valid && fetch_to_cache;
assign cache_write_seen = is_sdram && mem_valid && mem_we;
assign sdram_request = is_sdram && mem_valid && !fetch_to_cache;
assign mem_wait = (sdram_request && !sdram_done) || (cache_fetch && !cache_hit);

//reads: memory answers one tick after it gets address

//5 bits, up to 32 choices
localparam READ_NOTHING = 5'd0;
localparam READ_RAM = 5'd1;
localparam READ_LEDS = 5'd2;
localparam READ_UART_STATUS = 5'd3;
localparam READ_UART_DATA = 5'd4;
localparam READ_TEXT = 5'd5;
localparam READ_KEYBOARD_DATA = 5'd6;
localparam READ_KEYBOARD_STATUS = 5'd7;
localparam READ_MOUSE_DATA = 5'd8;
localparam READ_MOUSE_STATUS = 5'd9;
localparam READ_INTERRUPTS_PENDING = 5'd10;
localparam READ_INTERRUPTS_ENABLED = 5'd11;
localparam READ_TIMER = 5'd12;
localparam READ_SDRAM = 5'd13;
localparam READ_SPI_DATA = 5'd14;
localparam READ_SPI_STATUS = 5'd15;
localparam READ_SPI_SELECT = 5'd16;
localparam READ_SPI_SPEED = 5'd17;
localparam READ_GRAPHICS = 5'd18;
localparam READ_CACHE = 5'd19;
localparam READ_I2C = 5'd20;

reg[4:0] read_choice;
always @(posedge clk) begin
    if (rst)
        read_choice <= READ_NOTHING;
    else if (is_ram)
        read_choice <= READ_RAM;
    else if (is_leds)
        read_choice <= READ_LEDS;
    else if (is_uart_status)
        read_choice <= READ_UART_STATUS;
    else if (is_uart_data)
        read_choice <= READ_UART_DATA;
    else if (is_text)
        read_choice <= READ_TEXT;
    else if (is_keyboard_data)
        read_choice <= READ_KEYBOARD_DATA;
    else if (is_keyboard_status)
        read_choice <= READ_KEYBOARD_STATUS;
    else if (is_mouse_data)
        read_choice <= READ_MOUSE_DATA;
    else if (is_mouse_status)
        read_choice <= READ_MOUSE_STATUS;
    else if (is_interrupts_pending)
        read_choice <= READ_INTERRUPTS_PENDING;
    else if (is_interrupts_enabled)
        read_choice <= READ_INTERRUPTS_ENABLED;
    else if (is_timer)
        read_choice <= READ_TIMER;
    else if (is_sdram)
        read_choice <= fetch_to_cache ? READ_CACHE : READ_SDRAM; //instructions come from the cache
    else if (is_spi_data)
        read_choice <= READ_SPI_DATA;
    else if (is_spi_status)
        read_choice <= READ_SPI_STATUS;
    else if (is_spi_select)
        read_choice <= READ_SPI_SELECT;
    else if (is_spi_speed)
        read_choice <= READ_SPI_SPEED;
    else if (is_i2c)
        read_choice <= READ_I2C;
    else if (is_graphics)
        read_choice <= READ_GRAPHICS;
    else
        read_choice <= READ_NOTHING;

end

//the answer: zeros on left to fill 32 bits

always @(*) begin
    case(read_choice)
        READ_RAM:           mem_read_data = ram_read_data;
        READ_LEDS:          mem_read_data = {26'h000_0000, leds_value};
        READ_UART_STATUS:   mem_read_data = {30'h0000_0000, uart_byte_waiting, uart_busy};
        READ_UART_DATA:     mem_read_data = {24'h00_0000, uart_received_byte};
        READ_TEXT:          mem_read_data = {16'h0000, text_read_data};
        READ_KEYBOARD_DATA:   mem_read_data = {24'h00_0000, keyboard_received_byte};
        READ_KEYBOARD_STATUS: mem_read_data = {30'h0000_0000, keyboard_byte_waiting, keyboard_is_sending};
        READ_MOUSE_DATA:      mem_read_data = {24'h00_0000, mouse_received_byte};
        READ_MOUSE_STATUS:    mem_read_data = {30'h0000_0000, mouse_byte_waiting, mouse_is_sending};
        READ_INTERRUPTS_PENDING: mem_read_data = {28'h000_0000, interrupts_pending};
        READ_INTERRUPTS_ENABLED: mem_read_data = {28'h000_0000, interrupts_enabled};
        READ_TIMER:           mem_read_data = timer_ticks;
        READ_SDRAM:           mem_read_data = sdram_read_data; //word the SDRAM controller caught
        READ_SPI_DATA:        mem_read_data = {24'h00_0000, spi_received_byte};
        READ_SPI_STATUS:      mem_read_data = {30'h0000_0000, spi_eth_waiting, spi_busy};
        READ_SPI_SELECT:      mem_read_data = {24'h00_0000, spi_selects};
        READ_SPI_SPEED:       mem_read_data = {24'h00_0000, spi_speed};
        READ_I2C:             mem_read_data = {30'h0000_0000, i2c_wires};
        READ_GRAPHICS:        mem_read_data = graphics_read_data; //answers one tick after the address
        READ_CACHE:           mem_read_data = cache_instruction; //block RAM, also one tick after
        default:            mem_read_data = 32'h0000_0000;
    endcase
end

endmodule
