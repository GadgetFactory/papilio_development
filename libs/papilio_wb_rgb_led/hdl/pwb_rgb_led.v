// pwb_rgb_led.v - RGB LED Wishbone Peripheral
// Simple RGB LED controller with 32-bit transfer

`include "pwb_pkg.vh"

module pwb_rgb_led #(
    parameter SLOT_NUMBER = 1,
    parameter DEVICE_ID = `PWB_DEVID_RGB_LED,
    parameter SPI_TRANSFER_BITS = 32
)(
    input wire clk,
    input wire rst,
    
    // Wishbone slave interface (always 32-bit)
    input wire [7:0]  wb_adr_i,
    input wire [31:0] wb_dat_i,
    output reg [31:0] wb_dat_o,
    input wire        wb_stb_i,
    input wire        wb_we_i,
    output reg        wb_ack_o,
    
    // RGB output
    output reg [23:0] rgb_out
);

// Register map:
// 0x00: RGB value [31:8] = RGB, [7:0] = reserved
//       Write all 3 channels atomically with 32-bit transfer

always @(posedge clk) begin
    if (rst) begin
        wb_ack_o <= 1'b0;
        rgb_out <= 24'h000000;
    end else if (wb_stb_i) begin
        wb_ack_o <= 1'b1;
        
        if (wb_we_i) begin
            // Write - atomic RGB update!
            case (wb_adr_i[7:0])
                8'h00: rgb_out <= wb_dat_i[31:8];  // Upper 24 bits are RGB
            endcase
        end else begin
            // Read
            case (wb_adr_i[7:0])
                8'h00: wb_dat_o <= {rgb_out, 8'h00};
                default: wb_dat_o <= 32'hFFFFFFFF;
            endcase
        end
    end else begin
        wb_ack_o <= 1'b0;
    end
end

endmodule
