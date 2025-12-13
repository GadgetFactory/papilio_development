#!/usr/bin/env python3
"""Test RGB LED with correct GRB mapping for WS2812B"""

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

print("RGB LED Test - Corrected for WS2812B (GRB order)")
print("=" * 50)
print("Register mapping:")
print("  0x8100 = GREEN")
print("  0x8101 = RED")
print("  0x8102 = BLUE")
print()

# Read current state
print("1. Reading current values...")
g = mcp_read(ser, 0x8100)
r = mcp_read(ser, 0x8101)
b = mcp_read(ser, 0x8102)
print(f"   0x8100 (G): 0x{g:02X}, 0x8101 (R): 0x{r:02X}, 0x8102 (B): 0x{b:02X}")

# Set to RED
print("\n2. Setting to RED...")
print("   Writing: G=0, R=255, B=0")
mcp_write(ser, 0x8100, 0x00)  # G = 0
mcp_write(ser, 0x8101, 0xFF)  # R = 255
mcp_write(ser, 0x8102, 0x00)  # B = 0
time.sleep(0.5)
print("   LED should be RED now")

input("\nPress Enter to change to GREEN...")

# Set to GREEN
print("\n3. Setting to GREEN...")
print("   Writing: G=255, R=0, B=0")
mcp_write(ser, 0x8100, 0xFF)  # G = 255
mcp_write(ser, 0x8101, 0x00)  # R = 0
mcp_write(ser, 0x8102, 0x00)  # B = 0
time.sleep(0.5)
print("   LED should be GREEN now")

input("\nPress Enter to change to BLUE...")

# Set to BLUE
print("\n4. Setting to BLUE...")
print("   Writing: G=0, R=0, B=255")
mcp_write(ser, 0x8100, 0x00)  # G = 0
mcp_write(ser, 0x8101, 0x00)  # R = 0
mcp_write(ser, 0x8102, 0xFF)  # B = 255
time.sleep(0.5)
print("   LED should be BLUE now")

ser.close()
