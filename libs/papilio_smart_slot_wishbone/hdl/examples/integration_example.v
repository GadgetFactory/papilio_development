// integration_example.v - Complete integration example
// Shows how to connect Smart Slot Wishbone with multiple peripherals

`include "../rtl/ssw_pkg.vh"

module integration_example (
    input wire clk_50mhz,
    input wire reset_n,
    
    // ESP32 SPI interface
    input wire esp_sclk,
    input wire esp_mosi,
    output wire esp_miso,
    input wire esp_cs_n,
    
    // RGB LED
    output wire [7:0] led_red,
    output wire [7:0] led_green,
    output wire [7:0] led_blue,
    
    // Other peripherals would go here
    // output wire [7:0] gpio_out,
    // etc.
);

// System reset
wire sys_rst = !reset_n;

// =============================================================================
// Wishbone Bus
// =============================================================================

wire [23:0] wb_adr;
wire [7:0]  wb_dat_m2s;  // Master to slave (write data)
wire [7:0]  wb_dat_s2m;  // Slave to master (read data)
wire        wb_cyc;
wire        wb_stb;
wire        wb_we;
wire        wb_ack;
wire [1:0]  access_tier;
wire        burst_mode;
wire [15:0] burst_count;

// =============================================================================
// SPI Bridge
// =============================================================================

ssw_spi_bridge bridge (
    .clk(clk_50mhz),
    .rst(sys_rst),
    
    // SPI interface
    .spi_sclk(esp_sclk),
    .spi_mosi(esp_mosi),
    .spi_miso(esp_miso),
    .spi_cs_n(esp_cs_n),
    
    // Wishbone master
    .wb_adr_o(wb_adr),
    .wb_dat_o(wb_dat_m2s),
    .wb_dat_i(wb_dat_s2m),
    .wb_cyc_o(wb_cyc),
    .wb_stb_o(wb_stb),
    .wb_we_o(wb_we),
    .wb_ack_i(wb_ack),
    
    // Control signals
    .access_tier_o(access_tier),
    .burst_mode_o(burst_mode),
    .burst_count_o(burst_count)
);

// =============================================================================
// Address Decoder
// =============================================================================

wire [31:0] slot_select;
wire extended_select;
wire large_select;

ssw_slot_decoder decoder (
    .wb_adr_i(wb_adr),
    .access_tier_i(access_tier),
    .slot_select(slot_select),
    .extended_select(extended_select),
    .large_select(large_select)
);

// =============================================================================
// Peripherals
// =============================================================================

// Device IDs
wire [15:0] device_ids [0:31];

// Slot 0: System Control
wire [7:0] sys_dat_o;
wire sys_ack;

wb_system_control #(
    .VERSION(8'h10),
    .SLOT_COUNT(8'd32),
    .MEM_SIZE_MB(8'd16)
) system_control (
    .clk(clk_50mhz),
    .rst(sys_rst),
    .wb_adr_i(wb_adr),
    .wb_dat_i(wb_dat_m2s),
    .wb_dat_o(sys_dat_o),
    .wb_cyc_i(wb_cyc),
    .wb_stb_i(wb_stb),
    .wb_we_i(wb_we),
    .wb_ack_o(sys_ack),
    .slot_select_i(slot_select[0]),
    
    // Device IDs from all peripherals
    .device_id_0(device_ids[0]),
    .device_id_1(device_ids[1]),
    .device_id_2(device_ids[2]),
    .device_id_3(device_ids[3]),
    .device_id_4(device_ids[4]),
    .device_id_5(device_ids[5]),
    .device_id_6(device_ids[6]),
    .device_id_7(device_ids[7]),
    .device_id_8(device_ids[8]),
    .device_id_9(device_ids[9]),
    .device_id_10(device_ids[10]),
    .device_id_11(device_ids[11]),
    .device_id_12(device_ids[12]),
    .device_id_13(device_ids[13]),
    .device_id_14(device_ids[14]),
    .device_id_15(device_ids[15]),
    .device_id_16(device_ids[16]),
    .device_id_17(device_ids[17]),
    .device_id_18(device_ids[18]),
    .device_id_19(device_ids[19]),
    .device_id_20(device_ids[20]),
    .device_id_21(device_ids[21]),
    .device_id_22(device_ids[22]),
    .device_id_23(device_ids[23]),
    .device_id_24(device_ids[24]),
    .device_id_25(device_ids[25]),
    .device_id_26(device_ids[26]),
    .device_id_27(device_ids[27]),
    .device_id_28(device_ids[28]),
    .device_id_29(device_ids[29]),
    .device_id_30(device_ids[30]),
    .device_id_31(device_ids[31])
);

assign device_ids[0] = `SSW_DEVID_SYSTEM;

// Slot 1: RGB LED
wire [7:0] rgb_dat_o;
wire rgb_ack;

wb_rgb_led #(
    .SLOT_NUMBER(1)
) rgb_led (
    .clk(clk_50mhz),
    .rst(sys_rst),
    .wb_adr_i(wb_adr),
    .wb_dat_i(wb_dat_m2s),
    .wb_dat_o(rgb_dat_o),
    .wb_cyc_i(wb_cyc),
    .wb_stb_i(wb_stb),
    .wb_we_i(wb_we),
    .wb_ack_o(rgb_ack),
    .slot_select_i(slot_select[1]),
    .red_o(led_red),
    .green_o(led_green),
    .blue_o(led_blue)
);

assign device_ids[1] = `SSW_DEVID_RGB_LED;

// Fill remaining device IDs with EMPTY
genvar i;
generate
    for (i = 2; i < 32; i = i + 1) begin : empty_slots
        assign device_ids[i] = `SSW_DEVID_EMPTY;
    end
endgenerate

// =============================================================================
// Wishbone Response Multiplexer
// =============================================================================

// Combine read data from all slaves
assign wb_dat_s2m = slot_select[0] ? sys_dat_o :
                    slot_select[1] ? rgb_dat_o :
                    8'h00;  // Default to 0 if no slave selected

// Combine ACK signals
assign wb_ack = slot_select[0] ? sys_ack :
                slot_select[1] ? rgb_ack :
                1'b0;  // No ACK if no slave selected

endmodule
