// pwb2_memory_map.v - Papilio Wishbone Bus 2 Memory Map (Slot 0)
// Provides system information and device enumeration

`include "pwb2_pkg.vh"

module pwb2_memory_map #(
    parameter NUM_SLOTS = 32,
    parameter [15:0] DEVICE_IDS [0:31] = '{default: `PWB2_DEVID_EMPTY},
    parameter [5:0] SPI_WIDTHS [0:31] = '{default: `PWB2_SPI_WIDTH_8},
    parameter [31:0] CAPABILITIES = 32'h0000000F  // All features enabled
)(
    input wire clk,
    input wire rst,
    
    // Wishbone slave interface
    input wire [7:0] wb_adr_i,      // Only lower 8 bits
    input wire [31:0] wb_dat_i,
    output reg [31:0] wb_dat_o,
    input wire wb_stb_i,
    input wire wb_we_i,
    output reg wb_ack_o
);

// =============================================================================
// System Registers
// =============================================================================

// Count actual slots used (non-empty)
function [7:0] count_slots;
    integer i;
    begin
        count_slots = 0;
        for (i = 0; i < NUM_SLOTS; i = i + 1) begin
            if (DEVICE_IDS[i] != `PWB2_DEVID_EMPTY)
                count_slots = count_slots + 1;
        end
    end
endfunction

wire [7:0] slot_count = count_slots();

// =============================================================================
// Read Logic
// =============================================================================

always @(posedge clk) begin
    if (rst) begin
        wb_dat_o <= 32'h00000000;
        wb_ack_o <= 1'b0;
    end else begin
        wb_ack_o <= wb_stb_i && !wb_ack_o;  // Acknowledge after one cycle
        
        if (wb_stb_i && !wb_we_i) begin  // Read only
            case (wb_adr_i)
                // System info registers
                `PWB2_REG_DEVICE_ID_L: wb_dat_o <= {24'h0, `PWB2_DEVID_SYSTEM[7:0]};
                `PWB2_REG_DEVICE_ID_H: wb_dat_o <= {24'h0, `PWB2_DEVID_SYSTEM[15:8]};
                `PWB2_REG_VERSION:     wb_dat_o <= {24'h0, `PWB2_VERSION};
                `PWB2_REG_SLOT_COUNT:  wb_dat_o <= {24'h0, slot_count};
                `PWB2_REG_CAPABILITIES: wb_dat_o <= CAPABILITIES;
                `PWB2_REG_STATUS:      wb_dat_o <= 32'h00000001;  // Always ready
                
                default: begin
                    // Check if accessing memory map area
                    if (wb_adr_i >= `PWB2_MEMMAP_START) begin
                        // Calculate slot number and offset
                        // Address format: 0x10 + (slot * 16) + offset
                        reg [7:0] map_addr;
                        reg [4:0] map_slot;
                        reg [3:0] map_offset;
                        
                        map_addr = wb_adr_i - `PWB2_MEMMAP_START;
                        map_slot = map_addr[7:4];  // Divide by 16
                        map_offset = map_addr[3:0];
                        
                        if (map_slot < NUM_SLOTS) begin
                            case (map_offset)
                                `PWB2_MEMMAP_DEVID_L:   wb_dat_o <= {24'h0, DEVICE_IDS[map_slot][7:0]};
                                `PWB2_MEMMAP_DEVID_H:   wb_dat_o <= {24'h0, DEVICE_IDS[map_slot][15:8]};
                                `PWB2_MEMMAP_SPI_WIDTH: wb_dat_o <= {26'h0, SPI_WIDTHS[map_slot]};
                                `PWB2_MEMMAP_FLAGS:     wb_dat_o <= 32'h00000000;  // Reserved
                                default:                wb_dat_o <= 32'h00000000;
                            endcase
                        end else begin
                            wb_dat_o <= 32'h00000000;
                        end
                    end else begin
                        wb_dat_o <= 32'h00000000;
                    end
                end
            endcase
        end
    end
end

endmodule
