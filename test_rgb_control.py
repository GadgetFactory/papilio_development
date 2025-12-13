#!/usr/bin/env python3
"""Test RGB LED control and verify current state"""

import serial
import time

def mcp_write(ser, address, data):
    ser.read(ser.in_waiting)
    cmd = f"W {address:04X} {data:02X}\n"
    ser.write(cmd.encode())
    time.sleep(0.05)
    return ser.read(ser.in_waiting).decode('utf-8', errors='ignore')

def mcp_read(ser, address):
    ser.read(ser.in_waiting)
    cmd = f"R {address:04X}\n"
    ser.write(cmd.encode())
    time.sleep(0.1)
    response = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
    try:
        if '=' in response:
            return int(response.split('=')[1].strip().split()[0], 16)
        elif ':' in response:
            return int(response.split(':')[1].strip().split()[0], 16)
    except:
        pass
    return None

ser = serial.Serial('COM4', 115200, timeout=1)
time.sleep(0.5)

print("RGB LED Test")
print("=" * 40)

# Read current state
print("\n1. Reading current RGB values...")
r = mcp_read(ser, 0x8100)
g = mcp_read(ser, 0x8101)
b = mcp_read(ser, 0x8102)
print(f"   R: 0x{r:02X} ({r}), G: 0x{g:02X} ({g}), B: 0x{b:02X} ({b})")

# Set to RED
print("\n2. Setting to RED (255, 0, 0)...")
mcp_write(ser, 0x8100, 0xFF)
mcp_write(ser, 0x8101, 0x00)
mcp_write(ser, 0x8102, 0x00)
time.sleep(0.5)
print("   LED should be RED now")

# Verify
r = mcp_read(ser, 0x8100)
g = mcp_read(ser, 0x8101)
b = mcp_read(ser, 0x8102)
print(f"   Verify: R: 0x{r:02X}, G: 0x{g:02X}, B: 0x{b:02X}")

input("\nPress Enter to continue to BLUE...")

# Set to BLUE
print("\n3. Setting to BLUE (0, 0, 255)...")
mcp_write(ser, 0x8100, 0x00)
mcp_write(ser, 0x8101, 0x00)
mcp_write(ser, 0x8102, 0xFF)
time.sleep(0.5)
print("   LED should be BLUE now")

ser.close()
