#!/usr/bin/env python3
"""Search through all LA samples to find WS2812B transmission"""

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

print("Searching for WS2812B transmission in LA capture")
print("=" * 60)

# Set LED to known color
print("\n1. Setting LED to RED...")
mcp_write(ser, 0x8100, 0x00)  # G
mcp_write(ser, 0x8101, 0xFF)  # R
mcp_write(ser, 0x8102, 0x00)  # B
time.sleep(0.1)

# Arm LA and trigger
print("2. Arming LA and changing to BLUE...")
mcp_write(ser, 0x8300, 0x01)
time.sleep(0.001)
mcp_write(ser, 0x8100, 0x00)  # G
mcp_write(ser, 0x8101, 0x00)  # R
mcp_write(ser, 0x8102, 0xFF)  # B
time.sleep(0.3)

# Read all samples
print("3. Reading 1024 samples...")
samples = []
for addr in range(0x8304, 0x8304 + 1024):
    val = mcp_read(ser, addr)
    if val is not None:
        samples.append(val)

print(f"   Got {len(samples)} samples")

# Look for transitions on bit 0 (rgb_led)
print("\n4. Searching for transitions on bit 0 (rgb_led)...")
transitions = []
for i in range(1, len(samples)):
    prev_bit = samples[i-1] & 0x01
    curr_bit = samples[i] & 0x01
    if prev_bit != curr_bit:
        transitions.append((i, prev_bit, curr_bit))

print(f"   Found {len(transitions)} transitions")

if transitions:
    print(f"\n5. First 10 transitions:")
    for i, (idx, prev, curr) in enumerate(transitions[:10]):
        direction = "↑" if curr == 1 else "↓"
        print(f"   Transition {i}: sample {idx:4d}, {prev}→{curr} {direction}")
    
    # Show samples around first transition
    first_trans = transitions[0][0]
    print(f"\n6. Samples around first transition (sample {first_trans}):")
    start = max(0, first_trans - 5)
    end = min(len(samples), first_trans + 10)
    for i in range(start, end):
        bit0 = samples[i] & 0x01
        marker = " <--" if i == first_trans else ""
        print(f"   Sample {i:4d}: 0x{samples[i]:08X} (bit0={bit0}){marker}")
else:
    print("   No transitions found - signal is static")
    
    # Check if all samples are same value
    unique_values = set(samples)
    print(f"\n5. Unique sample values: {len(unique_values)}")
    for val in list(unique_values)[:5]:
        count = samples.count(val)
        print(f"   0x{val:08X}: {count} times")

ser.close()
