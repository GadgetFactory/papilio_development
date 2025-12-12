# Logic Analyzer Integration

## Overview

A lightweight SUMP-compatible logic analyzer has been integrated into the Papilio Arcade FPGA design. This allows you to capture and debug 32 internal FPGA signals in real-time through the existing MCP server interface.

## Features

- **32 Channels**: Captures 32 internal FPGA signals simultaneously
- **1024 Samples**: Memory depth of 1024 samples per channel
- **Configurable Triggers**: Set trigger masks and values for conditional capture
- **Variable Sample Rate**: Adjustable clock divider (27MHz down to ~100kHz)
- **MCP Integration**: Access through your existing SPI/Wishbone MCP server
- **VCD Export**: Export captures to VCD format for viewing in GTKWave
- **SUMP Compatible**: Can work with PulseView/Sigrok clients (future enhancement)

## Hardware Resources

- **Memory**: ~1 Block RAM (32 bits × 1024 samples)
- **Logic**: ~200-300 LUTs
- **Address Space**: 0x8300-0x83FF (256 bytes)

## Monitored Signals

The logic analyzer currently monitors these 32 signals:

| Channels | Signal Group | Description |
|----------|--------------|-------------|
| 0-7      | Wishbone Bus | `wb_cyc`, `wb_stb`, `wb_we`, `wb_ack`, `wb_adr[15:12]` |
| 8-11     | SPI Interface | `esp_cs_n`, `esp_clk`, `esp_mosi`, `esp_miso` |
| 12-15    | Video/System | `pix_clk`, `hdmi_rst_n`, `video_mode[1:0]` |
| 16-31    | Peripherals | `sid_sel`, `ym2149_sel`, `la_sel`, `rgb_led_sel`, `fb_sel`, `text_sel`, etc. |

You can easily modify `top.v` to monitor different signals by changing the `la_probe_signals` wire definition.

## Register Map

Base address: **0x8300**

| Address | Register | R/W | Description |
|---------|----------|-----|-------------|
| 0x8300  | CMD/STATUS | R/W | Command register (W) / State register (R) |
| 0x8302  | ID_0 | R | Device ID byte 0 ('S') |
| 0x8303  | ID_1 | R | Device ID byte 1 ('U') |
| 0x8304-07 | TRIGGER_MASK | W | 32-bit trigger mask (LSB first) |
| 0x8308-0B | TRIGGER_VALUE | W | 32-bit trigger value (LSB first) |
| 0x830C-0D | DELAY_COUNT | W | Post-trigger sample count (16-bit) |
| 0x8310-11 | READ_COUNT | W | Total sample count (16-bit) |
| 0x8314  | DIVIDER | W | Sample rate clock divider |
| 0x8318  | FLAGS | W | Configuration flags |
| 0x8380-FF | DATA | R | Captured sample data |

## Commands

Write to register 0x8300:

- **0x00**: RESET - Reset to idle state
- **0x01**: ARM - Arm and wait for trigger
- **0x02**: ID - Query device ID
- **0x11**: XON - Flow control on
- **0x13**: XOFF - Flow control off

## States

Read from register 0x8300 (bits 2:0):

- **0**: IDLE - Ready to arm
- **1**: ARMED - Waiting for trigger
- **2**: TRIGGERED - Trigger detected
- **3**: CAPTURING - Actively capturing samples
- **4**: DONE - Capture complete, data ready

## Python API Usage

### Basic Capture

```python
from logic_analyzer_tool import LogicAnalyzer

# Create logic analyzer (requires SPI bridge object)
la = LogicAnalyzer(spi_bridge)

# Simple immediate capture (no trigger)
samples = la.capture(
    trigger_mask=0x00000000,    # 0 = immediate trigger
    trigger_value=0x00000000,
    total_samples=1024,          # Capture 1024 samples
    post_trigger=512,            # 512 after trigger
    sample_rate_div=0            # Full speed (27MHz)
)

# Print results
la.print_samples(samples, max_lines=50)

# Export to VCD for GTKWave
la.export_vcd(samples, "capture.vcd", channel_names)
```

### Triggered Capture

```python
# Wait for Wishbone cycle to start (wb_cyc goes high)
samples = la.capture(
    trigger_mask=0x00000080,     # Check bit 7 (wb_cyc)
    trigger_value=0x00000080,    # Trigger when it's 1
    total_samples=512,
    post_trigger=256,            # Capture 256 samples after trigger
    sample_rate_div=1            # 13.5MHz sample rate
)
```

### Manual Control

```python
# Fine-grained control
la.reset()
la.configure_trigger(mask=0x00000080, value=0x00000080)
la.configure_capture(total_samples=1024, post_trigger_samples=512, sample_rate_div=0)
la.arm()

# Wait for capture
if la.wait_for_done(timeout=5.0):
    samples = la.read_samples(1024)
    # Process samples...
```

## MCP Server Integration

The logic analyzer provides three MCP tools:

### 1. logic_analyzer_status

Get current status of the logic analyzer.

```json
{
  "name": "logic_analyzer_status"
}
```

Returns:
```json
{
  "state": 0,
  "state_name": "IDLE",
  "channels": 32,
  "depth": 1024
}
```

### 2. logic_analyzer_capture

Perform a capture with optional trigger.

```json
{
  "name": "logic_analyzer_capture",
  "arguments": {
    "trigger_mask": 0,
    "trigger_value": 0,
    "num_samples": 1024,
    "post_trigger": 512,
    "sample_rate_div": 0,
    "export_vcd": true,
    "filename": "capture.vcd"
  }
}
```

### 3. logic_analyzer_reset

Reset the logic analyzer to idle state.

```json
{
  "name": "logic_analyzer_reset"
}
```

## Sample Rate Configuration

The `sample_rate_div` parameter divides the 27MHz system clock:

| Divider | Sample Rate | Time/Sample | Memory Duration |
|---------|-------------|-------------|-----------------|
| 0       | 27 MHz      | 37 ns       | 37.9 µs |
| 1       | 13.5 MHz    | 74 ns       | 75.8 µs |
| 2       | 9 MHz       | 111 ns      | 113.7 µs |
| 10      | 2.45 MHz    | 408 ns      | 417.9 µs |
| 26      | 1 MHz       | 1 µs        | 1.02 ms |
| 99      | 270 kHz     | 3.7 µs      | 3.79 ms |
| 255     | 105.7 kHz   | 9.5 µs      | 9.73 ms |

## Viewing Captures

### GTKWave

1. Export capture to VCD:
   ```python
   la.export_vcd(samples, "capture.vcd", CHANNEL_NAMES)
   ```

2. Open in GTKWave:
   ```bash
   gtkwave capture.vcd
   ```

### PulseView/Sigrok (Future)

The hardware is SUMP-compatible. Future integration with PulseView would require:
1. UART interface addition (or USB bridge)
2. SUMP protocol handler in firmware
3. Sigrok device driver configuration

## Example: Debug SPI Communication

```python
# Capture SPI transaction
samples = la.capture(
    trigger_mask=0x00000800,      # Monitor esp_cs_n (bit 11)
    trigger_value=0x00000000,     # Trigger when CS goes low
    total_samples=1024,
    post_trigger=900,             # Capture mostly after trigger
    sample_rate_div=1             # 13.5MHz for SPI at ~2MHz
)

# Export for analysis
la.export_vcd(samples, "spi_debug.vcd", CHANNEL_NAMES)
```

## Customizing Monitored Signals

Edit `top.v` to change which signals are monitored:

```verilog
// In top.v, modify this wire definition:
wire [31:0] la_probe_signals = {
    // Add your signals here (MSB to LSB)
    your_custom_signal_31,
    your_custom_signal_30,
    // ... more signals ...
    your_custom_signal_1,
    your_custom_signal_0
};
```

Then update `CHANNEL_NAMES` in `logic_analyzer_tool.py` to match.

## Testing

Run the test script to verify functionality:

```bash
cd libs/papilio_mcp_server
python test_logic_analyzer.py
```

This runs with a mock SPI bridge for testing without hardware.

## Troubleshooting

### Capture Never Completes

- Check trigger conditions (use mask=0 for immediate trigger)
- Verify signals are actually changing
- Increase timeout value

### All Samples are Zero

- Verify clock is running
- Check that probed signals are connected
- Confirm logic analyzer is not in reset

### Memory Depth Issues

- Adjust `MEM_DEPTH` parameter in `wb_logic_analyzer.v`
- Reduce number of channels if needed
- Use sample rate divider to extend time coverage

## Future Enhancements

- [ ] RLE compression for longer captures
- [ ] Multiple trigger stages (sequential triggering)
- [ ] Edge detection triggers (rising/falling)
- [ ] Circular buffer mode
- [ ] UART interface for direct SUMP protocol support
- [ ] PulseView/Sigrok integration
- [ ] Real-time streaming mode

## References

- [SUMP Protocol Documentation](https://www.sump.org/projects/analyzer/protocol/)
- [Sigrok/PulseView](https://sigrok.org/)
- [GTKWave](http://gtkwave.sourceforge.net/)
- [Original SUMP Logic Analyzer](https://github.com/blackmesalabs/sump3)
