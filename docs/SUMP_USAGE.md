# SUMP Logic Analyzer Usage Guide

## Overview

The Papilio Arcade board now includes a built-in SUMP2 logic analyzer connected directly to the ESP32's UART. This allows you to debug the Wishbone bus and other FPGA signals without needing a separate USB-UART adapter.

## Hardware Architecture

```
┌─────────────┐
│   Computer  │
│   USB Port  │
└──────┬──────┘
       │ USB
       ↓
┌──────────────────┐
│  ESP32-S3        │
│  Serial1 UART    │
└─────┬────────────┘
      │ GPIO 17 (RX) ← FPGA C9 (TX)
      │ GPIO 18 (TX) → FPGA E14 (RX)
      ↓
┌─────────────────────┐
│  FPGA SUMP2         │
│  Logic Analyzer     │
│  32-bit @ 27 MHz    │
└─────────────────────┘
```

## Quick Start

### 1. Enable SUMP Passthrough Mode

Open Arduino Serial Monitor (or any terminal) at **115200 baud** on your Papilio's COM port.

Send command:
```
S 1
```

Expected response:
```
[MCP] SUMP passthrough ENABLED - connect OLS/sigrok to this serial port
[MCP] To exit SUMP mode, reset ESP32 or send Ctrl+C (0x03)
```

**Important:** Close the Serial Monitor before connecting OLS/PulseView (only one application can use the serial port at a time).

### 2. Connect with OLS (Open Logic Sniffer)

**Download:** https://lxtreme.nl/projects/ols/

**Setup:**
1. Launch OLS
2. Click **Capture → Begin Capture**
3. Port Settings:
   - **Speed:** 115200
   - **Port:** Your Papilio COM port (e.g., COM4)
4. Device Settings:
   - **Device Type:** Demon Core (or any SUMP compatible)
   - **Sampling Rate:** 27 MHz
   - **Sample Count:** 2048
   - **Channel Groups:** Enable all 4 groups (32 channels)
5. **Trigger** tab:
   - Set trigger conditions, or
   - Disable triggers for immediate capture
6. Click **Capture**

### 3. Connect with PulseView (sigrok)

**Download:** https://sigrok.org/wiki/Downloads

**Setup:**
1. Launch PulseView
2. Click device dropdown → **Connect to Device**
3. Select driver: **Openbench Logic Sniffer & SUMP compatibles (ols)**
4. Scan for device on your COM port
5. Configure:
   - **Sample rate:** 27 MHz
   - **Channels:** Enable 0-31 (all 32 channels)
   - **Sample count:** 2048
6. Click **Run** to capture

### 4. Exit SUMP Mode

To return to normal MCP command mode:
- **Option 1:** Press the ESP32 reset button
- **Option 2:** Close OLS/PulseView, reconnect Serial Monitor, send Ctrl+C (0x03)

## Signal Mapping

The 32-bit capture is mapped to Wishbone debug signals (see `top.v`):

| Bits   | Signal          | Description                |
|--------|-----------------|----------------------------|
| [31:24]| `debug_cmd`     | SPI command byte           |
| [23:16]| `wb_adr_o[7:0]` | Wishbone address (low byte)|
| [15:8] | `wb_dat_o[7:0]` | Wishbone data              |
| [7:0]  | Status flags    | Various debug flags        |

You can modify the `sump_events` assignment in `top.v` to capture different signals.

## Troubleshooting

### OLS can't connect
- Verify COM port is correct
- Ensure Serial Monitor is closed
- Try resetting ESP32
- Check that SUMP mode is enabled (send `S 1` first)

### No data captured
- Check trigger settings (try disabling triggers first)
- Verify FPGA bitstream is loaded (`make flash-fpga`)
- Generate activity on Wishbone bus (send MCP commands like `R 0000`)

### Serial Monitor doesn't work after OLS
- OLS/PulseView may leave the port in a bad state
- Reset ESP32 to restore normal operation
- Alternatively, close and reopen Serial Monitor

## Advanced Usage

### Capture Wishbone Transactions

1. Enable SUMP passthrough: `S 1`
2. Set OLS trigger on bits [23:16] (Wishbone address)
3. In another terminal, send MCP Wishbone commands to generate activity:
   ```
   R 0000    # Read from address 0x0000
   W 0001 FF # Write 0xFF to 0x0001
   ```
4. OLS will capture the bus activity

### Custom Signal Mapping

Edit `src/gateware/top.v`:

```verilog
assign sump_events = {
    your_signal_1[7:0],   // Bits 31-24
    your_signal_2[7:0],   // Bits 23-16
    your_signal_3[7:0],   // Bits 15-8
    your_signal_4[7:0]    // Bits 7-0
};
```

Rebuild FPGA: `make flash-fpga`

### Increase Sample Depth

Edit `libs/sump2_logic_analyzer/gateware/sump2_simple.v`:

```verilog
sump2_simple #(
    .DEPTH_LEN(4096),  // Increase from 2048
    .DEPTH_BITS(12),   // Update from 11
    .EVENT_BYTES(4),
    .FREQ_MHZ(16'd27)
) sump_inst (
    // ...
);
```

Rebuild FPGA: `make flash-fpga`

## MCP Command Reference

All commands are sent via Serial Monitor at 115200 baud:

| Command | Description                     |
|---------|---------------------------------|
| `S 1`   | Enable SUMP passthrough         |
| `S 0`   | Disable SUMP passthrough        |
| `H`     | Help (show all MCP commands)    |
| `R AAAA`| Read Wishbone address (test)    |
| `W AAAA DD` | Write to Wishbone (test)    |

## References

- **SUMP Protocol:** https://www.sump.org/projects/analyzer/protocol/
- **OLS Software:** https://lxtreme.nl/projects/ols/
- **sigrok/PulseView:** https://sigrok.org/
- **Original SUMP2:** https://github.com/blackmesalabs/sump2

## Notes

- The SUMP UART runs at **115200 baud** (not the 27 MHz capture rate)
- Maximum capture depth: **2048 samples** (configurable)
- Capture width: **32 bits** (4 bytes per sample)
- Sample rate: **27 MHz** (same as FPGA clock)
- Trigger support: 32-bit mask with AND/OR and rising/falling edge
