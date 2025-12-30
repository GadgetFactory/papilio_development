// ssw_spi_bridge.v - Smart Slot Wishbone SPI Bridge
// Converts SPI transactions to Wishbone bus cycles

`include "ssw_pkg.vh"

module ssw_spi_bridge (
    // System clock and reset
    input wire clk,
    input wire rst,
    
    // SPI slave interface
    input wire spi_sclk,
    input wire spi_mosi,
    output reg spi_miso,
    input wire spi_cs_n,
    
    // Wishbone master interface
    output reg [23:0] wb_adr_o,
    output reg [7:0]  wb_dat_o,
    input wire [7:0]  wb_dat_i,
    output reg        wb_cyc_o,
    output reg        wb_stb_o,
    output reg        wb_we_o,
    input wire        wb_ack_i,
    
    // Control signals
    output reg [1:0]  access_tier_o,     // 0=slot, 1=extended, 2=large
    output reg        burst_mode_o,
    output reg [15:0] burst_count_o,
    
    // Debug/status
    output reg [7:0]  last_cmd_o,
    output reg        error_o
);

// =============================================================================
// SPI Interface - Clock Domain Crossing
// =============================================================================

// Synchronize SPI signals to system clock
reg [2:0] spi_sclk_sync;
reg [2:0] spi_cs_sync;
reg [1:0] spi_mosi_sync;

always @(posedge clk) begin
    spi_sclk_sync <= {spi_sclk_sync[1:0], spi_sclk};
    spi_cs_sync <= {spi_cs_sync[1:0], spi_cs_n};
    spi_mosi_sync <= {spi_mosi_sync[0], spi_mosi};
end

wire spi_sclk_rising = (spi_sclk_sync[2:1] == 2'b01);
wire spi_sclk_falling = (spi_sclk_sync[2:1] == 2'b10);
wire spi_cs_active = !spi_cs_sync[1];
wire spi_cs_deassert = (spi_cs_sync[2:1] == 2'b01);

// SPI shift register
reg [7:0] spi_shift_in;
reg [7:0] spi_shift_out;
reg [2:0] bit_count;
reg byte_ready;

always @(posedge clk) begin
    if (rst || !spi_cs_active) begin
        bit_count <= 3'd0;
        byte_ready <= 1'b0;
    end else if (spi_sclk_rising) begin
        spi_shift_in <= {spi_shift_in[6:0], spi_mosi_sync[1]};
        bit_count <= bit_count + 1'b1;
        byte_ready <= (bit_count == 3'd7);
    end else begin
        byte_ready <= 1'b0;
    end
end

// SPI output (on falling edge for mode 0)
always @(posedge clk) begin
    if (spi_sclk_falling && spi_cs_active) begin
        spi_miso <= spi_shift_out[7];
        spi_shift_out <= {spi_shift_out[6:0], 1'b0};
    end
end

// =============================================================================
// Protocol State Machine
// =============================================================================

localparam [3:0]
    STATE_IDLE      = 4'd0,
    STATE_RX_CMD    = 4'd1,
    STATE_RX_REG    = 4'd2,
    STATE_RX_ADDR_H = 4'd3,
    STATE_RX_ADDR_M = 4'd4,
    STATE_RX_ADDR_L = 4'd5,
    STATE_RX_COUNT_H = 4'd6,
    STATE_RX_COUNT_L = 4'd7,
    STATE_RX_DATA   = 4'd8,
    STATE_WB_WRITE  = 4'd9,
    STATE_WB_READ   = 4'd10,
    STATE_TX_DATA   = 4'd11,
    STATE_ERROR     = 4'd12;

reg [3:0] state, next_state;

reg [7:0]  cmd_reg;
reg [1:0]  mode;
reg [4:0]  slot_or_bank;
reg [23:0] address;
reg [15:0] burst_count;
reg        is_read;
reg        is_burst;

always @(posedge clk) begin
    if (rst) begin
        state <= STATE_IDLE;
    end else begin
        state <= next_state;
    end
end

// State machine
always @(*) begin
    next_state = state;
    
    case (state)
        STATE_IDLE: begin
            if (spi_cs_active && byte_ready)
                next_state = STATE_RX_CMD;
        end
        
        STATE_RX_CMD: begin
            if (byte_ready) begin
                case (`SSW_GET_MODE(spi_shift_in))
                    `SSW_MODE_SLOT: next_state = STATE_RX_REG;
                    `SSW_MODE_EXTENDED: next_state = STATE_RX_ADDR_H;
                    `SSW_MODE_LARGE: next_state = STATE_RX_ADDR_H;
                    default: next_state = STATE_ERROR;
                endcase
            end
        end
        
        STATE_RX_REG: begin
            if (byte_ready) begin
                if (is_burst)
                    next_state = STATE_RX_COUNT_H;
                else
                    next_state = STATE_RX_DATA;
            end
        end
        
        STATE_RX_ADDR_H: begin
            if (byte_ready) begin
                if (mode == `SSW_MODE_LARGE)
                    next_state = STATE_RX_ADDR_M;
                else
                    next_state = STATE_RX_ADDR_L;
            end
        end
        
        STATE_RX_ADDR_M: begin
            if (byte_ready)
                next_state = STATE_RX_ADDR_L;
        end
        
        STATE_RX_ADDR_L: begin
            if (byte_ready) begin
                if (is_burst)
                    next_state = STATE_RX_COUNT_H;
                else
                    next_state = STATE_RX_DATA;
            end
        end
        
        STATE_RX_COUNT_H: begin
            if (byte_ready)
                next_state = STATE_RX_COUNT_L;
        end
        
        STATE_RX_COUNT_L: begin
            if (byte_ready)
                next_state = STATE_RX_DATA;
        end
        
        STATE_RX_DATA: begin
            if (byte_ready) begin
                if (is_read)
                    next_state = STATE_WB_READ;
                else
                    next_state = STATE_WB_WRITE;
            end
        end
        
        STATE_WB_WRITE: begin
            if (wb_ack_i) begin
                if (is_burst && burst_count > 0)
                    next_state = STATE_RX_DATA;  // Get next byte
                else
                    next_state = STATE_IDLE;
            end
        end
        
        STATE_WB_READ: begin
            if (wb_ack_i)
                next_state = STATE_TX_DATA;
        end
        
        STATE_TX_DATA: begin
            if (byte_ready) begin  // Byte shifted out
                if (is_burst && burst_count > 0)
                    next_state = STATE_WB_READ;  // Read next
                else
                    next_state = STATE_IDLE;
            end
        end
        
        STATE_ERROR: begin
            if (spi_cs_deassert)
                next_state = STATE_IDLE;
        end
        
        default: next_state = STATE_IDLE;
    endcase
    
    // Return to idle on CS deassert
    if (spi_cs_deassert && state != STATE_IDLE)
        next_state = STATE_IDLE;
end

// State machine outputs
always @(posedge clk) begin
    if (rst) begin
        wb_cyc_o <= 1'b0;
        wb_stb_o <= 1'b0;
        error_o <= 1'b0;
        burst_mode_o <= 1'b0;
    end else begin
        case (state)
            STATE_RX_CMD: begin
                if (byte_ready) begin
                    cmd_reg <= spi_shift_in;
                    last_cmd_o <= spi_shift_in;
                    mode <= `SSW_GET_MODE(spi_shift_in);
                    slot_or_bank <= `SSW_GET_SLOT(spi_shift_in);
                    is_read <= !`SSW_GET_RW(spi_shift_in);
                    is_burst <= `SSW_IS_BURST(spi_shift_in);
                    burst_mode_o <= `SSW_IS_BURST(spi_shift_in);
                    
                    // Set access tier
                    case (`SSW_GET_MODE(spi_shift_in))
                        `SSW_MODE_SLOT: access_tier_o <= 2'd0;
                        `SSW_MODE_EXTENDED: access_tier_o <= 2'd1;
                        `SSW_MODE_LARGE: access_tier_o <= 2'd2;
                        default: access_tier_o <= 2'd3;
                    endcase
                end
            end
            
            STATE_RX_REG: begin
                if (byte_ready) begin
                    // Build slot-mode address: {000, slot[4:0], reg[7:0]}
                    wb_adr_o <= `SSW_SLOT_ADDR(slot_or_bank, spi_shift_in);
                end
            end
            
            STATE_RX_ADDR_H: begin
                if (byte_ready)
                    address[23:16] <= spi_shift_in;
            end
            
            STATE_RX_ADDR_M: begin
                if (byte_ready)
                    address[15:8] <= spi_shift_in;
            end
            
            STATE_RX_ADDR_L: begin
                if (byte_ready) begin
                    if (mode == `SSW_MODE_EXTENDED) begin
                        // Extended mode: 16-bit address
                        wb_adr_o <= {8'h00, address[23:16], spi_shift_in};
                    end else begin
                        // Large mode: 24-bit address
                        wb_adr_o <= {address[23:8], spi_shift_in};
                    end
                end
            end
            
            STATE_RX_COUNT_H: begin
                if (byte_ready)
                    burst_count[15:8] <= spi_shift_in;
            end
            
            STATE_RX_COUNT_L: begin
                if (byte_ready) begin
                    burst_count[7:0] <= spi_shift_in;
                    burst_count_o <= {burst_count[15:8], spi_shift_in};
                end
            end
            
            STATE_RX_DATA: begin
                if (byte_ready) begin
                    wb_dat_o <= spi_shift_in;
                end
            end
            
            STATE_WB_WRITE: begin
                wb_cyc_o <= 1'b1;
                wb_stb_o <= 1'b1;
                wb_we_o <= 1'b1;
                
                if (wb_ack_i) begin
                    wb_stb_o <= 1'b0;
                    if (is_burst) begin
                        wb_adr_o <= wb_adr_o + 1'b1;  // Auto-increment
                        burst_count <= burst_count - 1'b1;
                        burst_count_o <= burst_count - 1'b1;
                        if (burst_count == 1)
                            wb_cyc_o <= 1'b0;
                    end else begin
                        wb_cyc_o <= 1'b0;
                    end
                end
            end
            
            STATE_WB_READ: begin
                wb_cyc_o <= 1'b1;
                wb_stb_o <= 1'b1;
                wb_we_o <= 1'b0;
                
                if (wb_ack_i) begin
                    wb_stb_o <= 1'b0;
                    spi_shift_out <= wb_dat_i;  // Load data for TX
                    if (is_burst) begin
                        wb_adr_o <= wb_adr_o + 1'b1;  // Auto-increment
                        burst_count <= burst_count - 1'b1;
                        burst_count_o <= burst_count - 1'b1;
                    end
                end
            end
            
            STATE_TX_DATA: begin
                if (byte_ready && (!is_burst || burst_count == 0))
                    wb_cyc_o <= 1'b0;
            end
            
            STATE_ERROR: begin
                error_o <= 1'b1;
                wb_cyc_o <= 1'b0;
                wb_stb_o <= 1'b0;
            end
            
            STATE_IDLE: begin
                wb_cyc_o <= 1'b0;
                wb_stb_o <= 1'b0;
                error_o <= 1'b0;
                burst_mode_o <= 1'b0;
                burst_count_o <= 16'd0;
            end
        endcase
    end
end

endmodule
