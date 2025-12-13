#!/usr/bin/env python3
"""Test LA register access"""

import serial
import time

ser = serial.Serial('COM4', 115200, timeout=1)
time.sleep(0.5)

print("LA Register Access Test")
print("=" * 60)

# Clear buffer
ser.read(ser.in_waiting)

# Read status (offset 0x00)
print("\n1. Reading LA status register (0x8300)...")
ser.write(b"R 8300\n")
time.sleep(0.1)
response = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
print(f"   Response: {repr(response)}")

# Read ID registers (offset 0x02-0x03)
print("\n2. Reading LA ID registers (should be 'SU' = 0x53 0x55)...")
ser.read(ser.in_waiting)
ser.write(b"R 8302\n")
time.sleep(0.1)
response = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
print(f"   0x8302: {repr(response)}")

ser.read(ser.in_waiting)
ser.write(b"R 8303\n")
time.sleep(0.1)
response = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
print(f"   0x8303: {repr(response)}")

# Try ARM command
print("\n3. Sending ARM command (0x01 to 0x8300)...")
ser.read(ser.in_waiting)
ser.write(b"W 8300 01\n")
time.sleep(0.1)
response = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
print(f"   Response: {repr(response)}")

# Read status again
ser.read(ser.in_waiting)
ser.write(b"R 8300\n")
time.sleep(0.1)
response = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
print(f"   Status after ARM: {repr(response)}")

ser.close()
