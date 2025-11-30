# Papilio Arcade MCP Server

An MCP (Model Context Protocol) server that allows AI assistants like GitHub Copilot to directly control the Papilio Arcade FPGA board.

## Features

- **RGB LED Control**: Set and read RGB LED colors
- **Wishbone Bus Access**: Read/write to any Wishbone bus address
- **FPGA Status**: Get debug dumps and status information
- **Serial Port Management**: List ports and connect to the board

## Installation

1. Install Python dependencies:
   ```bash
   pip install pyserial
   ```

2. Add to your VS Code MCP settings (`.vscode/mcp.json` or user settings):
   ```json
   {
     "mcpServers": {
       "papilio": {
         "command": "python",
         "args": ["mcp_server/papilio_mcp_server.py", "--port", "COM4"]
       }
     }
   }
   ```

## Available Tools

### `set_rgb_led`
Set the RGB LED color on the FPGA board.
- `red`: Red channel (0-255)
- `green`: Green channel (0-255)  
- `blue`: Blue channel (0-255)

### `get_rgb_led`
Read the current RGB LED color values.

### `wishbone_read`
Read a byte from a Wishbone bus address.
- `address`: Address (0x0000-0xFFFF)

### `wishbone_write`
Write a byte to a Wishbone bus address.
- `address`: Address (0x0000-0xFFFF)
- `data`: Data byte (0-255)

### `send_raw_command`
Send a raw textual command directly to the board and stream back output.
Parameters:
- `command`: The command string (e.g. `H`, `D`, `F E0`).
- `timeout` (default 5): Seconds to keep reading before stopping.
- `stop_on_marker` (default true): Stop early if a line starts with or contains one of `OK`, `ERR`, `DONE`, `END`.
- `max_lines` (default 200): Maximum number of lines to return; adds a truncation notice when exceeded.
- `max_chars` (default 16000): Total character budget; output is truncated with an ellipsis beyond this.

Use smaller `timeout`, `max_lines`, and `max_chars` to prevent 413 (Request Entity Too Large) transport errors.

### `capture_screenshot`
Capture a webcam image of the HDMI monitor.
Parameters:
- `save_to_file` (default true): Persist PNG to `mcp_server/screenshots/`.
- `filename`: Optional custom file name.
- `inline_image` (default true): Include base64 image in tool response. Set to false to avoid large payloads.
- `scale_percent` (default 100): Downscale the captured image (e.g. 50 = half width/height) before encoding.
- `max_inline_bytes` (default 300000): Omit inline image if base64 length exceeds this threshold (text response only).

Recommendations to avoid 413 errors:
- Set `inline_image=false` for high‑resolution screens when image not strictly needed.
- Use `scale_percent=50` (or lower) plus a conservative `max_inline_bytes` (e.g. 150000).
- Combine `stop_on_marker=true` with modest `timeout` in `send_raw_command` for long operations.

### `get_fpga_status`
Get debug status and register dump from the FPGA.

### `list_serial_ports`
List available serial ports.

### `connect_board`
Connect to the board on a specific serial port.
- `port`: Serial port name (e.g., "COM4")

## Wishbone Address Map

| Address Range | Peripheral |
|--------------|------------|
| 0x0000-0x000F | RGB LED Controller |
| 0x0010-0x7FFF | Framebuffer (160x120 RGB332) |

## Usage Examples

Once the MCP server is configured, you can ask Copilot:
- "Set the RGB LED to red"
- "Make the LED blue"
- "Turn the LED green"
- "Read the current LED color"
- "Write 0xFF to address 0x0000"
- "Run raw command H with truncation" → `send_raw_command {"command":"H","timeout":2,"max_lines":40}`
- "Capture a small screenshot" → `capture_screenshot {"scale_percent":50,"inline_image":true,"max_inline_bytes":150000}`
- "Capture without embedding image" → `capture_screenshot {"inline_image":false}`
