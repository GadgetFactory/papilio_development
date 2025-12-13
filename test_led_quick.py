#!/usr/bin/env python3
"""Quick test to verify LED is responding"""

import serial
import time

def mcp_write(ser, address, data):
    ser.read(ser.in_waiting)
    cmd = f"W {address:04X} {data:02X}\n"
    ser.write(cmd.encode())
    time.sleep(0.05)
    response = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
    print(f"  Write 0x{address:04X} = 0x{data:02X}: {response.strip()}")
    return response

ser = serial.Serial('COM4', 115200, timeout=1)
time.sleep(0.5)

print("Setting LED to BLUE...")
mcp_write(ser, 0x8100, 0x00)  # Green
mcp_write(ser, 0x8101, 0x00)  # Red  
mcp_write(ser, 0x8102, 0xFF)  # Blue

time.sleep(1)

print("\nSetting LED to RED...")
mcp_write(ser, 0x8100, 0x00)  # Green
mcp_write(ser, 0x8101, 0xFF)  # Red
mcp_write(ser, 0x8102, 0x00)  # Blue

time.sleep(1)

print("\nSetting LED to GREEN...")
mcp_write(ser, 0x8100, 0xFF)  # Green
mcp_write(ser, 0x8101, 0x00)  # Red
mcp_write(ser, 0x8102, 0x00)  # Blue

print("\nDo you see the LED changing colors?")
