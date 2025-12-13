#!/usr/bin/env python3
"""Analyze all captured samples to find WS2812B pattern"""

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
    except:
        pass
    return None

ser = serial.Serial('COM4', 115200, timeout=1)
time.sleep(0.5)

print("Analyzing WS2812B Capture Pattern")
print("=" * 60)

# Set RED, arm, trigger with BLUE
print("Setting up capture...")
mcp_write(ser, 0x8100, 0x00)
mcp_write(ser, 0x8101, 0xFF)
mcp_write(ser, 0x8102, 0x00)
time.sleep(0.1)

# Trigger on HIGH (wait for transmission to start)
mcp_write(ser, 0x8300 + 0x04, 0x01)  # mask bit 0
mcp_write(ser, 0x8300 + 0x05, 0x00)
mcp_write(ser, 0x8300 + 0x06, 0x00)
mcp_write(ser, 0x8300 + 0x07, 0x00)
mcp_write(ser, 0x8300 + 0x08, 0x01)  # value = 1 (trigger on HIGH)
mcp_write(ser, 0x8300 + 0x09, 0x00)
mcp_write(ser, 0x8300 + 0x0A, 0x00)
mcp_write(ser, 0x8300 + 0x0B, 0x00)

mcp_write(ser, 0x8300, 0x01)
time.sleep(0.01)

mcp_write(ser, 0x8100, 0x00)
mcp_write(ser, 0x8101, 0x00)
mcp_write(ser, 0x8102, 0xFF)
time.sleep(0.3)

# Read all samples
samples = []
for i in range(1024):
    val = mcp_read(ser, 0x8300 + 0x80 + i)
    if val is not None:
        samples.append(val)

# Find all transitions
print(f"\nAnalyzing {len(samples)} samples...")
transitions = []
for i in range(1, len(samples)):
    if (samples[i] & 0x01) != (samples[i-1] & 0x01):
        transitions.append(i)

print(f"Found {len(transitions)} transitions\n")

if transitions:
    print("Transition details:")
    for idx in transitions[:20]:
        val = samples[idx] & 0x01
        direction = "↑" if val else "↓"
        print(f"  Sample {idx:4d}: {direction}")
    
    # Analyze run lengths
    print("\nRun length analysis (first 50 transitions):")
    for i in range(min(50, len(transitions)-1)):
        run_length = transitions[i+1] - transitions[i]
        bit_val = samples[transitions[i]] & 0x01
        print(f"  Transition {i:2d}: {'HIGH' if bit_val else 'LOW '} for {run_length:3d} samples")
else:
    # Count consecutive values
    print("No transitions - signal is static")
    low_count = sum(1 for s in samples if (s & 0x01) == 0)
    high_count = len(samples) - low_count
    print(f"  LOW:  {low_count} samples")
    print(f"  HIGH: {high_count} samples")

ser.close()
