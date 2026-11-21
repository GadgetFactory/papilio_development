// spi_counter_test.v - Simple SPI counter test
// Sends incrementing counter bytes over SPI MISO

module top (
    input wire clk,
    input wire rst,
    
    // SPI from ESP32
    input wire esp_sclk,
    input wire esp_mosi,
    output wire esp_miso,
    input wire esp_cs_n,
    
    // RGB LED (unused)
    output wire rgb_led
);

// Counter increments on each SPI transaction
reg [7:0] counter;
reg [2:0] bit_count;
reg [7:0] shift_out;

always @(posedge esp_sclk or posedge esp_cs_n) begin
    if (esp_cs_n) begin
        counter <= counter + 8'd1;
        shift_out <= counter;
        bit_count <= 3'd0;
    end else begin
        shift_out <= {shift_out[6:0], 1'b0};
        bit_count <= bit_count + 3'd1;
    end
end

assign esp_miso = esp_cs_n ? 1'bz : shift_out[7];
assign rgb_led = 1'b0;

endmodule