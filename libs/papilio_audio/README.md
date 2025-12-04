# Papilio Audio Library

Retro sound chip emulation for the Papilio Arcade FPGA board.

## Supported Sound Chips

### SID 6581 (Commodore 64)
The legendary SID chip from the Commodore 64, featuring:
- 3 independent voices
- ADSR envelope generator per voice
- Multiple waveforms (triangle, sawtooth, pulse, noise)
- Ring modulation and sync
- Multi-mode filter (low-pass, band-pass, high-pass)

### YM2149 (AY-3-8910 compatible)
Popular sound chip used in Atari ST, ZX Spectrum 128, and many arcade games:
- 3 square wave tone generators
- 1 noise generator
- Volume envelope generator
- Mixer control

### POKEY (Atari 8-bit)
The POKEY chip from Atari computers and arcade games:
- 4 audio channels
- Flexible frequency divider options
- Noise generator with multiple polynomials
- High-pass filter

## Quick Start

```cpp
#include <SPI.h>
#include <WishboneSPIMaster.h>
#include <PapilioAudio.h>

WishboneSPIMaster fpgaSPI(SPI, SS);
SID6581 sid(fpgaSPI, WB_AUDIO_SID_BASE);

void setup() {
    SPI.begin();
    fpgaSPI.begin();
    
    sid.begin();
    sid.setVolume(15);
    
    // Configure voice 1
    sid.V1.setTriangle(true);
    sid.V1.setEnvelopeAttack(0);
    sid.V1.setEnvelopeDecay(0);
    sid.V1.setEnvelopeSustain(15);
    sid.V1.setEnvelopeRelease(0);
    
    // Play a note
    sid.V1.setNote(60, true);  // Middle C
}

void loop() {
    // Your audio code here
}
```

## Wishbone Address Map

| Sound Chip | Base Address | Size |
|------------|--------------|------|
| SID 6581   | 0x30         | 32 bytes |
| YM2149     | 0x50         | 16 bytes |
| POKEY      | 0x60         | 16 bytes |
| Audio Mixer| 0x70         | 16 bytes |

## API Reference

### SID6581 Class

#### Voice Methods (V1, V2, V3)
- `setNote(note, active)` - Set MIDI note and gate
- `setFreq(freq)` - Set frequency directly
- `setTriangle(active)` - Enable triangle waveform
- `setSawtooth(active)` - Enable sawtooth waveform
- `setSquare(active, pwm)` - Enable square wave with PWM
- `setNoise(active)` - Enable noise
- `setEnvelopeAttack(rate)` - Set attack rate (0-15)
- `setEnvelopeDecay(rate)` - Set decay rate (0-15)
- `setEnvelopeSustain(level)` - Set sustain level (0-15)
- `setEnvelopeRelease(rate)` - Set release rate (0-15)
- `setGate(active)` - Control note gate
- `reset()` - Reset voice to defaults

#### Global Methods
- `setVolume(volume)` - Set master volume (0-15)
- `reset()` - Reset all voices

### YM2149 Class

#### Voice Methods (V1, V2, V3)
- `setNote(note, active)` - Set MIDI note
- `setFreq(freq)` - Set frequency directly
- `setVolume(volume)` - Set voice volume (0-15)
- `setTone(active)` - Enable tone output
- `setNoise(active)` - Enable noise output
- `setEnvelope(active)` - Use envelope for volume
- `reset()` - Reset voice to defaults

#### Global Methods
- `setNoiseFrequency(freq)` - Set noise generator frequency
- `setEnvelopeFrequency(freq)` - Set envelope frequency
- `setEnvelopeShape(cont, att, alt, hold)` - Set envelope shape
- `reset()` - Reset all voices

### POKEY Class

#### Channel Methods (CH1, CH2, CH3, CH4)
- `setFrequency(freq)` - Set audio frequency
- `setVolume(volume)` - Set channel volume (0-15)
- `setDistortion(dist)` - Set distortion type (0-7)
- `reset()` - Reset channel to defaults

#### Global Methods
- `setAUDCTL(value)` - Set audio control register
- `reset()` - Reset all channels

## Gateware Integration

This library requires the corresponding VHDL audio cores to be integrated into the FPGA gateware. See the `gateware/` directory for the required modules:

- `audio_wb_sid6581.v` - SID Wishbone wrapper
- `audio_wb_ym2149.v` - YM2149 Wishbone wrapper
- `audio_wb_pokey.v` - POKEY Wishbone wrapper
- `audio_mixer.v` - Audio mixer for combining outputs
- `audio_sigmadelta_dac.v` - Sigma-delta DAC for analog output

## License

This library is released under the GPL-3.0 license.

Original sound chip implementations are based on work from:
- SID: Alvaro Lopes (alvieboy@alvie.com)
- YM2149: MikeJ (fpgaarcade.com)
- POKEY: MikeJ (fpgaarcade.com)
