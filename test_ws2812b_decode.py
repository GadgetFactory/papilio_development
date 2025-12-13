#!/usr/bin/env python3
"""Capture and decode WS2812B LED protocol from Logic Analyzer"""

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

def decode_ws2812b_bit(high_count, low_count):
    """Decode WS2812B bit based on timing
    At 27 MHz: 
    - '1' bit: ~22 samples high, ~12 samples low
    - '0' bit: ~11 samples high, ~23 samples low
    """
    # Allow some tolerance
    if high_count > 17:  # More than ~0.6µs high = '1'
        return 1
    else:  # Less = '0'
        return 0

def find_ws2812b_data(samples, bit_position=0):
    """Extract WS2812B data from captured samples
    
    Args:
        samples: List of 32-bit sample values
        bit_position: Which bit to examine (0-31)
    """
    bits = []
    i = 0
    
    # Skip leading low (reset period)
    while i < len(samples) and not (samples[i] & (1 << bit_position)):
        i += 1
    
    if i >= len(samples):
        return None, "No rising edge found"
    
    # Decode bits
    while i < len(samples) and len(bits) < 24:
        # Count high samples
        high_count = 0
        while i < len(samples) and (samples[i] & (1 << bit_position)):
            high_count += 1
            i += 1
        
        if high_count == 0:
            break
        
        # Count low samples
        low_count = 0
        while i < len(samples) and not (samples[i] & (1 << bit_position)):
            low_count += 1
            i += 1
        
        # Decode bit
        bit = decode_ws2812b_bit(high_count, low_count)
        bits.append(bit)
        
        # Debug first few bits
        if len(bits) <= 3:
            print(f"  Bit {len(bits)-1}: high={high_count}, low={low_count} -> {bit}")
    
    if len(bits) < 24:
        return None, f"Only found {len(bits)} bits"
    
    # Convert to GRB bytes
    g = sum(bits[i] << (7-i) for i in range(8))
    r = sum(bits[8+i] << (7-i) for i in range(8))
    b = sum(bits[16+i] << (7-i) for i in range(8))
    
    return (g, r, b), f"Decoded {len(bits)} bits"

ser = serial.Serial('COM4', 115200, timeout=1)
time.sleep(0.5)

print("WS2812B Protocol Capture and Decode")
print("=" * 60)

# Set LED to RED (G=0x00, R=0xFF, B=0x00)
print("\n1. Setting LED to RED (G=0x00, R=0xFF, B=0x00)...")
mcp_write(ser, 0x8100, 0x00)  # G
mcp_write(ser, 0x8101, 0xFF)  # R
mcp_write(ser, 0x8102, 0x00)  # B
time.sleep(0.1)

# Verify registers
g = mcp_read(ser, 0x8100)
r = mcp_read(ser, 0x8101)
b = mcp_read(ser, 0x8102)
print(f"   Registers: G=0x{g:02X}, R=0x{r:02X}, B=0x{b:02X}")

# Arm LA and immediately trigger
print("\n2. Arming Logic Analyzer and triggering LED update...")
mcp_write(ser, 0x8300, 0x01)
time.sleep(0.001)  # Minimal delay

# Trigger by changing LED color
print("   Changing LED to BLUE...")
mcp_write(ser, 0x8100, 0x00)  # G
mcp_write(ser, 0x8101, 0x00)  # R
mcp_write(ser, 0x8102, 0xFF)  # B
time.sleep(0.3)  # Wait for capture to complete

# Read LA status
status = mcp_read(ser, 0x8300)
print(f"   LA Status: 0x{status:02X} {'(Armed)' if status & 0x01 else '(Done)'}")

# Read samples
print("\n3. Reading captured samples...")
samples = []
for addr in range(0x8304, 0x8304 + 1024):
    val = mcp_read(ser, addr)
    if val is not None:
        samples.append(val)

print(f"   Read {len(samples)} samples")

if len(samples) >= 50:
    # Show first 16 samples with bit 0 (rgb_led signal)
    print("\n4. First 16 samples (bit 0 = rgb_led):")
    for i in range(min(16, len(samples))):
        bit_val = (samples[i] & 0x01)
        print(f"   Sample {i:3d}: 0x{samples[i]:08X} -> rgb_led={bit_val}")
    
    # Decode WS2812B data from bit 0
    print("\n5. Decoding WS2812B protocol from bit 0:")
    result, msg = find_ws2812b_data(samples, bit_position=0)
    print(f"   {msg}")
    
    if result:
        g, r, b = result
        print(f"\n   Decoded GRB: G=0x{g:02X}, R=0x{r:02X}, B=0x{b:02X}")
        
        # Expected is BLUE: G=0x00, R=0x00, B=0xFF
        expected_g, expected_r, expected_b = 0x00, 0x00, 0xFF
        match = (g == expected_g and r == expected_r and b == expected_b)
        
        print(f"   Expected:    G=0x{expected_g:02X}, R=0x{expected_r:02X}, B=0x{expected_b:02X}")
        print(f"\n   Result: {'✓ MATCH' if match else '✗ MISMATCH'}")
    
    # Also try decoding from bit 31 (should be same signal)
    print("\n6. Verifying with bit 31 (should match):")
    result2, msg2 = find_ws2812b_data(samples, bit_position=31)
    print(f"   {msg2}")
    if result2:
        g2, r2, b2 = result2
        print(f"   Decoded GRB: G=0x{g2:02X}, R=0x{r2:02X}, B=0x{b2:02X}")

print("\nDone!")
ser.close()
