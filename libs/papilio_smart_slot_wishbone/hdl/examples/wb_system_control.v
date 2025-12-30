// wb_system_control.v - System Control Peripheral
// Implements device enumeration and system information (Slot 0)

`include "../rtl/ssw_pkg.vh"

module wb_system_control #(
    parameter SLOT_NUMBER = 0,
    parameter DEVICE_ID = `SSW_DEVID_SYSTEM,
    parameter VERSION = 8'h10,      // Version 1.0
    parameter SLOT_COUNT = 8'd32,
    parameter MEM_SIZE_MB = 8'd16   // External memory size in MB
)(
    input wire clk,
    input wire rst,
    
    // Wishbone slave interface
    input wire [23:0] wb_adr_i,
    input wire [7:0]  wb_dat_i,
    output reg [7:0]  wb_dat_o,
    input wire        wb_cyc_i,
    input wire        wb_stb_i,
    input wire        wb_we_i,
    output reg        wb_ack_o,
    input wire        slot_select_i,
    
    // Device ID inputs (from all peripherals)
    input wire [15:0] device_id_0,
    input wire [15:0] device_id_1,
    input wire [15:0] device_id_2,
    input wire [15:0] device_id_3,
    input wire [15:0] device_id_4,
    input wire [15:0] device_id_5,
    input wire [15:0] device_id_6,
    input wire [15:0] device_id_7,
    input wire [15:0] device_id_8,
    input wire [15:0] device_id_9,
    input wire [15:0] device_id_10,
    input wire [15:0] device_id_11,
    input wire [15:0] device_id_12,
    input wire [15:0] device_id_13,
    input wire [15:0] device_id_14,
    input wire [15:0] device_id_15,
    input wire [15:0] device_id_16,
    input wire [15:0] device_id_17,
    input wire [15:0] device_id_18,
    input wire [15:0] device_id_19,
    input wire [15:0] device_id_20,
    input wire [15:0] device_id_21,
    input wire [15:0] device_id_22,
    input wire [15:0] device_id_23,
    input wire [15:0] device_id_24,
    input wire [15:0] device_id_25,
    input wire [15:0] device_id_26,
    input wire [15:0] device_id_27,
    input wire [15:0] device_id_28,
    input wire [15:0] device_id_29,
    input wire [15:0] device_id_30,
    input wire [15:0] device_id_31
);

// Capability flags
localparam CAPS_SLOT_MODE     = 8'b00000001;
localparam CAPS_EXTENDED_MODE = 8'b00000010;
localparam CAPS_LARGE_MODE    = 8'b00000100;
localparam CAPS_BURST_MODE    = 8'b00001000;
localparam CAPABILITIES = CAPS_SLOT_MODE | CAPS_EXTENDED_MODE | 
                          CAPS_LARGE_MODE | CAPS_BURST_MODE;

// Create device ID array
wire [15:0] device_ids [0:31];
assign device_ids[0]  = device_id_0;
assign device_ids[1]  = device_id_1;
assign device_ids[2]  = device_id_2;
assign device_ids[3]  = device_id_3;
assign device_ids[4]  = device_id_4;
assign device_ids[5]  = device_id_5;
assign device_ids[6]  = device_id_6;
assign device_ids[7]  = device_id_7;
assign device_ids[8]  = device_id_8;
assign device_ids[9]  = device_id_9;
assign device_ids[10] = device_id_10;
assign device_ids[11] = device_id_11;
assign device_ids[12] = device_id_12;
assign device_ids[13] = device_id_13;
assign device_ids[14] = device_id_14;
assign device_ids[15] = device_id_15;
assign device_ids[16] = device_id_16;
assign device_ids[17] = device_id_17;
assign device_ids[18] = device_id_18;
assign device_ids[19] = device_id_19;
assign device_ids[20] = device_id_20;
assign device_ids[21] = device_id_21;
assign device_ids[22] = device_id_22;
assign device_ids[23] = device_id_23;
assign device_ids[24] = device_id_24;
assign device_ids[25] = device_id_25;
assign device_ids[26] = device_id_26;
assign device_ids[27] = device_id_27;
assign device_ids[28] = device_id_28;
assign device_ids[29] = device_id_29;
assign device_ids[30] = device_id_30;
assign device_ids[31] = device_id_31;

wire selected = wb_cyc_i && wb_stb_i && slot_select_i;
wire [7:0] reg_addr = wb_adr_i[7:0];

always @(posedge clk) begin
    if (rst) begin
        wb_ack_o <= 1'b0;
    end else begin
        wb_ack_o <= selected;
        
        // All registers are read-only
        case (reg_addr)
            `SSW_SYS_VERSION:     wb_dat_o <= VERSION;
            `SSW_SYS_CAPABILITIES: wb_dat_o <= CAPABILITIES;
            `SSW_SYS_SLOT_COUNT:  wb_dat_o <= SLOT_COUNT;
            `SSW_SYS_MEM_SIZE:    wb_dat_o <= MEM_SIZE_MB;
            
            default: begin
                // Device ID area (0x10-0x4F)
                if (reg_addr >= `SSW_SYS_DEV_ID_BASE && reg_addr < 8'h50) begin
                    wire [5:0] id_offset = reg_addr - `SSW_SYS_DEV_ID_BASE;
                    wire [4:0] slot_num = id_offset[5:1];  // Divide by 2
                    wire is_low_byte = id_offset[0];
                    
                    // Return device ID bytes (big-endian)
                    wb_dat_o <= is_low_byte ? 
                               device_ids[slot_num][7:0] :   // Low byte
                               device_ids[slot_num][15:8];   // High byte
                end else begin
                    wb_dat_o <= 8'h00;
                end
            end
        endcase
    end
end

endmodule
