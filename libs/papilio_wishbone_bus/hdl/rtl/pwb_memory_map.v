// pwb_memory_map.v - Papilio Wishbone Bus Memory Map Peripheral
// Centralized device enumeration and configuration

`include "pwb_pkg.vh"

module pwb_memory_map #(
    parameter NUM_SLOTS = 32,
    parameter [15:0] SLOT_DEVICE_IDS [0:31] = '{default: `PWB_DEVID_EMPTY},
    parameter [5:0]  SLOT_SPI_BITS [0:31] = '{default: `PWB_SPI_WIDTH_8}
)(
    input wire clk,
    input wire rst,
    
    // Wishbone slave interface (Slot 0)
    input wire [7:0]  wb_adr_i,
    input wire [31:0] wb_dat_i,
    output reg [31:0] wb_dat_o,
    input wire        wb_stb_i,
    input wire        wb_we_i,
    output reg        wb_ack_o
);

// Version: 1.0 (0x10)
localparam VERSION = 8'h10;

// Capabilities:
// [0]: Slot mode
// [1]: Extended mode
// [2]: Large mode
// [3]: Burst mode
// [4]: Variable SPI width
localparam CAPABILITIES = 8'b00011111;

always @(posedge clk) begin
    if (rst) begin
        wb_ack_o <= 1'b0;
        wb_dat_o <= 32'h0;
    end else if (wb_stb_i && !wb_we_i) begin  // Read only
        wb_ack_o <= 1'b1;
        
        case (wb_adr_i)
            `PWB_REG_VERSION: begin
                wb_dat_o <= {24'h0, VERSION};
            end
            
            `PWB_REG_SLOT_COUNT: begin
                wb_dat_o <= {24'h0, NUM_SLOTS[7:0]};
            end
            
            `PWB_REG_CAPABILITIES: begin
                wb_dat_o <= {24'h0, CAPABILITIES};
            end
            
            `PWB_REG_RESERVED: begin
                wb_dat_o <= 32'h0;
            end
            
            default: begin
                // Device descriptors
                if (wb_adr_i >= `PWB_REG_DESC_BASE && 
                    wb_adr_i < (`PWB_REG_DESC_BASE + (NUM_SLOTS * 2))) begin
                    
                    integer slot_idx;
                    integer word_offset;
                    
                    slot_idx = (wb_adr_i - `PWB_REG_DESC_BASE) >> 1;  // Divide by 2
                    word_offset = (wb_adr_i - `PWB_REG_DESC_BASE) & 1;  // Mod 2
                    
                    if (word_offset == 0) begin
                        // Word 0: Device descriptor
                        wb_dat_o <= {
                            SLOT_DEVICE_IDS[slot_idx],  // [31:16] Device ID
                            2'b00,                       // [15:14] Reserved
                            SLOT_SPI_BITS[slot_idx],     // [13:8]  SPI bits
                            8'h00                        // [7:0]   Flags
                        };
                    end else begin
                        // Word 1: Reserved for future use
                        wb_dat_o <= 32'h00000000;
                    end
                end else begin
                    // Invalid address
                    wb_dat_o <= 32'hFFFFFFFF;
                end
            end
        endcase
    end else begin
        wb_ack_o <= 1'b0;
    end
end

endmodule
