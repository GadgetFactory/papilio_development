#!/usr/bin/env python3
"""Capture WS2812B while rapidly changing LED colors to ensure transmission"""

import serial
import time

def mcp_write(ser, address, data):
    ser.read(ser.in_waiting)
    cmd = f"W {address:04X} {data:02X}\n"
    ser.write(cmd.encode())
    time.sleep(0.02)
    ser.read(ser.in_waiting)

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

print("Arming LA and rapidly changing LED colors...")

# Arm LA first
mcp_write(ser, 0x8300, 0x01)
time.sleep(0.01)

# Rapidly toggle LED colors to generate WS2812B traffic
for i in range(10):
    if i % 2 == 0:
        # RED
        mcp_write(ser, 0x8100, 0x00)
        mcp_write(ser, 0x8101, 0xFF)
        mcp_write(ser, 0x8102, 0x00)
    else:
        # BLUE
        mcp_write(ser, 0x8100, 0x00)
        mcp_write(ser, 0x8101, 0x00)
        mcp_write(ser, 0x8102, 0xFF)

time.sleep(0.1)

# Read samples
print("\nReading samples...")
samples = []
for addr in range(0x8000, 0x8400, 4):
    data = mcp_read(ser, addr)
    if data is not None:
        samples.append(data)

print(f"Captured {len(samples)} samples\n")

# Look for transitions on bits [7:0] (should be rgb_led)
bit_7_values = [(s >> 7) & 1 for s in samples]
transitions = sum(1 for i in range(len(bit_7_values)-1) if bit_7_values[i] != bit_7_values[i+1])
ones = sum(bit_7_values)

print(f"Bit 7 (rgb_led) analysis:")
print(f"  HIGH samples: {ones}/{len(samples)} ({100*ones/len(samples):.1f}%)")
print(f"  Transitions: {transitions}")

if transitions > 10:
    print(f"\n✓ Detected WS2812B activity! ({transitions} transitions)")
    
    # Show samples with transitions
    print("\nSamples showing bit 7 transitions:")
    for i in range(1, min(len(samples), 100)):
        prev = (samples[i-1] >> 7) & 1
        curr = (samples[i] >> 7) & 1
        if prev != curr:
            print(f"  Sample {i}: {samples[i]:08X} (bit7: {prev}→{curr})")
else:
    print(f"\n✗ No WS2812B activity detected (only {transitions} transitions)")
    print("\nShowing first 16 samples:")
    for i in range(min(16, len(samples))):
        print(f"  Sample {i}: {samples[i]:08X}")
