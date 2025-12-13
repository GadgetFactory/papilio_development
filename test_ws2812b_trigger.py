#!/usr/bin/env python3
"""Capture WS2812B with trigger on falling edge"""

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

print("WS2812B Capture with Trigger on Falling Edge")
print("=" * 60)

# Set LED to RED (so rgb_led is currently high)
print("\n1. Setting LED to RED (ensuring rgb_led is HIGH)...")
mcp_write(ser, 0x8100, 0x00)  # G
mcp_write(ser, 0x8101, 0xFF)  # R
mcp_write(ser, 0x8102, 0x00)  # B
time.sleep(0.2)

# Configure LA trigger
print("\n2. Configuring LA trigger...")
print("   Trigger Mask:  0x00000001 (monitor bit 0 = rgb_led)")
print("   Trigger Value: 0x00000000 (wait for bit 0 = LOW)")

# Write trigger mask (offset 0x04-0x07)
mcp_write(ser, 0x8300 + 0x04, 0x01)  # LSB
mcp_write(ser, 0x8300 + 0x05, 0x00)
mcp_write(ser, 0x8300 + 0x06, 0x00)
mcp_write(ser, 0x8300 + 0x07, 0x00)  # MSB

# Write trigger value (offset 0x08-0x0B)
mcp_write(ser, 0x8300 + 0x08, 0x00)  # All zeros
mcp_write(ser, 0x8300 + 0x09, 0x00)
mcp_write(ser, 0x8300 + 0x0A, 0x00)
mcp_write(ser, 0x8300 + 0x0B, 0x00)

# Arm LA
print("\n3. Arming LA (will wait for trigger)...")
mcp_write(ser, 0x8300, 0x01)
time.sleep(0.1)

# Check status
status = mcp_read(ser, 0x8300)
print(f"   LA Status: 0x{status:02X} {'(Armed - waiting)' if status & 0x01 else '(Done/Triggered)'}")

# Trigger by changing LED (this will cause rgb_led to transmit, starting with LOW)
print("\n4. Triggering: Changing LED to BLUE...")
mcp_write(ser, 0x8100, 0x00)  # G
mcp_write(ser, 0x8101, 0x00)  # R
mcp_write(ser, 0x8102, 0xFF)  # B
time.sleep(0.3)

# Check status
status = mcp_read(ser, 0x8300)
print(f"   LA Status: 0x{status:02X} {'(Armed)' if status & 0x01 else '(Done)'}")

# Read first 32 samples
print("\n5. First 32 samples (bit 0 = rgb_led):")
samples = []
for i in range(32):
    addr = 0x8300 + 0x80 + i  # Data starts at offset 0x80
    val = mcp_read(ser, addr)
    if val is not None:
        samples.append(val)
        bit0 = val & 0x01
        print(f"   Sample {i:2d}: 0x{val:02X} (bit0={bit0})")

# Look for transitions
if samples:
    print("\n6. Transition analysis:")
    trans_count = 0
    for i in range(1, len(samples)):
        if (samples[i] & 0x01) != (samples[i-1] & 0x01):
            trans_count += 1
            direction = "↑" if (samples[i] & 0x01) else "↓"
            print(f"   Transition at sample {i}: {direction}")
            if trans_count >= 10:
                break
    
    if trans_count == 0:
        print("   No transitions found")

ser.close()
