// ssw_arbiter.v - Smart Slot Wishbone Memory Arbiter
// Routes Wishbone transactions to on-chip BRAM or external memory

`include "ssw_pkg.vh"

module ssw_arbiter (
    input wire clk,
    input wire rst,
    
    // Wishbone slave (from SPI bridge)
    input wire [23:0] wb_adr_i,
    input wire [7:0]  wb_dat_i,
    output reg [7:0]  wb_dat_o,
    input wire        wb_cyc_i,
    input wire        wb_stb_i,
    input wire        wb_we_i,
    output reg        wb_ack_o,
    input wire [1:0]  access_tier_i,
    
    // On-chip BRAM (for tier 1 & 2: 0x0000-0xFFFF)
    output reg [15:0] bram_addr,
    output reg [7:0]  bram_din,
    input wire [7:0]  bram_dout,
    output reg        bram_we,
    output reg        bram_en,
    
    // External DDR/SDRAM controller (for tier 3: 0x10000-0xFFFFFF)
    output reg [23:0] ddr_addr,
    output reg [7:0]  ddr_din,
    input wire [7:0]  ddr_dout,
    output reg        ddr_req,
    output reg        ddr_we,
    input wire        ddr_ack
);

wire access_bram = (access_tier_i != 2'd2);  // Tiers 1 & 2
wire access_ddr = (access_tier_i == 2'd2);    // Tier 3

always @(posedge clk) begin
    if (rst) begin
        wb_ack_o <= 1'b0;
        bram_we <= 1'b0;
        bram_en <= 1'b0;
        ddr_req <= 1'b0;
    end else begin
        if (wb_stb_i && wb_cyc_i) begin
            if (access_bram) begin
                // On-chip BRAM: fast, single-cycle
                bram_addr <= wb_adr_i[15:0];
                bram_din <= wb_dat_i;
                bram_we <= wb_we_i;
                bram_en <= 1'b1;
                wb_dat_o <= bram_dout;
                wb_ack_o <= 1'b1;  // Single cycle!
            end else begin
                // External DDR: slower, multi-cycle
                ddr_addr <= wb_adr_i;
                ddr_din <= wb_dat_i;
                ddr_we <= wb_we_i;
                ddr_req <= 1'b1;
                
                if (ddr_ack) begin
                    wb_dat_o <= ddr_dout;
                    wb_ack_o <= 1'b1;
                    ddr_req <= 1'b0;
                end else begin
                    wb_ack_o <= 1'b0;
                end
            end
        end else begin
            wb_ack_o <= 1'b0;
            bram_we <= 1'b0;
            bram_en <= 1'b0;
            ddr_req <= 1'b0;
        end
    end
end

endmodule
