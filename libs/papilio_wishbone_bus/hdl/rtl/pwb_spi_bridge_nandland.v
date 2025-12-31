// SPI to Wishbone Bridge - Based on Nandland SPI_Slave (MIT Licensed)
// Original: https://github.com/nandland/spi-slave
// Modified for Wishbone protocol integration
// CPOL=0, CPHA=0 (Mode 0)

module pwb_spi_bridge_nandland (
    // System
    input wire clk,           // System clock (27MHz)
    input wire rst,           // Active high reset
    
    // SPI Interface (slave)
    input  wire esp_sclk,     // SPI clock from master
    input  wire esp_mosi,     // SPI MOSI
    output wire esp_miso,     // SPI MISO
    input  wire esp_cs_n,     // SPI CS (active low)
    
    // Wishbone Master Interface
    output reg         wb_cyc_o,
    output reg         wb_stb_o,
    output reg         wb_we_o,
    output reg  [31:0] wb_addr_o,
    output reg  [31:0] wb_data_o,
    output reg  [3:0]  wb_sel_o,
    input  wire [31:0] wb_data_i,
    input  wire        wb_ack_i,
    input  wire        wb_err_i
);

    // SPI receive/transmit registers
    reg [7:0] spi_rx_byte;
    reg       spi_rx_dv;       // Data valid pulse (1 clk cycle in SPI domain)
    reg [7:0] spi_tx_byte;     // Byte to transmit on MISO
    reg       spi_tx_dv;       // Load pulse for TX byte
    
    // SPI domain signals
    reg [2:0] spi_rx_bit_count;
    reg [7:0] spi_rx_byte_temp;
    reg       spi_rx_done;
    
    reg [2:0] spi_tx_bit_count;
    reg       spi_miso_bit;
    reg       spi_preload_miso;
    
    // Clock domain crossing for RX
    reg       spi_rx_done_sync1;
    reg       spi_rx_done_sync2;
    reg       spi_rx_done_sync3;
    
    // Clock domain crossing for TX (system -> SPI)
    reg [7:0] spi_tx_byte_hold;
    
    // Protocol state machine
    localparam STATE_CMD        = 4'd0;
    localparam STATE_ADDR_BYTE0 = 4'd1;
    localparam STATE_ADDR_BYTE1 = 4'd2;
    localparam STATE_ADDR_BYTE2 = 4'd3;
    localparam STATE_ADDR_BYTE3 = 4'd4;
    localparam STATE_WR_DATA0   = 4'd5;
    localparam STATE_WR_DATA1   = 4'd6;
    localparam STATE_WR_DATA2   = 4'd7;
    localparam STATE_WR_DATA3   = 4'd8;
    localparam STATE_RD_DATA0   = 4'd9;
    localparam STATE_RD_DATA1   = 4'd10;
    localparam STATE_RD_DATA2   = 4'd11;
    localparam STATE_RD_DATA3   = 4'd12;
    localparam STATE_ECHO       = 4'd13;
    
    reg [3:0]  state;
    reg [31:0] addr_reg;
    reg [31:0] wr_data_reg;
    reg [31:0] rd_data_reg;
    reg        is_read;
    
    // Command definitions
    localparam CMD_WRITE = 8'h01;
    localparam CMD_READ  = 8'h02;
    localparam CMD_ECHO  = 8'hFF;

    //----------------------------------------------------------------------
    // SPI RECEIVER (in SPI clock domain)
    // Samples on rising edge of SCLK (CPHA=0)
    //----------------------------------------------------------------------
    always @(posedge esp_sclk or posedge esp_cs_n) begin
        if (esp_cs_n) begin
            spi_rx_bit_count <= 3'd0;
            spi_rx_done      <= 1'b0;
        end else begin
            spi_rx_bit_count <= spi_rx_bit_count + 3'd1;
            
            // Shift in LSB first, build up to MSB
            spi_rx_byte_temp <= {spi_rx_byte_temp[6:0], esp_mosi};
            
            // After bit 7, byte is complete
            if (spi_rx_bit_count == 3'd7) begin
                spi_rx_done <= 1'b1;
                spi_rx_byte <= {spi_rx_byte_temp[6:0], esp_mosi};
            end else if (spi_rx_bit_count == 3'd2) begin
                // Clear done flag early for next byte
                spi_rx_done <= 1'b0;
            end
        end
    end
    
    //----------------------------------------------------------------------
    // SPI TRANSMITTER (in SPI clock domain)
    // Outputs on rising edge of SCLK (CPHA=0)
    // Uses preload mechanism from Nandland design
    //----------------------------------------------------------------------
    
    // Preload control: set when CS high, clear on first clock edge
    always @(posedge esp_sclk or posedge esp_cs_n) begin
        if (esp_cs_n) begin
            spi_preload_miso <= 1'b1;
        end else begin
            spi_preload_miso <= 1'b0;
        end
    end
    
    // Transmit bit shifting - Nandland approach
    // Counter decrements separately from bit output
    always @(posedge esp_sclk or posedge esp_cs_n) begin
        if (esp_cs_n) begin
            spi_tx_bit_count <= 3'd7;  // Start at MSB position
        end else begin
            spi_tx_bit_count <= spi_tx_bit_count - 3'd1;
        end
    end
    
    // MISO bit register - loads on falling edge after counter updates
    always @(negedge esp_sclk or posedge esp_cs_n) begin
        if (esp_cs_n) begin
            spi_miso_bit <= spi_tx_byte_hold[7];  // Preload MSB
        end else begin
            // After master samples on rising edge, we update on falling edge
            spi_miso_bit <= spi_tx_byte_hold[spi_tx_bit_count];
        end
    end
    
    // MISO output: preload MSB initially, then use shifted bit
    wire miso_mux = spi_preload_miso ? spi_tx_byte_hold[7] : spi_miso_bit;
    assign esp_miso = esp_cs_n ? 1'bZ : miso_mux;
    
    //----------------------------------------------------------------------
    // CLOCK DOMAIN CROSSING: SPI -> System clock
    //----------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            spi_rx_done_sync1 <= 1'b0;
            spi_rx_done_sync2 <= 1'b0;
            spi_rx_done_sync3 <= 1'b0;
            spi_rx_dv         <= 1'b0;
        end else begin
            // Two-stage synchronizer
            spi_rx_done_sync1 <= spi_rx_done;
            spi_rx_done_sync2 <= spi_rx_done_sync1;
            spi_rx_done_sync3 <= spi_rx_done_sync2;
            
            // Detect rising edge
            if (spi_rx_done_sync2 && !spi_rx_done_sync3) begin
                spi_rx_dv <= 1'b1;
            end else begin
                spi_rx_dv <= 1'b0;
            end
        end
    end
    
    //----------------------------------------------------------------------
    // CLOCK DOMAIN CROSSING: System -> SPI clock
    // Hold TX byte in register that's stable in SPI clock domain
    //----------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            spi_tx_byte_hold <= 8'h00;
        end else begin
            if (spi_tx_dv) begin
                spi_tx_byte_hold <= spi_tx_byte;
            end
        end
    end
    
    //----------------------------------------------------------------------
    // PROTOCOL STATE MACHINE (in system clock domain)
    //----------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= STATE_CMD;
            addr_reg    <= 32'h0;
            wr_data_reg <= 32'h0;
            rd_data_reg <= 32'h0;
            is_read     <= 1'b0;
            wb_cyc_o    <= 1'b0;
            wb_stb_o    <= 1'b0;
            wb_we_o     <= 1'b0;
            wb_addr_o   <= 32'h0;
            wb_data_o   <= 32'h0;
            wb_sel_o    <= 4'b0;
            spi_tx_byte <= 8'h00;
            spi_tx_dv   <= 1'b0;
        end else begin
            spi_tx_dv   <= 1'b0;  // Default: no TX load
            
            // Wishbone auto-deassert on ACK
            if (wb_ack_i || wb_err_i) begin
                wb_cyc_o <= 1'b0;
                wb_stb_o <= 1'b0;
            end
            
            // State machine triggered by received bytes
            if (spi_rx_dv) begin
                case (state)
                    STATE_CMD: begin
                        if (spi_rx_byte == CMD_WRITE) begin
                            is_read <= 1'b0;
                            state   <= STATE_ADDR_BYTE0;
                        end else if (spi_rx_byte == CMD_READ) begin
                            is_read <= 1'b1;
                            state   <= STATE_ADDR_BYTE0;
                        end else if (spi_rx_byte == CMD_ECHO) begin
                            state <= STATE_ECHO;
                        end
                    end
                    
                    STATE_ADDR_BYTE0: begin
                        addr_reg[31:24] <= spi_rx_byte;
                        state           <= STATE_ADDR_BYTE1;
                    end
                    
                    STATE_ADDR_BYTE1: begin
                        addr_reg[23:16] <= spi_rx_byte;
                        state           <= STATE_ADDR_BYTE2;
                    end
                    
                    STATE_ADDR_BYTE2: begin
                        addr_reg[15:8] <= spi_rx_byte;
                        state          <= STATE_ADDR_BYTE3;
                    end
                    
                    STATE_ADDR_BYTE3: begin
                        addr_reg[7:0] <= spi_rx_byte;
                        if (is_read) begin
                            state <= STATE_RD_DATA0;
                        end else begin
                            state <= STATE_WR_DATA0;
                        end
                    end
                    
                    STATE_WR_DATA0: begin
                        wr_data_reg[31:24] <= spi_rx_byte;
                        state              <= STATE_WR_DATA1;
                    end
                    
                    STATE_WR_DATA1: begin
                        wr_data_reg[23:16] <= spi_rx_byte;
                        state              <= STATE_WR_DATA2;
                    end
                    
                    STATE_WR_DATA2: begin
                        wr_data_reg[15:8] <= spi_rx_byte;
                        state             <= STATE_WR_DATA3;
                    end
                    
                    STATE_WR_DATA3: begin
                        wr_data_reg[7:0] <= spi_rx_byte;
                        // Initiate Wishbone write
                        wb_cyc_o  <= 1'b1;
                        wb_stb_o  <= 1'b1;
                        wb_we_o   <= 1'b1;
                        wb_addr_o <= addr_reg;
                        wb_data_o <= {wr_data_reg[31:8], spi_rx_byte};
                        wb_sel_o  <= 4'b1111;
                        state     <= STATE_CMD;
                    end
                    
                    STATE_RD_DATA0: begin
                        // Initiate Wishbone read if not already pending
                        if (!wb_cyc_o) begin
                            wb_cyc_o  <= 1'b1;
                            wb_stb_o  <= 1'b1;
                            wb_we_o   <= 1'b0;
                            wb_addr_o <= addr_reg;
                            wb_sel_o  <= 4'b1111;
                        end
                        // Wait for ACK then send byte 0
                        if (wb_ack_i) begin
                            rd_data_reg     <= wb_data_i;
                            spi_tx_byte     <= wb_data_i[31:24];
                            spi_tx_dv       <= 1'b1;
                            state           <= STATE_RD_DATA1;
                        end
                    end
                    
                    STATE_RD_DATA1: begin
                        spi_tx_byte <= rd_data_reg[23:16];
                        spi_tx_dv   <= 1'b1;
                        state       <= STATE_RD_DATA2;
                    end
                    
                    STATE_RD_DATA2: begin
                        spi_tx_byte <= rd_data_reg[15:8];
                        spi_tx_dv   <= 1'b1;
                        state       <= STATE_RD_DATA3;
                    end
                    
                    STATE_RD_DATA3: begin
                        spi_tx_byte <= rd_data_reg[7:0];
                        spi_tx_dv   <= 1'b1;
                        state       <= STATE_CMD;
                    end
                    
                    STATE_ECHO: begin
                        // Echo back the received byte
                        spi_tx_byte <= spi_rx_byte;
                        spi_tx_dv   <= 1'b1;
                        state       <= STATE_CMD;
                    end
                    
                    default: begin
                        state <= STATE_CMD;
                    end
                endcase
            end
            
            // Handle read state when waiting for Wishbone ACK
            if (state == STATE_RD_DATA0 && !spi_rx_dv) begin
                if (!wb_cyc_o) begin
                    wb_cyc_o  <= 1'b1;
                    wb_stb_o  <= 1'b1;
                    wb_we_o   <= 1'b0;
                    wb_addr_o <= addr_reg;
                    wb_sel_o  <= 4'b1111;
                end
            end
        end
    end

endmodule
