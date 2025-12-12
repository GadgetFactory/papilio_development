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
//`define ENABLE_AUDIO_SID  // Temporarily disabled to free resources for logic analyzer

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
    
    // UART for SUMP logic analyzer
    input wire sump_rx,
    output wire sump_tx
);

    // Reset signal (active high)
    wire rst = ~rst_n;
    
    // =========================================================================
    // SPI to Wishbone Bridge with DMA
    // =========================================================================
    wire [15:0] wb_adr_o;
    wire [7:0] wb_dat_o;
    wire wb_cyc_o;
    wire wb_stb_o;
    wire wb_we_o;
    wire [7:0] wb_dat_i;
    wire wb_ack_i;
    
    // Debug signals from SPI bridge
    wire [2:0] debug_byte_count;
    wire debug_is_dma_write;
    wire debug_start_dma;
    wire [2:0] debug_wb_state;
    wire [7:0] debug_cmd;
    
    // Async FIFO for DMA transfers (ESP32 to FPGA)
    wire fifo_wr_clk = esp_clk;
    wire fifo_rd_clk = clk_27mhz;
    wire fifo_wr_rst;
    wire fifo_rd_rst;
    wire fifo_wr_en;
    wire [7:0] fifo_wr_data;
    wire fifo_full;
    wire [9:0] fifo_wr_count;
    wire fifo_rd_en;
    wire [7:0] fifo_rd_data;
    wire fifo_empty;
    wire [9:0] fifo_rd_count;
    
    // Debug analyzer control
    reg debug_trigger;
    reg [7:0] debug_trigger_value;
    
    // Reset synchronizers for async FIFO
    reg [2:0] fifo_wr_rst_sync;
    reg [2:0] fifo_rd_rst_sync;
    
    always @(posedge fifo_wr_clk or posedge rst) begin
        if (rst)
            fifo_wr_rst_sync <= 3'b111;
        else
            fifo_wr_rst_sync <= {fifo_wr_rst_sync[1:0], 1'b0};
    end
    assign fifo_wr_rst = fifo_wr_rst_sync[2];
    
    always @(posedge fifo_rd_clk or posedge rst) begin
        if (rst)
            fifo_rd_rst_sync <= 3'b111;
        else
            fifo_rd_rst_sync <= {fifo_rd_rst_sync[1:0], 1'b0};
    end
    assign fifo_rd_rst = fifo_rd_rst_sync[2];
    
    // Instantiate async FIFO (512 bytes)
    async_fifo #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(9)  // 512 entries
    ) u_dma_fifo (
        .wr_clk(fifo_wr_clk),
        .wr_rst(fifo_wr_rst),
        .wr_en(fifo_wr_en),
        .wr_data(fifo_wr_data),
        .full(fifo_full),
        .wr_count(fifo_wr_count),
        
        .rd_clk(fifo_rd_clk),
        .rd_rst(fifo_rd_rst),
        .rd_en(fifo_rd_en),
        .rd_data(fifo_rd_data),
        .empty(fifo_empty),
        .rd_count(fifo_rd_count)
    );

    simple_spi_wb_bridge_with_dma u_spi_bridge (
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
        .wb_ack_i(wb_ack_i),
        // FIFO write interface (SPI clock domain)
        .fifo_wr_clk(fifo_wr_clk),
        .fifo_wr_data(fifo_wr_data),
        .fifo_wr_en(fifo_wr_en),
        .fifo_full(fifo_full),
        // FIFO read interface (system clock domain)
        .fifo_rd_en(fifo_rd_en),
        .fifo_rd_data(fifo_rd_data),
        .fifo_empty(fifo_empty),
        .fifo_rd_count(fifo_rd_count),
        // Debug outputs
        .debug_byte_count(debug_byte_count),
        .debug_is_dma_write(debug_is_dma_write),
        .debug_start_dma(debug_start_dma),
        .debug_wb_state(debug_wb_state),
        .debug_cmd(debug_cmd)
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
    //   0x8220-0x823F: YM2149 PSG chip
    //   0x8240-0x824F: Audio PCM passthrough (for DMA streaming)
    
    localparam ADDR_MODE_CTRL  = 16'h0000;
    localparam ADDR_TP_BASE    = 16'h0010;
    localparam ADDR_TEXT_BASE  = 16'h0020;
    localparam ADDR_FB_BASE    = 16'h0100;
    localparam ADDR_RGB_LED    = 16'h8100;
    localparam ADDR_SID_BASE   = 16'h8200;
    localparam ADDR_YM2149_BASE = 16'h8220;
    localparam ADDR_PCM_BASE   = 16'h8240;
    localparam ADDR_DEBUG_ANALYZER = 16'h8300;
    
    wire rgb_led_selected = (wb_adr_o[15:8] == 8'h81);
    wire sid_selected     = (wb_adr_o[15:8] == 8'h82) && (wb_adr_o[7:5] == 3'b000);  // 0x8200-0x821F
    wire ym2149_selected  = (wb_adr_o[15:8] == 8'h82) && (wb_adr_o[7:5] == 3'b001);  // 0x8220-0x823F
    wire pcm_selected     = (wb_adr_o[15:8] == 8'h82) && (wb_adr_o[7:4] == 4'b0100); // 0x8240-0x824F
    wire debug_analyzer_sel = (wb_adr_o[15:8] == 8'h83);  // 0x8300-0x83FF
    wire mode_ctrl_sel    = (wb_adr_o < ADDR_TP_BASE) && !rgb_led_selected && !sid_selected;
    wire tp_sel           = (wb_adr_o >= ADDR_TP_BASE) && (wb_adr_o < ADDR_TEXT_BASE);
    wire text_sel         = (wb_adr_o >= ADDR_TEXT_BASE) && (wb_adr_o < ADDR_FB_BASE);
    wire fb_sel           = (wb_adr_o >= ADDR_FB_BASE) && (wb_adr_o < ADDR_RGB_LED);
    
    // =========================================================================
    // RGB LED Controller (at 0x8100-0x81FF)
    // =========================================================================
    wire [7:0] s0_wb_dat_i;
    wire s0_wb_ack;
    
    wb_simple_rgb_led u_rgb_led (
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
    // SUMP2 Logic Analyzer - Simple version for Gowin FPGA
    // =========================================================================
    // Capture important debug signals for analysis
    wire [31:0] sump_events;
    assign sump_events = {
        // [31:24] - SPI/DMA debug (8 bits)
        debug_cmd[7:0],
        // [23:16] - Wishbone bus (8 bits) 
        wb_adr_o[7:0],
        // [15:8] - Wishbone data and control (8 bits)
        wb_dat_o[7:0],
        // [7:0] - Status flags (8 bits)
        fifo_full,
        fifo_empty,
        debug_start_dma,
        debug_is_dma_write,
        debug_wb_state[2:0],
        wb_cyc_o
    };
    
    sump2_simple #(
        .DEPTH_LEN(2048),    // 2K samples
        .DEPTH_BITS(11),     // 2^11 = 2048
        .EVENT_BYTES(4),     // 32-bit capture
        .FREQ_MHZ(16'd27)    // 27MHz clock
    ) u_sump_analyzer (
        .clk(clk_27mhz),
        .rst(rst),
        .uart_rx(sump_rx),
        .uart_tx(sump_tx),
        .events_din(sump_events)
    );
    
    // =========================================================================
    // DMA Debug Logic Analyzer (at 0x8300-0x83FF) - Wishbone backup
    // =========================================================================
    wire [7:0] debug_wb_dat_o;
    wire debug_wb_ack;
    
    dma_debug_analyzer #(
        .ADDR_WIDTH(7)  // 128 samples = 512 bytes of data
    ) u_debug_analyzer (
        .clk(clk_27mhz),
        .rst(rst),
        // Trigger control
        .trigger(debug_trigger),
        .trigger_value(debug_trigger_value),
        // Signals to capture
        .spi_cs_active(!esp_cs_n),
        .spi_sclk_posedge(1'b0),  // Not exposed, will capture state instead
        .spi_mosi_byte(debug_cmd),
        .byte_count(debug_byte_count),
        .is_dma_write(debug_is_dma_write),
        .start_dma(debug_start_dma),
        .fifo_wr_en(fifo_wr_en),
        .fifo_wr_data(fifo_wr_data),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty),
        .wb_state(debug_wb_state),
        .wb_cyc(wb_cyc_o),
        .wb_stb(wb_stb_o),
        .wb_ack(wb_ack_i),
        .wb_adr(wb_adr_o),
        .wb_dat(wb_dat_o),
        // Wishbone slave interface for reading/writing
        .wb_cyc_i(wb_cyc_o && debug_analyzer_sel),
        .wb_stb_i(wb_stb_o && debug_analyzer_sel),
        .wb_we_i(wb_we_o),
        .wb_adr_i(wb_adr_o),
        .wb_dat_i(wb_dat_o),
        .wb_dat_o(debug_wb_dat_o),
        .wb_ack_o(debug_wb_ack)
    );
    
    // Debug trigger control registers (write-only at 0x8400-0x8401)
    wire debug_ctrl_sel = (wb_adr_o[15:8] == 8'h84);
    always @(posedge clk_27mhz or posedge rst) begin
        if (rst) begin
            debug_trigger <= 0;
            debug_trigger_value <= 8'h02;  // Default: trigger on DMA write command
        end else begin
            debug_trigger <= 0;  // Auto-clear after 1 cycle
            if (wb_cyc_o && wb_stb_o && wb_we_o && debug_ctrl_sel) begin
                if (wb_adr_o[0] == 1'b0)
                    debug_trigger <= wb_dat_o[0];
                else
                    debug_trigger_value <= wb_dat_o;
            end
        end
    end
    
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
    
    // Simple audio mixer - OR SID, YM2149, and PCM outputs
    // (1-bit PDM signals can be mixed with OR for testing)
    assign audio_left = sid_audio_pdm | ym2149_audio_pdm | pcm_audio_pdm_left;
    assign audio_right = sid_audio_pdm | ym2149_audio_pdm | pcm_audio_pdm_right;
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
    // Audio PCM Passthrough (at 0x8240-0x824F) - For DMA streaming
    // =========================================================================
    wire [7:0] pcm_wb_dat_o;
    wire pcm_wb_ack;
    wire signed [17:0] pcm_audio_left_data;
    wire signed [17:0] pcm_audio_right_data;
    wire pcm_sample_toggle;
    
    wb_audio_passthrough u_pcm_passthrough (
        .wb_clk_i(clk_27mhz),
        .wb_rst_i(rst),
        .wb_adr_i(wb_adr_o),
        .wb_dat_i(wb_dat_o),
        .wb_dat_o(pcm_wb_dat_o),
        .wb_we_i(wb_we_o),
        .wb_cyc_i(wb_cyc_o && pcm_selected),
        .wb_stb_i(wb_stb_o && pcm_selected),
        .wb_ack_o(pcm_wb_ack),
        .audio_left(pcm_audio_left_data),
        .audio_right(pcm_audio_right_data),
        .sample_toggle(pcm_sample_toggle)
    );
    
    // Synchronize PCM audio from 27MHz to pix_clk (74.25MHz) domain
    reg signed [17:0] pcm_audio_left_sync1, pcm_audio_left_sync2;
    reg signed [17:0] pcm_audio_right_sync1, pcm_audio_right_sync2;
    always @(posedge pix_clk or negedge hdmi_rst_n) begin
        if (!hdmi_rst_n) begin
            pcm_audio_left_sync1 <= 18'sd0;
            pcm_audio_left_sync2 <= 18'sd0;
            pcm_audio_right_sync1 <= 18'sd0;
            pcm_audio_right_sync2 <= 18'sd0;
        end else begin
            pcm_audio_left_sync1 <= pcm_audio_left_data;
            pcm_audio_left_sync2 <= pcm_audio_left_sync1;
            pcm_audio_right_sync1 <= pcm_audio_right_data;
            pcm_audio_right_sync2 <= pcm_audio_right_sync1;
        end
    end
    
    // PCM sigma-delta DACs (stereo)
    wire pcm_audio_pdm_left;
    wire pcm_audio_pdm_right;
    sigma_delta_dac #(.BITS(18)) u_pcm_dac_left (
        .clk(pix_clk),
        .rst_n(hdmi_rst_n),
        .data_in(pcm_audio_left_sync2),
        .audio_out(pcm_audio_pdm_left)
    );
    sigma_delta_dac #(.BITS(18)) u_pcm_dac_right (
        .clk(pix_clk),
        .rst_n(hdmi_rst_n),
        .data_in(pcm_audio_right_sync2),
        .audio_out(pcm_audio_pdm_right)
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
    
    // Gate the output based on selection for proper OR-ing in multiplexer
    wire [7:0] mode_ctrl_dat = mode_ctrl_sel ? {6'b0, video_mode} : 8'h00;
    
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
    // Use conditional multiplexing for data (avoids bus contention)
    assign wb_dat_i = rgb_led_selected  ? s0_wb_dat_i :
                      sid_selected      ? sid_wb_dat_o :
                      ym2149_selected   ? ym2149_wb_dat_o :
                      pcm_selected      ? pcm_wb_dat_o :
                      debug_analyzer_sel ? debug_wb_dat_o :
                      mode_ctrl_sel     ? mode_ctrl_dat :
                      tp_sel            ? tp_dat :
                      text_sel          ? text_dat :
                      fb_sel            ? fb_dat :
                      8'hFF;  // Default for unmapped addresses
    
    // OR the acks directly - slaves only assert when selected
    assign wb_ack_i = s0_wb_ack | sid_wb_ack | ym2149_wb_ack | pcm_wb_ack | debug_wb_ack | mode_ctrl_ack | tp_ack | text_ack | fb_ack;

endmodule
