#!/usr/bin/env python3
"""
Papilio Arcade MCP Server
=========================
An MCP (Model Context Protocol) server that provides tools to control
the Papilio Arcade FPGA board via serial commands.

Features:
- RGB LED control (set colors, get status)
- Wishbone bus read/write access
- Framebuffer operations
- JTAG bridge control

Usage:
    python papilio_mcp_server.py [--port COM4] [--baud 115200]
"""

import sys
import json
import asyncio
import serial
import serial.tools.list_ports
from typing import Optional
import argparse

# MCP Protocol version
MCP_VERSION = "2024-11-05"

class PapilioController:
    """Controls the Papilio Arcade board via serial commands."""
    
    def __init__(self, port: str = None, baud: int = 115200):
        self.port = port
        self.baud = baud
        self.serial: Optional[serial.Serial] = None
        
    def find_port(self) -> Optional[str]:
        """Auto-detect the Papilio board COM port."""
        ports = serial.tools.list_ports.comports()
        for p in ports:
            # Look for ESP32-S3 USB Serial/JTAG
            if "USB" in p.description or "Serial" in p.description:
                return p.device
        return None
    
    def connect(self) -> bool:
        """Connect to the board."""
        if self.serial and self.serial.is_open:
            return True
            
        port = self.port or self.find_port()
        if not port:
            return False
            
        try:
            self.serial = serial.Serial(port, self.baud, timeout=2)
            # Clear any pending data
            self.serial.reset_input_buffer()
            return True
        except Exception as e:
            self.serial = None
            return False
    
    def disconnect(self):
        """Disconnect from the board."""
        if self.serial:
            self.serial.close()
            self.serial = None
    
    def send_command(self, cmd: str) -> str:
        """Send a command and read the response."""
        if not self.connect():
            return "ERROR: Not connected to board"
        
        try:
            # Clear input buffer
            self.serial.reset_input_buffer()
            
            # Send command
            self.serial.write(f"{cmd}\n".encode())
            self.serial.flush()
            
            # Read response lines
            response_lines = []
            timeout_count = 0
            while timeout_count < 3:
                line = self.serial.readline().decode('utf-8', errors='ignore').strip()
                if line:
                    response_lines.append(line)
                    timeout_count = 0
                    # Check for end markers
                    if line.startswith("OK") or line.startswith("ERR") or line == "END" or "DONE" in line:
                        break
                else:
                    timeout_count += 1
            
            return "\n".join(response_lines) if response_lines else "No response"
        except Exception as e:
            return f"ERROR: {str(e)}"
    
    def set_rgb_led(self, red: int, green: int, blue: int) -> str:
        """Set the RGB LED color (0-255 for each channel)."""
        # RGB LED is at Wishbone address 0x8100-0x8103
        # Note: WS2812B uses GRB order
        # Address map: 0x8100=Green, 0x8101=Red, 0x8102=Blue, 0x8103=Status
        results = []
        results.append(self.send_command(f"W 8100 {green:02X}"))  # Green
        results.append(self.send_command(f"W 8101 {red:02X}"))    # Red  
        results.append(self.send_command(f"W 8102 {blue:02X}"))   # Blue
        return "\n".join(results)
    
    def get_rgb_led(self) -> dict:
        """Get current RGB LED values."""
        g = self.send_command("R 8100")  # Green
        r = self.send_command("R 8101")  # Red
        b = self.send_command("R 8102")  # Blue
        
        # Parse responses like "OK R 0000=FF"
        def parse_value(resp):
            try:
                if "=" in resp:
                    return int(resp.split("=")[1].strip(), 16)
            except:
                pass
            return 0
        
        return {
            "red": parse_value(r),
            "green": parse_value(g),
            "blue": parse_value(b)
        }
    
    def wishbone_read(self, address: int) -> int:
        """Read from Wishbone bus address."""
        resp = self.send_command(f"R {address:04X}")
        try:
            if "=" in resp:
                return int(resp.split("=")[1].strip(), 16)
        except:
            pass
        return 0
    
    def wishbone_write(self, address: int, data: int) -> str:
        """Write to Wishbone bus address."""
        return self.send_command(f"W {address:04X} {data:02X}")
    
    def get_debug_dump(self) -> str:
        """Get debug register dump."""
        return self.send_command("D")
    
    def get_jtag_status(self) -> str:
        """Get JTAG bridge status."""
        return self.send_command("J")
    
    def set_jtag_enabled(self, enabled: bool) -> str:
        """Enable/disable JTAG bridge."""
        return self.send_command(f"J {'1' if enabled else '0'}")


# Global controller instance
controller = PapilioController()


def handle_initialize(request_id, params):
    """Handle initialize request."""
    return {
        "jsonrpc": "2.0",
        "id": request_id,
        "result": {
            "protocolVersion": MCP_VERSION,
            "capabilities": {
                "tools": {}
            },
            "serverInfo": {
                "name": "papilio-mcp-server",
                "version": "1.0.0"
            }
        }
    }


def handle_tools_list(request_id):
    """Handle tools/list request."""
    tools = [
        {
            "name": "set_rgb_led",
            "description": "Set the RGB LED color on the Papilio Arcade FPGA board. Each color channel is 0-255.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "red": {
                        "type": "integer",
                        "description": "Red channel value (0-255)",
                        "minimum": 0,
                        "maximum": 255
                    },
                    "green": {
                        "type": "integer",
                        "description": "Green channel value (0-255)",
                        "minimum": 0,
                        "maximum": 255
                    },
                    "blue": {
                        "type": "integer",
                        "description": "Blue channel value (0-255)",
                        "minimum": 0,
                        "maximum": 255
                    }
                },
                "required": ["red", "green", "blue"]
            }
        },
        {
            "name": "get_rgb_led",
            "description": "Get the current RGB LED color values from the Papilio Arcade FPGA board.",
            "inputSchema": {
                "type": "object",
                "properties": {}
            }
        },
        {
            "name": "wishbone_read",
            "description": "Read a byte from a Wishbone bus address on the FPGA.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "address": {
                        "type": "integer",
                        "description": "Wishbone address (0x0000-0xFFFF)",
                        "minimum": 0,
                        "maximum": 65535
                    }
                },
                "required": ["address"]
            }
        },
        {
            "name": "wishbone_write",
            "description": "Write a byte to a Wishbone bus address on the FPGA.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "address": {
                        "type": "integer",
                        "description": "Wishbone address (0x0000-0xFFFF)",
                        "minimum": 0,
                        "maximum": 65535
                    },
                    "data": {
                        "type": "integer",
                        "description": "Data byte to write (0-255)",
                        "minimum": 0,
                        "maximum": 255
                    }
                },
                "required": ["address", "data"]
            }
        },
        {
            "name": "get_fpga_status",
            "description": "Get debug status and register dump from the FPGA.",
            "inputSchema": {
                "type": "object",
                "properties": {}
            }
        },
        {
            "name": "list_serial_ports",
            "description": "List available serial ports for connecting to the Papilio board.",
            "inputSchema": {
                "type": "object",
                "properties": {}
            }
        },
        {
            "name": "connect_board",
            "description": "Connect to the Papilio board on a specific serial port.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "port": {
                        "type": "string",
                        "description": "Serial port name (e.g., COM4, /dev/ttyUSB0)"
                    }
                },
                "required": ["port"]
            }
        },
        {
            "name": "disconnect_board",
            "description": "Disconnect from the Papilio board to free the serial port. Use this before flashing the FPGA.",
            "inputSchema": {
                "type": "object",
                "properties": {}
            }
        },
        {
            "name": "send_raw_command",
            "description": "Send a raw command to the board and return all serial output. Useful for debug commands.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "command": {
                        "type": "string",
                        "description": "The raw command to send (e.g., 'G' for GPIO debug, 'H' for help)"
                    },
                    "timeout": {
                        "type": "number",
                        "description": "Timeout in seconds to wait for response (default 5)",
                        "default": 5
                    }
                },
                "required": ["command"]
            }
        }
    ]
    
    return {
        "jsonrpc": "2.0",
        "id": request_id,
        "result": {
            "tools": tools
        }
    }


def handle_tools_call(request_id, params):
    """Handle tools/call request."""
    tool_name = params.get("name")
    arguments = params.get("arguments", {})
    
    try:
        if tool_name == "set_rgb_led":
            red = arguments.get("red", 0)
            green = arguments.get("green", 0)
            blue = arguments.get("blue", 0)
            result = controller.set_rgb_led(red, green, blue)
            content = f"Set RGB LED to R={red}, G={green}, B={blue}\n{result}"
            
        elif tool_name == "get_rgb_led":
            values = controller.get_rgb_led()
            content = f"RGB LED values: Red={values['red']}, Green={values['green']}, Blue={values['blue']}"
            
        elif tool_name == "wishbone_read":
            address = arguments.get("address", 0)
            value = controller.wishbone_read(address)
            content = f"Read from 0x{address:04X}: 0x{value:02X} ({value})"
            
        elif tool_name == "wishbone_write":
            address = arguments.get("address", 0)
            data = arguments.get("data", 0)
            result = controller.wishbone_write(address, data)
            content = f"Write 0x{data:02X} to 0x{address:04X}: {result}"
            
        elif tool_name == "get_fpga_status":
            result = controller.get_debug_dump()
            content = f"FPGA Status:\n{result}"
            
        elif tool_name == "list_serial_ports":
            ports = serial.tools.list_ports.comports()
            port_list = [f"{p.device}: {p.description}" for p in ports]
            content = "Available serial ports:\n" + "\n".join(port_list) if port_list else "No serial ports found"
            
        elif tool_name == "connect_board":
            port = arguments.get("port")
            controller.port = port
            controller.disconnect()
            if controller.connect():
                content = f"Connected to {port}"
            else:
                content = f"Failed to connect to {port}"
                
        elif tool_name == "disconnect_board":
            controller.disconnect()
            content = "Disconnected from board. Serial port is now free."
            
        elif tool_name == "send_raw_command":
            command = arguments.get("command", "")
            timeout = arguments.get("timeout", 5)
            if not controller.connect():
                content = "ERROR: Not connected to board"
            else:
                try:
                    controller.serial.reset_input_buffer()
                    controller.serial.write(f"{command}\n".encode())
                    controller.serial.flush()
                    
                    # Read all output for the specified timeout
                    import time
                    start_time = time.time()
                    response_lines = []
                    while (time.time() - start_time) < timeout:
                        if controller.serial.in_waiting:
                            line = controller.serial.readline().decode('utf-8', errors='ignore').strip()
                            if line:
                                response_lines.append(line)
                        else:
                            time.sleep(0.1)
                    
                    content = "\n".join(response_lines) if response_lines else "No response"
                except Exception as e:
                    content = f"Error: {str(e)}"
        else:
            content = f"Unknown tool: {tool_name}"
            
    except Exception as e:
        content = f"Error: {str(e)}"
    
    return {
        "jsonrpc": "2.0",
        "id": request_id,
        "result": {
            "content": [
                {
                    "type": "text",
                    "text": content
                }
            ]
        }
    }


def process_request(request: dict) -> Optional[dict]:
    """Process an incoming JSON-RPC request."""
    method = request.get("method")
    request_id = request.get("id")
    params = request.get("params", {})
    
    if method == "initialize":
        return handle_initialize(request_id, params)
    elif method == "initialized":
        # Notification, no response needed
        return None
    elif method == "tools/list":
        return handle_tools_list(request_id)
    elif method == "tools/call":
        return handle_tools_call(request_id, params)
    elif method == "ping":
        return {"jsonrpc": "2.0", "id": request_id, "result": {}}
    else:
        # Unknown method
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "error": {
                "code": -32601,
                "message": f"Method not found: {method}"
            }
        }


def main():
    """Main entry point - runs the MCP server over stdio."""
    parser = argparse.ArgumentParser(description="Papilio Arcade MCP Server")
    parser.add_argument("--port", help="Serial port (e.g., COM4)", default=None)
    parser.add_argument("--baud", type=int, help="Baud rate", default=115200)
    args = parser.parse_args()
    
    # Configure controller
    controller.port = args.port
    controller.baud = args.baud
    
    # Read from stdin, write to stdout (MCP stdio transport)
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break
                
            line = line.strip()
            if not line:
                continue
            
            request = json.loads(line)
            response = process_request(request)
            
            if response:
                sys.stdout.write(json.dumps(response) + "\n")
                sys.stdout.flush()
                
        except json.JSONDecodeError as e:
            error_response = {
                "jsonrpc": "2.0",
                "id": None,
                "error": {
                    "code": -32700,
                    "message": f"Parse error: {str(e)}"
                }
            }
            sys.stdout.write(json.dumps(error_response) + "\n")
            sys.stdout.flush()
        except Exception as e:
            # Log to stderr for debugging
            sys.stderr.write(f"Error: {str(e)}\n")
            sys.stderr.flush()


if __name__ == "__main__":
    main()
