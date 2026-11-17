//Video clocks, the two HDMI clocks from the 27MHz crystal
//serial_clk = 126MHz for the serializers
//pixel_clk = 25.2MHz = 126 / 5, one pixel per tick
//126 = 27 x 14 / 3 (FBDIV_SEL = 13 is x14, IDIV_SEL = 2 is /3)
//PLL runs inside at 126 x ODIV_SEL (8) = 1008MHz, range 500-1250MHz
//CLKDIV divides by 5 so the two stay in step
//is_locked = 1 once the PLL is steady

module video_clocks (
    input wire clk_27mhz,
    output wire serial_clk,
    output wire pixel_clk,
    output wire is_locked
);

rPLL pll (
    .CLKIN(clk_27mhz),
    .CLKOUT(serial_clk),
    .LOCK(is_locked),
    .CLKOUTP(),
    .CLKOUTD(),
    .CLKOUTD3(),
    .RESET(1'b0),
    .RESET_P(1'b0),
    .CLKFB(1'b0),
    .FBDSEL(6'b00_0000),
    .IDSEL(6'b00_0000),
    .ODSEL(6'b00_0000),
    .PSDA(4'b0000),
    .DUTYDA(4'b0000),
    .FDLY(4'b0000)
);
defparam pll.FCLKIN = "27";
defparam pll.DYN_IDIV_SEL = "false";
defparam pll.IDIV_SEL = 2;
defparam pll.DYN_FBDIV_SEL = "false";
defparam pll.FBDIV_SEL = 13;
defparam pll.DYN_ODIV_SEL = "false";
defparam pll.ODIV_SEL = 8;
defparam pll.PSDA_SEL = "0000";
defparam pll.DYN_DA_EN = "true";
defparam pll.DUTYDA_SEL = "1000";
defparam pll.CLKOUT_FT_DIR = 1'b1;
defparam pll.CLKOUTP_FT_DIR = 1'b1;
defparam pll.CLKOUT_DLY_STEP = 0;
defparam pll.CLKOUTP_DLY_STEP = 0;
defparam pll.CLKFB_SEL = "internal";
defparam pll.CLKOUT_BYPASS = "false";
defparam pll.CLKOUTP_BYPASS = "false";
defparam pll.CLKOUTD_BYPASS = "false";
defparam pll.DYN_SDIV_SEL = 2;
defparam pll.CLKOUTD_SRC = "CLKOUT";
defparam pll.CLKOUTD3_SRC = "CLKOUT";
defparam pll.DEVICE = "GW2AR-18C";

//held in reset until the PLL locks
CLKDIV divide_by_5 (
    .HCLKIN(serial_clk),
    .RESETN(is_locked),
    .CALIB(1'b0),
    .CLKOUT(pixel_clk)
);
defparam divide_by_5.DIV_MODE = "5";
defparam divide_by_5.GSREN = "false";

endmodule
