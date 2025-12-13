// la_mem_sdpb.v  
// Simple Dual-Port Block RAM wrapper for logic analyzer using Gowin SDPB primitives
// Two 16-bit banks for 32-bit sample storage

module la_mem_sdpb (
    input wire clk,
    input wire rst,
    
    // Write port
    input wire wr_en,
    input wire [9:0] wr_addr,
    input wire [31:0] wr_data,
    
    // Read port
    input wire [9:0] rd_addr,
    output wire [31:0] rd_data
);

    // Two SDPB primitives for 16-bit banks
    wire [15:0] rd_data_low;
    wire [15:0] rd_data_high;
    
    assign rd_data = {rd_data_high, rd_data_low};
    
    // Lower 16 bits [15:0]
    SDPB sdpb_low (
        .CLKA(clk),
        .CEA(1'b1),
        .CLKB(clk),
        .CEB(1'b1),
        .OCE(1'b1),
        .RESET(rst),
        .BLKSELA(3'b000),
        .BLKSELB(3'b000),
        .ADA({3'b000, wr_addr, 4'b0000}),  // Write address [13:0]
        .DI(wr_data[15:0]),
        .ADB({3'b000, rd_addr, 4'b0000}),  // Read address [13:0]
        .DO(rd_data_low)
    );
    defparam sdpb_low.READ_MODE = 1'b0;
    defparam sdpb_low.BIT_WIDTH_0 = 16;
    defparam sdpb_low.BIT_WIDTH_1 = 16;
    defparam sdpb_low.BLK_SEL_0 = 3'b000;
    defparam sdpb_low.BLK_SEL_1 = 3'b000;
    defparam sdpb_low.RESET_MODE = "SYNC";
    
    // Upper 16 bits [31:16]
    SDPB sdpb_high (
        .CLKA(clk),
        .CEA(1'b1),
        .CLKB(clk),
        .CEB(1'b1),
        .OCE(1'b1),
        .RESET(rst),
        .BLKSELA(3'b000),
        .BLKSELB(3'b000),
        .ADA({3'b000, wr_addr, 4'b0000}),  // Write address [13:0]
        .DI(wr_data[31:16]),
        .ADB({3'b000, rd_addr, 4'b0000}),  // Read address [13:0]
        .DO(rd_data_high)
    );
    defparam sdpb_high.READ_MODE = 1'b0;
    defparam sdpb_high.BIT_WIDTH_0 = 16;
    defparam sdpb_high.BIT_WIDTH_1 = 16;
    defparam sdpb_high.BLK_SEL_0 = 3'b000;
    defparam sdpb_high.BLK_SEL_1 = 3'b000;
    defparam sdpb_high.RESET_MODE = "SYNC";

endmodule
