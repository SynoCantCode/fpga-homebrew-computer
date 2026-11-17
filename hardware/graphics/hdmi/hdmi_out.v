//HDMI out, really DVI over an HDMI cable, picture only
//3 TMDS encoders make 10-bit codes, 3 serializers send them a bit at a time
//4th pair carries the pixel clock
//channel 0 = blue (+ hsync and vsync in blank time), 1 = green, 2 = red
//each wire is a pair, the signal and its opposite
//uses Gowin OSER10 (serializer) and ELVDS_OBUF (pair driver)

module hdmi_out (
    input wire pixel_clk, //25.2MHz, one pixel per tick
    input wire serial_clk, //126MHz = 5 x pixel_clk, 2 bits per tick
    input wire rst,
    input wire [7:0] red,
    input wire [7:0] green,
    input wire [7:0] blue,
    input wire hsync,
    input wire vsync,
    input wire is_visible,
    output wire tmds_clk_p, //clock pair
    output wire tmds_clk_n,
    output wire [2:0] tmds_data_p, //3 data pairs, [0] blue, [1] green, [2] red
    output wire [2:0] tmds_data_n
);

//3 encoders, 8 bit colour in, 10-bit code out a tick later
wire [9:0] blue_code;
wire [9:0] green_code;
wire [9:0] red_code;

tmds_encoder blue_encoder (
    .pixel_clk(pixel_clk), .rst(rst), .colour(blue), .control({vsync, hsync}), .is_visible(is_visible), .code(blue_code)
);
tmds_encoder green_encoder (
    .pixel_clk(pixel_clk), .rst(rst), .colour(green), .control(2'b00), .is_visible(is_visible), .code(green_code)
);
tmds_encoder red_encoder (
    .pixel_clk(pixel_clk), .rst(rst), .colour(red), .control(2'b00), .is_visible(is_visible), .code(red_code)
);

//3 serializers, 10 bits per pixel, bit 0 first
//PCLK = take the next 10 bits, FCLK = fast clock, both edges
wire [2:0] serial_bit;

OSER10 blue_serializer (
    .Q(serial_bit[0]),
    .D0(blue_code[0]), .D1(blue_code[1]), .D2(blue_code[2]), .D3(blue_code[3]), .D4(blue_code[4]),
    .D5(blue_code[5]), .D6(blue_code[6]), .D7(blue_code[7]), .D8(blue_code[8]), .D9(blue_code[9]),
    .PCLK(pixel_clk), .FCLK(serial_clk), .RESET(rst)
);
OSER10 green_serializer (
    .Q(serial_bit[1]),
    .D0(green_code[0]), .D1(green_code[1]), .D2(green_code[2]), .D3(green_code[3]), .D4(green_code[4]),
    .D5(green_code[5]), .D6(green_code[6]), .D7(green_code[7]), .D8(green_code[8]), .D9(green_code[9]),
    .PCLK(pixel_clk), .FCLK(serial_clk), .RESET(rst)
);
OSER10 red_serializer (
    .Q(serial_bit[2]),
    .D0(red_code[0]), .D1(red_code[1]), .D2(red_code[2]), .D3(red_code[3]), .D4(red_code[4]),
    .D5(red_code[5]), .D6(red_code[6]), .D7(red_code[7]), .D8(red_code[8]), .D9(red_code[9]),
    .PCLK(pixel_clk), .FCLK(serial_clk), .RESET(rst)
);

//pair drivers, one signal to a pair
//clock pair carries the pixel clock
ELVDS_OBUF clock_pair (.I(pixel_clk), .O(tmds_clk_p), .OB(tmds_clk_n));
ELVDS_OBUF blue_pair (.I(serial_bit[0]), .O(tmds_data_p[0]), .OB(tmds_data_n[0]));
ELVDS_OBUF green_pair (.I(serial_bit[1]), .O(tmds_data_p[1]), .OB(tmds_data_n[1]));
ELVDS_OBUF red_pair (.I(serial_bit[2]), .O(tmds_data_p[2]), .OB(tmds_data_n[2]));

endmodule
