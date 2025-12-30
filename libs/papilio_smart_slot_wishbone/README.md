# Smart Slot Wishbone (SSW)

A three-tier addressing architecture for ESP32-to-FPGA communication over SPI, providing efficient access to both small peripherals and large external memory.

## Features

- **Three-tier addressing**: Slot mode (3 bytes), Extended mode (4 bytes), Large memory mode (5 bytes)
- **32 peripheral slots**: 256 bytes each, perfect for control registers
- **64KB on-chip memory**: For small framebuffers and audio buffers
- **16MB external memory**: For DDR/SDRAM framebuffers and large datasets
- **Burst mode support**: Dramatically reduces overhead for bulk transfers (80%+ efficiency gain)
- **Plug-and-play architecture**: Auto-enumeration of peripherals
- **Device ID registry**: Standard IDs for common peripherals

## Address Space

```
Tier 1 (Slot):     0x000000 - 0x001FFF (8KB)   - 32 slots × 256 bytes
Tier 2 (Extended): 0x002000 - 0x00FFFF (56KB)  - On-chip BRAM
Tier 3 (Large):    0x010000 - 0xFFFFFF (16MB)  - External DDR/SDRAM
```

## Protocol

### Command Byte Format
```
[7:RW] [6:5:MODE] [4:0:MODE_DATA]
```

### Transaction Types

**Slot Mode (3 bytes):**
```
[CMD] [REG] [DATA]
```

**Extended Mode (4 bytes):**
```
[CMD] [ADDR_H] [ADDR_L] [DATA]
```

**Large Mode (5 bytes):**
```
[CMD] [ADDR[23:16]] [ADDR[15:8]] [ADDR[7:0]] [DATA]
```

**Burst Mode (+2 bytes header):**
```
[CMD|BURST_FLAG] [...addr...] [COUNT_H] [COUNT_L] [DATA...×COUNT]
```

## Quick Start

### FPGA Side (Verilog)

```verilog
`include "ssw_pkg.vh"

module my_design (
    // SPI interface
    input wire esp_clk,
    input wire esp_mosi,
    output wire esp_miso,
    input wire esp_cs_n,
    // ...
);

// Instantiate SSW bridge
wire [23:0] wb_adr;
wire [7:0] wb_dat_o, wb_dat_i;
wire wb_cyc, wb_stb, wb_we, wb_ack;

ssw_spi_bridge bridge (
    .clk(sys_clk),
    .rst(sys_rst),
    .spi_sclk(esp_clk),
    .spi_mosi(esp_mosi),
    .spi_miso(esp_miso),
    .spi_cs_n(esp_cs_n),
    .wb_adr_o(wb_adr),
    .wb_dat_o(wb_dat_o),
    .wb_dat_i(wb_dat_i),
    .wb_cyc_o(wb_cyc),
    .wb_stb_o(wb_stb),
    .wb_we_o(wb_we),
    .wb_ack_i(wb_ack)
);

// Connect your peripherals to slots
wb_rgb_led #(.SLOT_NUMBER(1)) rgb_led (...);
wb_sid6581 #(.SLOT_NUMBER(2)) sid (...);
// ...
endmodule
```

### ESP32 Side (Arduino)

```cpp
#include <SmartSlotWishbone.h>

SmartSlotWishbone ssw;

void setup() {
    ssw.begin();
    
    // Enumerate devices
    ssw.enumerateDevices();
    
    // Write to RGB LED (slot 1)
    ssw.writeSlot(1, 0, 255);  // Red
    ssw.writeSlot(1, 1, 128);  // Green
    ssw.writeSlot(1, 2, 0);    // Blue
    
    // Update framebuffer with burst
    uint8_t pixels[153600];
    // ... fill pixels ...
    ssw.writeExtendedBurst(0x2000, pixels, 153600);
}
```

## Directory Structure

```
libs/papilio_smart_slot_wishbone/
├── README.md                    (This file)
├── LICENSE
├── docs/
│   ├── PROTOCOL.md             (Detailed protocol specification)
│   └── INTEGRATION_GUIDE.md    (How to integrate into designs)
├── hdl/
│   ├── rtl/                    (Verilog RTL)
│   ├── sim/                    (Testbenches)
│   └── examples/               (Example peripherals)
├── firmware/
│   ├── arduino/                (Arduino/ESP32 library)
│   └── python/                 (Python library for testing)
└── tools/                      (Helper scripts)
```

## Documentation

- [Protocol Specification](docs/PROTOCOL.md)
- [Integration Guide](docs/INTEGRATION_GUIDE.md)
- [Device ID Registry](tools/device_id_registry.json)

## License

MIT License - See LICENSE file for details

## Contributing

This library is part of the Papilio FPGA development ecosystem. Contributions welcome!
