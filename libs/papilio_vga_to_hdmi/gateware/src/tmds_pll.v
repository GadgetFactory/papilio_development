// tmds_pll.v
// PLL for generating TMDS serial clock (5x pixel clock)
// This module instantiates the appropriate PLL for the input frequency
//
// For HQVGA (50MHz pixel clock), we use gowin_rpll_50_250

module tmds_pll (
    input wire clkin,       // Input clock (pixel clock)
    output wire clkout,     // Output clock (5x pixel clock)
    output wire lock        // PLL lock indicator
);

    // For HQVGA: 50MHz → 250MHz
    gowin_rpll_50_250 u_pll (
        .clkin(clkin),
        .clkout(clkout),
        .lock(lock)
    );

endmodule
