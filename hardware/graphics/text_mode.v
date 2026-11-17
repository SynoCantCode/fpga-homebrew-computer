//Text mode, sweep (x, y) to pixel colour, 80 x 30 letters of 8 x 16 dots
//3 steps per pixel
//1. which cell, column = x / 8, row = y / 16
//2. which letter, read the text buffer
//3. is the dot on, read the font
//pixel comes out 3 ticks after the sweep
//everything else is passed along the same 3 steps (pipeline)

module text_mode #(
    parameter FONT_FILE = "hw/graphics/font.hex"
) (
    input wire pixel_clk,
    input wire rst,

    //CPU door into the text buffer
    input wire cpu_clk,
    input wire [11:0] cpu_cell,
    input wire cpu_we,
    input wire [15:0] cpu_write_data,
    output wire [15:0] cpu_read_data,

    //the sweep, for the other layers
    output wire [9:0] sweep_x,
    output wire [9:0] sweep_y,

    //picture out, 8 bit rgb plus sync
    output reg [7:0] red,
    output reg [7:0] green,
    output reg [7:0] blue,
    output reg hsync,
    output reg vsync,
    output reg is_visible,
    output reg is_see_through //1 = see-through, background dot of a cell with background colour 0
);

//the sweep
wire [9:0] x;
wire [9:0] y;
wire sweep_is_visible;
wire sweep_hsync;
wire sweep_vsync;

video_timing timing (
    .pixel_clk(pixel_clk),
    .rst(rst),
    .x(x),
    .y(y),
    .is_visible(sweep_is_visible),
    .hsync(sweep_hsync),
    .vsync(sweep_vsync)
);
assign sweep_x = x;
assign sweep_y = y;

//step 0: which cell, row = y / 16, column = x / 8
//cell = row x 80 + column, row x 80 = row x 64 + row x 16
wire [4:0] row = y[8:4];
wire [6:0] column = x[9:3];
wire [11:0] cell_number = ({row, 6'b00_0000} + {row, 4'b0000}) + column;

wire [15:0] cell_data;

text_buffer letters (
    .cpu_clk(cpu_clk),
    .cpu_cell(cpu_cell),
    .cpu_we(cpu_we),
    .cpu_write_data(cpu_write_data),
    .cpu_read_data(cpu_read_data),
    .pixel_clk(pixel_clk),
    .screen_cell(cell_number),
    .screen_read_data(cell_data)
);

//step 1: cell_data arrived, keep dot across, line down, sync and visible
reg [2:0] dot_1;
reg [3:0] line_1;
reg is_visible_1;
reg hsync_1;
reg vsync_1;
always @(posedge pixel_clk) begin
    dot_1 <= x[2:0];
    line_1 <= y[3:0];
    is_visible_1 <= sweep_is_visible;
    hsync_1 <= sweep_hsync;
    vsync_1 <= sweep_vsync;
end

//font address = {letter, line}
wire [7:0] font_dots;

font_rom #(.FONT_FILE(FONT_FILE)) font (
    .clk(pixel_clk),
    .address({cell_data[7:0], line_1}),
    .dots(font_dots)
);

//step 2: font_dots arrived, keep the two colours
reg [3:0] letter_colour_2;
reg [3:0] background_colour_2;
reg [2:0] dot_2;
reg is_visible_2;
reg hsync_2;
reg vsync_2;
always @(posedge pixel_clk) begin
    letter_colour_2 <= cell_data[11:8];
    background_colour_2 <= cell_data[15:12];
    dot_2 <= dot_1;
    is_visible_2 <= is_visible_1;
    hsync_2 <= hsync_1;
    vsync_2 <= vsync_1;
end

//bit 7 is the left dot
wire is_dot_on = font_dots[3'd7 - dot_2];
wire [3:0] colour = is_dot_on ? letter_colour_2 : background_colour_2;

//16 colour palette, IBM PC colours except 1, 7 and 15
reg [23:0] rgb;
always @(*) begin
    case (colour)
        4'h0: rgb = 24'h00_00_00; //black
        4'h1: rgb = 24'h50_44_C8; //blue-violet
        4'h2: rgb = 24'h00_AA_00; //green
        4'h3: rgb = 24'h00_AA_AA; //cyan
        4'h4: rgb = 24'hAA_00_00; //red
        4'h5: rgb = 24'hAA_00_AA; //magenta
        4'h6: rgb = 24'hAA_55_00; //brown
        4'h7: rgb = 24'hC0_C0_C0; //silver
        4'h8: rgb = 24'h55_55_55; //dark grey
        4'h9: rgb = 24'h55_55_FF; //light blue
        4'hA: rgb = 24'h55_FF_55; //light green
        4'hB: rgb = 24'h55_FF_FF; //light cyan
        4'hC: rgb = 24'hFF_55_55; //light red
        4'hD: rgb = 24'hFF_55_FF; //light magenta
        4'hE: rgb = 24'hFF_FF_55; //yellow
        default: rgb = 24'hE8_E8_E8; //white, a bit darker
    endcase
end

//step 3: finished pixel, black in blank time
always @(posedge pixel_clk) begin
    if (is_visible_2) begin
        red <= rgb[23:16];
        green <= rgb[15:8];
        blue <= rgb[7:0];
    end else begin
        red <= 8'h00;
        green <= 8'h00;
        blue <= 8'h00;
    end
    hsync <= hsync_2;
    vsync <= vsync_2;
    is_visible <= is_visible_2;
    is_see_through <= !is_dot_on && (background_colour_2 == 4'h0);
end

endmodule
