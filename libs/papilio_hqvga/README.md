# Papilio HQVGA Library

**160x120 pixel VGA output for Papilio Arcade boards**

## Overview

This library provides HQVGA (Half-Quarter VGA, 160x120 pixels) video output for Papilio boards featuring:
- Gowin FPGA (GW2A series)
- ESP32-S3 microcontroller
- VGA output at 800x600@72Hz with 5x5 pixel scaling

Originally developed by Alvaro Lopes for ZPUINO, ported to work with Gowin FPGAs and ESP32-S3.

## Features

- 160x120 pixel resolution (scaled 5x5 to 800x600)
- 8-bit color (3R:3G:2B)
- Character display with 8x8 font
- Graphics primitives: lines, rectangles, pixel operations
- Dual-port memory architecture for flicker-free rendering
- Wishbone bus interface for ESP32-S3 communication

## Hardware Requirements

- Papilio Arcade board or compatible
- Gowin GW2A-18 FPGA or higher
- ESP32-S3 with SPI Wishbone bridge
- VGA output connector

## Resolution Details

- Native resolution: 160x120 pixels
- Display resolution: 800x600@72Hz
- Pixel scaling: 5x5 (each logical pixel becomes 5x5 physical pixels)
- Color depth: 8 bits per pixel (RGB332 format)
- Memory: 19,200 bytes frame buffer

## API Overview

### Initialization
```cpp
#include <HQVGA.h>

void setup() {
  VGA.begin(VGA_WISHBONE_SLOT, CHARMAP_WISHBONE_SLOT);
  VGA.clear();
  VGA.setColor(WHITE);
}
```

### Drawing Functions
```cpp
// Pixels
VGA.putPixel(x, y);
VGA.putPixel(x, y, color);

// Lines and rectangles
VGA.drawLine(x0, y0, x1, y1);
VGA.drawRect(x, y, width, height);
VGA.clearArea(x, y, width, height);

// Text
VGA.printchar(x, y, 'A');
VGA.printtext(x, y, "Hello World");

// Color
VGA.setColor(RED);
VGA.setColor(r, g, b);  // 0-7 for R/G, 0-3 for B
VGA.setBackgroundColor(BLACK);
```

### Memory Operations
```cpp
// Read/write pixel arrays
pixel_t buffer[100];
VGA.readArea(x, y, width, height, buffer);
VGA.writeArea(x, y, width, height, buffer);

// Move screen regions
VGA.moveArea(src_x, src_y, width, height, dst_x, dst_y);
```

## VHDL Gateware

The gateware is written in VHDL and consists of:

- **HQVGA.vhd** - Top-level VGA controller with timing generator
- **zpuino_vga_ram.vhd** - Frame buffer RAM (dual-port)
- **HQVGA_char_ram_8x8_sp.vhd** - Character ROM with 8x8 font
- **generic_dp_ram.vhd** - Generic dual-port RAM module

### Gowin Compatibility Notes

The original ZPUINO/Xilinx code needs these adaptations for Gowin:

1. **VHDL Compatibility**: Gowin IDE supports VHDL synthesis
2. **RAM Inference**: Replace Xilinx-specific RAM primitives with generic inference
3. **Clock Management**: Use Gowin rPLL instead of DCM
4. **Wishbone Interface**: Adapt to match ESP32-S3 SPI bridge timing
5. **I/O Standards**: Update pin constraints for Tang Primer 20K

## Integration Steps

1. Add VHDL files to your Gowin project (.gprj)
2. Instantiate HQVGA module in your top-level design
3. Connect Wishbone bus to SPI bridge
4. Add VGA pin constraints to pins.cst
5. Include library in platformio.ini

## TODO

- [ ] Port VHDL to work with Gowin synthesis (replace UNISIM components)
- [ ] Adapt Wishbone interface timing for ESP32-S3 SPI bridge
- [ ] Create C++ wrapper compatible with ESP32-S3 (non-ZPU)
- [ ] Add Gowin rPLL for clock generation
- [ ] Test frame buffer RAM synthesis on GW2A
- [ ] Update pin constraints for Tang Primer 20K
- [ ] Add integration example with papilio_wishbone_spi_master

## License

FreeBSD License (BSD-2-Clause)

Original work Copyright 2011 Alvaro Lopes
Modifications Copyright 2025 Gadget Factory

## References

- Original ZPUINO VGA: https://github.com/alvieboy/zpuino
- Gowin FPGA documentation
- VGA timing specifications: 800x600@72Hz
