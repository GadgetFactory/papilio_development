#!/usr/bin/env python3
"""Basic MCP communication test"""

import serial
import time

ser = serial.Serial('COM4', 115200, timeout=1)
time.sleep(1)

print("Basic MCP Communication Test")
print("=" * 60)

# Clear buffer
ser.read(ser.in_waiting)

# Test LA read (should return a valid status byte)
print("\n1. Testing LA status read (0x8300)...")
ser.write(b"R 8300\n")
time.sleep(0.1)
response = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
print(f"   Response: {repr(response)}")

# Test RGB LED read
print("\n2. Testing RGB LED Green read (0x8100)...")
ser.read(ser.in_waiting)
ser.write(b"R 8100\n")
time.sleep(0.1)
response = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
print(f"   Response: {repr(response)}")

# Test RGB LED write
print("\n3. Writing RED (G=0x00, R=0xFF, B=0x00)...")
ser.read(ser.in_waiting)
ser.write(b"W 8100 00\n")  # G
time.sleep(0.05)
print(f"   Response: {repr(ser.read(ser.in_waiting).decode('utf-8', errors='ignore'))}")

ser.read(ser.in_waiting)
ser.write(b"W 8101 FF\n")  # R
time.sleep(0.05)
print(f"   Response: {repr(ser.read(ser.in_waiting).decode('utf-8', errors='ignore'))}")

ser.read(ser.in_waiting)
ser.write(b"W 8102 00\n")  # B
time.sleep(0.05)
print(f"   Response: {repr(ser.read(ser.in_waiting).decode('utf-8', errors='ignore'))}")

print("\n4. LED should be RED now. Is it? (yes/no)")

# Read back values
print("\n5. Reading back values...")
ser.read(ser.in_waiting)
ser.write(b"R 8100\n")
time.sleep(0.1)
print(f"   G: {repr(ser.read(ser.in_waiting).decode('utf-8', errors='ignore'))}")

ser.read(ser.in_waiting)
ser.write(b"R 8101\n")
time.sleep(0.1)
print(f"   R: {repr(ser.read(ser.in_waiting).decode('utf-8', errors='ignore'))}")

ser.read(ser.in_waiting)
ser.write(b"R 8102\n")
time.sleep(0.1)
print(f"   B: {repr(ser.read(ser.in_waiting).decode('utf-8', errors='ignore'))}")

ser.close()
