// top.v
// Papilio Arcade Board - HDMI video output with Wishbone control + USB Serial

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
    
    // Wishbone signals - Master (SPI bridge)
    wire [7:0] wb_adr_o;
    wire [7:0] wb_dat_o;
    wire [7:0] wb_dat_i;
    wire wb_cyc_o;
    wire wb_stb_o;
    wire wb_we_o;
    wire wb_ack_i;
    
    // Wishbone signals - Slave 0 (RGB LED)
    wire [7:0] s0_wb_adr;
    wire [7:0] s0_wb_dat_o;
    wire [7:0] s0_wb_dat_i;
    wire s0_wb_cyc;
    wire s0_wb_stb;
    wire s0_wb_we;
    wire s0_wb_ack;
    
    // Wishbone signals - Slave 1 (HDMI)
    wire [7:0] s1_wb_adr;
    wire [7:0] s1_wb_dat_o;
    wire [7:0] s1_wb_dat_i;
    wire s1_wb_cyc;
    wire s1_wb_stb;
    wire s1_wb_we;
    wire s1_wb_ack;

    // Wishbone signals - Slave 2 (Character RAM)
    wire [7:0] s2_wb_adr;
    wire [7:0] s2_wb_dat_o;
    wire [7:0] s2_wb_dat_i;
    wire s2_wb_cyc;
    wire s2_wb_stb;
    wire s2_wb_we;
    wire s2_wb_ack;
    
    // Character RAM video interface
    wire [11:0] video_char_addr;
    wire [7:0] video_char_data;
    wire [7:0] video_attr_data;
    
    // SPI to Wishbone bridge with UART debug
    simple_spi_wb_bridge_debug u_spi_wb_bridge (
        .clk(clk_27mhz),
        .rst(rst),
        .spi_sclk(esp_clk),
        .spi_mosi(esp_mosi),
        .spi_cs_n(esp_cs_n),
        .wb_adr_o(wb_adr_o),
        .wb_dat_o(wb_dat_o),
        .wb_dat_i(wb_dat_i),
        .wb_cyc_o(wb_cyc_o),
        .wb_stb_o(wb_stb_o),
        .wb_we_o(wb_we_o),
        .wb_ack_i(wb_ack_i),
        .uart_tx(esp_miso)
    );
    
    // Wishbone address decoder
    wb_address_decoder u_wb_decoder (
        .clk(clk_27mhz),
        .rst(rst),
        .wb_adr_i(wb_adr_o),
        .wb_dat_i(wb_dat_o),
        .wb_dat_o(wb_dat_i),
        .wb_cyc_i(wb_cyc_o),
        .wb_stb_i(wb_stb_o),
        .wb_we_i(wb_we_o),
        .wb_ack_o(wb_ack_i),
        .s0_wb_adr_o(s0_wb_adr),
        .s0_wb_dat_o(s0_wb_dat_o),
        .s0_wb_dat_i(s0_wb_dat_i),
        .s0_wb_cyc_o(s0_wb_cyc),
        .s0_wb_stb_o(s0_wb_stb),
        .s0_wb_we_o(s0_wb_we),
        .s0_wb_ack_i(s0_wb_ack),
        .s1_wb_adr_o(s1_wb_adr),
        .s1_wb_dat_o(s1_wb_dat_o),
        .s1_wb_dat_i(s1_wb_dat_i),
        .s1_wb_cyc_o(s1_wb_cyc),
        .s1_wb_stb_o(s1_wb_stb),
        .s1_wb_we_o(s1_wb_we),
        .s1_wb_ack_i(s1_wb_ack),
        .s2_wb_adr_o(s2_wb_adr),
        .s2_wb_dat_o(s2_wb_dat_o),
        .s2_wb_dat_i(s2_wb_dat_i),
        .s2_wb_cyc_o(s2_wb_cyc),
        .s2_wb_stb_o(s2_wb_stb),
        .s2_wb_we_o(s2_wb_we),
        .s2_wb_ack_i(s2_wb_ack)
    );
    

    // Wishbone RGB LED controller (Slave 0, addresses 0x00-0x0F)
    wb_simple_rgb_led u_wb_rgb_led (
        .clk(clk_27mhz),
        .rst(rst),
        .wb_adr_i(s0_wb_adr),
        .wb_dat_i(s0_wb_dat_o),
        .wb_dat_o(s0_wb_dat_i),
        .wb_cyc_i(s0_wb_cyc),
        .wb_stb_i(s0_wb_stb),
        .wb_we_i(s0_wb_we),
        .wb_ack_o(s0_wb_ack),
        .led_out(rgb_led)
    );

    // HDMI video controller (Slave 1, addresses 0x10-0x1F)
    // Uses PLL for proper HDMI timing and DVI transmitter
    wb_video_ctrl u_wb_video_ctrl (
        .clk(clk_27mhz),
        .rst_n(rst_n),
        .wb_adr_i(s1_wb_adr),
        .wb_dat_i(s1_wb_dat_o),
        .wb_dat_o(s1_wb_dat_i),
        .wb_cyc_i(s1_wb_cyc),
        .wb_stb_i(s1_wb_stb),
        .wb_we_i(s1_wb_we),
        .wb_ack_o(s1_wb_ack),
        .text_char_addr(video_char_addr),
        .text_char_data(video_char_data),
        .O_tmds_clk_p(O_tmds_clk_p),
        .O_tmds_clk_n(O_tmds_clk_n),
        .O_tmds_data_p(O_tmds_data_p),
        .O_tmds_data_n(O_tmds_data_n)
    );
    
    // Character RAM controller (Slave 2, addresses 0x20-0x2F)
    // 80x30 character text mode with 8x8 VGA font
    wb_char_ram u_wb_char_ram (
        .clk(clk_27mhz),
        .rst_n(rst_n),
        .wb_adr_i(s2_wb_adr),
        .wb_dat_i(s2_wb_dat_o),
        .wb_dat_o(s2_wb_dat_i),
        .wb_cyc_i(s2_wb_cyc),
        .wb_stb_i(s2_wb_stb),
        .wb_we_i(s2_wb_we),
        .wb_ack_o(s2_wb_ack),
        .video_char_addr(video_char_addr),
        .video_char_data(video_char_data)
    );

endmodule

