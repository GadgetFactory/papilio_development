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
