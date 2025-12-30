# Smart Slot Wishbone Integration Guide

## Overview

This guide shows how to integrate Smart Slot Wishbone into your FPGA designs and ESP32 firmware.

## FPGA Integration

### 1. Add SSW to Your Project

Copy the HDL files to your project:
```
libs/papilio_smart_slot_wishbone/hdl/rtl/
  - ssw_pkg.vh
  - ssw_spi_bridge.v
  - ssw_slot_decoder.v
  - ssw_arbiter.v
```

Add to your synthesis tool's include path or reference directly.

### 2. Instantiate the SPI Bridge

```verilog
`include "ssw_pkg.vh"

module top (
    input wire clk_50mhz,
    
    // ESP32 SPI interface
    input wire esp_sclk,
    input wire esp_mosi,
    output wire esp_miso,
    input wire esp_cs_n,
    
    // Your other I/O
    // ...
);

// Wishbone bus
wire [23:0] wb_adr;
wire [7:0] wb_dat_m2s;  // Master to slave (write data)
wire [7:0] wb_dat_s2m;  // Slave to master (read data)
wire wb_cyc, wb_stb, wb_we, wb_ack;
wire [1:0] access_tier;
wire burst_mode;
wire [15:0] burst_count;

// Instantiate SSW bridge
ssw_spi_bridge ssw_bridge (
    .clk(clk_50mhz),
    .rst(reset),
    
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
```

### 3. Add Slot Decoder

```verilog
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
```

### 4. Create Wishbone Peripherals

#### Simple Peripheral Template

```verilog
module wb_rgb_led #(
    parameter SLOT_NUMBER = 1,
    parameter DEVICE_ID = `SSW_DEVID_RGB_LED
)(
    input wire clk,
    input wire rst,
    
    // Wishbone slave interface
    input wire [23:0] wb_adr_i,
    input wire [7:0] wb_dat_i,
    output reg [7:0] wb_dat_o,
    input wire wb_cyc_i,
    input wire wb_stb_i,
    input wire wb_we_i,
    output reg wb_ack_o,
    input wire slot_select_i,
    
    // RGB LED outputs
    output reg [7:0] red,
    output reg [7:0] green,
    output reg [7:0] blue
);

wire selected = wb_cyc_i && wb_stb_i && slot_select_i;
wire [7:0] reg_addr = wb_adr_i[7:0];  // Register within slot

always @(posedge clk) begin
    if (rst) begin
        red <= 8'd0;
        green <= 8'd0;
        blue <= 8'd0;
        wb_ack_o <= 1'b0;
    end else begin
        wb_ack_o <= selected;  // Single-cycle ACK
        
        if (selected && wb_we_i) begin
            case (reg_addr)
                8'h00: red <= wb_dat_i;
                8'h01: green <= wb_dat_i;
                8'h02: blue <= wb_dat_i;
            endcase
        end
        
        // Read data
        case (reg_addr)
            8'h00: wb_dat_o <= red;
            8'h01: wb_dat_o <= green;
            8'h02: wb_dat_o <= blue;
            default: wb_dat_o <= 8'h00;
        endcase
    end
end

endmodule
```

### 5. Connect Peripherals

```verilog
// RGB LED at slot 1
wire [7:0] rgb_dat_o;
wire rgb_ack;

wb_rgb_led #(
    .SLOT_NUMBER(1)
) rgb_led (
    .clk(clk_50mhz),
    .rst(reset),
    .wb_adr_i(wb_adr),
    .wb_dat_i(wb_dat_m2s),
    .wb_dat_o(rgb_dat_o),
    .wb_cyc_i(wb_cyc),
    .wb_stb_i(wb_stb),
    .wb_we_i(wb_we),
    .wb_ack_o(rgb_ack),
    .slot_select_i(slot_select[1]),
    .red(led_red),
    .green(led_green),
    .blue(led_blue)
);

// Add more peripherals...

// Combine read data and ACKs
assign wb_dat_s2m = slot_select[1] ? rgb_dat_o :
                    slot_select[2] ? sid_dat_o :
                    8'h00;

assign wb_ack = slot_select[1] ? rgb_ack :
                slot_select[2] ? sid_ack :
                1'b0;
```

### 6. Add Memory Arbiter (Optional)

For on-chip BRAM and external DDR:

```verilog
ssw_arbiter arbiter (
    .clk(clk_50mhz),
    .rst(reset),
    
    // Wishbone slave
    .wb_adr_i(wb_adr),
    .wb_dat_i(wb_dat_m2s),
    .wb_dat_o(mem_dat_o),
    .wb_cyc_i(wb_cyc),
    .wb_stb_i(wb_stb),
    .wb_we_i(wb_we),
    .wb_ack_o(mem_ack),
    .access_tier_i(access_tier),
    
    // BRAM interface
    .bram_addr(bram_addr),
    .bram_din(bram_din),
    .bram_dout(bram_dout),
    .bram_we(bram_we),
    .bram_en(bram_en),
    
    // DDR controller interface
    .ddr_addr(ddr_addr),
    .ddr_din(ddr_din),
    .ddr_dout(ddr_dout),
    .ddr_req(ddr_req),
    .ddr_we(ddr_we),
    .ddr_ack(ddr_ack)
);
```

## ESP32 Integration

### 1. Install Arduino Library

Copy the library to your Arduino libraries folder:
```
~/Arduino/libraries/SmartSlotWishbone/
```

Or use PlatformIO:
```ini
[env:esp32]
platform = espressif32
board = esp32dev
framework = arduino
lib_deps = 
    SmartSlotWishbone
```

### 2. Basic Usage

```cpp
#include <SmartSlotWishbone.h>

SmartSlotWishbone ssw;

void setup() {
    Serial.begin(115200);
    
    // Initialize SSW
    ssw.begin();
    
    // Enumerate devices
    ssw.enumerateDevices();
    ssw.printDevices();
    
    // Find RGB LED
    DeviceInfo* led = ssw.findDevice(SSW_DEVID_RGB_LED);
    if (led) {
        // Set to red
        ssw.setRGB(led->slot, 255, 0, 0);
    }
}
```

### 3. Advanced Usage

```cpp
void updateDisplay() {
    // Create framebuffer
    uint8_t fb[320 * 240 * 2];  // RGB565
    
    // Fill with gradient
    for (int y = 0; y < 240; y++) {
        for (int x = 0; x < 320; x++) {
            uint16_t color = (x << 6) | (y >> 2);
            fb[(y * 320 + x) * 2] = color >> 8;
            fb[(y * 320 + x) * 2 + 1] = color & 0xFF;
        }
    }
    
    // Update framebuffer with burst
    ssw.writeExtendedBurst(0x2000, fb, sizeof(fb));
}
```

## System Control Implementation

Create a system control peripheral at slot 0:

```verilog
module wb_system_control (
    input wire clk,
    input wire rst,
    
    // Wishbone interface
    input wire [23:0] wb_adr_i,
    input wire [7:0] wb_dat_i,
    output reg [7:0] wb_dat_o,
    input wire wb_cyc_i,
    input wire wb_stb_i,
    input wire wb_we_i,
    output reg wb_ack_o,
    input wire slot_select_i,
    
    // Device information inputs
    input wire [15:0] device_ids [0:31]
);

localparam VERSION = 8'h10;  // Version 1.0
localparam CAPS = 8'b00000111;  // Burst, Extended, Large modes
localparam SLOT_COUNT = 8'd32;
localparam MEM_SIZE = 8'd16;  // 16 MB

wire selected = wb_cyc_i && wb_stb_i && slot_select_i;
wire [7:0] reg_addr = wb_adr_i[7:0];

always @(posedge clk) begin
    if (rst) begin
        wb_ack_o <= 1'b0;
    end else begin
        wb_ack_o <= selected;
        
        // Read-only registers
        case (reg_addr)
            8'h00: wb_dat_o <= VERSION;
            8'h01: wb_dat_o <= CAPS;
            8'h02: wb_dat_o <= SLOT_COUNT;
            8'h03: wb_dat_o <= MEM_SIZE;
            default: begin
                // Device IDs (0x10-0x4F)
                if (reg_addr >= 8'h10 && reg_addr < 8'h50) begin
                    wire [5:0] id_offset = reg_addr - 8'h10;
                    wire [4:0] slot_num = id_offset >> 1;
                    wire is_high_byte = id_offset[0];
                    
                    wb_dat_o <= is_high_byte ? 
                               device_ids[slot_num][7:0] :   // Low byte
                               device_ids[slot_num][15:8];  // High byte
                end else begin
                    wb_dat_o <= 8'h00;
                end
            end
        endcase
    end
end

endmodule
```

## Best Practices

1. **Single-cycle ACK for peripherals**: Return ACK in same cycle as request
2. **Multi-cycle ACK for memory**: DDR may need several cycles
3. **Default to 0xFF on invalid reads**: Makes debugging easier
4. **Use burst mode for >10 bytes**: Dramatic efficiency improvement
5. **Pipeline Wishbone arbiter**: For high performance
6. **Add timeout logic**: Prevent lockup on misbehaving slaves
7. **Version your device IDs**: Allow backward compatibility

## Troubleshooting

**No devices found:**
- Check SPI connections (especially CS polarity)
- Verify FPGA is programmed and running
- Check system control slot implementation

**Corrupted data:**
- Reduce SPI clock speed
- Check signal integrity (use pullups if needed)
- Verify SPI mode (should be Mode 0)

**Slow transfers:**
- Use burst mode for multi-byte transfers
- Increase SPI clock if stable
- Enable DMA on ESP32

**Wishbone lockup:**
- Add timeout to bridge
- Ensure all slaves return ACK
- Check for addressing conflicts
