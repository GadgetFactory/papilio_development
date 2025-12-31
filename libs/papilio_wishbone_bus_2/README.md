# Papilio Wishbone Bus 2 (PWB2)

A next-generation ESP32-to-FPGA communication infrastructure combining the best features of previous Wishbone bus implementations.

## Key Features

- **32-bit Native Wishbone**: Standard 32-bit bus for all peripherals internally
- **Variable SPI Widths**: Peripherals declare optimal transfer size (8/16/32-bit)
- **Three-Tier Addressing**: Efficient access to registers, on-chip memory, and external DDR
- **Burst Mode**: High-performance bulk transfers with 80%+ efficiency gain
- **Plug-and-Play**: Automatic peripheral integration via Python script
- **Memory Map**: Device enumeration and system information
- **Proven Components**: Uses established SPI slave cores

## Quick Start

### For ESP32 (Arduino)

```cpp
#include <PapilioWishbone2.h>

PapilioWishbone2 pwb2;

void setup() {
    pwb2.begin();                    // Initialize
    pwb2.enumerateDevices();         // Discover peripherals
    pwb2.printDevices(Serial);       // Show device map
    
    // Write to RGB LED (slot 1)
    pwb2.writeSlot8(1, 0, 255);      // Red
    pwb2.writeSlot8(1, 1, 128);      // Green
    pwb2.writeSlot8(1, 2, 64);       // Blue
    
    // Burst write to framebuffer
    uint32_t pixels[1024];
    pwb2.writeExtendedBurst(0x2000, pixels, 1024);
}
```

### For FPGA (Verilog)

Add to `platformio.ini`:
```ini
lib_deps =
    papilio_wishbone_bus_2
    pwb2_rgb_led_example

extra_scripts = 
    pre:libs/papilio_wishbone_bus_2/tools/generate_pwb2_top.py
```

The Python script automatically generates `top.v` with all peripherals!

## Address Space

```
Tier 1 (Slot):     0x00_0000 - 0x00_1FFF (8KB)   - 32 slots × 256 bytes
Tier 2 (Extended): 0x00_2000 - 0x00_FFFF (56KB)  - On-chip BRAM
Tier 3 (Large):    0x01_0000 - 0xFF_FFFF (16MB)  - External DDR/SDRAM
```

## API Overview

### Initialization
- `bool begin(uint32_t spi_clock_hz = 20000000)`
- `void enumerateDevices()`
- `void printDevices(Stream& stream = Serial)`

### Tier 1: Slot Access (Registers)
- `writeSlot8/16/32(slot, reg, data)`
- `readSlot8/16/32(slot, reg)`
- `writeSlotBurst(slot, start_reg, data[], count)`
- `readSlotBurst(slot, start_reg, data[], count)`

### Tier 2: Extended (On-chip)
- `writeExtended(addr, data)`
- `readExtended(addr)`
- `writeExtendedBurst(addr, data[], count)`
- `readExtendedBurst(addr, data[], count)`

### Tier 3: Large (External DDR)
- `writeLarge(addr, data)`
- `readLarge(addr)`
- `writeLargeBurst(addr, data[], count)`
- `readLargeBurst(addr, data[], count)`

## Performance

### Burst Mode Benefits
- **Slot mode**: 3 bytes/transaction vs 7+ bytes (slot+reg+data×4+count)
- **Burst mode**: Overhead amortized over many words
- **Example**: 1KB transfer - 5× faster with burst!

### Comparison

| Mode | 1KB Transfer | Overhead | Efficiency |
|------|-------------|----------|------------|
| Single writes | 256 × 7 = 1792 bytes | 75% | 25% |
| Burst mode | 3 + 2 + 1024 = 1029 bytes | 0.5% | 99.5% |

## Creating a Peripheral

### 1. Create Verilog module
```verilog
`include "pwb2_pkg.vh"

module my_peripheral #(
    parameter SLOT_NUMBER = 1,
    parameter DEVICE_ID = 16'hXXXX
)(
    input wire clk,
    input wire rst,
    
    // Standard 32-bit Wishbone slave
    input wire [7:0] wb_adr_i,
    input wire [31:0] wb_dat_i,
    output reg [31:0] wb_dat_o,
    input wire wb_stb_i,
    input wire wb_we_i,
    output reg wb_ack_o,
    
    // Your peripheral ports
    output wire my_output
);
    // Your logic here
endmodule
```

### 2. Create `wishbone_peripheral.json`
```json
{
  "name": "My Peripheral",
  "module_name": "my_peripheral",
  "device_id": 0xXXXX,
  "spi_transfer_bits": 32,
  "slots_required": 1,
  "ports": [
    {"name": "my_output", "connection": "my_signal"}
  ]
}
```

### 3. Create `library.json`
```json
{
  "name": "my_pwb2_peripheral",
  "keywords": ["pwb2", "wishbone"],
  "export": {
    "include": ["*.v", "wishbone_peripheral.json"]
  }
}
```

### 4. Add to project
```ini
lib_deps =
    papilio_wishbone_bus_2
    my_pwb2_peripheral
```

That's it! The generator will automatically integrate it.

## Documentation

- [Architecture](ARCHITECTURE.md) - Complete system design
- [Protocol Specification](docs/PROTOCOL.md) - Detailed protocol
- [Integration Guide](docs/INTEGRATION_GUIDE.md) - Step-by-step integration
- [Creating Peripherals](docs/PERIPHERAL_GUIDE.md) - Peripheral development guide

## Examples

- [BasicPeripheralAccess](firmware/arduino/examples/BasicPeripheralAccess) - Simple RGB LED control
- [BurstTransfer](firmware/arduino/examples/BurstTransfer) - Performance demo
- [pwb2_rgb_led](examples/pwb2_rgb_led) - Reference peripheral implementation

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    ESP32 (Arduino)                       │
│  PapilioWishbone2 Library - Three-tier API              │
└────────────────────┬────────────────────────────────────┘
                     │ SPI (8/16/32-bit variable)
┌────────────────────┴────────────────────────────────────┐
│                    FPGA                                  │
│  ┌───────────────────────────────────────────────────┐  │
│  │ PWB2 SPI Bridge                                   │  │
│  │ - Variable width support                          │  │
│  │ - Three-tier addressing                           │  │
│  │ - Burst mode                                      │  │
│  └────────────────┬──────────────────────────────────┘  │
│                   │ 32-bit Wishbone                     │
│  ┌────────────────┴──────────────────────────────────┐  │
│  │ PWB2 Interconnect                                 │  │
│  │ - Slot decoder                                    │  │
│  │ - Memory map (Slot 0)                             │  │
│  └──┬────┬────┬────┬─────────────────────────────────┘  │
│     │    │    │    │                                     │
│  Slot0 Slot1 Slot2 Extended/Large Memory                │
│  SysMem RGB  GPIO  BRAM/DDR                             │
└─────────────────────────────────────────────────────────┘
```

## Benefits Over Previous Libraries

### vs. Smart Slot Wishbone (SSW)
- ✅ 32-bit native Wishbone (vs 8-bit)
- ✅ Variable SPI widths per peripheral
- ✅ Automatic top-level generation
- ✅ Proven SPI core

### vs. Papilio Wishbone Bus (PWB v1)
- ✅ Three-tier addressing (vs flat)
- ✅ Burst mode support
- ✅ Large external memory (16MB)
- ✅ More efficient protocol

## Requirements

### ESP32
- ESP32 Arduino framework
- SPI library (included)

### FPGA
- SystemVerilog support (for parameters)
- 50MHz+ system clock
- SPI pins connected to ESP32

## License

MIT License - See [LICENSE](LICENSE) file

## Contributing

Part of the Papilio FPGA development ecosystem. Contributions welcome!

## Support

- GitHub Issues: [Report bugs](https://github.com/GadgetFactory/papilio_development/issues)
- Forum: [Papilio Forum](https://forum.gadgetfactory.net)
- Email: jack.gassett@gadgetfactory.net
