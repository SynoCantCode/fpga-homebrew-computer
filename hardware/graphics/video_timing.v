//where is pixel rn
//x and y counters

module video_timing (

    input wire pixel_clk, //25.2Mhz
    input wire rst,
    output reg [9:0] x, //0-799 (0-639 vis, 640-799 blank)
    output reg [9:0] y, //0-524 (0-479 vis, 480-524 blank)
    output wire is_visible, //1 = this pixel is on screen, 0=blank time
    output wire hsync, //line sync, active-low
    output wire vsync //frame sync, active-low

);

//line: 640 visible, 16 front porch, 96 hsync, 48 back porch = 800
localparam H_VISIBLE = 10'd640;
localparam H_FRONT = 10'd16;
localparam H_SYNC = 10'd96;
localparam H_BACK = 10'd48; //not used below, left over before H_TOTAL
localparam H_TOTAL = 10'd800;

//frame: 480 visible, 10 front porch, 2 vsync, 33 back porch = 525
localparam V_VISIBLE = 10'd480;
localparam V_FRONT = 10'd10;
localparam V_SYNC = 10'd2;
localparam V_BACK = 10'd33; //same, left over before V_TOTAL
localparam V_TOTAL = 10'd525;

//the sweep, one step every tick
//x wraps at 799 then y moves down, y wraps at 524
always @(posedge pixel_clk) begin
    if (rst) begin
        x <= 10'd0;
        y <= 10'd0;
    end else if (x == (H_TOTAL - 10'd1)) begin
        x <= 10'd0;
        if (y == (V_TOTAL - 10'd1))
            y <= 10'd0;
        else
            y <= y + 10'd1;
    end else begin
        x <= x + 10'd1;
    end
end

//visible = top-left 640 x 480
assign is_visible = (x < H_VISIBLE) && (y < V_VISIBLE);

//hsync pulse x 656 to 751
//vsync pulse lines 490 and 491
//! because active-low, 0 = pulse
assign hsync = !((x >= (H_VISIBLE + H_FRONT)) && (x < (H_VISIBLE + H_FRONT + H_SYNC)));
assign vsync = !((y >= (V_VISIBLE + V_FRONT)) && (y < (V_VISIBLE + V_FRONT + V_SYNC)));

endmodule