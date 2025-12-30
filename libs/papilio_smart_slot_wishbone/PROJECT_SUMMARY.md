# Smart Slot Wishbone Library - Project Summary

## What Was Created

A complete **Smart Slot Wishbone (SSW)** communication library for ESP32-to-FPGA interfacing over SPI. This three-tier addressing architecture provides efficient access to both small peripherals and large external memory.

## Repository Structure

```
libs/papilio_smart_slot_wishbone/
├── README.md                              ✓ Main documentation
├── LICENSE                                ✓ MIT License
│
├── docs/
│   ├── PROTOCOL.md                        ✓ Detailed protocol specification
│   └── INTEGRATION_GUIDE.md               ✓ Step-by-step integration guide
│
├── hdl/
│   └── rtl/
│       ├── ssw_pkg.vh                     ✓ Protocol constants & definitions
│       ├── ssw_spi_bridge.v               ✓ Main SPI-to-Wishbone bridge
│       └── ssw_slot_decoder.v             ✓ Address decoder
│
├── firmware/
│   └── arduino/
│       ├── library.properties             ✓ Arduino library metadata
│       ├── src/
│       │   ├── SmartSlotWishbone.h        ✓ C++ header
│       │   └── SmartSlotWishbone.cpp      ✓ C++ implementation
│       └── examples/
│           ├── BasicPeripheralAccess/     ✓ Simple RGB LED example
│           ├── FramebufferUpdate/         ✓ Burst mode performance demo
│           └── DeviceEnumeration/         ✓ Device discovery example
│
└── tools/
    └── device_id_registry.json            ✓ Standard device IDs
```

## Key Features

### Three-Tier Addressing
1. **Tier 1 - Slot Mode (3 bytes)**: For peripheral registers (32 slots × 256 bytes)
2. **Tier 2 - Extended Mode (4 bytes)**: For on-chip memory (64KB)
3. **Tier 3 - Large Mode (5 bytes)**: For external DDR/SDRAM (16MB)

### Performance Optimizations
- **Burst Mode**: Reduces SPI overhead by 80%+ for large transfers
- **Auto-increment**: Addresses increment automatically in burst mode
- **DMA Support**: Uses ESP32 DMA for efficient transfers

### Plug-and-Play Architecture
- **Device Enumeration**: Auto-discovery of FPGA peripherals
- **Standard Device IDs**: Registry of common peripheral types
- **Slot-based Design**: Easy addition of new peripherals

## Files Completed

### HDL (Verilog)
✅ **ssw_pkg.vh** - Protocol definitions, constants, device IDs, helper macros
✅ **ssw_spi_bridge.v** - Complete SPI-to-Wishbone bridge with:
  - 3-stage clock domain crossing
  - Full state machine for all modes
  - Burst mode support
  - Error handling

✅ **ssw_slot_decoder.v** - Address decoder with tier selection

### Firmware (ESP32/Arduino)
✅ **SmartSlotWishbone.h** - Full API with:
  - All three tier access methods
  - Burst read/write for each tier
  - Device enumeration
  - System information queries
  
✅ **SmartSlotWishbone.cpp** - Complete implementation with:
  - Efficient SPI transfers
  - DMA support on ESP32
  - Transaction counting
  - Debug mode

### Examples
✅ **BasicPeripheralAccess.ino** - RGB LED color cycling
✅ **FramebufferUpdate.ino** - Performance comparison demo
✅ **DeviceEnumeration.ino** - Device discovery

### Documentation
✅ **README.md** - Quick start guide
✅ **PROTOCOL.md** - Complete protocol specification with:
  - Command byte format
  - All transaction types
  - Address space map
  - Performance characteristics
  
✅ **INTEGRATION_GUIDE.md** - Integration walkthrough with:
  - FPGA integration steps
  - ESP32 integration steps
  - Custom peripheral template
  - Performance tips
  - Debugging guide

✅ **device_id_registry.json** - Standard device ID database

## Usage Example

### FPGA Side
```verilog
ssw_spi_bridge bridge (
    .clk(sys_clk),
    .spi_sclk(esp_clk),
    .spi_mosi(esp_mosi),
    .spi_miso(esp_miso),
    .spi_cs_n(esp_cs),
    .wb_adr_o(wb_adr),
    .wb_dat_o(wb_dat_m2s),
    .wb_dat_i(wb_dat_s2m),
    // ... rest of Wishbone signals
);
```

### ESP32 Side
```cpp
SmartSlotWishbone ssw;

void setup() {
    ssw.begin();
    ssw.enumerateDevices();
    
    // Write to RGB LED (Slot 1)
    ssw.writeSlot(1, 0, 255);  // Red
    
    // Update framebuffer with burst
    ssw.writeExtendedBurst(0x2000, pixels, 153600);
}
```

## Performance Gains

### Compared to Standard Wishbone SPI
- **Slot mode**: 25% fewer bytes (3 vs 4)
- **Burst mode**: 80% fewer bytes for large transfers
- **DDR framebuffer**: Supports 16MB vs 64KB limit

### Example: 1MB Framebuffer Update
- Old way (single writes): 5,242,880 bytes
- SSW burst mode: 1,048,583 bytes
- **Improvement**: 5× faster!

## Next Steps

1. **Test the library**: Try the examples on your hardware
2. **Create peripherals**: Use the template in INTEGRATION_GUIDE.md
3. **Contribute**: Add new device IDs to the registry
4. **Optimize**: Experiment with higher SPI clock speeds

## Getting Started

1. Copy library to your project:
   ```bash
   cd your_fpga_project/libs
   ln -s ../../papilio_smart_slot_wishbone .
   ```

2. Include in Arduino:
   ```bash
   cp -r firmware/arduino/src ~/Arduino/libraries/SmartSlotWishbone/
   ```

3. Follow the INTEGRATION_GUIDE.md for detailed steps!

## Support

- Documentation: See `docs/` folder
- Examples: See `firmware/arduino/examples/`
- Issues: Use GitHub issues
- Forum: Papilio FPGA community forum

## License

MIT License - Free to use in commercial and open-source projects

---

**Repository**: https://github.com/GadgetFactory/papilio_development
**Library Path**: `libs/papilio_smart_slot_wishbone/`
**Created**: December 30, 2025
