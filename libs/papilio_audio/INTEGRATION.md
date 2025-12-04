# Papilio Audio Library Integration Guide

This document describes how to integrate the papilio_audio library into your Papilio Arcade project.

## Overview

The papilio_audio library provides Arduino-compatible APIs for controlling classic retro sound chips:
- **SID 6581** - Commodore 64 sound chip
- **YM2149** - AY-3-8910 compatible PSG (Atari ST, ZX Spectrum 128)
- **POKEY** - Atari 8-bit and arcade sound chip

## Status

**Firmware:** ✅ Complete - Arduino API ready to use  
**Gateware:** ⚠️ Adaptation Required - The included VHDL files use ZPUino-style packed vector Wishbone interface. They need to be adapted to the Papilio Arcade's simple 8-bit SPI-Wishbone interface.

## Wishbone Address Map

| Component | Base Address | Size | Description |
|-----------|--------------|------|-------------|
| SID 6581  | 0x30         | 32 bytes | Commodore 64 SID chip |
| YM2149    | 0x50         | 16 bytes | AY-3-8910 PSG |
| POKEY     | 0x60         | 16 bytes | Atari POKEY |
| Audio Mixer | 0x70       | 16 bytes | Mixer control |

## Firmware Integration

### 1. Add to platformio.ini

```ini
lib_deps = 
    libs/papilio_wishbone_spi_master
    libs/papilio_audio
```

### 2. Include in your sketch

```cpp
#include <SPI.h>
#include <PapilioAudio.h>

// SPI pins for ESP32-S3
#define SPI_SCK   12
#define SPI_MISO  13
#define SPI_MOSI  11
#define SPI_CS    10

// Create sound chip instances with Wishbone base addresses
SID6581 sid(WB_AUDIO_SID_BASE);
YM2149 ym(WB_AUDIO_YM2149_BASE);
POKEY pokey(WB_AUDIO_POKEY_BASE);
AudioMixer mixer(WB_AUDIO_MIXER_BASE);

void setup() {
    SPI.begin(SPI_SCK, SPI_MISO, SPI_MOSI, SPI_CS);
    
    // Initialize Wishbone SPI interface
    wishboneInit(&SPI, SPI_CS);
    
    // Initialize the chip(s) you want to use
    sid.begin();
    ym.begin();
    pokey.begin();
    mixer.begin();
}
```

## Gateware Integration

### Status: Adaptation Required

The included VHDL files are from the original ZPUino DesignLab and use a packed 62-bit/34-bit vector interface for Wishbone signals. The Papilio Arcade uses a simpler 8-bit Wishbone interface with discrete signals.

**To use these audio cores, you need to:**

1. Create Wishbone wrapper modules that convert from the simple 8-bit interface to the ZPUino-style packed vectors
2. Or rewrite the wrappers to use discrete Wishbone signals directly

### Required VHDL Files

**For SID:**
- `AUDIO_zpuino_wb_sid6581.vhd` - Wishbone wrapper (needs adaptation)
- `sid_6581.vhd` - Main SID core
- `sid_voice.vhd` - Voice module  
- `sid_filters.vhd` - Filter implementation
- `sid_coeffs.vhd` - Filter coefficients
- `sid_components.vhd` - Common components

**For YM2149:**
- `AUDIO_zpuino_wb_YM2149.vhd` - Complete YM2149 with Wishbone (needs adaptation)

**For POKEY:**
- `AUDIO_zpuino_wb_pokey.vhd` - Complete POKEY with Wishbone (needs adaptation)

**For audio output:**
- `AUDIO_zpuino_sa_audiomixer.vhd` - Audio mixer
- `AUDIO_zpuino_sa_sigmadeltaDAC.vhd` - Sigma-delta DAC

### 2. ZPUino Wishbone Interface

The ZPUino-style Wishbone uses packed vectors:
- `wishbone_in[61:0]` - Contains clock, reset, data, address, control signals
- `wishbone_out[33:0]` - Contains data output, ack, interrupt

To adapt for Papilio Arcade's simple interface, you'll need a wrapper like:

```verilog
// Example wrapper for SID (concept - not tested)
module sid_wrapper (
    input wire clk,
    input wire rst,
    // Simple Wishbone
    input wire [7:0] wb_adr_i,
    input wire [7:0] wb_dat_i,
    output wire [7:0] wb_dat_o,
    input wire wb_cyc_i,
    input wire wb_stb_i,
    input wire wb_we_i,
    output wire wb_ack_o,
    // Audio
    input wire clk_1mhz,
    output wire [17:0] audio_data
);
    // Pack signals for ZPUino-style interface
    wire [61:0] wishbone_in;
    wire [33:0] wishbone_out;
    
    assign wishbone_in = {clk, rst, wb_dat_i, 24'b0, wb_adr_i[4:0], wb_we_i, wb_cyc_i, wb_stb_i};
    assign wb_dat_o = wishbone_out[33:26];
    assign wb_ack_o = wishbone_out[25];
    
    AUDIO_zpuino_wb_sid6581 u_sid (
        .wishbone_in(wishbone_in),
        .wishbone_out(wishbone_out),
        .clk_1MHZ(clk_1mhz),
        .audio_data(audio_data)
    );
endmodule
```

### 3. Add pin constraints

Add audio output pin to your pins.cst:

```
IO_LOC "audio_out" XX;
IO_PORT "audio_out" IO_TYPE=LVCMOS33 PULL_MODE=NONE DRIVE=8;
```

Replace XX with the appropriate pin number for audio output.

## Clock Requirements

Each sound chip has specific clock requirements:

| Chip | Clock | Notes |
|------|-------|-------|
| SID 6581 | 1 MHz | PAL: 985248 Hz, NTSC: 1022727 Hz |
| YM2149 | 2 MHz | Derived from system clock |
| POKEY | 1.79 MHz | NTSC timing |

Generate these clocks using PLLs or clock dividers in your FPGA design.

## Audio Output

The audio mixer combines all chip outputs into a single sigma-delta modulated signal. Connect this to an RC low-pass filter (e.g., 10kΩ + 100nF) to convert to analog audio.

## Future Work

- [ ] Create native Verilog wrappers with simple Wishbone interface
- [ ] Add audio output pin support to Papilio Arcade board
- [ ] Test with actual hardware

## Example Projects

See the `examples/` directory for complete working examples:
- `sid_demo/` - SID chip demonstration
- `ym2149_demo/` - YM2149 PSG demonstration
- `pokey_demo/` - POKEY demonstration
- `pokey_demo/` - POKEY chip demonstration

## Troubleshooting

1. **No sound**: Check that audio peripheral is properly addressed in Wishbone decoder
2. **Distorted sound**: Verify clock frequencies are correct
3. **Wrong notes**: Ensure correct MIDI-to-frequency conversion is being used
4. **Clipping**: Reduce individual chip volumes before mixing

## License

This library and the included VHDL cores are released under GPL-3.0.

Original implementations:
- SID: Alvaro Lopes (alvieboy@alvie.com)
- YM2149: MikeJ (fpgaarcade.com)  
- POKEY: MikeJ (fpgaarcade.com)
