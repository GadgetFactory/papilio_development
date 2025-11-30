// top.v
// Papilio Arcade Board - Combined Video with MCP Debug Interface
// Supports: Framebuffer, Text Mode, and Test Patterns

(* top = "true" *)
module top (
    input wire clk_27mhz,
    input wire rst_n,
      
    // SPI interface (for Wishbone bridge)
    input wire esp_clk,
    input wire esp_mosi,
    output wire esp_miso,
    input wire esp_cs_n,
    
    // RGB LED output
    output wire rgb_led,

    // HDMI outputs (TMDS differential pairs)
    output wire O_tmds_clk_p,
    output wire O_tmds_clk_n,
    output wire [2:0] O_tmds_data_p,
    output wire [2:0] O_tmds_data_n
);

    // Reset signal (active high)
    wire rst = ~rst_n;
    
    // =========================================================================
    // SPI to Wishbone Bridge
    // =========================================================================
    wire [15:0] wb_adr_o;
    wire [7:0] wb_dat_o;
    wire wb_cyc_o;
    wire wb_stb_o;
    wire wb_we_o;
    wire [7:0] wb_dat_i;
    wire wb_ack_i;

    simple_spi_wb_bridge u_spi_bridge (
        .clk(clk_27mhz),
        .rst(rst),
        // SPI interface
        .spi_sclk(esp_clk),
        .spi_mosi(esp_mosi),
        .spi_miso(esp_miso),
        .spi_cs_n(esp_cs_n),
        // Wishbone master interface
        .wb_adr_o(wb_adr_o),
        .wb_dat_o(wb_dat_o),
        .wb_dat_i(wb_dat_i),
        .wb_cyc_o(wb_cyc_o),
        .wb_stb_o(wb_stb_o),
        .wb_we_o(wb_we_o),
        .wb_ack_i(wb_ack_i)
    );
    
    // =========================================================================
    // Address Decoding
    // =========================================================================
    // Address map:
    //   0x0000-0x7FFF: Video module (framebuffer + control)
    //   0x8100-0x81FF: RGB LED controller
    
    wire video_selected = (wb_adr_o[15:8] != 8'h81);  // Everything except 0x81xx
    wire rgb_led_selected = (wb_adr_o[15:8] == 8'h81);
    
    // =========================================================================
    // RGB LED Slave (at 0x8100-0x81FF)
    // =========================================================================
    wire [7:0] s0_wb_dat_i;
    wire s0_wb_ack;
    
    wb_simple_rgb_led u_wb_rgb_led (
        .clk(clk_27mhz),
        .rst(rst),
        .wb_adr_i(wb_adr_o[7:0]),
        .wb_dat_i(wb_dat_o),
        .wb_dat_o(s0_wb_dat_i),
        .wb_cyc_i(wb_cyc_o && rgb_led_selected),
        .wb_stb_i(wb_stb_o && rgb_led_selected),
        .wb_we_i(wb_we_o),
        .wb_ack_o(s0_wb_ack),
        .led_out(rgb_led)
    );
    
    // =========================================================================
    // Combined Video Module (Framebuffer + Text + Test Patterns)
    // =========================================================================
    wire [7:0] video_wb_dat;
    wire video_wb_ack;
    
    video_top_combined u_video_top (
        .I_clk(clk_27mhz),
        .I_rst_n(rst_n),
        // Wishbone slave interface
        .I_wb_clk(clk_27mhz),
        .I_wb_rst(rst),
        .I_wb_adr(wb_adr_o[15:0]),
        .I_wb_dat(wb_dat_o),
        .I_wb_we(wb_we_o),
        .I_wb_stb(wb_stb_o && video_selected),
        .I_wb_cyc(wb_cyc_o && video_selected),
        .O_wb_ack(video_wb_ack),
        .O_wb_dat(video_wb_dat),
        // HDMI output
        .O_tmds_clk_p(O_tmds_clk_p),
        .O_tmds_clk_n(O_tmds_clk_n),
        .O_tmds_data_p(O_tmds_data_p),
        .O_tmds_data_n(O_tmds_data_n)
    );
    
    // =========================================================================
    // Wishbone Bus Multiplexer
    // =========================================================================
    assign wb_dat_i = rgb_led_selected ? s0_wb_dat_i :
                      video_selected   ? video_wb_dat :
                      8'hFF;
    
    assign wb_ack_i = (rgb_led_selected && s0_wb_ack) ||
                      (video_selected && video_wb_ack);

endmodule
