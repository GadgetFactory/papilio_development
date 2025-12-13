#!/usr/bin/env python3
"""Capture Wishbone with trigger on unique value - simple readout"""

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

print("Wishbone Data Capture with Trigger")
print("=" * 60)

UNIQUE_VALUE = 0xAB

# Set GREEN
print("1. Setting LED to GREEN...")
mcp_write(ser, 0x8100, 0xFF)
mcp_write(ser, 0x8101, 0x00)
mcp_write(ser, 0x8102, 0x00)
time.sleep(0.1)

# Configure trigger: wb_dat_o[7:0] = 0xAB (bits [31:24] of probe)
print(f"2. Configuring trigger (wb_dat_o = 0x{UNIQUE_VALUE:02X})...")
mcp_write(ser, 0x8304, 0x00)  # mask [7:0]
mcp_write(ser, 0x8305, 0x00)  # [15:8]
mcp_write(ser, 0x8306, 0x00)  # [23:16]
mcp_write(ser, 0x8307, 0xFF)  # [31:24] = FF (check data bus)

mcp_write(ser, 0x8308, 0x00)  # value [7:0]
mcp_write(ser, 0x8309, 0x00)  # [15:8]
mcp_write(ser, 0x830A, 0x00)  # [23:16]
mcp_write(ser, 0x830B, UNIQUE_VALUE)  # [31:24] = AB

# Arm
print("3. Arming LA...")
mcp_write(ser, 0x8300, 0x01)
time.sleep(0.05)

# Trigger
print(f"4. Writing unique value (R = 0x{UNIQUE_VALUE:02X})...")
mcp_write(ser, 0x8101, UNIQUE_VALUE)
time.sleep(0.2)

status = mcp_read(ser, 0x8300)
print(f"   Status: 0x{status:02X} ({'TRIGGERED!' if status == 0x04 else 'Not triggered'})")

# Read samples (wb_dat_o[7:0] from each captured sample)
print("\n5. Reading captured wb_dat_o values...")
samples = []
for i in range(64):
    val = mcp_read(ser, 0x8380 + i)
    if val is not None:
        samples.append(val)

print(f"   Read {len(samples)} samples\n")
print("   First 32 wb_dat_o samples:")
for i in range(min(32, len(samples))):
    marker = f" <-- TRIGGER!" if samples[i] == UNIQUE_VALUE else ""
    print(f"   Sample {i:2d}: 0x{samples[i]:02X}{marker}")

# Analysis
found = [i for i, v in enumerate(samples) if v == UNIQUE_VALUE]
if found:
    print(f"\n6. ✓ Success! Found 0x{UNIQUE_VALUE:02X} at samples: {found[:5]}")
    print(f"   This confirms we captured the Wishbone write of R=0x{UNIQUE_VALUE:02X}!")
else:
    print(f"\n6. ✗ Value 0x{UNIQUE_VALUE:02X} not found in capture")

ser.close()
