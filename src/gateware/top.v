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
    
    // Wishbone signals - Master (SPI bridge with 16-bit addressing)
    wire [15:0] wb_adr_o;
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
    
    // Wishbone signals - Slave 3 (HQVGA with 15-bit frame buffer addressing)
    wire [14:0] s3_wb_adr;  // 15-bit address for 19,200 pixel frame buffer
    wire [7:0] s3_wb_dat_o;
    wire [7:0] s3_wb_dat_i;
    wire s3_wb_cyc;
    wire s3_wb_stb;
    wire s3_wb_we;
    wire s3_wb_ack;
    
    // Character RAM video interface
    wire [11:0] video_char_addr;
    wire [7:0] video_char_data;
    wire [7:0] video_attr_data;
    
    // Custom font RAM interface
    wire custom_font_we;
    wire [5:0] custom_font_addr;
    wire [7:0] custom_font_data;
    
    // 50MHz clock for HQVGA
    wire clk_50mhz;
    wire pll_50mhz_lock;
    
    // VGA signals from HQVGA
    wire vga_hsync, vga_vsync;
    wire vga_r2, vga_r1, vga_r0;
    wire vga_g2, vga_g1, vga_g0;
    wire vga_b1, vga_b0;
    
    // Expanded 8-bit RGB for HDMI adapter
    wire [7:0] vga_r_8bit = {vga_r2, vga_r1, vga_r0, vga_r2, vga_r1, vga_r0, vga_r2, vga_r1};
    wire [7:0] vga_g_8bit = {vga_g2, vga_g1, vga_g0, vga_g2, vga_g1, vga_g0, vga_g2, vga_g1};
    wire [7:0] vga_b_8bit = {vga_b1, vga_b0, vga_b1, vga_b0, vga_b1, vga_b0, vga_b1, vga_b0};
    
    // VGA display enable from HQVGA
    wire vga_de;
    
    // ========== DIRECT VGA TEST PATTERN (bypass HQVGA) ==========
    // Generate 800x600@72Hz VGA timing directly for testing
    // This bypasses the HQVGA module to test vga_to_hdmi directly
    
    // 800x600@72Hz timing
    localparam H_DISPLAY = 800;
    localparam H_FRONT = 56;
    localparam H_SYNC = 120;
    localparam H_BACK = 64;
    localparam H_TOTAL = H_DISPLAY + H_FRONT + H_SYNC + H_BACK;  // 1040
    
    localparam V_DISPLAY = 600;
    localparam V_FRONT = 37;
    localparam V_SYNC = 6;
    localparam V_BACK = 23;
    localparam V_TOTAL = V_DISPLAY + V_FRONT + V_SYNC + V_BACK;  // 666
    
    reg [10:0] h_count = 0;
    reg [9:0] v_count = 0;
    reg test_hsync = 1;
    reg test_vsync = 1;
    reg test_de = 0;
    reg [7:0] test_r = 0;
    reg [7:0] test_g = 0;
    reg [7:0] test_b = 0;
    
    always @(posedge clk_50mhz) begin
        if (!pll_50mhz_lock) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            // Horizontal counter
            if (h_count == H_TOTAL - 1) begin
                h_count <= 0;
                // Vertical counter
                if (v_count == V_TOTAL - 1)
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
            end else begin
                h_count <= h_count + 1;
            end
            
            // Sync signals (positive polarity for 800x600@72Hz)
            test_hsync <= (h_count >= H_DISPLAY + H_FRONT) && (h_count < H_DISPLAY + H_FRONT + H_SYNC) ? 1'b0 : 1'b1;
            test_vsync <= (v_count >= V_DISPLAY + V_FRONT) && (v_count < V_DISPLAY + V_FRONT + V_SYNC) ? 1'b0 : 1'b1;
            
            // Data enable - active during visible area
            test_de <= (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
            
            // Test pattern: SOLID RED
            if ((h_count < H_DISPLAY) && (v_count < V_DISPLAY)) begin
                test_r <= 8'hFF;  // Full red
                test_g <= 8'h00;
                test_b <= 8'h00;
            end else begin
                test_r <= 8'h00;
                test_g <= 8'h00;
                test_b <= 8'h00;
            end
        end
    end
    // ========== END DIRECT VGA TEST ==========
    
    // HQVGA Wishbone bus (100-bit format)
    wire [100:0] hqvga_wb_in;
    wire [100:0] hqvga_wb_out;
    wire [32:0] vga_bus;  // Unused for now
    
    // Pixel clock comes from video_top_800x600 (50.4MHz from TMDS PLL / 5)
    // This ensures VGA and HDMI clocks are phase-aligned
    wire hdmi_pix_clk;
    wire hdmi_pix_clk_locked;
    assign clk_50mhz = hdmi_pix_clk;
    assign pll_50mhz_lock = hdmi_pix_clk_locked;
    
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
    
    // Wishbone address decoder (now with 4 slaves)
    // Note: HQVGA (slave 3) is connected directly to SPI bridge for testing
    // Decoder still handles slaves 0-2 (RGB LED, HDMI, Char RAM)
    wire decoder_ack;  // Decoder's ack output (not used, we generate wb_ack_i manually)
    wb_address_decoder_4 u_wb_decoder (
        .clk(clk_27mhz),
        .rst(rst),
        .wb_adr_i(wb_adr_o),
        .wb_dat_i(wb_dat_o),
        .wb_dat_o(wb_dat_i),
        .wb_cyc_i(wb_cyc_o),
        .wb_stb_i(wb_stb_o),
        .wb_we_i(wb_we_o),
        .wb_ack_o(decoder_ack),
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
        .s2_wb_ack_i(s2_wb_ack),
        .s3_wb_adr_o(s3_wb_adr),
        .s3_wb_dat_o(s3_wb_dat_o),
        .s3_wb_dat_i(s3_wb_dat_i),
        .s3_wb_cyc_o(s3_wb_cyc),
        .s3_wb_stb_o(s3_wb_stb),
        .s3_wb_we_o(s3_wb_we),
        .s3_wb_ack_i(s3_wb_ack)
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

    // HDMI video controller (Slave 1, addresses 0x10-0x1F) - DISABLED
    // NOTE: Currently using HQVGA + VGA-to-HDMI adapter instead
    // To re-enable this, comment out the vga_to_hdmi instantiation below
    // and uncomment this module
    /*
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
        .text_attr_data(video_attr_data),
        .custom_font_we(custom_font_we),
        .custom_font_addr(custom_font_addr),
        .custom_font_data(custom_font_data),
        .O_tmds_clk_p(O_tmds_clk_p),
        .O_tmds_clk_n(O_tmds_clk_n),
        .O_tmds_data_p(O_tmds_data_p),
        .O_tmds_data_n(O_tmds_data_n)
    );
    */
    
    // Stub for slave 1 (no ACK, returns 0)
    assign s1_wb_dat_i = 8'h00;
    assign s1_wb_ack = s1_wb_cyc && s1_wb_stb;
    
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
        .video_char_data(video_char_data),
        .video_attr_data(video_attr_data),
        .custom_font_we(custom_font_we),
        .custom_font_addr(custom_font_addr),
        .custom_font_data(custom_font_data)
    );
    
    // Pack Wishbone signals for HQVGA (100-bit format)
    // DIRECT CONNECTION FOR TESTING - bypass decoder
    // 15-bit address supports full 19,200 pixel frame buffer (160x120)
    // HQVGA extracts wb_adr_i[16:2] for RAM address
    // With word-aligned addresses from ESP32 (pixel*4), bits [16:2] give pixel index
    assign hqvga_wb_in[61] = clk_27mhz;
    assign hqvga_wb_in[60] = rst;
    assign hqvga_wb_in[59:28] = {24'b0, wb_dat_o};  // Direct from SPI bridge, extend 8-bit to 32-bit
    assign hqvga_wb_in[27:3] = {10'b0, wb_adr_o[14:0]};  // Direct 15-bit address from SPI bridge
    assign hqvga_wb_in[2] = wb_we_o;   // Direct from SPI bridge
    assign hqvga_wb_in[1] = wb_cyc_o && !wb_adr_o[15];  // Select HQVGA when bit 15 = 0
    assign hqvga_wb_in[0] = wb_stb_o && !wb_adr_o[15];  // Select HQVGA when bit 15 = 0
    assign hqvga_wb_in[100:62] = 39'b0;  // Unused upper bits
    
    // Generate ACK directly - bypass decoder for HQVGA
    wire hqvga_selected = !wb_adr_o[15];
    
    // HDMI Framebuffer ACK signal
    wire hdmi_fb_ack;
    
    // Route ACK from either HQVGA or HDMI framebuffer (or other slaves)
    // For now, HDMI framebuffer is the primary target for pixel writes
    assign wb_ack_i = hqvga_selected ? hdmi_fb_ack : 
                      (s0_wb_ack | s1_wb_ack | s2_wb_ack);
    
    // Unpack Wishbone response from HQVGA (kept for compatibility, but not used for video)
    assign s3_wb_dat_i = hqvga_wb_out[9:2];  // Get lower 8 bits
    assign s3_wb_ack = hqvga_wb_out[1];
    
    // HQVGA controller - DISABLED for now, using HDMI framebuffer instead
    // Keep the module instantiated but don't use its video output
    HQVGA u_hqvga (
        .wishbone_in(hqvga_wb_in),
        .wishbone_out(hqvga_wb_out),
        .VGA_Bus(vga_bus),
        .clk_50Mhz(clk_50mhz),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .vga_de(vga_de),
        .vga_r2(vga_r2),
        .vga_r1(vga_r1),
        .vga_r0(vga_r0),
        .vga_g2(vga_g2),
        .vga_g1(vga_g1),
        .vga_g0(vga_g0),
        .vga_b1(vga_b1),
        .vga_b0(vga_b0)
    );
    
    // HDMI output with built-in 160x120 framebuffer
    // Directly connected to Wishbone bus - ESP32 writes pixels here
    // Outputs 720p HDMI with 6x scaling (960x720 centered)
    video_top_framebuffer u_video_top (
        .I_clk(clk_27mhz),
        .I_rst_n(rst_n),
        // Wishbone slave interface - direct from SPI bridge
        .I_wb_clk(clk_27mhz),
        .I_wb_rst(rst),
        .I_wb_adr(wb_adr_o[14:0]),       // 15-bit address for 19,200 pixels
        .I_wb_dat(wb_dat_o),              // 8-bit data
        .I_wb_we(wb_we_o),
        .I_wb_stb(wb_stb_o && hqvga_selected),  // Select when bit 15 = 0
        .I_wb_cyc(wb_cyc_o && hqvga_selected),
        .O_wb_ack(hdmi_fb_ack),
        .O_wb_dat(),                       // Read data (not used by HQVGA lib)
        // HDMI output
        .O_tmds_clk_p(O_tmds_clk_p),
        .O_tmds_clk_n(O_tmds_clk_n),
        .O_tmds_data_p(O_tmds_data_p),
        .O_tmds_data_n(O_tmds_data_n)
    );

endmodule

