# Smart Slot Wishbone Library - Quick Start

## What's Included

The complete Smart Slot Wishbone library has been added to your repository at:
`libs/papilio_smart_slot_wishbone/`

### Directory Structure

```
libs/papilio_smart_slot_wishbone/
├── README.md                          # Main documentation
├── LICENSE                            # MIT License
│
├── docs/
│   ├── PROTOCOL.md                    # Detailed protocol specification
│   └── INTEGRATION_GUIDE.md           # Integration instructions
│
├── hdl/
│   ├── rtl/
│   │   ├── ssw_pkg.vh                 # Protocol constants & macros
│   │   ├── ssw_spi_bridge.v           # Main SPI-to-Wishbone bridge
│   │   ├── ssw_slot_decoder.v         # Address decoder
│   │   └── ssw_arbiter.v              # Memory arbiter (BRAM/DDR)
│   │
│   └── examples/
│       ├── wb_rgb_led.v               # Example: RGB LED peripheral
│       ├── wb_system_control.v        # Example: System control (slot 0)
│       └── integration_example.v      # Complete working example
│
├── firmware/
│   └── arduino/
│       ├── library.properties         # Arduino library metadata
│       ├── src/
│       │   ├── SmartSlotWishbone.h    # Arduino library header
│       │   └── SmartSlotWishbone.cpp  # Arduino library implementation
│       │
│       └── examples/
│           ├── BasicPeripheralAccess/  # Basic usage example
│           ├── FramebufferUpdate/      # Framebuffer demo
│           └── DeviceEnumeration/      # Device discovery demo
│
└── tools/
    └── device_id_registry.json        # Standard device ID registry
```

## Quick Integration

### For FPGA (Verilog)

1. **Include the package:**
```verilog
`include "libs/papilio_smart_slot_wishbone/hdl/rtl/ssw_pkg.vh"
```

2. **Instantiate the bridge:**
```verilog
ssw_spi_bridge bridge (
    .clk(clk_50mhz),
    .rst(reset),
    .spi_sclk(esp_sclk),
    .spi_mosi(esp_mosi),
    .spi_miso(esp_miso),
    .spi_cs_n(esp_cs_n),
    // ... Wishbone connections
);
```

3. **See full example:**
   - `hdl/examples/integration_example.v`

### For ESP32 (Arduino)

1. **Copy library to Arduino:**
```bash
cp -r libs/papilio_smart_slot_wishbone/firmware/arduino ~/Arduino/libraries/SmartSlotWishbone
```

2. **Use in sketch:**
```cpp
#include <SmartSlotWishbone.h>

SmartSlotWishbone ssw;

void setup() {
    ssw.begin();
    ssw.enumerateDevices();
    ssw.printDevices();
}
```

3. **See examples:**
   - `firmware/arduino/examples/BasicPeripheralAccess/`
   - `firmware/arduino/examples/FramebufferUpdate/`

## Key Features

✅ **Three-tier addressing:**
- Tier 1: 3 bytes for peripherals (32 slots × 256 bytes)
- Tier 2: 4 bytes for on-chip memory (64KB)
- Tier 3: 5 bytes for external DDR/SDRAM (16MB)

✅ **Burst mode:**
- 75-80% overhead reduction
- Perfect for framebuffers and bulk transfers

✅ **Plug-and-play:**
- Automatic device enumeration
- Standard device ID registry
- USB-like discovery

✅ **Well-documented:**
- Complete protocol specification
- Integration guide with examples
- Working example peripherals

## Next Steps

1. **Read the docs:**
   - [PROTOCOL.md](docs/PROTOCOL.md) - Protocol details
   - [INTEGRATION_GUIDE.md](docs/INTEGRATION_GUIDE.md) - How to integrate

2. **Try the examples:**
   - FPGA: `hdl/examples/integration_example.v`
   - Arduino: `firmware/arduino/examples/`

3. **Create your own peripherals:**
   - Use `hdl/examples/wb_rgb_led.v` as template
   - Register device ID in `tools/device_id_registry.json`

## Performance

**RGB LED (3 bytes):**
- Old: 12 bytes total (4 × 3)
- New: 9 bytes total (3 × 3)
- **25% improvement**

**Framebuffer (153,600 bytes):**
- Old: 614,400 bytes total
- New: 153,606 bytes total (burst)
- **75% improvement**

**Large DDR (4MB):**
- Old: 20,971,520 bytes
- New: 4,194,752 bytes (burst)
- **80% improvement**

## Repository Location

All files committed to:
https://github.com/GadgetFactory/papilio_development/tree/master/libs/papilio_smart_slot_wishbone

## License

MIT License - See [LICENSE](LICENSE) file

---

**Ready to use!** No need to switch to Claude Code - everything is already in your GitHub repo. Just clone/pull and start integrating! 🚀
