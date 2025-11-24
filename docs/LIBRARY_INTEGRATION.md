# Library Integration Guide

This document describes how to integrate new PlatformIO libraries with gateware components into the Papilio Arcade Template.

## Standard Wishbone Address Map

The template uses an 8-bit address space divided into 16-byte regions:

| Slave | Address Range | Purpose | Module |
|-------|--------------|---------|---------|
| 0 | 0x00-0x0F | RGB LED Control | `wb_simple_rgb_led` |
| 1 | 0x10-0x1F | HDMI Video | `wb_video_ctrl` |
| 2 | 0x20-0x2F | USB Serial (reserved) | - |
| 3+ | 0x30+ | Available for expansion | - |

## Project Structure

```
template_test/
├── src/
│   ├── papliio_arcade_template.ino    # ESP32 firmware
│   └── gateware/
│       ├── top.v                       # Top-level FPGA module
│       ├── pins.cst                    # Pin constraints
│       └── papilio_arcade_template.gprj # Gowin project file
├── platformio.ini                      # PlatformIO configuration
└── docs/
    └── LIBRARY_INTEGRATION.md          # This file
```

## Adding a New Library

### 1. Firmware Integration

**Add to `platformio.ini`:**
```ini
lib_deps = 
    https://github.com/GadgetFactory/papilio_wishbone_spi_master.git#main
    https://github.com/GadgetFactory/papilio_rgb_led.git#main
    https://github.com/GadgetFactory/papilio_hdmi.git#main  ; <-- New library
```

**Include in sketch:**
```cpp
#include <YourLibrary.h>

// Create persistent instance
YourLibraryClass *instance = nullptr;

void setup() {
    instance = new YourLibraryClass(fpgaSPI, SPI_CS, ...);
    instance->begin();
}
```

### 2. Gateware Integration

**Update `top.v`:**

1. Add Wishbone slave signals:
```verilog
// Wishbone signals - Slave N (Your peripheral)
wire [7:0] sN_wb_adr;
wire [7:0] sN_wb_dat_o;
wire [7:0] sN_wb_dat_i;
wire sN_wb_cyc;
wire sN_wb_stb;
wire sN_wb_we;
wire sN_wb_ack;
```

2. Connect to address decoder:
```verilog
wb_address_decoder u_wb_decoder (
    // ... existing connections ...
    .sN_wb_adr_o(sN_wb_adr),
    .sN_wb_dat_o(sN_wb_dat_o),
    .sN_wb_dat_i(sN_wb_dat_i),
    .sN_wb_cyc_o(sN_wb_cyc),
    .sN_wb_stb_o(sN_wb_stb),
    .sN_wb_we_o(sN_wb_we),
    .sN_wb_ack_i(sN_wb_ack)
);
```

3. Instantiate the peripheral module:
```verilog
your_wb_module u_your_module (
    .clk(clk_27mhz),
    .rst_n(rst_n),
    .wb_adr_i(sN_wb_adr),
    .wb_dat_i(sN_wb_dat_o),
    .wb_dat_o(sN_wb_dat_i),
    .wb_cyc_i(sN_wb_cyc),
    .wb_stb_i(sN_wb_stb),
    .wb_we_i(sN_wb_we),
    .wb_ack_o(sN_wb_ack),
    // ... peripheral-specific ports ...
);
```

**Update `papilio_arcade_template.gprj`:**

Add gateware source files:
```xml
<FileList>
    <File path="..\..\path\to\your\module.v" type="file.verilog" enable="1"/>
    <File path="..\..\path\to\helper\module.v" type="file.verilog" enable="1"/>
</FileList>
```

**Update `pins.cst`:**

Add pin constraints for new peripheral I/O:
```
IO_LOC "your_signal" PIN_NUMBER;
IO_PORT "your_signal" IO_TYPE=LVCMOS18 PULL_MODE=NONE DRIVE=8;
```

### 3. Update Address Decoder

If adding a new slave beyond slave 2, update the Wishbone address decoder to add the new slave ports and decoding logic.

## Example: HDMI Library Integration

See the current implementation for a complete example:

**Firmware (`src/papliio_arcade_template.ino`):**
- Persistent `HDMIController` instance
- Initialized in `setup()` with `begin()` and `setVideoPattern()`
- Wishbone address: 0x10

**Gateware (`src/gateware/top.v`):**
- Module: `wb_video_ctrl`
- Top-level ports: `O_tmds_clk_p/n`, `O_tmds_data_p[2:0]/n[2:0]`
- Connected to Wishbone slave 1

**Pin Constraints (`src/gateware/pins.cst`):**
- LVCMOS18D differential pairs for HDMI TMDS signals
- Format: `IO_LOC "signal" pin1,pin2;`

**Gateware Sources (`.gprj`):**
- `wb_video_ctrl.v`
- `video_top_wb.v`
- `testpattern.v`
- `TMDS_rPLL.v`
- `dvi_tx/dvi_tx.v` (Gowin IP core)
- Supporting modules

## Tips for Clean Integration

1. **Check existing implementations** - Look at papilio_rgb_led for simple examples, papilio_hdmi for complex ones
2. **Maintain address map** - Document which Wishbone slave addresses are used
3. **Use descriptive names** - Module instances should indicate their function
4. **Test incrementally** - Add firmware first, then gateware, then pins
5. **Reference working projects** - Compare with known-working implementations like papilio_arcade_board

## Troubleshooting

**Build fails with "instantiating unknown module":**
- Ensure all required gateware files are added to `.gprj`
- Check for IP cores that need to be copied to project

**FPGA works but firmware can't communicate:**
- Verify Wishbone address matches between firmware and gateware
- Check SPI pins are correctly connected in both domains

**Pin constraint errors:**
- Verify pin names in `.cst` match port names in `top.v`
- For differential pairs, use correct IO_TYPE (LVCMOS18D, LVDS, etc.)
- Check bank voltage requirements for chosen IO standard

## Reference Projects

- **Simple template:** This repository (papilio_arcade_template)
- **Working HDMI implementation:** papilio_arcade_board
- **Library sources:** https://github.com/GadgetFactory/
