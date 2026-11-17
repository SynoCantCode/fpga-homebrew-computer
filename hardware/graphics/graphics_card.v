//Graphics card, everything that makes the picture
//3 layers, front to back
//1. mouse pointer, 16 x 16, 2 bits a dot (0 = see-through, 1-3 = its colours)
//2. text screen, 80 x 30 cells, background colour 0 is see-through
//3. pixel screen, 640 x 480, 1 byte a pixel from the SDRAM
//byte = colour number 0-255, palette turns it into 24 bit rgb
//mixer shows the front-most layer that is not see-through, black if none
//each layer can be switched off
//Two clocks
//CPU side (registers, SDRAM, line fetcher) on 27MHz clk
//screen side (sweep, layers, mixer) on 25.2MHz pixel_clk
//they meet through two-door RAMs and settings caught with 2 flip-flops
//Registers, 0xFFFF_9000 - 0xFFFF_9FFF, cpu_address = offset
//0x000 GRAPHICS_CONTROL bit 0 = pixels on, bit 1 = text on, bit 2 = pointer on (reset: 0b010)
//0x004 GRAPHICS_PAGE bit 0 = page to show (0 = 0x1020_0000, 1 = 0x1028_0000), from the next frame
//read: bit 0 = page wanted, bit 8 = page being shown
//0x008 GRAPHICS_FRAME read: frames since reset, 60 a second
//0x00C POINTER_X top-left dot x (0-639)
//0x010 POINTER_Y top-left dot y (0-479)
//0x014 POINTER_COLOUR_1 0x00RRGGBB for dots of value 1
//0x018 POINTER_COLOUR_2 value 2
//0x01C POINTER_COLOUR_3 value 3
//0x100-0x13C POINTER_PICTURE 16 words, row 0-15, write only, dot c = bits 2c+1..2c
//0x400-0x7FC PALETTE 256 words, write only, 0x00RRGGBB
//0x200-0x21C blitter registers
//picture comes out 4 pixel ticks after the sweep (text 3, mixer 1), sync is 4 late too

module graphics_card #(
    parameter FONT_FILE = "hw/graphics/font.hex"
) (
    //CPU side, 27MHz system clock
    input wire clk,
    input wire rst,

    //card registers
    input wire [11:0] cpu_address,
    input wire cpu_write,
    input wire [31:0] cpu_write_data,
    output reg [31:0] cpu_read_data, //register at cpu_address, one tick later

    //text screen cells, 0x2000_0000
    input wire [11:0] text_cell,
    input wire text_write,
    input wire [15:0] text_write_data,
    output wire [15:0] text_read_data,

    //SDRAM second door, one row of pixels per burst
    output wire video_request,
    output wire [22:0] video_address,
    input wire video_word_valid,
    input wire [7:0] video_word_index,
    input wire [31:0] video_word,
    input wire video_done,

    //SDRAM third door, blitter bursts
    output wire blit_request,
    output wire blit_write,
    output wire [22:0] blit_address,
    output wire [8:0] blit_count,
    input wire blit_word_valid,
    input wire [7:0] blit_word_index,
    input wire [31:0] blit_word,
    input wire [8:0] blit_index,
    output wire [31:0] blit_write_data,
    output wire [3:0] blit_write_mask,
    input wire blit_done,

    //screen side, 25.2MHz pixel clock
    input wire pixel_clk,
    input wire video_rst,
    output reg [7:0] red,
    output reg [7:0] green,
    output reg [7:0] blue,
    output reg hsync,
    output reg vsync,
    output reg is_visible
);

//CPU side (clk)

reg [2:0] control; //bit 0 pixels, bit 1 text, bit 2 pointer
reg page_wanted;
reg [9:0] pointer_x;
reg [9:0] pointer_y;
reg [23:0] pointer_colour_1;
reg [23:0] pointer_colour_2;
reg [23:0] pointer_colour_3;
wire page_shown;
wire blitter_busy; //blitter is doing a job
wire [31:0] frame_count;

//which register a write goes to
wire is_picture_write = cpu_write && (cpu_address[11:6] == 6'b0001_00); //0x100-0x13C
wire is_palette_write = cpu_write && (cpu_address[11:10] == 2'b01); //0x400-0x7FC

always @(posedge clk) begin
    if (rst) begin
        control <= 3'b010; //text only
        page_wanted <= 1'b0;
        pointer_x <= 10'd320;
        pointer_y <= 10'd240;
        pointer_colour_1 <= 24'h00_00_00;
        pointer_colour_2 <= 24'hFF_FF_FF;
        pointer_colour_3 <= 24'h80_80_80;
    end else if (cpu_write) begin
        case (cpu_address)
            12'h000: control <= cpu_write_data[2:0];
            12'h004: page_wanted <= cpu_write_data[0];
            12'h00C: pointer_x <= cpu_write_data[9:0];
            12'h010: pointer_y <= cpu_write_data[9:0];
            12'h014: pointer_colour_1 <= cpu_write_data[23:0];
            12'h018: pointer_colour_2 <= cpu_write_data[23:0];
            12'h01C: pointer_colour_3 <= cpu_write_data[23:0];
            default: ;
        endcase
    end
end

//reading registers back, picture and palette read as 0
always @(posedge clk) begin
    case (cpu_address)
        12'h000: cpu_read_data <= {29'd0, control};
        12'h004: cpu_read_data <= {23'd0, page_shown, 7'd0, page_wanted};
        12'h008: cpu_read_data <= frame_count;
        12'h00C: cpu_read_data <= {22'd0, pointer_x};
        12'h010: cpu_read_data <= {22'd0, pointer_y};
        12'h014: cpu_read_data <= {8'd0, pointer_colour_1};
        12'h018: cpu_read_data <= {8'd0, pointer_colour_2};
        12'h01C: cpu_read_data <= {8'd0, pointer_colour_3};
        12'h21C: cpu_read_data <= {31'd0, blitter_busy};
        default: cpu_read_data <= 32'd0;
    endcase
end

//blitter, registers 0x200-0x21C
blitter #(.FONT_FILE(FONT_FILE)) painter (
    .clk(clk),
    .rst(rst),
    .cpu_address(cpu_address),
    .cpu_write(cpu_write),
    .cpu_write_data(cpu_write_data),
    .busy(blitter_busy),
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
    .blit_done(blit_done)
);

//line fetcher, next row of pixels from SDRAM into the line buffer
wire line_toggle; //from the screen side
wire [8:0] line_number;
wire buffer_write;
wire [8:0] buffer_write_address;
wire [31:0] buffer_write_data;

line_fetcher fetcher (
    .clk(clk),
    .rst(rst),
    .line_toggle(line_toggle),
    .line_number(line_number),
    .pixels_on(control[0]),
    .page_wanted(page_wanted),
    .page_shown(page_shown),
    .frame_count(frame_count),
    .video_request(video_request),
    .video_address(video_address),
    .video_word_valid(video_word_valid),
    .video_word_index(video_word_index),
    .video_word(video_word),
    .video_done(video_done),
    .buffer_write(buffer_write),
    .buffer_address(buffer_write_address),
    .buffer_data(buffer_write_data)
);

//screen side (pixel_clk)

//text layer, also runs the sweep (x, y)
wire [9:0] x;
wire [9:0] y;
wire [7:0] text_red;
wire [7:0] text_green;
wire [7:0] text_blue;
wire text_hsync;
wire text_vsync;
wire text_visible;
wire text_see_through;

text_mode #(.FONT_FILE(FONT_FILE)) letters (
    .pixel_clk(pixel_clk),
    .rst(video_rst),
    .cpu_clk(clk),
    .cpu_cell(text_cell),
    .cpu_we(text_write),
    .cpu_write_data(text_write_data),
    .cpu_read_data(text_read_data),
    .sweep_x(x),
    .sweep_y(y),
    .red(text_red),
    .green(text_green),
    .blue(text_blue),
    .hsync(text_hsync),
    .vsync(text_vsync),
    .is_visible(text_visible),
    .is_see_through(text_see_through)
);

//settings caught on the pixel side with 2 flip-flops
reg [2:0] control_caught, control_safe;
reg [9:0] pointer_x_caught, pointer_x_safe;
reg [9:0] pointer_y_caught, pointer_y_safe;
reg [23:0] colour_1_caught, colour_1_safe;
reg [23:0] colour_2_caught, colour_2_safe;
reg [23:0] colour_3_caught, colour_3_safe;
always @(posedge pixel_clk) begin
    control_caught <= control;          control_safe <= control_caught;
    pointer_x_caught <= pointer_x;      pointer_x_safe <= pointer_x_caught;
    pointer_y_caught <= pointer_y;      pointer_y_safe <= pointer_y_caught;
    colour_1_caught <= pointer_colour_1; colour_1_safe <= colour_1_caught;
    colour_2_caught <= pointer_colour_2; colour_2_safe <= colour_2_caught;
    colour_3_caught <= pointer_colour_3; colour_3_safe <= colour_3_caught;
end

//tells the line fetcher which row is next, at x = 0
//rows 0-479 shown, row 0 is fetched during row 524
reg toggle;
reg [8:0] next_row;
assign line_toggle = toggle;
assign line_number = next_row;
always @(posedge pixel_clk) begin
    if (video_rst) begin
        toggle <= 1'b0;
        next_row <= 9'd0;
    end else if (x == 10'd0) begin
        if (y == 10'd524) begin
            next_row <= 9'd0;
            toggle <= ~toggle;
        end else if (y < 10'd479) begin
            next_row <= y[8:0] + 9'd1;
            toggle <= ~toggle;
        end
    end
end

//pixel layer
//tick 1: word with this dot from the line buffer, dot 0 = bits 7-0
wire [31:0] buffer_word;
two_door_ram #(.WIDTH(32), .ADDRESS_BITS(9)) line_buffer (
    .write_clk(clk),
    .write_enable(buffer_write),
    .write_address(buffer_write_address),
    .write_data(buffer_write_data),
    .read_clk(pixel_clk),
    .read_address({y[0], x[9:2]}),
    .read_data(buffer_word)
);
reg [1:0] dot_in_word_1;
always @(posedge pixel_clk) dot_in_word_1 <= x[1:0];
wire [7:0] colour_number = buffer_word >> {dot_in_word_1, 3'b000};

//tick 2: colour number through the palette
wire [23:0] palette_rgb;
two_door_ram #(.WIDTH(24), .ADDRESS_BITS(8)) palette (
    .write_clk(clk),
    .write_enable(is_palette_write),
    .write_address(cpu_address[9:2]),
    .write_data(cpu_write_data[23:0]),
    .read_clk(pixel_clk),
    .read_address(colour_number),
    .read_data(palette_rgb)
);

//tick 3: kept to line up with the text layer
reg [23:0] pixel_rgb_3;
always @(posedge pixel_clk) pixel_rgb_3 <= palette_rgb;

//pointer
//tick 0: is this dot in the pointer's 16 x 16 square
//unsigned, so left of the pointer wraps and fails < 16
wire [9:0] pointer_dx = x - pointer_x_safe;
wire [9:0] pointer_dy = y - pointer_y_safe;
wire is_in_pointer = (pointer_dx < 10'd16) && (pointer_dy < 10'd16);

//tick 1: the pointer picture's row
wire [31:0] pointer_row;
two_door_ram #(.WIDTH(32), .ADDRESS_BITS(4)) pointer_picture (
    .write_clk(clk),
    .write_enable(is_picture_write),
    .write_address(cpu_address[5:2]),
    .write_data(cpu_write_data),
    .read_clk(pixel_clk),
    .read_address(pointer_dy[3:0]),
    .read_data(pointer_row)
);
reg [3:0] pointer_column_1;
reg is_in_pointer_1;
always @(posedge pixel_clk) begin
    pointer_column_1 <= pointer_dx[3:0];
    is_in_pointer_1 <= is_in_pointer;
end
wire [1:0] pointer_dot = is_in_pointer_1 ? (pointer_row >> {pointer_column_1, 1'b0}) : 2'b00;

//ticks 2 and 3: kept to line up
reg [1:0] pointer_dot_2, pointer_dot_3;
always @(posedge pixel_clk) begin
    pointer_dot_2 <= pointer_dot;
    pointer_dot_3 <= pointer_dot_2;
end

//mixer (tick 4), front-most layer that is not see-through
reg [23:0] mixed;
always @(*) begin
    if (control_safe[2] && (pointer_dot_3 == 2'd1))
        mixed = colour_1_safe;
    else if (control_safe[2] && (pointer_dot_3 == 2'd2))
        mixed = colour_2_safe;
    else if (control_safe[2] && (pointer_dot_3 == 2'd3))
        mixed = colour_3_safe;
    else if (control_safe[1] && !text_see_through)
        mixed = {text_red, text_green, text_blue};
    else if (control_safe[0])
        mixed = pixel_rgb_3;
    else
        mixed = 24'h00_00_00;
end

always @(posedge pixel_clk) begin
    if (text_visible) begin
        red <= mixed[23:16];
        green <= mixed[15:8];
        blue <= mixed[7:0];
    end else begin
        red <= 8'h00; //blank time is black
        green <= 8'h00;
        blue <= 8'h00;
    end
    hsync <= text_hsync;
    vsync <= text_vsync;
    is_visible <= text_visible;
end

endmodule
