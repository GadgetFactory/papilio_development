#!/usr/bin/env python3
"""Check all 32 bits of captured LA data"""

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

print("Setting LED to RED and capturing...")
mcp_write(ser, 0x8100, 0x00)  # Green
mcp_write(ser, 0x8101, 0xFF)  # Red
mcp_write(ser, 0x8102, 0x00)  # Blue
time.sleep(0.1)

# Arm and trigger
mcp_write(ser, 0x8300, 0x01)  # Arm
mcp_write(ser, 0x8101, 0xFF)  # Trigger with another write
time.sleep(0.05)

# Read samples
samples = []
for addr in range(0x8000, 0x8400, 4):
    data = mcp_read(ser, addr)
    if data is not None:
        samples.append(data)

print(f"\nCaptured {len(samples)} samples")
print("\nFirst 32 samples showing all 32 bits:")
print("Sample | Bit [31:24]  | Bit [23:16]  | Bit [15:8]   | Bit [7:0]    | Hex")
print("-------+--------------+--------------+--------------+--------------+----------")
for i in range(min(32, len(samples))):
    s = samples[i]
    b31_24 = (s >> 24) & 0xFF
    b23_16 = (s >> 16) & 0xFF
    b15_8  = (s >> 8) & 0xFF
    b7_0   = s & 0xFF
    print(f"{i:4d}   | {b31_24:08b} | {b23_16:08b} | {b15_8:08b} | {b7_0:08b} | {s:08X}")

# Analyze each bit position
print("\n\nBit activity analysis:")
for bit in [31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]:
    bit_values = [(s >> bit) & 1 for s in samples]
    ones = sum(bit_values)
    transitions = sum(1 for i in range(len(bit_values)-1) if bit_values[i] != bit_values[i+1])
    if ones > 0 or transitions > 0:
        print(f"  Bit {bit:2d}: {ones:3d} ones ({100*ones/len(samples):5.1f}%), {transitions:3d} transitions")
