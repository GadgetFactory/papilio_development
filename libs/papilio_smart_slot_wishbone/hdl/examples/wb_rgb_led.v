// wb_rgb_led.v - Simple RGB LED Wishbone Peripheral
// Example peripheral for Smart Slot Wishbone

`include "../rtl/ssw_pkg.vh"

module wb_rgb_led #(
    parameter SLOT_NUMBER = 1,
    parameter DEVICE_ID = `SSW_DEVID_RGB_LED
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
    
    // RGB LED outputs (8-bit PWM)
    output reg [7:0] red_o,
    output reg [7:0] green_o,
    output reg [7:0] blue_o
);

// Register addresses
localparam REG_RED   = 8'h00;
localparam REG_GREEN = 8'h01;
localparam REG_BLUE  = 8'h02;

// Decode
wire selected = wb_cyc_i && wb_stb_i && slot_select_i;
wire [7:0] reg_addr = wb_adr_i[7:0];  // Register offset within slot

// Color registers
reg [7:0] red_reg;
reg [7:0] green_reg;
reg [7:0] blue_reg;

// Wishbone interface
always @(posedge clk) begin
    if (rst) begin
        red_reg <= 8'd0;
        green_reg <= 8'd0;
        blue_reg <= 8'd0;
        wb_ack_o <= 1'b0;
    end else begin
        // Single-cycle acknowledgment
        wb_ack_o <= selected;
        
        // Write handling
        if (selected && wb_we_i) begin
            case (reg_addr)
                REG_RED:   red_reg <= wb_dat_i;
                REG_GREEN: green_reg <= wb_dat_i;
                REG_BLUE:  blue_reg <= wb_dat_i;
            endcase
        end
        
        // Read handling
        case (reg_addr)
            REG_RED:   wb_dat_o <= red_reg;
            REG_GREEN: wb_dat_o <= green_reg;
            REG_BLUE:  wb_dat_o <= blue_reg;
            default:   wb_dat_o <= 8'h00;
        endcase
    end
end

// PWM generators for smooth color control
reg [7:0] pwm_counter;

always @(posedge clk) begin
    if (rst) begin
        pwm_counter <= 8'd0;
        red_o <= 1'b0;
        green_o <= 1'b0;
        blue_o <= 1'b0;
    end else begin
        pwm_counter <= pwm_counter + 1'b1;
        
        // Compare with color values for PWM
        red_o <= (pwm_counter < red_reg) ? 8'hFF : 8'h00;
        green_o <= (pwm_counter < green_reg) ? 8'hFF : 8'h00;
        blue_o <= (pwm_counter < blue_reg) ? 8'hFF : 8'h00;
    end
end

endmodule
