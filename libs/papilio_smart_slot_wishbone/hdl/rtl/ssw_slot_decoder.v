// ssw_slot_decoder.v - Smart Slot Wishbone Address Decoder
// Decodes addresses and generates slot select signals

`include "ssw_pkg.vh"

module ssw_slot_decoder #(
    parameter NUM_SLOTS = 32
)(
    input wire [23:0] wb_adr_i,
    input wire [1:0]  access_tier_i,
    
    output reg [NUM_SLOTS-1:0] slot_select,
    output reg                 extended_select,
    output reg                 large_select
);

// Extract slot number from address
wire [4:0] slot_num = wb_adr_i[12:8];  // Bits [12:8] for slot mode

always @(*) begin
    slot_select = {NUM_SLOTS{1'b0}};
    extended_select = 1'b0;
    large_select = 1'b0;
    
    case (access_tier_i)
        2'd0: begin  // Slot mode
            if (slot_num < NUM_SLOTS)
                slot_select[slot_num] = 1'b1;
        end
        
        2'd1: begin  // Extended mode
            extended_select = 1'b1;
        end
        
        2'd2: begin  // Large mode
            large_select = 1'b1;
        end
        
        default: begin
            // Reserved - no selection
        end
    endcase
end

endmodule
