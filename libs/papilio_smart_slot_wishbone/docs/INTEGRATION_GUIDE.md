# Smart Slot Wishbone Integration Guide

## Table of Contents

1. [Quick Start](#quick-start)
2. [FPGA Integration](#fpga-integration)
3. [ESP32 Integration](#esp32-integration)
4. [Creating Custom Peripherals](#creating-custom-peripherals)
5. [Memory Architecture](#memory-architecture)
6. [Performance Optimization](#performance-optimization)
7. [Debugging](#debugging)

## Quick Start

### Minimum FPGA Design

```verilog
`include "ssw_pkg.vh"

module top (
    input wire clk,
    input wire rst,
    
    // SPI from ESP32
    input wire esp_sclk,
    input wire esp_mosi,
    output wire esp_miso,
    input wire esp_cs_n,
    
    // Your peripherals
    output reg [23:0] rgb_led
);

// Wishbone bus
wire [23:0] wb_adr;
wire [7:0] wb_dat_m2s, wb_dat_s2m;
wire wb_cyc, wb_stb, wb_we, wb_ack;
wire [1:0] access_tier;

// SSW Bridge
ssw_spi_bridge bridge (
    .clk(clk),
    .rst(rst),
    .spi_sclk(esp_sclk),
    .spi_mosi(esp_mosi),
    .spi_miso(esp_miso),
    .spi_cs_n(esp_cs_n),
    .wb_adr_o(wb_adr),
    .wb_dat_o(wb_dat_m2s),
    .wb_dat_i(wb_dat_s2m),
    .wb_cyc_o(wb_cyc),
    .wb_stb_o(wb_stb),
    .wb_we_o(wb_we),
    .wb_ack_i(wb_ack),
    .access_tier_o(access_tier)
);

// Slot decoder
wire [31:0] slot_sel;
ssw_slot_decoder decoder (
    .wb_adr_i(wb_adr),
    .access_tier_i(access_tier),
    .slot_select(slot_sel)
);

// RGB LED peripheral (Slot 1)
wire rgb_ack;
assign rgb_ack = slot_sel[1] && wb_stb;

always @(posedge clk) begin
    if (rst) begin
        rgb_led <= 24'h000000;
    end else if (rgb_ack && wb_we) begin
        case (wb_adr[7:0])
            8'h00: rgb_led[23:16] <= wb_dat_m2s;  // R
            8'h01: rgb_led[15:8]  <= wb_dat_m2s;  // G
            8'h02: rgb_led[7:0]   <= wb_dat_m2s;  // B
        endcase
    end
end

// ACK generation
assign wb_ack = rgb_ack;

endmodule
```

### Minimum ESP32 Code

```cpp
#include <SmartSlotWishbone.h>

SmartSlotWishbone ssw;

void setup() {
    ssw.begin();
    
    // Set RGB LED to purple
    ssw.writeSlot(1, 0, 255);  // R
    ssw.writeSlot(1, 1, 0);    // G
    ssw.writeSlot(1, 2, 255);  // B
}
```

## FPGA Integration

### Step 1: Add SSW Files to Project

```bash
cd your_fpga_project/
mkdir -p libs
cd libs
ln -s ../../papilio_smart_slot_wishbone .
```

In your synthesis tool, add:
- `libs/papilio_smart_slot_wishbone/hdl/rtl/*.v`

### Step 2: Instantiate Bridge

```verilog
ssw_spi_bridge #(
    .SPI_MODE(0)  // SPI Mode 0
) bridge (
    .clk(sys_clk),     // System clock (e.g., 100 MHz)
    .rst(sys_rst),
    .spi_sclk(esp_clk),
    .spi_mosi(esp_mosi),
    .spi_miso(esp_miso),
    .spi_cs_n(esp_cs),
    // Wishbone outputs
    .wb_adr_o(wb_adr),
    .wb_dat_o(wb_dat_m2s),
    .wb_dat_i(wb_dat_s2m),
    .wb_cyc_o(wb_cyc),
    .wb_stb_o(wb_stb),
    .wb_we_o(wb_we),
    .wb_ack_i(wb_ack),
    .access_tier_o(access_tier)
);
```

### Step 3: Add Slot Decoder

```verilog
ssw_slot_decoder #(
    .NUM_SLOTS(32)
) decoder (
    .wb_adr_i(wb_adr),
    .access_tier_i(access_tier),
    .slot_select(slot_sel),      // One-hot
    .extended_select(ext_sel),
    .large_select(large_sel)
);
```

### Step 4: Connect Peripherals

Each peripheral gets its own slot:

```verilog
// System control (Slot 0) - Required!
system_control #(
    .VERSION(8'h10),
    .NUM_SLOTS(4)
) sys_ctrl (
    .clk(clk),
    .rst(rst),
    .wb_adr_i(wb_adr[7:0]),
    .wb_dat_o(sys_dat),
    .wb_stb_i(slot_sel[0]),
    .wb_we_i(wb_we),
    .wb_ack_o(sys_ack)
);

// RGB LED (Slot 1)
rgb_led_controller rgb (
    .clk(clk),
    .rst(rst),
    .wb_adr_i(wb_adr[7:0]),
    .wb_dat_i(wb_dat_m2s),
    .wb_dat_o(rgb_dat),
    .wb_stb_i(slot_sel[1]),
    .wb_we_i(wb_we),
    .wb_ack_o(rgb_ack),
    .rgb_out(rgb_led)
);

// SID Audio (Slot 2)
sid_controller sid (
    .clk(clk),
    .rst(rst),
    .wb_adr_i(wb_adr[7:0]),
    .wb_dat_i(wb_dat_m2s),
    .wb_stb_i(slot_sel[2]),
    .wb_we_i(wb_we),
    .wb_ack_o(sid_ack),
    .audio_out(audio)
);

// Combine ACKs and data
assign wb_ack = sys_ack | rgb_ack | sid_ack;
assign wb_dat_s2m = sys_ack ? sys_dat :
                    rgb_ack ? rgb_dat :
                    sid_ack ? sid_dat : 8'hFF;
```

### Step 5: Add System Control Module

Required for device enumeration:

```verilog
module system_control #(
    parameter VERSION = 8'h10,
    parameter NUM_SLOTS = 4,
    parameter [15:0] SLOT_IDS [0:31] = {
        `SSW_DEVID_SYSTEM,   // Slot 0
        `SSW_DEVID_RGB_LED,  // Slot 1
        `SSW_DEVID_SID,      // Slot 2
        `SSW_DEVID_YM2149,   // Slot 3
        {28{`SSW_DEVID_EMPTY}} // Rest empty
    }
)(
    input wire clk,
    input wire rst,
    input wire [7:0] wb_adr_i,
    output reg [7:0] wb_dat_o,
    input wire wb_stb_i,
    input wire wb_we_i,
    output reg wb_ack_o
);

always @(posedge clk) begin
    if (rst) begin
        wb_ack_o <= 1'b0;
    end else if (wb_stb_i) begin
        wb_ack_o <= 1'b1;
        
        if (wb_adr_i == `SSW_SYS_VERSION)
            wb_dat_o <= VERSION;
        else if (wb_adr_i == `SSW_SYS_CAPABILITIES)
            wb_dat_o <= 8'b00001111;  // All modes supported
        else if (wb_adr_i == `SSW_SYS_SLOT_COUNT)
            wb_dat_o <= NUM_SLOTS;
        else if (wb_adr_i >= `SSW_SYS_DEV_ID_BASE && 
                 wb_adr_i < `SSW_SYS_DEV_ID_BASE + 64) begin
            // Device IDs (16-bit, stored as pairs)
            integer slot_idx = (wb_adr_i - `SSW_SYS_DEV_ID_BASE) / 2;
            integer byte_idx = (wb_adr_i - `SSW_SYS_DEV_ID_BASE) % 2;
            
            if (byte_idx == 0)
                wb_dat_o <= SLOT_IDS[slot_idx][15:8];  // High byte
            else
                wb_dat_o <= SLOT_IDS[slot_idx][7:0];   // Low byte
        end else
            wb_dat_o <= 8'hFF;
    end else begin
        wb_ack_o <= 1'b0;
    end
end

endmodule
```

## ESP32 Integration

### Step 1: Install Library

Copy library to Arduino libraries folder:

```bash
cp -r libs/papilio_smart_slot_wishbone/firmware/arduino/src \
      ~/Arduino/libraries/SmartSlotWishbone/
```

### Step 2: Include and Initialize

```cpp
#include <SmartSlotWishbone.h>

SmartSlotWishbone ssw(&SPI, 5);  // CS on GPIO 5

void setup() {
    // Initialize at 20 MHz
    if (!ssw.begin(20000000)) {
        Serial.println("SSW init failed!");
        while(1);
    }
    
    // Enumerate devices
    ssw.enumerateDevices();
    ssw.printDevices();
}
```

### Step 3: Use Appropriate Tier

```cpp
// Tier 1: Control registers (fast, 3 bytes)
ssw.writeSlot(1, 0, 255);  // RGB red channel

// Tier 2: Small framebuffer (4 bytes)
uint8_t fb[320*240];
ssw.writeExtendedBurst(0x2000, fb, sizeof(fb));

// Tier 3: Large framebuffer (5 bytes)
uint8_t largeFB[1920*1080];
ssw.writeLargeBurst(0x010000, largeFB, sizeof(largeFB));
```

## Creating Custom Peripherals

### Template

```verilog
`include "ssw_pkg.vh"

module my_peripheral #(
    parameter SLOT_NUMBER = 0,
    parameter DEVICE_ID = 16'hXXXX
)(
    input wire clk,
    input wire rst,
    
    // Wishbone slave interface
    input wire [7:0] wb_adr_i,   // Only lower 8 bits
    input wire [7:0] wb_dat_i,
    output reg [7:0] wb_dat_o,
    input wire wb_stb_i,
    input wire wb_we_i,
    output reg wb_ack_o,
    
    // Your peripheral I/O
    output wire [7:0] my_output
);

// Register map
reg [7:0] ctrl_reg;
reg [7:0] status_reg;
reg [7:0] data_reg;

// Wishbone logic
always @(posedge clk) begin
    if (rst) begin
        wb_ack_o <= 1'b0;
        ctrl_reg <= 8'h00;
    end else if (wb_stb_i) begin
        wb_ack_o <= 1'b1;
        
        if (wb_we_i) begin
            // Write
            case (wb_adr_i)
                8'h00: ctrl_reg <= wb_dat_i;
                8'h02: data_reg <= wb_dat_i;
            endcase
        end else begin
            // Read
            case (wb_adr_i)
                8'h00: wb_dat_o <= ctrl_reg;
                8'h01: wb_dat_o <= status_reg;
                8'h02: wb_dat_o <= data_reg;
                default: wb_dat_o <= 8'hFF;
            endcase
        end
    end else begin
        wb_ack_o <= 1'b0;
    end
end

// Your peripheral logic here
assign my_output = data_reg;

endmodule
```

## Memory Architecture

### On-Chip BRAM

For Tier 2 (Extended mode):

```verilog
// 64KB BRAM for framebuffer
reg [7:0] bram [0:65535];

always @(posedge clk) begin
    if (ext_sel && wb_stb_i) begin
        if (wb_we_i)
            bram[wb_adr[15:0]] <= wb_dat_m2s;
        else
            wb_dat_s2m <= bram[wb_adr[15:0]];
    end
end
```

### External DDR/SDRAM

For Tier 3 (Large mode):

```verilog
// DDR controller interface
wire ddr_req, ddr_we, ddr_ack;
wire [23:0] ddr_addr;
wire [7:0] ddr_din, ddr_dout;

// Arbiter for DDR access
always @(posedge clk) begin
    if (large_sel && wb_stb_i) begin
        ddr_addr <= wb_adr;
        ddr_din <= wb_dat_m2s;
        ddr_we <= wb_we;
        ddr_req <= 1'b1;
    end
end

assign wb_ack = ddr_ack;
assign wb_dat_s2m = ddr_dout;
```

## Performance Optimization

### 1. Use Burst Mode for Large Transfers

```cpp
// BAD: Single writes (slow!)
for (int i = 0; i < 1000; i++) {
    ssw.writeExtended(addr + i, data[i]);
}

// GOOD: Burst write (4x faster!)
ssw.writeExtendedBurst(addr, data, 1000);
```

### 2. Increase SPI Clock Speed

```cpp
// Try higher speeds if your wiring supports it
ssw.begin(40000000);  // 40 MHz instead of 20 MHz
```

### 3. Use DMA on ESP32

The library automatically uses DMA for burst transfers on ESP32.

### 4. Pipeline FPGA Operations

Use registered outputs to meet timing:

```verilog
always @(posedge clk) begin
    if (wb_ack_i) begin
        // Pipeline data
        data_out <= processed_data;
    end
end
```

## Debugging

### Enable Debug Mode

```cpp
ssw.setDebug(true);
```

### Monitor Transactions

```cpp
Serial.printf("Transactions: %lu\n", ssw.getTransactionCount());
ssw.resetTransactionCount();
```

### FPGA Debug Signals

Add debug outputs to bridge:

```verilog
ssw_spi_bridge bridge (
    // ... normal ports ...
    .last_cmd_o(debug_cmd),
    .error_o(debug_error)
);
```

### Common Issues

1. **No response**: Check SPI wiring, clock polarity
2. **Wrong data**: Verify slot numbers match
3. **Slow performance**: Use burst mode
4. **Intermittent errors**: Add pull-ups to SPI lines

## Next Steps

- See [PROTOCOL.md](PROTOCOL.md) for detailed protocol spec
- Check `examples/` for working code
- Join the community forum for support
