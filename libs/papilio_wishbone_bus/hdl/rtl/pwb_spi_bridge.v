// pwb_spi_bridge.v - Papilio Wishbone Bus SPI Bridge
// Converts variable-width SPI transactions to 32-bit Wishbone cycles

`include "pwb_pkg.vh"

module pwb_spi_bridge #(
    parameter [5:0] SLOT_SPI_BITS [0:31] = '{default: `PWB_SPI_WIDTH_8}
)(
    // System clock and reset
    input wire clk,
    input wire rst,
    
    // SPI slave interface
    input wire spi_sclk,
    input wire spi_mosi,
    output reg spi_miso,
    input wire spi_cs_n,
    
    // Wishbone master interface (always 32-bit)
    output reg [23:0] wb_adr_o,
    output reg [31:0] wb_dat_o,
    input wire [31:0] wb_dat_i,
    output reg        wb_cyc_o,
    output reg        wb_stb_o,
    output reg        wb_we_o,
    input wire        wb_ack_i,
    
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
    STATE_RX_DATA   = 4'd6,
    STATE_WB_WRITE  = 4'd7,
    STATE_WB_READ   = 4'd8,
    STATE_TX_DATA   = 4'd9,
    STATE_ERROR     = 4'd10;

reg [3:0] state, next_state;

reg [7:0]  cmd_reg;
reg [1:0]  mode;
reg [4:0]  current_slot;
reg [23:0] address;
reg        is_read;

// Variable-width SPI accumulation
reg [31:0] data_accumulator;
reg [2:0]  bytes_received;
reg [2:0]  bytes_expected;  // 1, 2, or 4 (for 8, 16, or 32 bits)

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
                case (`PWB_GET_MODE(spi_shift_in))
                    `PWB_MODE_SLOT: next_state = STATE_RX_REG;
                    `PWB_MODE_EXTENDED: next_state = STATE_RX_ADDR_H;
                    `PWB_MODE_LARGE: next_state = STATE_RX_ADDR_H;
                    default: next_state = STATE_ERROR;
                endcase
            end
        end
        
        STATE_RX_REG: begin
            if (byte_ready)
                next_state = STATE_RX_DATA;
        end
        
        STATE_RX_ADDR_H: begin
            if (byte_ready) begin
                if (mode == `PWB_MODE_LARGE)
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
            if (byte_ready)
                next_state = STATE_RX_DATA;
        end
        
        STATE_RX_DATA: begin
            if (byte_ready) begin
                // Check if we have all bytes for this slot
                if (bytes_received + 1 == bytes_expected) begin
                    if (is_read)
                        next_state = STATE_WB_READ;
                    else
                        next_state = STATE_WB_WRITE;
                end
                // else stay in STATE_RX_DATA for more bytes
            end
        end
        
        STATE_WB_WRITE: begin
            if (wb_ack_i)
                next_state = STATE_IDLE;
        end
        
        STATE_WB_READ: begin
            if (wb_ack_i)
                next_state = STATE_TX_DATA;
        end
        
        STATE_TX_DATA: begin
            if (byte_ready)  // Byte shifted out
                next_state = STATE_IDLE;
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
        bytes_received <= 3'd0;
        bytes_expected <= 3'd1;
        data_accumulator <= 32'h0;
    end else begin
        case (state)
            STATE_RX_CMD: begin
                if (byte_ready) begin
                    cmd_reg <= spi_shift_in;
                    last_cmd_o <= spi_shift_in;
                    mode <= `PWB_GET_MODE(spi_shift_in);
                    current_slot <= `PWB_GET_SLOT(spi_shift_in);
                    is_read <= !`PWB_GET_RW(spi_shift_in);
                    
                    // Look up SPI width for this slot
                    case (SLOT_SPI_BITS[`PWB_GET_SLOT(spi_shift_in)])
                        `PWB_SPI_WIDTH_8:  bytes_expected <= 3'd1;
                        `PWB_SPI_WIDTH_16: bytes_expected <= 3'd2;
                        `PWB_SPI_WIDTH_32: bytes_expected <= 3'd4;
                        default:           bytes_expected <= 3'd1;
                    endcase
                    
                    bytes_received <= 3'd0;
                    data_accumulator <= 32'h0;
                end
            end
            
            STATE_RX_REG: begin
                if (byte_ready) begin
                    // Build slot-mode address: {000, slot[4:0], reg[7:0]}
                    wb_adr_o <= `PWB_SLOT_ADDR(current_slot, spi_shift_in);
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
                    if (mode == `PWB_MODE_EXTENDED) begin
                        // Extended mode: 16-bit address
                        wb_adr_o <= {8'h00, address[23:16], spi_shift_in};
                    end else begin
                        // Large mode: 24-bit address
                        wb_adr_o <= {address[23:8], spi_shift_in};
                    end
                end
            end
            
            STATE_RX_DATA: begin
                if (byte_ready) begin
                    // Accumulate bytes (shift left, add new byte on right)
                    data_accumulator <= {data_accumulator[23:0], spi_shift_in};
                    bytes_received <= bytes_received + 1'b1;
                    
                    // On last byte, assemble 32-bit Wishbone data
                    if (bytes_received + 1 == bytes_expected) begin
                        case (bytes_expected)
                            3'd1: wb_dat_o <= {24'h000000, spi_shift_in};
                            3'd2: wb_dat_o <= {16'h0000, data_accumulator[7:0], spi_shift_in};
                            3'd4: wb_dat_o <= {data_accumulator[23:0], spi_shift_in};
                            default: wb_dat_o <= {24'h000000, spi_shift_in};
                        endcase
                    end
                end
            end
            
            STATE_WB_WRITE: begin
                wb_cyc_o <= 1'b1;
                wb_stb_o <= 1'b1;
                wb_we_o <= 1'b1;
                
                if (wb_ack_i) begin
                    wb_cyc_o <= 1'b0;
                    wb_stb_o <= 1'b0;
                    bytes_received <= 3'd0;
                    data_accumulator <= 32'h0;
                end
            end
            
            STATE_WB_READ: begin
                wb_cyc_o <= 1'b1;
                wb_stb_o <= 1'b1;
                wb_we_o <= 1'b0;
                
                if (wb_ack_i) begin
                    wb_stb_o <= 1'b0;
                    // Load read data for transmission
                    // Send back the same number of bytes that were requested
                    case (bytes_expected)
                        3'd1: spi_shift_out <= wb_dat_i[7:0];
                        3'd2: spi_shift_out <= wb_dat_i[15:8];  // Will send MSB first
                        3'd4: spi_shift_out <= wb_dat_i[31:24]; // Will send MSB first
                        default: spi_shift_out <= wb_dat_i[7:0];
                    endcase
                end
            end
            
            STATE_TX_DATA: begin
                if (byte_ready) begin
                    wb_cyc_o <= 1'b0;
                    bytes_received <= 3'd0;
                end
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
                bytes_received <= 3'd0;
                data_accumulator <= 32'h0;
            end
        endcase
    end
end

endmodule
