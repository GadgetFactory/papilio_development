// vga_to_hdmi.v
// VGA to HDMI adapter for Papilio Arcade Board
// Converts standard VGA RGB signals to HDMI TMDS differential output
//
// Input: VGA timing (hsync, vsync, RGB)
// Output: HDMI TMDS differential pairs
//
// This module handles:
// - TMDS encoding (8b/10b for each RGB channel)
// - Clock generation (5x pixel clock for serialization)
// - Differential output buffering

module vga_to_hdmi (
    // VGA inputs
    input wire clk_pixel,       // VGA pixel clock (25MHz, 50MHz, 74.25MHz, etc.)
    input wire rst_n,           // Active low reset
    input wire vga_hsync,       // VGA horizontal sync
    input wire vga_vsync,       // VGA vertical sync
    input wire vga_de,          // VGA display enable (active video area)
    input wire [7:0] vga_r,     // VGA red (8-bit)
    input wire [7:0] vga_g,     // VGA green (8-bit)
    input wire [7:0] vga_b,     // VGA blue (8-bit)
    
    // HDMI outputs (TMDS differential pairs)
    output wire hdmi_clk_p,     // HDMI clock positive
    output wire hdmi_clk_n,     // HDMI clock negative
    output wire [2:0] hdmi_d_p, // HDMI data positive {red, green, blue}
    output wire [2:0] hdmi_d_n  // HDMI data negative {red, green, blue}
);

    wire rst = ~rst_n;
    
    // PLL to generate 5x serial clock for TMDS serialization
    wire clk_serial;    // 5x pixel clock
    wire pll_lock;
    
    tmds_pll u_pll (
        .clkin(clk_pixel),
        .clkout(clk_serial),
        .lock(pll_lock)
    );
    
    // Reset synchronization
    reg [1:0] rst_sync;
    wire tmds_rst_n = pll_lock && !rst_sync[1];
    
    always @(posedge clk_pixel or posedge rst) begin
        if (rst) begin
            rst_sync <= 2'b11;
        end else begin
            rst_sync <= {rst_sync[0], 1'b0};
        end
    end
    
    // TMDS encoding for each channel
    wire [9:0] tmds_ch0;  // Blue + hsync/vsync control
    wire [9:0] tmds_ch1;  // Green
    wire [9:0] tmds_ch2;  // Red
    
    // Channel 0: Blue (carries hsync/vsync in control period)
    tmds_encoder u_encoder_ch0 (
        .clk(clk_pixel),
        .rst(!tmds_rst_n),
        .video_active(vga_de),
        .data_in(vga_b),
        .c0(vga_hsync),
        .c1(vga_vsync),
        .tmds_out(tmds_ch0)
    );
    
    // Channel 1: Green
    tmds_encoder u_encoder_ch1 (
        .clk(clk_pixel),
        .rst(!tmds_rst_n),
        .video_active(vga_de),
        .data_in(vga_g),
        .c0(1'b0),
        .c1(1'b0),
        .tmds_out(tmds_ch1)
    );
    
    // Channel 2: Red
    tmds_encoder u_encoder_ch2 (
        .clk(clk_pixel),
        .rst(!tmds_rst_n),
        .video_active(vga_de),
        .data_in(vga_r),
        .c0(1'b0),
        .c1(1'b0),
        .tmds_out(tmds_ch2)
    );
    
    // TMDS serialization (10:1) for each data channel
    tmds_serializer u_ser_ch0 (
        .clk_pixel(clk_pixel),
        .clk_serial(clk_serial),
        .rst_n(tmds_rst_n),
        .tmds_data(tmds_ch0),
        .tmds_p(hdmi_d_p[0]),  // Blue
        .tmds_n(hdmi_d_n[0])
    );
    
    tmds_serializer u_ser_ch1 (
        .clk_pixel(clk_pixel),
        .clk_serial(clk_serial),
        .rst_n(tmds_rst_n),
        .tmds_data(tmds_ch1),
        .tmds_p(hdmi_d_p[1]),  // Green
        .tmds_n(hdmi_d_n[1])
    );
    
    tmds_serializer u_ser_ch2 (
        .clk_pixel(clk_pixel),
        .clk_serial(clk_serial),
        .rst_n(tmds_rst_n),
        .tmds_data(tmds_ch2),
        .tmds_p(hdmi_d_p[2]),  // Red
        .tmds_n(hdmi_d_n[2])
    );
    
    // Clock output - HDMI/DVI uses pixel clock directly, not serialized
    // The receiver expects the pixel clock as a reference for data recovery
    ELVDS_OBUF u_clk_obuf (
        .I(clk_pixel),
        .O(hdmi_clk_p),
        .OB(hdmi_clk_n)
    );

endmodule
