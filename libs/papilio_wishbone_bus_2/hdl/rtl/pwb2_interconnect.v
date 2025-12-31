// pwb2_interconnect.v - Papilio Wishbone Bus 2 Interconnect
// Routes Wishbone transactions to appropriate peripheral slots

`include "pwb2_pkg.vh"

module pwb2_interconnect #(
    parameter NUM_SLOTS = 32,
    parameter [15:0] DEVICE_IDS [0:31] = '{default: `PWB2_DEVID_EMPTY},
    parameter [5:0] SPI_WIDTHS [0:31] = '{default: `PWB2_SPI_WIDTH_8}
)(
    input wire clk,
    input wire rst,
    
    // Wishbone slave (from SPI bridge)
    input wire [23:0] wb_adr_i,
    input wire [31:0] wb_dat_i,
    output reg [31:0] wb_dat_o,
    input wire wb_cyc_i,
    input wire wb_stb_i,
    input wire wb_we_i,
    output reg wb_ack_o,
    
    // Wishbone masters (to peripheral slots)
    output wire [23:0] wb_slot_adr_o,
    output wire [31:0] wb_slot_dat_o,
    input wire [31:0] wb_slot_dat_i [0:NUM_SLOTS-1],
    output reg [NUM_SLOTS-1:0] wb_slot_stb_o,
    output wire wb_slot_we_o,
    input wire [NUM_SLOTS-1:0] wb_slot_ack_i
);

// =============================================================================
// Address Decoding
// =============================================================================

// Decode slot number from address
wire [4:0] slot_select = `PWB2_ADDR_TO_SLOT(wb_adr_i);

// One-hot slot select
reg [NUM_SLOTS-1:0] slot_active;

always @(*) begin
    slot_active = {NUM_SLOTS{1'b0}};
    if (wb_cyc_i && wb_stb_i && `PWB2_IS_SLOT(wb_adr_i)) begin
        slot_active[slot_select] = 1'b1;
    end
end

// =============================================================================
// Strobe Generation
// =============================================================================

always @(*) begin
    wb_slot_stb_o = slot_active & {NUM_SLOTS{wb_stb_i}};
end

// Common signals to all slots
assign wb_slot_adr_o = wb_adr_i;
assign wb_slot_dat_o = wb_dat_i;
assign wb_slot_we_o = wb_we_i;

// =============================================================================
// Response Multiplexing
// =============================================================================

// Combine acknowledge signals
wire any_ack = |(wb_slot_ack_i & slot_active);

// Multiplex data from active slot
integer i;
always @(*) begin
    wb_dat_o = 32'h00000000;
    for (i = 0; i < NUM_SLOTS; i = i + 1) begin
        if (slot_active[i]) begin
            wb_dat_o = wb_slot_dat_i[i];
        end
    end
end

// Register acknowledge for timing
always @(posedge clk) begin
    if (rst) begin
        wb_ack_o <= 1'b0;
    end else begin
        wb_ack_o <= any_ack;
    end
end

endmodule
