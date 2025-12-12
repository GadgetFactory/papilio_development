# SUMP2 Logic Analyzer for Gowin FPGA

A simplified SUMP2 logic analyzer adapted for the Papilio Arcade board with Gowin GW2A-18C FPGA.

## Features

- **32-bit capture width** - Monitor 32 signals simultaneously
- **2048 samples** - Configurable depth (can be increased to 4096+ if resources allow)
- **27 MHz sampling rate** - Fast enough for most digital debug
- **UART interface** at 115200 baud - Compatible with OLS (Open Logic Sniffer) software
- **Trigger modes**:
  - AND rising edge
  - AND falling edge  
  - OR rising edge
  - OR falling edge
- **Pre/post trigger capture** - See what happened before and after trigger event

## Source

Based on the excellent **blackmesalabs/sump2** project:
- Repository: https://github.com/blackmesalabs/sump2
- Author: Kevin M. Hubbard (Black Mesa Labs)
- License: CERN Open Hardware Licence v1.2

## Integration

The logic analyzer is integrated into `top.v` and captures key debug signals:

### Captured Signals (32-bit)
- **[31:24]** - SPI command byte from ESP32
- **[23:16]** - Wishbone address bus (lower 8 bits)
- **[15:8]**  - Wishbone data bus
- **[7:0]**   - Status flags:
  - FIFO full/empty
  - DMA start
  - DMA write flag
  - Wishbone state machine (3 bits)
  - Wishbone cycle active

## Usage

### Method 1: Using Papilio MCP Passthrough (Recommended)

The SUMP logic analyzer UART is connected to the ESP32, allowing access through USB without additional hardware.

**1. Enable SUMP Passthrough Mode**

Open Arduino Serial Monitor (115200 baud) and send:
```
S 1
```

Response:
```
[MCP] SUMP passthrough ENABLED - connect OLS/sigrok to this serial port
```

**2. Use with OLS**

1. Download OLS from: https://lxtreme.nl/projects/ols/
2. In OLS: **Capture → Begin Capture**
3. Port Settings:
   - Speed: **115200 baud**
   - Port: Same COM port as Arduino (e.g., COM4)
4. Device Settings:
   - Device Type: **Demon Core (SUMP compatible)**
   - Sampling Rate: **27 MHz**
   - Channel Groups: **4** (32 bits total)
5. Set triggers or disable for immediate capture
6. Click **Capture**

**3. Use with PulseView (sigrok)**

```bash
# Install sigrok
sudo apt install sigrok-cli pulseview

# Launch PulseView
pulseview

# Select driver: "Openbench Logic Sniffer & SUMP compatibles"
# Scan for device on your COM port
# Configure: 32 channels, 27 MHz sample rate
```

**4. Return to Normal MCP Mode**

- Reset ESP32, or
- Send Ctrl+C (0x03) over serial

### Method 2: Direct UART Connection

Connect a USB-to-UART adapter to FPGA pins:
- **RX** → `sump_tx` (C9 - FPGA TX output)
- **TX** → `sump_rx` (E14 - FPGA RX input)
- **GND** → Ground

Then use OLS/PulseView as described above.

## Configuration

Edit `sump2_simple.v` parameters:

```verilog
.DEPTH_LEN(2048),    // Increase to 4096 for more samples
.DEPTH_BITS(11),     // Update to 12 for 4096 samples
.EVENT_BYTES(4),     // Keep at 4 for 32-bit capture
.FREQ_MHZ(16'd27)    // Clock frequency
```

Edit `top.v` to change captured signals:

```verilog
wire [31:0] sump_events;
assign sump_events = {
    your_signal_1,
    your_signal_2,
    // ... up to 32 bits
};
```

## Memory Usage

Current configuration uses approximately:
- **2048 x 32-bit** = 8 KB of block RAM
- Small amount of logic for UART and trigger detection

Increasing to 4096 samples doubles RAM usage to 16 KB.

## Protocol

Implements SUMP protocol for compatibility with OLS and sigrok. Basic commands:

- `0x00` - RESET
- `0x01` - ARM (start capture)
- `0x02` - ID query
- `0x81` - Set trigger mask (4 bytes follow)
- `0x82` - Set trigger values (4 bytes follow)

## Limitations

This simplified version:
- No RLE (Run-Length Encoding) compression
- No external RAM support (uses internal block RAM only)
- Basic trigger modes only (no complex patterns)
- Fixed sample rate (no divider)

For advanced features, see the full sump2 project or consider the deep_sump extension.

## Files

- `libs/sump2_logic_analyzer/gateware/sump2_simple.v` - Main logic analyzer module
- `src/gateware/top.v` - Integration and signal selection
- `src/gateware/papilio_arcade_template.gprj` - Project file (module enabled)

## Troubleshooting

**No capture in OLS:**
- Check UART connections (RX/TX may be swapped)
- Verify baud rate is 115200
- Ensure FPGA is programmed and running

**Garbled data:**
- Check ground connection
- Try different trigger settings
- Reduce capture sample count

**Out of resources:**
- Reduce `DEPTH_LEN` parameter
- Disable unused video modes in `top.v`

## References

- SUMP protocol: http://dangerousprototypes.com/docs/The_Logic_Sniffer%27s_extended_SUMP_protocol
- OLS software: https://lxtreme.nl/projects/ols/
- sigrok: https://sigrok.org/
- Original sump2: https://github.com/blackmesalabs/sump2
