#!/usr/bin/env python3
"""Capture and decode full 32-bit Wishbone transaction"""

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

def read_32bit_samples(ser, count):
    """Read 32-bit samples (4 bytes per sample)"""
    samples = []
    for i in range(count):
        # Read 4 consecutive bytes
        b0 = mcp_read(ser, 0x8380 + i*4 + 0)  # LSB [7:0]
        b1 = mcp_read(ser, 0x8380 + i*4 + 1)  # [15:8]
        b2 = mcp_read(ser, 0x8380 + i*4 + 2)  # [23:16]
        b3 = mcp_read(ser, 0x8380 + i*4 + 3)  # MSB [31:24]
        
        if None not in [b0, b1, b2, b3]:
            sample = (b3 << 24) | (b2 << 16) | (b1 << 8) | b0
            samples.append(sample)
    return samples

ser = serial.Serial('COM4', 115200, timeout=1)
time.sleep(0.5)

print("Wishbone Transaction Capture - Full 32-bit Decode")
print("=" * 60)

UNIQUE_VALUE = 0xAB

# Set to GREEN first
print("1. Setting LED to GREEN...")
mcp_write(ser, 0x8100, 0xFF)
mcp_write(ser, 0x8101, 0x00)
mcp_write(ser, 0x8102, 0x00)
time.sleep(0.1)

# Configure trigger for wb_dat_o = 0xAB (bits [31:24])
print(f"2. Configuring trigger (wb_dat_o = 0x{UNIQUE_VALUE:02X})...")
mcp_write(ser, 0x8304, 0x00)
mcp_write(ser, 0x8305, 0x00)
mcp_write(ser, 0x8306, 0x00)
mcp_write(ser, 0x8307, 0xFF)  # mask [31:24]

mcp_write(ser, 0x8308, 0x00)
mcp_write(ser, 0x8309, 0x00)
mcp_write(ser, 0x830A, 0x00)
mcp_write(ser, 0x830B, UNIQUE_VALUE)  # value [31:24]

# Arm and trigger
print("3. Arming and triggering...")
mcp_write(ser, 0x8300, 0x01)
time.sleep(0.01)
mcp_write(ser, 0x8101, UNIQUE_VALUE)
time.sleep(0.2)

status = mcp_read(ser, 0x8300)
print(f"   Status: 0x{status:02X} ({'TRIGGERED' if status == 0x04 else 'Error'})")

# Read 32-bit samples
print("\n4. Reading 32-bit samples...")
samples = read_32bit_samples(ser, 32)
print(f"   Read {len(samples)} full samples")

# Decode
print("\n5. Decoded samples:")
print("   Sample | wb_dat_o | wb_adr_o | Ctrl | Debug")
print("   " + "-" * 55)

for i, s in enumerate(samples):
    wb_dat = (s >> 24) & 0xFF  # [31:24]
    ctrl = (s >> 16) & 0xFF     # [23:16]
    wb_adr = (s >> 8) & 0xFF    # [15:8]
    debug = s & 0xFF            # [7:0]
    
    # Decode control bits [23:16]
    wb_cyc = (ctrl >> 7) & 1
    wb_stb = (ctrl >> 6) & 1
    wb_we = (ctrl >> 5) & 1
    wb_ack = (ctrl >> 4) & 1
    rgb_sel = (ctrl >> 3) & 1
    
    marker = ""
    if wb_dat == UNIQUE_VALUE:
        marker = " <-- TRIGGER VALUE!"
    if wb_stb and wb_we and rgb_sel:
        marker += " WB_WRITE"
    
    print(f"   {i:4d}   |   0x{wb_dat:02X}   |   0x{wb_adr:02X}   | {wb_cyc}{wb_stb}{wb_we}{wb_ack} | 0x{debug:02X}{marker}")

print(f"\n6. Analysis:")
found = [i for i, s in enumerate(samples) if ((s >> 24) & 0xFF) == UNIQUE_VALUE]
if found:
    print(f"   ✓ Found value 0x{UNIQUE_VALUE:02X} at sample {found[0]}")
    s = samples[found[0]]
    print(f"   Full capture: 0x{s:08X}")
    print(f"   wb_dat_o = 0x{(s >> 24) & 0xFF:02X}")
    print(f"   wb_adr_o = 0x{(s >> 8) & 0xFF:02X}")
else:
    print(f"   ✗ Value 0x{UNIQUE_VALUE:02X} not found")

ser.close()
