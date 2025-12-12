# Logic Analyzer Quick Reference

## Hardware Integration

**Address Range**: `0x8300 - 0x83FF`  
**Memory**: ~1 BRAM (32 channels × 1024 samples)  
**Signals**: 32 channels of FPGA internals

## Quick Capture (Python)

```python
from logic_analyzer_tool import LogicAnalyzer

la = LogicAnalyzer(spi_bridge)

# Immediate capture (no trigger)
samples = la.capture()

# Triggered capture
samples = la.capture(
    trigger_mask=0x00000080,    # Check bit 7
    trigger_value=0x00000080,   # Wait for high
    total_samples=1024,
    post_trigger=512
)

# Export to GTKWave
la.export_vcd(samples, "debug.vcd", CHANNEL_NAMES)
```

## MCP Tools

### Status Check
```json
{"name": "logic_analyzer_status"}
```

### Capture Data
```json
{
  "name": "logic_analyzer_capture",
  "arguments": {
    "trigger_mask": 0,
    "num_samples": 1024,
    "export_vcd": true,
    "filename": "capture.vcd"
  }
}
```

### Reset
```json
{"name": "logic_analyzer_reset"}
```

## Channel Map (0-31)

| Bit | Signal | Description |
|-----|--------|-------------|
| 0-3 | wb_adr[15:12] | Wishbone address (upper bits) |
| 4   | wb_ack | Wishbone acknowledge |
| 5   | wb_we | Wishbone write enable |
| 6   | wb_stb | Wishbone strobe |
| 7   | wb_cyc | Wishbone cycle |
| 8   | esp_miso | SPI MISO |
| 9   | esp_mosi | SPI MOSI |
| 10  | esp_clk | SPI clock |
| 11  | esp_cs_n | SPI chip select |
| 12  | pix_clk | Pixel clock |
| 13  | hdmi_rst_n | HDMI reset |
| 14-15 | video_mode | Video mode select |
| 16-23 | Peripheral selects | fb_sel, text_sel, tp_sel, etc. |
| 24-31 | System | audio_left, rgb_led, rst, clk |

## Sample Rates

| Divider | Rate | Time/Sample | Duration (1024 samples) |
|---------|------|-------------|-------------------------|
| 0 | 27 MHz | 37 ns | 37.9 µs |
| 1 | 13.5 MHz | 74 ns | 75.8 µs |
| 10 | 2.45 MHz | 408 ns | 418 µs |
| 26 | 1 MHz | 1 µs | 1.02 ms |
| 99 | 270 kHz | 3.7 µs | 3.79 ms |

## Common Use Cases

### Debug SPI Transaction
```python
samples = la.capture(
    trigger_mask=0x00000800,     # esp_cs_n (bit 11)
    trigger_value=0x00000000,    # Wait for CS low
    sample_rate_div=1            # 13.5MHz
)
```

### Debug Wishbone Bus
```python
samples = la.capture(
    trigger_mask=0x00000080,     # wb_cyc (bit 7)
    trigger_value=0x00000080,    # Wait for cycle start
    sample_rate_div=0            # Full speed
)
```

### Continuous Monitor
```python
samples = la.capture(
    trigger_mask=0,              # Immediate
    sample_rate_div=100          # ~270kHz for longer duration
)
```

## Viewing Results

### In Python
```python
la.print_samples(samples, max_lines=50)
```

### GTKWave
```bash
gtkwave capture.vcd
```

### PulseView (Future)
- Hardware is SUMP-compatible
- Requires UART bridge or USB interface

## Troubleshooting

**Capture never completes?**
- Use `trigger_mask=0` for immediate capture
- Verify trigger condition can be met
- Increase timeout

**All zeros?**
- Check clock is running
- Verify signals are connected
- Confirm not in reset state

**Need different signals?**
- Edit `la_probe_signals` in `top.v`
- Update `CHANNEL_NAMES` in Python

## Files

- **Verilog**: `src/gateware/wb_logic_analyzer.v`
- **Python API**: `libs/papilio_mcp_server/logic_analyzer_tool.py`
- **Integration**: `libs/papilio_mcp_server/mcp_server_example.py`
- **Test**: `libs/papilio_mcp_server/test_logic_analyzer.py`
- **Docs**: `docs/LOGIC_ANALYZER.md`
