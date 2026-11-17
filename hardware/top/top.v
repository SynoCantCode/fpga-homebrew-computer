//the motherboard. Plugs and wires every part together
//its pins are the real board
//top.cst says which FPGA leg each pin is

module top #(

    parameter BOOT_FILE = "sw/os/boot.hex",
    parameter CLOCKS_PER_BIT = 27, //uart: 27 MHz / 27 = 1,000,000 baud
    parameter RESET_COUNTER_BITS = 20, //reset lasts 2^20 ticks (a 20 bit counter), about 39ms
    parameter CLOCKS_PER_TICK = 270000, //timer: 270,000 clock ticks = rings 100 times a second
    parameter HAS_SCREEN = 1, //1 = build the HDMI screen, tests set 0
    parameter SDRAM_POWER_UP_TICKS = 5600, //SDRAM 200 us power-up wait, tests make it short
    parameter BREAK_TICKS = 13500, //PC reset: uart_rx held low this long = 0.5 ms
    parameter USE_CACHE = 1, //1 = instruction cache serves SDRAM instruction fetches
    parameter SIMULATE_VIDEO = 0 //1 = run the graphics card's screen side on the system clock when HAS_SCREEN = 0

) (

    input wire clk,
    input wire reset_button,
    output wire [5:0] led_pins,
    output wire uart_tx,
    input wire uart_rx,

    //PS/2 keyboard and mouse, two-way wires, only pulled low or let go
    inout wire ps2_keyboard_clock,
    inout wire ps2_keyboard_data,
    inout wire ps2_mouse_clock,
    inout wire ps2_mouse_data,

    //microSD slot in SPI mode: clock, MOSI, MISO, chip select
    output wire sd_clock,
    output wire sd_mosi,
    input wire sd_miso,
    output wire sd_select_n,

    //I2C to the DS3231 clock and the MCP23017, pins 41, 42 on header J5, open drain
    inout wire i2c_scl,
    inout wire i2c_sda,

    //ENC28J60 Ethernet on SPI, pins 56 clock, 54 MOSI, 51 MISO, 48 select, 55 INT, 49 RESET
    output wire eth_clock,
    output wire eth_mosi,
    input wire eth_miso,
    output wire eth_select_n,
    input wire eth_interrupt_n,
    output wire eth_reset_n,

    //HDMI: 4 wire pairs, pixel clock, then blue, green, red
    output wire tmds_clk_p,
    output wire tmds_clk_n,
    output wire [2:0] tmds_data_p,
    output wire [2:0] tmds_data_n,

    //SDRAM chip inside the FPGA package, names are fixed, Gowin connects them itself
    output wire O_sdram_clk,
    output wire O_sdram_cke,
    output wire O_sdram_cs_n,
    output wire O_sdram_ras_n,
    output wire O_sdram_cas_n,
    output wire O_sdram_wen_n,
    output wire [1:0] O_sdram_ba,
    output wire [10:0] O_sdram_addr,
    output wire [3:0] O_sdram_dqm,
    inout wire [31:0] IO_sdram_dq

);

//2 flip-flop measure

reg button_caught = 1'b0;
reg button_safe = 1'b0;
always @(posedge clk) begin
    button_caught <= reset_button;
    button_safe <= button_caught;
end

//reset from the PC: uart_rx held low for BREAK_TICKS (0.5 ms)
//a normal byte is low for ~9 us at most
//works like the reset button
reg rx_caught = 1'b1;
reg rx_safe = 1'b1;
reg [13:0] break_count = 0; //ticks the line has been low
wire pc_break = (break_count >= BREAK_TICKS);
always @(posedge clk) begin
    rx_caught <= uart_rx;
    rx_safe <= rx_caught;
    if (rx_safe)
        break_count <= 0; //high again, start over
    else if (!pc_break)
        break_count <= break_count + 1;
end

reg [RESET_COUNTER_BITS-1:0] reset_counter = 0; //start at 0
wire rst = (reset_counter != {RESET_COUNTER_BITS{1'b1}}); //reset until counter is all 1s
always @(posedge clk) begin
    if (button_safe || pc_break) //button or PC break
        reset_counter <= 0;
    else if (rst)
        reset_counter <= reset_counter +1;
end

//the wires between the parts

wire [31:0] mem_address;
wire [31:0] mem_write_data;
wire mem_we;
wire [3:0] mem_byte_enable;
wire [31:0] mem_read_data;
wire halted;
wire mem_valid;
wire mem_wait;
wire sdram_request;
wire sdram_done;
wire [31:0] sdram_read_data;

wire ram_we;
wire [31:0] ram_read_data;
wire leds_write;
wire [5:0] leds_value;
wire uart_send;
wire uart_busy;
wire uart_take_byte;
wire [7:0] uart_received_byte;
wire uart_byte_waiting;
wire keyboard_send;
wire keyboard_take_byte;
wire [7:0] keyboard_received_byte;
wire keyboard_byte_waiting;
wire keyboard_is_sending;
wire mouse_send;
wire mouse_take_byte;
wire [7:0] mouse_received_byte;
wire mouse_byte_waiting;
wire mouse_is_sending;
wire interrupts_enabled_write;
wire [3:0] interrupts_pending;
wire [3:0] interrupts_enabled;
wire irq;
wire timer_acknowledge;
wire [31:0] timer_ticks;
wire timer_ringing;
wire spi_start;
wire spi_select_write;
wire spi_speed_write;
wire [7:0] spi_received_byte;
wire spi_busy;
wire [7:0] spi_selects;
wire [7:0] spi_speed;
wire spi_eth_waiting;
wire text_write;
wire [11:0] text_cell;
wire [15:0] text_read_data;
wire graphics_write;
wire [11:0] graphics_address;
wire [31:0] graphics_read_data;
wire video_request;
wire [22:0] video_address;
wire video_word_valid;
wire [7:0] video_word_index;
wire [31:0] video_word;
wire video_done;
wire blit_request;
wire blit_write;
wire [22:0] blit_address;
wire [8:0] blit_count;
wire blit_word_valid;
wire [7:0] blit_word_index;
wire [31:0] blit_word;
wire [8:0] blit_index;
wire [31:0] blit_write_data;
wire [3:0] blit_write_mask;
wire blit_done;
wire mem_is_fetch;
wire flush_cache;
wire cache_fetch;
wire cache_hit;
wire [31:0] cache_instruction;
wire cache_write_seen;
wire line_request;
wire [22:0] line_address;
wire line_word_valid;
wire [7:0] line_word_index;
wire [31:0] line_word;
wire line_done;

//the parts
cpu the_cpu (
    .clk(clk),
    .rst(rst),
    .mem_address(mem_address),
    .mem_write_data(mem_write_data),
    .mem_we(mem_we),
    .mem_byte_enable(mem_byte_enable),
    .mem_read_data(mem_read_data),
    .mem_wait(mem_wait), //1 = SDRAM not ready, stay in this step
    .mem_valid(mem_valid), //CPU is asking
    .mem_is_fetch(mem_is_fetch), //for an instruction
    .flush_cache(flush_cache), //FLUSH, to the instruction cache
    .irq(irq), //from the interrupt controller
    .halted(halted)
);

bus #(.USE_CACHE(USE_CACHE)) decoder (
    .clk(clk),
    .rst(rst),
    .mem_address(mem_address),
    .mem_write_data(mem_write_data),
    .mem_we(mem_we),
    .mem_valid(mem_valid),
    .mem_is_fetch(mem_is_fetch),
    .mem_wait(mem_wait),
    .cache_fetch(cache_fetch),
    .cache_hit(cache_hit),
    .cache_instruction(cache_instruction),
    .cache_write_seen(cache_write_seen),
    .mem_read_data(mem_read_data),
    .sdram_request(sdram_request),
    .sdram_done(sdram_done),
    .sdram_read_data(sdram_read_data),
    .ram_we(ram_we),
    .ram_read_data(ram_read_data),
    .leds_write(leds_write),
    .leds_value(leds_value),
    .uart_send(uart_send),
    .uart_busy(uart_busy),
    .uart_take_byte(uart_take_byte),
    .uart_received_byte(uart_received_byte),
    .uart_byte_waiting(uart_byte_waiting),
    .keyboard_send(keyboard_send),
    .keyboard_take_byte(keyboard_take_byte),
    .keyboard_received_byte(keyboard_received_byte),
    .keyboard_byte_waiting(keyboard_byte_waiting),
    .keyboard_is_sending(keyboard_is_sending),
    .mouse_send(mouse_send),
    .mouse_take_byte(mouse_take_byte),
    .mouse_received_byte(mouse_received_byte),
    .mouse_byte_waiting(mouse_byte_waiting),
    .mouse_is_sending(mouse_is_sending),
    .interrupts_enabled_write(interrupts_enabled_write),
    .interrupts_pending(interrupts_pending),
    .interrupts_enabled(interrupts_enabled),
    .timer_acknowledge(timer_acknowledge),
    .timer_ticks(timer_ticks),
    .spi_start(spi_start),
    .spi_select_write(spi_select_write),
    .spi_speed_write(spi_speed_write),
    .spi_received_byte(spi_received_byte),
    .spi_busy(spi_busy),
    .spi_selects(spi_selects),
    .spi_speed(spi_speed),
    .spi_eth_waiting(spi_eth_waiting),
    .i2c_write(i2c_write),
    .i2c_wires(i2c_wires),
    .text_write(text_write),
    .text_cell(text_cell),
    .text_read_data(text_read_data),
    .graphics_write(graphics_write),
    .graphics_address(graphics_address),
    .graphics_read_data(graphics_read_data)
);

memory #(.INIT_FILE(BOOT_FILE), .ADDRESS_BITS(15)) main_memory ( //32 KB block RAM, boot ROM (first 16 KB) + RAM
    .clk(clk),
    .we(ram_we), //from the bus
    .byte_enable(mem_byte_enable),
    .address(mem_address),
    .write_data(mem_write_data),
    .read_data(ram_read_data)
);

//SDRAM controller, 8 MB at 0x1000_0000
sdram #(.POWER_UP_TICKS(SDRAM_POWER_UP_TICKS)) big_memory (
    .clk(clk),
    .rst(rst),
    .request(sdram_request),
    .write(mem_we),
    .address(mem_address[22:0]),
    .write_data(mem_write_data),
    .byte_enable(mem_byte_enable),
    .read_data(sdram_read_data),
    .done(sdram_done),
    .is_ready(),
    .video_request(video_request), //graphics card door
    .video_address(video_address),
    .video_word_valid(video_word_valid),
    .video_word_index(video_word_index),
    .video_word(video_word),
    .video_done(video_done),
    .blit_request(blit_request), //blitter door
    .blit_write(blit_write),
    .blit_address(blit_address),
    .blit_count(blit_count),
    .blit_word_valid(blit_word_valid),
    .blit_word_index(blit_word_index),
    .blit_word(blit_word),
    .blit_index(blit_index),
    .blit_write_data(blit_write_data),
    .blit_write_mask(blit_write_mask),
    .blit_done(blit_done),
    .line_request(line_request), //instruction cache door
    .line_address(line_address),
    .line_word_valid(line_word_valid),
    .line_word_index(line_word_index),
    .line_word(line_word),
    .line_done(line_done),
    .sdram_clk(O_sdram_clk),
    .sdram_cke(O_sdram_cke),
    .sdram_cs_n(O_sdram_cs_n),
    .sdram_ras_n(O_sdram_ras_n),
    .sdram_cas_n(O_sdram_cas_n),
    .sdram_we_n(O_sdram_wen_n),
    .sdram_ba(O_sdram_ba),
    .sdram_addr(O_sdram_addr),
    .sdram_dqm(O_sdram_dqm),
    .sdram_dq(IO_sdram_dq)
);

//instruction cache
icache instruction_cache (
    .clk(clk),
    .rst(rst),
    .fetch(cache_fetch),
    .fetch_address(mem_address[22:0]),
    .hit(cache_hit),
    .instruction(cache_instruction),
    .write_seen(cache_write_seen),
    .write_address(mem_address[22:0]),
    .flush(flush_cache),
    .line_request(line_request),
    .line_address(line_address),
    .line_word_valid(line_word_valid),
    .line_word_index(line_word_index),
    .line_word(line_word),
    .line_done(line_done)
);

leds status_lights (
    .clk(clk),
    .rst(rst),
    .write(leds_write),
    .write_data(mem_write_data[5:0]),
    .value(leds_value),
    .led_pins(led_pins)
);

uart_tx #(.CLOCKS_PER_BIT(CLOCKS_PER_BIT)) serial (
    .clk(clk),
    .rst(rst),
    .send(uart_send),
    .byte_to_send(mem_write_data[7:0]),
    .busy(uart_busy),
    .tx(uart_tx)
);

uart_rx #(.CLOCKS_PER_BIT(CLOCKS_PER_BIT)) serial_in (
    .clk(clk),
    .rst(rst),
    .rx(uart_rx),
    .take_byte(uart_take_byte),
    .received_byte(uart_received_byte),
    .byte_waiting(uart_byte_waiting)
);

//keyboard and mouse, one PS/2 port each
//open drain, 1'bz = let go, pull-up brings it high
wire keyboard_pull_clock;
wire keyboard_pull_data;
wire mouse_pull_clock;
wire mouse_pull_data;

assign ps2_keyboard_clock = keyboard_pull_clock ? 1'b0 : 1'bz;
assign ps2_keyboard_data = keyboard_pull_data ? 1'b0 : 1'bz;
assign ps2_mouse_clock = mouse_pull_clock ? 1'b0 : 1'bz;
assign ps2_mouse_data = mouse_pull_data ? 1'b0 : 1'bz;

ps2 keyboard (
    .clk(clk),
    .rst(rst),
    .ps2_clock_in(ps2_keyboard_clock),
    .ps2_data_in(ps2_keyboard_data),
    .pull_clock_low(keyboard_pull_clock),
    .pull_data_low(keyboard_pull_data),
    .take_byte(keyboard_take_byte),
    .received_byte(keyboard_received_byte),
    .byte_waiting(keyboard_byte_waiting),
    .send(keyboard_send),
    .byte_to_send(mem_write_data[7:0]),
    .is_sending(keyboard_is_sending)
);

ps2 mouse (
    .clk(clk),
    .rst(rst),
    .ps2_clock_in(ps2_mouse_clock),
    .ps2_data_in(ps2_mouse_data),
    .pull_clock_low(mouse_pull_clock),
    .pull_data_low(mouse_pull_data),
    .take_byte(mouse_take_byte),
    .received_byte(mouse_received_byte),
    .byte_waiting(mouse_byte_waiting),
    .send(mouse_send),
    .byte_to_send(mem_write_data[7:0]),
    .is_sending(mouse_is_sending)
);

//I2C pins, CPU sets SCL and SDA and reads them back
wire i2c_write;
wire [1:0] i2c_wires;
i2c_pins i2c_link (
    .clk(clk),
    .rst(rst),
    .write(i2c_write),
    .write_data(mem_write_data[1:0]),
    .wires_now(i2c_wires),
    .i2c_scl(i2c_scl),
    .i2c_sda(i2c_sda)
);

//SPI controller, SD card and Ethernet
spi sd_link (
    .clk(clk),
    .rst(rst),
    .start(spi_start),
    .byte_to_send(mem_write_data[7:0]),
    .select_write(spi_select_write),
    .speed_write(spi_speed_write),
    .write_data(mem_write_data[7:0]),
    .received_byte(spi_received_byte),
    .busy(spi_busy),
    .selects(spi_selects),
    .speed(spi_speed),
    .spi_clock(sd_clock),
    .spi_mosi(sd_mosi),
    .spi_miso(sd_miso),
    .sd_select_n(sd_select_n),
    .eth_clock(eth_clock),
    .eth_mosi(eth_mosi),
    .eth_miso(eth_miso),
    .eth_select_n(eth_select_n),
    .eth_reset_n(eth_reset_n),
    .eth_interrupt_n(eth_interrupt_n),
    .eth_waiting(spi_eth_waiting)
);

//timer, rings 100 times a second and counts the rings
timer #(.CLOCKS_PER_TICK(CLOCKS_PER_TICK)) clock_tick (
    .clk(clk),
    .rst(rst),
    .acknowledge(timer_acknowledge),
    .ticks(timer_ticks),
    .ringing(timer_ringing)
);

//interrupt controller, every doorbell in, one irq out
//keyboard, mouse and UART ring while a byte is waiting
interrupts doorbells (
    .clk(clk),
    .rst(rst),
    .timer_ringing(timer_ringing),
    .keyboard_ringing(keyboard_byte_waiting),
    .mouse_ringing(mouse_byte_waiting),
    .uart_ringing(uart_byte_waiting),
    .enabled_write(interrupts_enabled_write),
    .write_data(mem_write_data[3:0]),
    .pending(interrupts_pending),
    .enabled(interrupts_enabled),
    .irq(irq)
);

//the screen: graphics card makes the picture, HDMI sends it
//runs on its own pixel clock, separate from the CPU
//clocks and HDMI only built when HAS_SCREEN = 1
wire pixel_clk;
wire video_rst;
wire [7:0] red;
wire [7:0] green;
wire [7:0] blue;
wire hsync;
wire vsync;
wire is_visible;

generate
    if (HAS_SCREEN) begin : screen
        wire serial_clk;
        wire is_locked;

        video_clocks clocks (
            .clk_27mhz(clk),
            .serial_clk(serial_clk),
            .pixel_clk(pixel_clk),
            .is_locked(is_locked)
        );

        //screen's own reset, waits for its clocks to lock
        assign video_rst = !is_locked;

        hdmi_out hdmi (
            .pixel_clk(pixel_clk),
            .serial_clk(serial_clk),
            .rst(video_rst),
            .red(red),
            .green(green),
            .blue(blue),
            .hsync(hsync),
            .vsync(vsync),
            .is_visible(is_visible),
            .tmds_clk_p(tmds_clk_p),
            .tmds_clk_n(tmds_clk_n),
            .tmds_data_p(tmds_data_p),
            .tmds_data_n(tmds_data_n)
        );
    end else begin : no_screen
        //no screen: no pixel clock (or the system clock with SIMULATE_VIDEO), HDMI pins at 0
        assign pixel_clk = SIMULATE_VIDEO ? clk : 1'b0;
        assign video_rst = rst;
        assign tmds_clk_p = 1'b0;
        assign tmds_clk_n = 1'b0;
        assign tmds_data_p = 3'b000;
        assign tmds_data_n = 3'b000;
    end
endgenerate

graphics_card graphics (
    .clk(clk),
    .rst(rst),
    .cpu_address(graphics_address),
    .cpu_write(graphics_write),
    .cpu_write_data(mem_write_data),
    .cpu_read_data(graphics_read_data),
    .text_cell(text_cell),
    .text_write(text_write),
    .text_write_data(mem_write_data[15:0]),
    .text_read_data(text_read_data),
    .video_request(video_request),
    .video_address(video_address),
    .video_word_valid(video_word_valid),
    .video_word_index(video_word_index),
    .video_word(video_word),
    .video_done(video_done),
    .blit_request(blit_request),
    .blit_write(blit_write),
    .blit_address(blit_address),
    .blit_count(blit_count),
    .blit_word_valid(blit_word_valid),
    .blit_word_index(blit_word_index),
    .blit_word(blit_word),
    .blit_index(blit_index),
    .blit_write_data(blit_write_data),
    .blit_write_mask(blit_write_mask),
    .blit_done(blit_done),
    .pixel_clk(pixel_clk),
    .video_rst(video_rst),
    .red(red),
    .green(green),
    .blue(blue),
    .hsync(hsync),
    .vsync(vsync),
    .is_visible(is_visible)
);

endmodule
