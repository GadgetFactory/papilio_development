#!/usr/bin/env python3
"""Capture Wishbone transaction with trigger on unique data value"""

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

print("Wishbone Transaction Capture with Data Trigger")
print("=" * 60)
print("\nProbe mapping:")
print("  [31:24] = wb_dat_o (Wishbone data bus)")
print("  [23:16] = Control (wb_cyc, wb_stb, wb_we, wb_ack, device selects)")
print("  [15:8]  = wb_adr_o (Wishbone address bus)")
print("  [7:0]   = Debug signals (rgb_led, SPI, etc.)")

# Set LED to a normal color first
print("\n1. Setting LED to GREEN...")
mcp_write(ser, 0x8100, 0xFF)  # G
mcp_write(ser, 0x8101, 0x00)  # R
mcp_write(ser, 0x8102, 0x00)  # B
time.sleep(0.1)

# Configure trigger: wait for wb_dat_o = 0xAB (unique red value)
# Bits [31:24] = wb_dat_o
UNIQUE_VALUE = 0xAB
print(f"\n2. Configuring trigger (wait for wb_dat_o = 0x{UNIQUE_VALUE:02X})...")

# trigger_mask: check bits [31:24] (wb_dat_o)
mcp_write(ser, 0x8300 + 0x04, 0x00)  # [7:0]
mcp_write(ser, 0x8300 + 0x05, 0x00)  # [15:8]
mcp_write(ser, 0x8300 + 0x06, 0x00)  # [23:16]
mcp_write(ser, 0x8300 + 0x07, 0xFF)  # [31:24] = 0xFF (check all data bits)

# trigger_value: wait for 0xAB on bits [31:24]
mcp_write(ser, 0x8300 + 0x08, 0x00)  # [7:0]
mcp_write(ser, 0x8300 + 0x09, 0x00)  # [15:8]
mcp_write(ser, 0x8300 + 0x0A, 0x00)  # [23:16]
mcp_write(ser, 0x8300 + 0x0B, UNIQUE_VALUE)  # [31:24] = 0xAB

# Arm LA
print("3. Arming LA (will wait for trigger)...")
mcp_write(ser, 0x8300, 0x01)
time.sleep(0.05)

status = mcp_read(ser, 0x8300)
print(f"   LA Status: 0x{status:02X} ({'Armed - waiting' if status & 0x01 else 'Already done?'})")

# Write unique red value to trigger
print(f"\n4. Writing unique RED value (R=0x{UNIQUE_VALUE:02X})...")
mcp_write(ser, 0x8101, UNIQUE_VALUE)  # Red register at 0x8101
time.sleep(0.2)

status = mcp_read(ser, 0x8300)
print(f"   LA Status: 0x{status:02X} ({'Armed' if status & 0x01 else 'TRIGGERED!'})")

# Read captured data
print("\n5. Reading captured samples...")
samples = []
for i in range(128):  # Read first 128 samples
    val = mcp_read(ser, 0x8300 + 0x80 + i)
    if val is not None:
        samples.append(val)

print(f"   Read {len(samples)} samples")

# Analyze captured data
print("\n6. First 32 samples (raw 8-bit reads):")
for i in range(min(32, len(samples))):
    print(f"   Sample {i:2d}: 0x{samples[i]:02X}")

# Look for our unique value in the data
print(f"\n7. Searching for unique value 0x{UNIQUE_VALUE:02X}:")
found_indices = [i for i, val in enumerate(samples) if val == UNIQUE_VALUE]
if found_indices:
    print(f"   Found at sample positions: {found_indices[:10]}")
    print(f"\n   Context around first match (sample {found_indices[0]}):")
    start = max(0, found_indices[0] - 4)
    end = min(len(samples), found_indices[0] + 8)
    for i in range(start, end):
        marker = " <-- MATCH" if i == found_indices[0] else ""
        print(f"   Sample {i:3d}: 0x{samples[i]:02X}{marker}")
else:
    print(f"   Value 0x{UNIQUE_VALUE:02X} not found in captured data")

ser.close()
