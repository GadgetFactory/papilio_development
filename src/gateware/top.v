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
`define ENABLE_AUDIO_SID

// Uncomment to enable SUMP Logic Analyzer on UART (disables Wishbone LA)
`define ENABLE_SUMP_UART_LA

// Uncomment to enable simple loopback test on SUMP UART (tx <= rx)
// Useful for verifying physical connection without analyzer logic
//`define ENABLE_SUMP_LOOPBACK

// Uncomment to enable TX test mode - sends pattern periodically
//`define ENABLE_SUMP_TX_TEST

// Uncomment to enable RX echo test - echoes received bytes back
//`define ENABLE_SUMP_RX_ECHO_TEST

// Uncomment to enable simple SUMP logic analyzer with working UART
`define ENABLE_SIMPLE_SUMP_LA

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
    
    // Audio outputs (PWM sigma-delta)
    output wire audio_left,
    output wire audio_right,

    // HDMI outputs (TMDS differential pairs)
    output wire O_tmds_clk_p,
    output wire O_tmds_clk_n,
    output wire [2:0] O_tmds_data_p,
    output wire [2:0] O_tmds_data_n,
    
    // SUMP Logic Analyzer UART (optional - enable with ENABLE_SUMP_UART_LA)
    input wire sump_rx,
    output wire sump_tx
);

    // Reset signal (active high)
    wire rst = ~rst_n;
    // Pixel clock and HDMI reset signals (declared early so they're
    // available to modules that synchronize into the pix_clk domain)
    wire pix_clk;
    wire pix_clk_5x;
    wire hdmi_rst_n;
    
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
    //   0x8200-0x821F: SID 6581 audio chip
    
    localparam ADDR_MODE_CTRL  = 16'h0000;
    localparam ADDR_TP_BASE    = 16'h0010;
    localparam ADDR_TEXT_BASE  = 16'h0020;
    localparam ADDR_FB_BASE    = 16'h0100;
    localparam ADDR_RGB_LED    = 16'h8100;
    localparam ADDR_SID_BASE   = 16'h8200;
    localparam ADDR_YM2149_BASE = 16'h8220;
    localparam ADDR_LOGIC_ANALYZER = 16'h8300;  // Logic Analyzer at 0x8300-0x83FF
    
    wire rgb_led_selected = (wb_adr_o[15:8] == 8'h81);
    wire sid_selected     = (wb_adr_o[15:8] == 8'h82) && (wb_adr_o[7:5] == 3'b000);  // 0x8200-0x821F
    wire ym2149_selected  = (wb_adr_o[15:8] == 8'h82) && (wb_adr_o[7:5] == 3'b001);  // 0x8220-0x823F
    wire la_selected      = (wb_adr_o[15:8] == 8'h83);  // Logic Analyzer 0x8300-0x83FF
    wire mode_ctrl_sel    = (wb_adr_o < ADDR_TP_BASE) && !rgb_led_selected && !sid_selected && !la_selected;
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
    // SID 6581 Audio Chip (at 0x8200-0x821F) - Conditional
    // =========================================================================
`ifdef ENABLE_AUDIO_SID
    // Generate 1MHz clock for SID from 27MHz
    // 27MHz / 27 = 1MHz
    reg [4:0] clk_1mhz_div;
    reg clk_1mhz;
    
    always @(posedge clk_27mhz or posedge rst) begin
        if (rst) begin
            clk_1mhz_div <= 5'd0;
            clk_1mhz <= 1'b0;
        end else begin
            if (clk_1mhz_div == 5'd13) begin
                clk_1mhz_div <= 5'd0;
                clk_1mhz <= ~clk_1mhz;
            end else begin
                clk_1mhz_div <= clk_1mhz_div + 1'b1;
            end
        end
    end
    
    wire [7:0] sid_wb_dat_o;
    wire sid_wb_ack;
    wire [17:0] sid_audio_data;
    wire sid_audio_pdm;
    
    // Use the VHDL wrapper (known working with ZPUino)
    wb_sid6581_simple u_sid (
        .wb_clk_i(clk_27mhz),
        .wb_rst_i(rst),
        .clk_1mhz(clk_1mhz),
        .wb_adr_i(wb_adr_o[4:0]),
        .wb_dat_i(wb_dat_o),
        .wb_dat_o(sid_wb_dat_o),
        .wb_cyc_i(wb_cyc_o && sid_selected),
        .wb_stb_i(wb_stb_o && sid_selected),
        .wb_we_i(wb_we_o),
        .wb_ack_o(sid_wb_ack),
        .audio_data(sid_audio_data)
    );
    
    // Synchronize SID audio data from 27MHz domain to pix_clk (74.25MHz) domain
    // Simple double-flop synchronizer for the 18-bit audio data
    reg [17:0] sid_audio_sync1, sid_audio_sync2;
    always @(posedge pix_clk or negedge hdmi_rst_n) begin
        if (!hdmi_rst_n) begin
            sid_audio_sync1 <= 18'd0;
            sid_audio_sync2 <= 18'd0;
        end else begin
            sid_audio_sync1 <= sid_audio_data;
            sid_audio_sync2 <= sid_audio_sync1;
        end
    end
    
    // Sigma-delta DAC converts 18-bit audio to 1-bit PDM
    // Use 74.25MHz pix_clk for better audio quality (original ZPUino used 96MHz)
    sigma_delta_dac #(.BITS(18)) u_audio_dac (
        .clk(pix_clk),
        .rst_n(hdmi_rst_n),
        .data_in(sid_audio_sync2),  // Use synchronized SID audio
        .audio_out(sid_audio_pdm)
    );
    
    // Simple audio mixer - OR both SID and YM2149 outputs
    // (1-bit PDM signals can be mixed with OR for testing)
    assign audio_left = sid_audio_pdm | ym2149_audio_pdm;
    assign audio_right = sid_audio_pdm | ym2149_audio_pdm;
`else
    wire [7:0] sid_wb_dat_o = 8'h00;
    wire sid_wb_ack = 1'b0;
    assign audio_left = ym2149_audio_pdm;
    assign audio_right = ym2149_audio_pdm;
`endif
    
    // =========================================================================
    // YM2149 PSG Audio Chip (at 0x8220-0x823F)
    // =========================================================================
    wire [7:0] ym2149_wb_dat_o;
    wire ym2149_wb_ack;
    wire [17:0] ym2149_audio_data;
    
    wb_ym2149_simple #(
        .CLK_FREQ_MHZ(27)
    ) u_ym2149 (
        .wb_clk_i(clk_27mhz),
        .wb_rst_i(rst),
        .wb_adr_i(wb_adr_o[4:0]),
        .wb_dat_i(wb_dat_o),
        .wb_dat_o(ym2149_wb_dat_o),
        .wb_cyc_i(wb_cyc_o && ym2149_selected),
        .wb_stb_i(wb_stb_o && ym2149_selected),
        .wb_we_i(wb_we_o),
        .wb_ack_o(ym2149_wb_ack),
        .audio_data(ym2149_audio_data)
    );
    
    // Synchronize YM2149 audio from 27MHz to pix_clk domain
    reg [17:0] ym2149_audio_sync1, ym2149_audio_sync2;
    always @(posedge pix_clk or negedge hdmi_rst_n) begin
        if (!hdmi_rst_n) begin
            ym2149_audio_sync1 <= 18'd0;
            ym2149_audio_sync2 <= 18'd0;
        end else begin
            ym2149_audio_sync1 <= ym2149_audio_data;
            ym2149_audio_sync2 <= ym2149_audio_sync1;
        end
    end
    
    // YM2149 sigma-delta DAC
    wire ym2149_audio_pdm;
    sigma_delta_dac #(.BITS(18)) u_ym2149_dac (
        .clk(pix_clk),
        .rst_n(hdmi_rst_n),
        .data_in(ym2149_audio_sync2),
        .audio_out(ym2149_audio_pdm)
    );
    
    // =========================================================================
    // Logic Analyzer (at 0x8300-0x83FF)
    // =========================================================================
    // Define signals to probe (32 channels)
    // Focus on capturing Wishbone bus for RGB LED writes
    // Add an 8-bit counter bank to the lower 8 probe bits for debugging
    reg [7:0] la_counter;
    always @(posedge clk_27mhz or posedge rst) begin
        if (rst) la_counter <= 8'b0;
        else la_counter <= la_counter + 1'b1;
    end

    wire [31:0] la_probe_signals = {
        // Wishbone data bus [31:24]
        wb_dat_o[7:0],
        // Wishbone control and address [23:16]
        wb_cyc_o, wb_stb_o, wb_we_o, wb_ack_i, rgb_led_selected, sid_selected, ym2149_selected, la_selected,
        // Wishbone address bus [15:8]
        wb_adr_o[7:0],
        // 8-bit counter for debug and LA capture [7:0]
        la_counter
    };
    
    wire [7:0] la_wb_dat_o;
    wire la_wb_ack;
    
    wb_logic_analyzer #(
        .NUM_CHANNELS(32),
        .MEM_DEPTH(2048)
    ) u_logic_analyzer (
        .clk(clk_27mhz),
        .rst(rst),
        .wb_adr_i(wb_adr_o[7:0]),
        .wb_dat_i(wb_dat_o),
        .wb_dat_o(la_wb_dat_o),
        .wb_cyc_i(wb_cyc_o && la_selected),
        .wb_stb_i(wb_stb_o && la_selected),
        .wb_we_i(wb_we_o),
        .wb_ack_o(la_wb_ack),
        .probe_in(la_probe_signals)
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
                      sid_selected     ? sid_wb_dat_o :
                      ym2149_selected  ? ym2149_wb_dat_o :
                      la_selected      ? la_wb_dat_o :
                      mode_ctrl_sel    ? mode_ctrl_dat :
                      tp_sel           ? tp_dat :
                      text_sel         ? text_dat :
                      fb_sel           ? fb_dat :
                      8'hFF;
    
    // OR the acks directly - slaves only assert when selected
    assign wb_ack_i = s0_wb_ack | sid_wb_ack | ym2149_wb_ack | la_wb_ack | mode_ctrl_ack | tp_ack | text_ack | fb_ack;

    // =========================================================================
    // SUMP Logic Analyzer on UART (Optional - Independent of Wishbone LA)
    // =========================================================================
    // Uncomment `define ENABLE_SUMP_UART_LA at top of file to enable
    // This provides standalone SUMP protocol logic analyzer over UART
    // Compatible with PulseView/Sigrok - 8 channels, up to 6K samples
    
`ifdef ENABLE_SUMP_TX_TEST
    // Test mode: Send bytes periodically to test TX path
    reg [31:0] tx_counter;
    reg [3:0] tx_bit_counter;
    reg [7:0] tx_shift_reg;
    reg tx_active;
    reg sump_tx_reg;
    
    // Baud rate generator for 115200 at 27MHz: 27000000/115200 = 234 clocks per bit
    localparam BAUD_DIVIDE = 234;
    reg [7:0] baud_counter;
    
    always @(posedge clk_27mhz or posedge rst) begin
        if (rst) begin
            tx_counter <= 0;
            tx_bit_counter <= 0;
            tx_shift_reg <= 8'h00;
            tx_active <= 0;
            sump_tx_reg <= 1'b1;  // UART idle high
            baud_counter <= 0;
        end else begin
            // Send a byte every ~27M cycles (once per second)
            tx_counter <= tx_counter + 1;
            
            if (!tx_active && tx_counter == 27000000) begin
                // Start new transmission - send 0x55 (alternating pattern)
                tx_counter <= 0;
                tx_shift_reg <= 8'h55;
                tx_active <= 1'b1;
                tx_bit_counter <= 0;
                baud_counter <= 0;
                sump_tx_reg <= 1'b0;  // Start bit
            end else if (tx_active) begin
                if (baud_counter == BAUD_DIVIDE - 1) begin
                    baud_counter <= 0;
                    if (tx_bit_counter < 8) begin
                        // Send data bits (LSB first)
                        sump_tx_reg <= tx_shift_reg[0];
                        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
                        tx_bit_counter <= tx_bit_counter + 1;
                    end else if (tx_bit_counter == 8) begin
                        // Send stop bit
                        sump_tx_reg <= 1'b1;
                        tx_bit_counter <= tx_bit_counter + 1;
                    end else begin
                        // Done
                        tx_active <= 0;
                        sump_tx_reg <= 1'b1;
                    end
                end else begin
                    baud_counter <= baud_counter + 1;
                end
            end
        end
    end
    
    assign sump_tx = sump_tx_reg;
    
`elsif ENABLE_SUMP_RX_ECHO_TEST
    // Test mode: Echo back whatever our simple UART receiver gets
    // Replace SUMP receiver with our own working UART
    
    reg [7:0] rx_data;
    reg rx_valid;
    reg [7:0] last_rx_byte;
    reg [31:0] tx_counter;
    reg [3:0] tx_bit_counter;
    reg [7:0] tx_shift_reg;
    reg tx_active;
    reg sump_tx_reg;
    
    // Baud rate generator for 115200 at 27MHz
    localparam BAUD_DIVIDE = 234;
    reg [7:0] baud_counter;
    
    // Simple UART Receiver
    reg [2:0] rx_state;
    reg [7:0] rx_baud_counter;
    reg [3:0] rx_bit_index;
    reg [7:0] rx_shift_reg;
    reg [1:0] sump_rx_sync;
    
    localparam RX_IDLE = 3'd0;
    localparam RX_START = 3'd1;
    localparam RX_DATA = 3'd2;
    localparam RX_STOP = 3'd3;
    
    // RX state machine
    always @(posedge clk_27mhz or posedge rst) begin
        if (rst) begin
            rx_state <= RX_IDLE;
            rx_data <= 8'h00;
            rx_valid <= 0;
            rx_baud_counter <= 0;
            rx_bit_index <= 0;
            rx_shift_reg <= 8'h00;
            sump_rx_sync <= 2'b11;
        end else begin
            // Synchronize input
            sump_rx_sync <= {sump_rx_sync[0], sump_rx};
            rx_valid <= 0;  // Pulse for one cycle
            
            case (rx_state)
                RX_IDLE: begin
                    rx_baud_counter <= 0;
                    if (sump_rx_sync[1] == 0) begin  // Start bit detected
                        rx_state <= RX_START;
                    end
                end
                
                RX_START: begin
                    if (rx_baud_counter == (BAUD_DIVIDE / 2)) begin
                        // Sample in middle of start bit
                        if (sump_rx_sync[1] == 0) begin
                            rx_state <= RX_DATA;
                            rx_baud_counter <= 0;
                            rx_bit_index <= 0;
                        end else begin
                            rx_state <= RX_IDLE;  // False start
                        end
                    end else begin
                        rx_baud_counter <= rx_baud_counter + 1;
                    end
                end
                
                RX_DATA: begin
                    if (rx_baud_counter == BAUD_DIVIDE - 1) begin
                        rx_baud_counter <= 0;
                        rx_shift_reg <= {sump_rx_sync[1], rx_shift_reg[7:1]};  // LSB first
                        if (rx_bit_index == 7) begin
                            rx_state <= RX_STOP;
                        end else begin
                            rx_bit_index <= rx_bit_index + 1;
                        end
                    end else begin
                        rx_baud_counter <= rx_baud_counter + 1;
                    end
                end
                
                RX_STOP: begin
                    if (rx_baud_counter == BAUD_DIVIDE - 1) begin
                        if (sump_rx_sync[1] == 1) begin  // Valid stop bit
                            rx_data <= rx_shift_reg;
                            rx_valid <= 1;
                        end
                        rx_state <= RX_IDLE;
                    end else begin
                        rx_baud_counter <= rx_baud_counter + 1;
                    end
                end
                
                default: rx_state <= RX_IDLE;
            endcase
        end
    end
    
    // TX echo logic
    always @(posedge clk_27mhz or posedge rst) begin
        if (rst) begin
            last_rx_byte <= 8'h00;
            tx_counter <= 0;
            tx_bit_counter <= 0;
            tx_shift_reg <= 8'h00;
            tx_active <= 0;
            sump_tx_reg <= 1'b1;
            baud_counter <= 0;
        end else begin
            // Capture byte when received
            if (rx_valid && !tx_active) begin
                last_rx_byte <= rx_data;
                tx_active <= 1'b1;
                tx_shift_reg <= rx_data;
                tx_bit_counter <= 0;
                baud_counter <= 0;
                sump_tx_reg <= 1'b0;  // Start bit
            end else if (tx_active) begin
                if (baud_counter == BAUD_DIVIDE - 1) begin
                    baud_counter <= 0;
                    if (tx_bit_counter < 8) begin
                        sump_tx_reg <= tx_shift_reg[0];
                        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
                        tx_bit_counter <= tx_bit_counter + 1;
                    end else if (tx_bit_counter == 8) begin
                        sump_tx_reg <= 1'b1;  // Stop bit
                        tx_bit_counter <= tx_bit_counter + 1;
                    end else begin
                        tx_active <= 0;
                        sump_tx_reg <= 1'b1;
                    end
                end else begin
                    baud_counter <= baud_counter + 1;
                end
            end
        end
    end
    
    assign sump_tx = sump_tx_reg;
    
`elsif ENABLE_SUMP_LOOPBACK
    // Simple loopback for SUMP UART: drive tx with rx for physical loopback testing
    assign sump_tx = sump_rx;
`else
    `ifdef ENABLE_SUMP_UART_LA
    // Define probe signals for SUMP analyzer (8 channels)
    // Connected to 8-bit counter - all channels should show counting pattern
    wire [7:0] sump_probe_signals = la_counter;
    
    // Instantiate SUMP Logic Analyzer (VHDL module)
    BENCHY_sa_SumpBlaze_LogicAnalyzer8 #(
        .brams(12)  // 12 BRAMs = 6K samples
    ) u_sump_analyzer (
        .clk_27Mhz(clk_27mhz),
        .la0(sump_probe_signals[0]),
        .la1(sump_probe_signals[1]),
        .la2(sump_probe_signals[2]),
        .la3(sump_probe_signals[3]),
        .la4(sump_probe_signals[4]),
        .la5(sump_probe_signals[5]),
        .la6(sump_probe_signals[6]),
        .la7(sump_probe_signals[7]),
        .rx(sump_rx),
        .tx(sump_tx)
    );
    `else
    // When SUMP UART LA is disabled, tie tx high (idle state)
    assign sump_tx = 1'b1;
    `endif
`endif

endmodule
