# HQVGA Gowin Porting Notes

## Overview
This document tracks the conversion from Xilinx ZPUINO VHDL to Gowin-compatible Verilog for the HQVGA library on the Papilio Arcade Board.

## Current Status (Nov 28, 2025)

### ✅ COMPLETED
1. **720p HDMI Output Working** - Using Gowin's DVI_TX_Top IP core
2. **160x120 Framebuffer** - `video_top_framebuffer.v` stores pixels in FPGA BRAM
3. **6x Scaling** - HQVGA 160x120 scaled to 960x720 within 1280x720 output
4. **ESP32-S3 SPI Communication** - Wishbone-over-SPI protocol working
5. **HQVGA C++ Library** - Ported to ESP32-S3 with pixel/text rendering
6. **8x8 Font** - Basic ASCII font (32-127) added to HQVGA.cpp

### ⚠️ KNOWN ISSUES
1. **Display Scrambled** - Pixel data appears scrambled/shifted on screen
   - Colors and shapes are visible but not aligned correctly
   - Likely address mapping or timing issue between framebuffer write and read
2. **Text Size** - Characters appear but scaling may need adjustment

## Architecture

### Video Pipeline
```
ESP32-S3 (SPI) → wb_spi_slave.v → video_top_framebuffer.v → DVI_TX_Top → HDMI
                                        ↓
                                 160x120 BRAM
                                   (RGB332)
                                        ↓
                                 6x Scaling Logic
                                        ↓
                                 720p RGB888 Output
```

### Key Files

**Gateware:**
- `libs/papilio_hdmi/gateware/src/video_top_framebuffer.v` - Main framebuffer module
- `libs/papilio_hdmi/gateware/src/wb_spi_slave.v` - SPI to Wishbone bridge
- `src/gateware/top.v` - Top-level integration
- `src/gateware/pins.cst` - Pin constraints

**Firmware:**
- `libs/papilio_hqvga/src/HQVGA.cpp` - ESP32 HQVGA library with font
- `libs/papilio_hqvga/src/HQVGA.h` - Header file
- `src/papliio_arcade_template.ino` - Example sketch

### Timing Configuration
- **HDMI Output:** 720p (1280x720 @ 60Hz)
- **Pixel Clock:** 74.25 MHz (from TMDS_rPLL 371.25 MHz ÷ 5)
- **Framebuffer:** 160x120 pixels, 8-bit RGB332
- **Scaling:** 6x (160×6=960 centered in 1280, 120×6=720)

### Address Mapping Fix Applied
The HQVGA library uses word-aligned addressing (addr << 2) matching ZPUino convention.
The framebuffer divides incoming address by 4:
```verilog
wire [14:0] wb_pixel_addr = I_wb_adr[14:2];  // Divide address by 4
```

## Next Steps

### Priority 1: Fix Scrambled Display
1. **Debug address mapping** - Verify pixel addresses match between write and read
2. **Check timing** - Ensure write completes before read occurs
3. **Verify scaling math** - The multiply-by-reciprocal (×171 >>10) may have edge cases
4. **Test direct pattern** - Write known test pattern and verify output

### Priority 2: Improve Performance
1. **Burst transfers** - Add multi-byte SPI transfers for faster fills
2. **DMA support** - Consider ESP32 DMA for large transfers

### Priority 3: Feature Completion
1. **VGALiquidCrystal** - Port virtual LCD display (needs getBasePointer alternative)
2. **Sprite support** - Add hardware sprite layer
3. **Double buffering** - Prevent tearing during updates

## Debugging the Scrambled Display

### Possible Causes
1. **Read/Write Address Mismatch**
   - Write uses I_wb_adr[14:2] for pixel address
   - Read uses pixel counter (h_count, v_count) scaled by 171/1024
   - These should map to same locations but may be off by 1 or more

2. **Timing Issue**
   - Framebuffer is single-port-like (one read + one write port)
   - If read and write try same address simultaneously, could corrupt

3. **Scaling Edge Cases**
   - Division by 6 using (x × 171) >> 10 is approximate (170.67 actual)
   - May cause pixel skipping or duplication at boundaries

4. **Horizontal Centering**
   - Black bars should be 160 pixels on each side: (1280-960)/2 = 160
   - If offset is wrong, image shifts left/right

### Debug Steps
1. Write solid colors to entire framebuffer - verify no corruption
2. Write horizontal gradient (x value) - check for horizontal scrambling
3. Write vertical gradient (y value) - check for vertical scrambling
4. Write checkerboard pattern - verify address alignment
5. Compare single pixel write/read - verify address mapping

## Files Modified This Session

1. `libs/papilio_hdmi/gateware/src/video_top_framebuffer.v` - Created new framebuffer module
2. `libs/papilio_hqvga/src/HQVGA.cpp` - Added 8x8 font, fixed printchar
3. `libs/papilio_hqvga/src/HQVGA.h` - Header updates
4. `src/gateware/top.v` - Integrated video_top_framebuffer
5. `src/gateware/papilio_arcade_template.gprj` - Added source files
6. `src/papliio_arcade_template.ino` - Color Bar example

## Reference

### RGB332 Color Format
```
Bit:  7  6  5  4  3  2  1  0
      R  R  R  G  G  G  B  B
```

### Predefined Colors
- RED: 0xE0 (111_000_00)
- GREEN: 0x1C (000_111_00)  
- BLUE: 0x03 (000_000_11)
- YELLOW: 0xFC (111_111_00)
- PURPLE: 0xE3 (111_000_11)
- CYAN: 0x1F (000_111_11)
- WHITE: 0xFF (111_111_11)
- BLACK: 0x00 (000_000_00)
