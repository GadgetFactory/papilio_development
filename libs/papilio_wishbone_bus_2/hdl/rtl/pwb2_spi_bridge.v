// pwb2_spi_bridge.v - Papilio Wishbone Bus 2 SPI Bridge
// Converts variable-width SPI transactions to 32-bit Wishbone cycles
// Supports three-tier addressing with burst mode

`include "pwb2_pkg.vh"

module pwb2_spi_bridge #(
    parameter NUM_SLOTS = 32,
    parameter [5:0] SLOT_SPI_BITS [0:31] = '{default: `PWB2_SPI_WIDTH_8}
)(
    // System clock and reset
    input wire clk,
    input wire rst,
    
    // SPI slave interface
    input wire spi_sclk,
    input wire spi_mosi,
    output wire spi_miso,
    input wire spi_cs_n,
    
    // Wishbone master interface (always 32-bit)
    output reg [23:0] wb_adr_o,
    output reg [31:0] wb_dat_o,
    input wire [31:0] wb_dat_i,
    output reg wb_cyc_o,
    output reg wb_stb_o,
    output reg wb_we_o,
    input wire wb_ack_i,
    
    // Status outputs
    output reg [1:0] access_tier_o,      // 0=slot, 1=extended, 2=large
    output reg burst_mode_o,
    output reg [15:0] burst_count_o,
    output reg error_o
);

// =============================================================================
// SPI Slave Instance
// =============================================================================
wire [7:0] spi_rx_data;
wire spi_rx_valid;
reg [7:0] spi_tx_data;
reg spi_tx_load;

spi_slave spi_inst (
    .clk(clk),
    .rst(rst),
    .spi_sclk(spi_sclk),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso),
    .spi_cs_n(spi_cs_n),
    .tx_data(spi_tx_data),
    .rx_data(spi_rx_data),
    .rx_valid(spi_rx_valid),
    .tx_load(spi_tx_load)
);

// =============================================================================
// Protocol State Machine
// =============================================================================
localparam [3:0]
    STATE_IDLE          = 4'd0,
    STATE_CMD           = 4'd1,
    STATE_SLOT_REG      = 4'd2,
    STATE_EXT_ADDR_H    = 4'd3,
    STATE_EXT_ADDR_L    = 4'd4,
    STATE_LARGE_ADDR_H  = 4'd5,
    STATE_LARGE_ADDR_M  = 4'd6,
    STATE_LARGE_ADDR_L  = 4'd7,
    STATE_COUNT_H       = 4'd8,
    STATE_COUNT_L       = 4'd9,
    STATE_DATA_B0       = 4'd10,
    STATE_DATA_B1       = 4'd11,
    STATE_DATA_B2       = 4'd12,
    STATE_DATA_B3       = 4'd13,
    STATE_WB_CYCLE      = 4'd14,
    STATE_ERROR         = 4'd15;

reg [3:0] state, next_state;

// Command decode
reg [7:0] cmd_byte;
reg is_write;
reg [1:0] mode;
reg is_burst;
reg [4:0] slot_number;

// Address and data
reg [23:0] address;
reg [31:0] data_reg;
reg [15:0] burst_count;
reg [1:0] byte_count;

// SPI transfer width for current slot
reg [5:0] current_spi_width;

// =============================================================================
// State Register
// =============================================================================
always @(posedge clk) begin
    if (rst) begin
        state <= STATE_IDLE;
    end else begin
        state <= next_state;
    end
end

// =============================================================================
// Next State Logic
// =============================================================================
always @(*) begin
    next_state = state;
    
    case (state)
        STATE_IDLE: begin
            if (spi_rx_valid)
                next_state = STATE_CMD;
        end
        
        STATE_CMD: begin
            if (spi_rx_valid) begin
                case (mode)
                    `PWB2_MODE_SLOT:     next_state = STATE_SLOT_REG;
                    `PWB2_MODE_EXTENDED: next_state = STATE_EXT_ADDR_H;
                    `PWB2_MODE_LARGE:    next_state = STATE_LARGE_ADDR_H;
                    default:             next_state = STATE_ERROR;
                endcase
            end
        end
        
        STATE_SLOT_REG: begin
            if (spi_rx_valid) begin
                if (is_burst)
                    next_state = STATE_COUNT_H;
                else
                    next_state = STATE_DATA_B0;
            end
        end
        
        STATE_EXT_ADDR_H: begin
            if (spi_rx_valid)
                next_state = STATE_EXT_ADDR_L;
        end
        
        STATE_EXT_ADDR_L: begin
            if (spi_rx_valid) begin
                if (is_burst)
                    next_state = STATE_COUNT_H;
                else
                    next_state = STATE_DATA_B0;
            end
        end
        
        STATE_LARGE_ADDR_H: begin
            if (spi_rx_valid)
                next_state = STATE_LARGE_ADDR_M;
        end
        
        STATE_LARGE_ADDR_M: begin
            if (spi_rx_valid)
                next_state = STATE_LARGE_ADDR_L;
        end
        
        STATE_LARGE_ADDR_L: begin
            if (spi_rx_valid) begin
                if (is_burst)
                    next_state = STATE_COUNT_H;
                else
                    next_state = STATE_DATA_B0;
            end
        end
        
        STATE_COUNT_H: begin
            if (spi_rx_valid)
                next_state = STATE_COUNT_L;
        end
        
        STATE_COUNT_L: begin
            if (spi_rx_valid)
                next_state = STATE_DATA_B0;
        end
        
        STATE_DATA_B0: begin
            if (spi_rx_valid) begin
                // For Extended/Large, always 32-bit
                if (mode != `PWB2_MODE_SLOT) begin
                    next_state = STATE_DATA_B1;
                end
                // For slots, check SPI width
                else begin
                    case (current_spi_width)
                        `PWB2_SPI_WIDTH_8:  next_state = STATE_WB_CYCLE;
                        `PWB2_SPI_WIDTH_16: next_state = STATE_DATA_B1;
                        `PWB2_SPI_WIDTH_32: next_state = STATE_DATA_B1;
                        default:            next_state = STATE_WB_CYCLE;
                    endcase
                end
            end
        end
        
        STATE_DATA_B1: begin
            if (spi_rx_valid) begin
                if (mode != `PWB2_MODE_SLOT) begin
                    next_state = STATE_DATA_B2;
                end else if (current_spi_width == `PWB2_SPI_WIDTH_16) begin
                    next_state = STATE_WB_CYCLE;
                end else begin
                    next_state = STATE_DATA_B2;
                end
            end
        end
        
        STATE_DATA_B2: begin
            if (spi_rx_valid)
                next_state = STATE_DATA_B3;
        end
        
        STATE_DATA_B3: begin
            if (spi_rx_valid)
                next_state = STATE_WB_CYCLE;
        end
        
        STATE_WB_CYCLE: begin
            if (wb_ack_i) begin
                if (is_burst && burst_count > 1) begin
                    // Continue burst - get next data word
                    next_state = STATE_DATA_B0;
                end else begin
                    next_state = STATE_IDLE;
                end
            end
        end
        
        STATE_ERROR: begin
            next_state = STATE_IDLE;  // Reset on next CS cycle
        end
    endcase
end

// =============================================================================
// Output Logic and Registers
// =============================================================================
always @(posedge clk) begin
    if (rst) begin
        cmd_byte <= 8'h00;
        is_write <= 1'b0;
        mode <= 2'b00;
        is_burst <= 1'b0;
        slot_number <= 5'd0;
        address <= 24'h000000;
        data_reg <= 32'h00000000;
        burst_count <= 16'd0;
        byte_count <= 2'd0;
        current_spi_width <= `PWB2_SPI_WIDTH_8;
        wb_cyc_o <= 1'b0;
        wb_stb_o <= 1'b0;
        wb_we_o <= 1'b0;
        wb_adr_o <= 24'h000000;
        wb_dat_o <= 32'h00000000;
        spi_tx_data <= 8'hFF;
        spi_tx_load <= 1'b0;
        access_tier_o <= 2'b00;
        burst_mode_o <= 1'b0;
        burst_count_o <= 16'd0;
        error_o <= 1'b0;
    end else begin
        spi_tx_load <= 1'b0;  // Pulse
        
        case (state)
            STATE_IDLE: begin
                wb_cyc_o <= 1'b0;
                wb_stb_o <= 1'b0;
                error_o <= 1'b0;
                byte_count <= 2'd0;
            end
            
            STATE_CMD: begin
                if (spi_rx_valid) begin
                    cmd_byte <= spi_rx_data;
                    is_write <= `PWB2_GET_RW(spi_rx_data);
                    mode <= `PWB2_GET_MODE(spi_rx_data);
                    is_burst <= `PWB2_GET_BURST(spi_rx_data);
                    slot_number <= `PWB2_GET_SLOT(spi_rx_data);
                    
                    // Set access tier for status
                    access_tier_o <= `PWB2_GET_MODE(spi_rx_data);
                    burst_mode_o <= `PWB2_GET_BURST(spi_rx_data);
                    
                    // Get SPI width for this slot
                    current_spi_width <= SLOT_SPI_BITS[`PWB2_GET_SLOT(spi_rx_data)];
                end
            end
            
            STATE_SLOT_REG: begin
                if (spi_rx_valid) begin
                    // Build slot address: {000, slot[4:0], reg[7:0]}
                    address <= {11'b0, slot_number, spi_rx_data};
                end
            end
            
            STATE_EXT_ADDR_H: begin
                if (spi_rx_valid)
                    address[15:8] <= spi_rx_data;
            end
            
            STATE_EXT_ADDR_L: begin
                if (spi_rx_valid)
                    address[7:0] <= spi_rx_data;
            end
            
            STATE_LARGE_ADDR_H: begin
                if (spi_rx_valid)
                    address[23:16] <= spi_rx_data;
            end
            
            STATE_LARGE_ADDR_M: begin
                if (spi_rx_valid)
                    address[15:8] <= spi_rx_data;
            end
            
            STATE_LARGE_ADDR_L: begin
                if (spi_rx_valid)
                    address[7:0] <= spi_rx_data;
            end
            
            STATE_COUNT_H: begin
                if (spi_rx_valid)
                    burst_count[15:8] <= spi_rx_data;
            end
            
            STATE_COUNT_L: begin
                if (spi_rx_valid) begin
                    burst_count[7:0] <= spi_rx_data;
                    burst_count_o <= {burst_count[15:8], spi_rx_data};
                end
            end
            
            STATE_DATA_B0: begin
                if (spi_rx_valid) begin
                    data_reg[31:24] <= spi_rx_data;
                    byte_count <= byte_count + 1'b1;
                end
            end
            
            STATE_DATA_B1: begin
                if (spi_rx_valid) begin
                    data_reg[23:16] <= spi_rx_data;
                    byte_count <= byte_count + 1'b1;
                end
            end
            
            STATE_DATA_B2: begin
                if (spi_rx_valid) begin
                    data_reg[15:8] <= spi_rx_data;
                    byte_count <= byte_count + 1'b1;
                end
            end
            
            STATE_DATA_B3: begin
                if (spi_rx_valid) begin
                    data_reg[7:0] <= spi_rx_data;
                    byte_count <= 2'd0;
                end
            end
            
            STATE_WB_CYCLE: begin
                if (!wb_cyc_o) begin
                    // Start Wishbone cycle
                    wb_cyc_o <= 1'b1;
                    wb_stb_o <= 1'b1;
                    wb_we_o <= is_write;
                    wb_adr_o <= address;
                    wb_dat_o <= data_reg;
                end else if (wb_ack_i) begin
                    // Cycle complete
                    if (!is_write) begin
                        // For read, prepare response data
                        spi_tx_data <= wb_dat_i[31:24];  // MSB first
                        spi_tx_load <= 1'b1;
                    end
                    
                    if (is_burst && burst_count > 1) begin
                        // Continue burst
                        burst_count <= burst_count - 1'b1;
                        burst_count_o <= burst_count - 1'b1;
                        address <= address + 24'd4;  // Auto-increment by 4 bytes (32-bit word)
                        wb_stb_o <= 1'b0;  // Deassert briefly
                        byte_count <= 2'd0;
                    end else begin
                        // End transaction
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                    end
                end
            end
            
            STATE_ERROR: begin
                error_o <= 1'b1;
                wb_cyc_o <= 1'b0;
                wb_stb_o <= 1'b0;
            end
        endcase
    end
end

endmodule
