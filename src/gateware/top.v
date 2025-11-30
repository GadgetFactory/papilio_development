// top.v
// Papilio Arcade Board - Modular Video with MCP Debug Interface
// ==============================================================================
// Uses open-source HDMI PHY (no proprietary Gowin DVI IP)
// Video modes are modular - enable/disable as needed to save resources
// ==============================================================================

// Uncomment the video modes you want to include:
`define ENABLE_VIDEO_TESTPATTERN
`define ENABLE_VIDEO_TEXT
`define ENABLE_VIDEO_FRAMEBUFFER

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
    // Address Decoding - Modular Video Architecture
    // =========================================================================
    // Address map:
    //   0x0000-0x000F: Video mode control
    //   0x0010-0x001F: Test pattern registers
    //   0x0020-0x00FF: Text mode registers + char RAM
    //   0x0100-0x7FFF: Framebuffer (word-aligned)
    //   0x8100-0x81FF: RGB LED controller
    
    localparam ADDR_MODE_CTRL  = 16'h0000;
    localparam ADDR_TP_BASE    = 16'h0010;
    localparam ADDR_TEXT_BASE  = 16'h0020;
    localparam ADDR_FB_BASE    = 16'h0100;
    localparam ADDR_RGB_LED    = 16'h8100;
    
    wire rgb_led_selected = (wb_adr_o[15:8] == 8'h81);
    wire mode_ctrl_sel    = (wb_adr_o < ADDR_TP_BASE) && !rgb_led_selected;
    wire tp_sel           = (wb_adr_o >= ADDR_TP_BASE) && (wb_adr_o < ADDR_TEXT_BASE);
    wire text_sel         = (wb_adr_o >= ADDR_TEXT_BASE) && (wb_adr_o < ADDR_FB_BASE);
    wire fb_sel           = (wb_adr_o >= ADDR_FB_BASE) && (wb_adr_o < ADDR_RGB_LED);
    
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
    // Video Mode Control Register (at 0x0000)
    // =========================================================================
    // Mode register:
    //   [1:0] = Video mode: 0=TestPattern, 1=Text, 2=Framebuffer
    reg [1:0] video_mode;
    reg mode_ctrl_ack;
    
    always @(posedge clk_27mhz or posedge rst) begin
        if (rst) begin
            video_mode <= 2'd0;  // Default to test pattern
            mode_ctrl_ack <= 1'b0;
        end else begin
            mode_ctrl_ack <= 1'b0;
            if (wb_stb_o && wb_cyc_o && mode_ctrl_sel) begin
                if (wb_we_o && wb_adr_o[3:0] == 4'h0)
                    video_mode <= wb_dat_o[1:0];
                mode_ctrl_ack <= 1'b1;
            end
        end
    end
    
    wire [7:0] mode_ctrl_dat = {6'b0, video_mode};
    
    // =========================================================================
    // HDMI PHY - Shared Physical Layer (Open Source - No Gowin IP)
    // =========================================================================
    wire pix_clk;
    wire pix_clk_5x;
    wire hdmi_rst_n;
    wire [11:0] h_cnt, v_cnt;
    wire [11:0] active_x, active_y;
    wire phy_de, phy_hs, phy_vs;
    
    // Video input to PHY (selected by mode mux)
    reg [7:0] rgb_r, rgb_g, rgb_b;
    reg       rgb_de, rgb_hs, rgb_vs;
    
    hdmi_phy_720p u_hdmi_phy (
        .I_clk          (clk_27mhz      ),
        .I_rst_n        (rst_n          ),
        
        .I_rgb_r        (rgb_r          ),
        .I_rgb_g        (rgb_g          ),
        .I_rgb_b        (rgb_b          ),
        .I_rgb_de       (rgb_de         ),
        .I_rgb_hs       (rgb_hs         ),
        .I_rgb_vs       (rgb_vs         ),
        
        .O_pix_clk      (pix_clk        ),
        .O_pix_clk_5x   (pix_clk_5x     ),
        .O_hdmi_rst_n   (hdmi_rst_n     ),
        .O_h_cnt        (h_cnt          ),
        .O_v_cnt        (v_cnt          ),
        .O_de           (phy_de         ),
        .O_hs           (phy_hs         ),
        .O_vs           (phy_vs         ),
        .O_active_x     (active_x       ),
        .O_active_y     (active_y       ),
        
        .O_tmds_clk_p   (O_tmds_clk_p   ),
        .O_tmds_clk_n   (O_tmds_clk_n   ),
        .O_tmds_data_p  (O_tmds_data_p  ),
        .O_tmds_data_n  (O_tmds_data_n  )
    );
    
    // =========================================================================
    // Test Pattern Generator (Mode 0) - Conditional
    // =========================================================================
`ifdef ENABLE_VIDEO_TESTPATTERN
    wire tp_ack;
    wire [7:0] tp_dat;
    wire [7:0] tp_rgb_r, tp_rgb_g, tp_rgb_b;
    wire tp_rgb_de, tp_rgb_hs, tp_rgb_vs;
    
    wb_video_testpattern u_testpattern (
        .I_wb_clk       (clk_27mhz      ),
        .I_wb_rst       (rst            ),
        .I_wb_adr       (wb_adr_o[7:0] - ADDR_TP_BASE[7:0]),
        .I_wb_dat       (wb_dat_o       ),
        .I_wb_we        (wb_we_o        ),
        .I_wb_stb       (wb_stb_o && tp_sel),
        .I_wb_cyc       (wb_cyc_o       ),
        .O_wb_ack       (tp_ack         ),
        .O_wb_dat       (tp_dat         ),
        
        .I_pix_clk      (pix_clk        ),
        .I_rst_n        (hdmi_rst_n     ),
        .I_active_x     (active_x       ),
        .I_active_y     (active_y       ),
        .I_de           (phy_de         ),
        .I_hs           (phy_hs         ),
        .I_vs           (phy_vs         ),
        
        .O_rgb_r        (tp_rgb_r       ),
        .O_rgb_g        (tp_rgb_g       ),
        .O_rgb_b        (tp_rgb_b       ),
        .O_rgb_de       (tp_rgb_de      ),
        .O_rgb_hs       (tp_rgb_hs      ),
        .O_rgb_vs       (tp_rgb_vs      )
    );
`else
    wire tp_ack = 1'b0;
    wire [7:0] tp_dat = 8'h00;
    wire [7:0] tp_rgb_r = 8'h00, tp_rgb_g = 8'h00, tp_rgb_b = 8'h00;
    wire tp_rgb_de = phy_de, tp_rgb_hs = phy_hs, tp_rgb_vs = phy_vs;
`endif
    
    // =========================================================================
    // Text Mode (Mode 1) - Conditional
    // =========================================================================
`ifdef ENABLE_VIDEO_TEXT
    wire text_ack;
    wire [7:0] text_dat;
    wire [7:0] text_rgb_r, text_rgb_g, text_rgb_b;
    wire text_rgb_de, text_rgb_hs, text_rgb_vs;
    
    wb_video_text u_text_mode (
        .I_wb_clk       (clk_27mhz      ),
        .I_wb_rst       (rst            ),
        .I_wb_adr       (wb_adr_o[7:0] - ADDR_TEXT_BASE[7:0]),
        .I_wb_dat       (wb_dat_o       ),
        .I_wb_we        (wb_we_o        ),
        .I_wb_stb       (wb_stb_o && text_sel),
        .I_wb_cyc       (wb_cyc_o       ),
        .O_wb_ack       (text_ack       ),
        .O_wb_dat       (text_dat       ),
        
        .I_pix_clk      (pix_clk        ),
        .I_rst_n        (hdmi_rst_n     ),
        .I_active_x     (active_x       ),
        .I_active_y     (active_y       ),
        .I_de           (phy_de         ),
        .I_hs           (phy_hs         ),
        .I_vs           (phy_vs         ),
        
        .O_rgb_r        (text_rgb_r     ),
        .O_rgb_g        (text_rgb_g     ),
        .O_rgb_b        (text_rgb_b     ),
        .O_rgb_de       (text_rgb_de    ),
        .O_rgb_hs       (text_rgb_hs    ),
        .O_rgb_vs       (text_rgb_vs    )
    );
`else
    wire text_ack = 1'b0;
    wire [7:0] text_dat = 8'h00;
    wire [7:0] text_rgb_r = 8'h00, text_rgb_g = 8'h00, text_rgb_b = 8'h00;
    wire text_rgb_de = phy_de, text_rgb_hs = phy_hs, text_rgb_vs = phy_vs;
`endif
    
    // =========================================================================
    // Framebuffer Mode (Mode 2) - Conditional
    // =========================================================================
`ifdef ENABLE_VIDEO_FRAMEBUFFER
    wire fb_ack;
    wire [7:0] fb_dat;
    wire [7:0] fb_rgb_r, fb_rgb_g, fb_rgb_b;
    wire fb_rgb_de, fb_rgb_hs, fb_rgb_vs;
    
    wb_video_framebuffer u_framebuffer (
        .I_wb_clk       (clk_27mhz      ),
        .I_wb_rst       (rst            ),
        .I_wb_adr       (wb_adr_o[14:0] - ADDR_FB_BASE[14:0]),
        .I_wb_dat       (wb_dat_o       ),
        .I_wb_we        (wb_we_o        ),
        .I_wb_stb       (wb_stb_o && fb_sel),
        .I_wb_cyc       (wb_cyc_o       ),
        .O_wb_ack       (fb_ack         ),
        .O_wb_dat       (fb_dat         ),
        
        .I_pix_clk      (pix_clk        ),
        .I_rst_n        (hdmi_rst_n     ),
        .I_h_cnt        (h_cnt          ),
        .I_v_cnt        (v_cnt          ),
        .I_active_x     (active_x       ),
        .I_active_y     (active_y       ),
        .I_de           (phy_de         ),
        .I_hs           (phy_hs         ),
        .I_vs           (phy_vs         ),
        
        .O_rgb_r        (fb_rgb_r       ),
        .O_rgb_g        (fb_rgb_g       ),
        .O_rgb_b        (fb_rgb_b       ),
        .O_rgb_de       (fb_rgb_de      ),
        .O_rgb_hs       (fb_rgb_hs      ),
        .O_rgb_vs       (fb_rgb_vs      )
    );
`else
    wire fb_ack = 1'b0;
    wire [7:0] fb_dat = 8'h00;
    wire [7:0] fb_rgb_r = 8'h00, fb_rgb_g = 8'h00, fb_rgb_b = 8'h00;
    wire fb_rgb_de = phy_de, fb_rgb_hs = phy_hs, fb_rgb_vs = phy_vs;
`endif
    
    // =========================================================================
    // Video Mode Multiplexer
    // =========================================================================
    reg [1:0] video_mode_sync;
    always @(posedge pix_clk or negedge hdmi_rst_n) begin
        if (!hdmi_rst_n)
            video_mode_sync <= 2'd0;
        else
            video_mode_sync <= video_mode;
    end
    
    always @(posedge pix_clk or negedge hdmi_rst_n) begin
        if (!hdmi_rst_n) begin
            rgb_r  <= 8'd0;
            rgb_g  <= 8'd0;
            rgb_b  <= 8'd0;
            rgb_de <= 1'b0;
            rgb_hs <= 1'b0;
            rgb_vs <= 1'b0;
        end else begin
            case (video_mode_sync)
                2'd0: begin  // Test pattern
                    rgb_r  <= tp_rgb_r;
                    rgb_g  <= tp_rgb_g;
                    rgb_b  <= tp_rgb_b;
                    rgb_de <= tp_rgb_de;
                    rgb_hs <= tp_rgb_hs;
                    rgb_vs <= tp_rgb_vs;
                end
                2'd1: begin  // Text mode
                    rgb_r  <= text_rgb_r;
                    rgb_g  <= text_rgb_g;
                    rgb_b  <= text_rgb_b;
                    rgb_de <= text_rgb_de;
                    rgb_hs <= text_rgb_hs;
                    rgb_vs <= text_rgb_vs;
                end
                2'd2: begin  // Framebuffer
                    rgb_r  <= fb_rgb_r;
                    rgb_g  <= fb_rgb_g;
                    rgb_b  <= fb_rgb_b;
                    rgb_de <= fb_rgb_de;
                    rgb_hs <= fb_rgb_hs;
                    rgb_vs <= fb_rgb_vs;
                end
                default: begin  // Default to test pattern
                    rgb_r  <= tp_rgb_r;
                    rgb_g  <= tp_rgb_g;
                    rgb_b  <= tp_rgb_b;
                    rgb_de <= tp_rgb_de;
                    rgb_hs <= tp_rgb_hs;
                    rgb_vs <= tp_rgb_vs;
                end
            endcase
        end
    end
    
    // =========================================================================
    // Wishbone Bus Multiplexer
    // =========================================================================
    assign wb_dat_i = rgb_led_selected ? s0_wb_dat_i :
                      mode_ctrl_sel    ? mode_ctrl_dat :
                      tp_sel           ? tp_dat :
                      text_sel         ? text_dat :
                      fb_sel           ? fb_dat :
                      8'hFF;
    
    assign wb_ack_i = (rgb_led_selected && s0_wb_ack) ||
                      (mode_ctrl_sel && mode_ctrl_ack) ||
                      (tp_sel && tp_ack) ||
                      (text_sel && text_ack) ||
                      (fb_sel && fb_ack);

endmodule
