#!/usr/bin/env python3
"""Capture and fully decode WS2812B with proper trigger"""

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

def decode_ws2812b(samples, bit_num=0):
    """Decode WS2812B from captured samples"""
    bits = []
    i = 0
    
    # Find first rising edge
    while i < len(samples) and not (samples[i] & (1 << bit_num)):
        i += 1
    
    print(f"\n   First rising edge at sample {i}")
    
    # Decode bits
    while i < len(samples) and len(bits) < 24:
        # Count high period
        high_start = i
        while i < len(samples) and (samples[i] & (1 << bit_num)):
            i += 1
        high_count = i - high_start
        
        if high_count == 0:
            break
        
        # Count low period
        low_start = i
        while i < len(samples) and not (samples[i] & (1 << bit_num)):
            i += 1
        low_count = i - low_start
        
        # Decode bit: high > 17 samples (~0.63µs) = '1', else '0'
        bit = 1 if high_count > 17 else 0
        bits.append(bit)
        
        if len(bits) <= 5 or len(bits) >= 22:
            print(f"   Bit {len(bits)-1:2d}: high={high_count:2d}, low={low_count:2d} -> {bit}")
    
    if len(bits) >= 24:
        # Convert to GRB bytes
        g = sum(bits[i] << (7-i) for i in range(8))
        r = sum(bits[8+i] << (7-i) for i in range(8))
        b = sum(bits[16+i] << (7-i) for i in range(8))
        return (g, r, b), len(bits)
    
    return None, len(bits)

ser = serial.Serial('COM4', 115200, timeout=1)
time.sleep(0.5)

print("WS2812B Protocol Capture with Trigger")
print("=" * 60)

# Set LED to RED
print("\n1. Setting LED to RED (G=0x00, R=0xFF, B=0x00)...")
mcp_write(ser, 0x8100, 0x00)
mcp_write(ser, 0x8101, 0xFF)
mcp_write(ser, 0x8102, 0x00)
time.sleep(0.2)

# Configure trigger for falling edge
print("\n2. Configuring trigger (wait for rgb_led LOW)...")
mcp_write(ser, 0x8300 + 0x04, 0x01)  # mask LSB
mcp_write(ser, 0x8300 + 0x05, 0x00)
mcp_write(ser, 0x8300 + 0x06, 0x00)
mcp_write(ser, 0x8300 + 0x07, 0x00)
mcp_write(ser, 0x8300 + 0x08, 0x00)  # value = 0 (trigger on LOW)
mcp_write(ser, 0x8300 + 0x09, 0x00)
mcp_write(ser, 0x8300 + 0x0A, 0x00)
mcp_write(ser, 0x8300 + 0x0B, 0x00)

# Arm LA
print("3. Arming LA...")
mcp_write(ser, 0x8300, 0x01)
time.sleep(0.05)

# Trigger with BLUE
print("4. Changing to BLUE (G=0x00, R=0x00, B=0xFF) to trigger...")
mcp_write(ser, 0x8100, 0x00)
mcp_write(ser, 0x8101, 0x00)
mcp_write(ser, 0x8102, 0xFF)
time.sleep(0.3)

# Check status
status = mcp_read(ser, 0x8300)
print(f"   LA Status: 0x{status:02X}")

# Read all 1024 samples (only need first byte of each 32-bit word for bit 0)
print("\n5. Reading samples...")
samples = []
for i in range(1024):
    addr = 0x8300 + 0x80 + i
    val = mcp_read(ser, addr)
    if val is not None:
        samples.append(val)

print(f"   Read {len(samples)} samples")

# Show first 32 samples
print("\n6. First 32 samples:")
for i in range(min(32, len(samples))):
    bit0 = samples[i] & 0x01
    print(f"   Sample {i:3d}: 0x{samples[i]:02X} (bit0={bit0})")

# Decode WS2812B
print("\n7. Decoding WS2812B protocol:")
result, bit_count = decode_ws2812b(samples, bit_num=0)

if result:
    g, r, b = result
    print(f"\n   ✓ Decoded {bit_count} bits")
    print(f"   Captured GRB: G=0x{g:02X}, R=0x{r:02X}, B=0x{b:02X}")
    print(f"   Expected:     G=0x00, R=0x00, B=0xFF")
    
    if g == 0x00 and r == 0x00 and b == 0xFF:
        print("\n   ✓✓✓ SUCCESS! WS2812B data matches BLUE!")
    else:
        print("\n   ✗ Mismatch")
else:
    print(f"\n   ✗ Only decoded {bit_count} bits (need 24)")

ser.close()
