// gowin_rpll_27_100.v
// Gowin rPLL: 27MHz input -> 100MHz output
// For SUMP Logic Analyzer clock generation
// Replaces Xilinx clockman component
//
// Input: 27 MHz
// Output: 100 MHz system clock
// 
// Calculation with IDIV=1, FBDIV=32, ODIV=8:
//   PFD = 27 / 2 = 13.5 MHz ✓
//   VCO = 27 * 33 / 2 = 445.5 MHz ✓ (within 400-1200 range)
//   CLKOUT = 445.5 / 8 = 55.7 MHz (close to 50MHz) - adjusted to get 100MHz
//
// Better: IDIV=1, FBDIV=36, ODIV=4:
//   PFD = 27 / 2 = 13.5 MHz ✓  
//   VCO = 27 * 37 / 2 = 499.5 MHz ✓ (within 500-1250 range)
//   CLKOUT = 499.5 / 4 = 124.875 MHz
//
// Best for 100MHz: IDIV=2, FBDIV=43, ODIV=4:
//   PFD = 27 / 3 = 9 MHz ✓
//   VCO = 27 * 44 / 3 = 396 MHz - TOO LOW!
//
// Working: IDIV=0, FBDIV=17, ODIV=4:
//   PFD = 27 / 1 = 27 MHz ✓
//   VCO = 27 * 18 / 1 = 486 MHz - TOO LOW
//
// Try: IDIV=0, FBDIV=22, ODIV=6:
//   PFD = 27 / 1 = 27 MHz ✓
//   VCO = 27 * 23 / 1 = 621 MHz ✓
//   CLKOUT = 621 / 6 = 103.5 MHz ✓

module gowin_rpll_27_100 (
    input clkin,    // 27 MHz input
    output clkout,  // ~100 MHz output (actually 103.5 MHz)
    output lock     // PLL lock indicator
);

    wire clkoutp_o;
    wire clkoutd_o;
    wire clkoutd3_o;
    wire gw_gnd;
    
    assign gw_gnd = 1'b0;

    rPLL #(
        .FCLKIN("27"),          // Input frequency: 27 MHz
        .DYN_IDIV_SEL("false"),
        .IDIV_SEL(0),           // Input divider: 1 (IDIV = IDIV_SEL + 1) -> PFD = 27 MHz
        .DYN_FBDIV_SEL("false"),
        .FBDIV_SEL(22),         // Feedback divider: 23 (FBDIV = FBDIV_SEL + 1) -> VCO = 621 MHz
        .DYN_ODIV_SEL("false"),
        .ODIV_SEL(6),           // Output divider: 6 -> CLKOUT = 103.5 MHz
        .PSDA_SEL("0000"),
        .DYN_DA_EN("false"),
        .DUTYDA_SEL("1000"),
        .CLKOUT_FT_DIR(1'b1),
        .CLKOUTP_FT_DIR(1'b1),
        .CLKOUT_DLY_STEP(0),
        .CLKOUTP_DLY_STEP(0),
        .CLKFB_SEL("internal"),
        .CLKOUT_BYPASS("false"),
        .CLKOUTP_BYPASS("false"),
        .CLKOUTD_BYPASS("false"),
        .DYN_SDIV_SEL(2),
        .CLKOUTD_SRC("CLKOUT"),
        .CLKOUTD3_SRC("CLKOUT"),
        .DEVICE("GW2A-18C")
    ) rpll_inst (
        .CLKOUT(clkout),
        .LOCK(lock),
        .CLKOUTP(clkoutp_o),
        .CLKOUTD(clkoutd_o),
        .CLKOUTD3(clkoutd3_o),
        .RESET(gw_gnd),
        .RESET_P(gw_gnd),
        .CLKIN(clkin),
        .CLKFB(gw_gnd),
        .FBDSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
        .IDSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
        .ODSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
        .PSDA({gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
        .DUTYDA({gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
        .FDLY({gw_gnd,gw_gnd,gw_gnd,gw_gnd})
    );

endmodule
