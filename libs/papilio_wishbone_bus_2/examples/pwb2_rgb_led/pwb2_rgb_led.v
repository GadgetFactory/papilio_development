// pwb2_rgb_led.v - Example PWB2 peripheral: RGB LED controller
// Demonstrates how to create a PWB2-compatible peripheral

`include "pwb2_pkg.vh"

module pwb2_rgb_led #(
    parameter SLOT_NUMBER = 1,
    parameter DEVICE_ID = `PWB2_DEVID_RGB_LED
)(
    input wire clk,
    input wire rst,
    
    // Wishbone slave interface - Standard 32-bit
    input wire [7:0] wb_adr_i,       // Only lower 8 bits (256 bytes per slot)
    input wire [31:0] wb_dat_i,      // Always 32-bit
    output reg [31:0] wb_dat_o,      // Always 32-bit
    input wire wb_stb_i,             // Strobe for this slot
    input wire wb_we_i,              // Write enable
    output reg wb_ack_o,             // Acknowledge
    
    // RGB LED output
    output wire [2:0] rgb_out
);

// =============================================================================
// Register Map
// =============================================================================
// 0x00: RED       (8-bit)
// 0x01: GREEN     (8-bit)
// 0x02: BLUE      (8-bit)
// 0x03: BRIGHTNESS (8-bit, 0-255)
// 0x04: CONTROL   (8-bit: [0]=enable, [1]=blink)
// 0x05: BLINK_RATE (8-bit, in 10ms units)

reg [7:0] red_reg;
reg [7:0] green_reg;
reg [7:0] blue_reg;
reg [7:0] brightness_reg;
reg [7:0] control_reg;
reg [7:0] blink_rate_reg;

// =============================================================================
// Wishbone Interface
// =============================================================================

always @(posedge clk) begin
    if (rst) begin
        red_reg <= 8'h00;
        green_reg <= 8'h00;
        blue_reg <= 8'h00;
        brightness_reg <= 8'hFF;  // Full brightness
        control_reg <= 8'h01;      // Enabled, no blink
        blink_rate_reg <= 8'h32;   // 500ms
        wb_dat_o <= 32'h00000000;
        wb_ack_o <= 1'b0;
    end else begin
        // Acknowledge all transactions after one cycle
        wb_ack_o <= wb_stb_i && !wb_ack_o;
        
        if (wb_stb_i && !wb_ack_o) begin
            if (wb_we_i) begin
                // Write
                case (wb_adr_i[7:0])
                    8'h00: red_reg <= wb_dat_i[7:0];
                    8'h01: green_reg <= wb_dat_i[7:0];
                    8'h02: blue_reg <= wb_dat_i[7:0];
                    8'h03: brightness_reg <= wb_dat_i[7:0];
                    8'h04: control_reg <= wb_dat_i[7:0];
                    8'h05: blink_rate_reg <= wb_dat_i[7:0];
                    default: ; // Ignore
                endcase
            end else begin
                // Read
                case (wb_adr_i[7:0])
                    8'h00: wb_dat_o <= {24'h0, red_reg};
                    8'h01: wb_dat_o <= {24'h0, green_reg};
                    8'h02: wb_dat_o <= {24'h0, blue_reg};
                    8'h03: wb_dat_o <= {24'h0, brightness_reg};
                    8'h04: wb_dat_o <= {24'h0, control_reg};
                    8'h05: wb_dat_o <= {24'h0, blink_rate_reg};
                    default: wb_dat_o <= 32'h00000000;
                endcase
            end
        end
    end
end

// =============================================================================
// LED Control Logic
// =============================================================================

wire enabled = control_reg[0];
wire blink_en = control_reg[1];

// Blink counter (assume 50MHz clock, count in 10ms units)
reg [19:0] blink_counter;
reg blink_state;

always @(posedge clk) begin
    if (rst) begin
        blink_counter <= 20'd0;
        blink_state <= 1'b1;
    end else if (blink_en) begin
        if (blink_counter >= (blink_rate_reg * 20'd50000)) begin
            blink_counter <= 20'd0;
            blink_state <= ~blink_state;
        end else begin
            blink_counter <= blink_counter + 1'b1;
        end
    end else begin
        blink_state <= 1'b1;
        blink_counter <= 20'd0;
    end
end

// Apply brightness scaling (simple 8-bit multiply)
wire [15:0] red_scaled = red_reg * brightness_reg;
wire [15:0] green_scaled = green_reg * brightness_reg;
wire [15:0] blue_scaled = blue_reg * brightness_reg;

// PWM outputs (using MSB for simple PWM)
reg [7:0] pwm_counter;
always @(posedge clk) begin
    if (rst)
        pwm_counter <= 8'h00;
    else
        pwm_counter <= pwm_counter + 1'b1;
end

wire pwm_red = (pwm_counter < red_scaled[15:8]);
wire pwm_green = (pwm_counter < green_scaled[15:8]);
wire pwm_blue = (pwm_counter < blue_scaled[15:8]);

// Final output with enable and blink
assign rgb_out[0] = enabled && blink_state && pwm_red;
assign rgb_out[1] = enabled && blink_state && pwm_green;
assign rgb_out[2] = enabled && blink_state && pwm_blue;

endmodule
