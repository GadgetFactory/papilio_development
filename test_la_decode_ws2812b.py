#!/usr/bin/env python3
"""
Test script to capture and decode WS2812B LED serial protocol using Logic Analyzer

WS2812B Protocol:
- Bit rate: ~800 kHz (1.25µs per bit)
- '1' bit: HIGH ~0.8µs, LOW ~0.45µs
- '0' bit: HIGH ~0.4µs, LOW ~0.85µs
- 24 bits per LED: [G7:G0][R7:R0][B7:B0] (GRB order)
- Reset: LOW >50µs

At 27 MHz LA sample rate:
- 1 bit = ~34 samples (1.25µs * 27 MHz)
- '1' HIGH = ~22 samples (0.8µs * 27 MHz)
- '0' HIGH = ~11 samples (0.4µs * 27 MHz)
"""

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

def decode_ws2812b_bit(high_count, low_count, total_count):
    """
    Decode a WS2812B bit based on HIGH/LOW sample counts
    Returns '1', '0', or None if indeterminate
    """
    # At 27 MHz:
    # '1' bit: ~22 HIGH, ~12 LOW (total ~34)
    # '0' bit: ~11 HIGH, ~23 LOW (total ~34)
    
    if total_count < 20 or total_count > 50:
        return None  # Invalid bit period
    
    high_ratio = high_count / total_count
    
    if high_ratio > 0.6:  # More than 60% high = '1'
        return '1'
    elif high_ratio < 0.4:  # Less than 40% high = '0'
        return '0'
    else:
        return None  # Unclear

def decode_ws2812b_samples(samples, bit_index):
    """
    Decode WS2812B protocol from captured samples
    bit_index specifies which bit of the 32-bit sample contains rgb_led signal
    Returns (green, red, blue) tuple or None if decode fails
    """
    # Extract rgb_led signal from samples
    rgb_led_samples = [(sample >> bit_index) & 1 for sample in samples]
    
    # Find transitions and decode bits
    bits = []
    i = 0
    while i < len(rgb_led_samples) and len(bits) < 24:
        # Look for start of bit (LOW to HIGH transition)
        while i < len(rgb_led_samples) and rgb_led_samples[i] == 0:
            i += 1
        
        if i >= len(rgb_led_samples):
            break
            
        # Count HIGH samples
        high_start = i
        while i < len(rgb_led_samples) and rgb_led_samples[i] == 1:
            i += 1
        high_count = i - high_start
        
        # Count LOW samples
        low_start = i
        while i < len(rgb_led_samples) and rgb_led_samples[i] == 0:
            i += 1
        low_count = i - low_start
        
        total_count = high_count + low_count
        bit = decode_ws2812b_bit(high_count, low_count, total_count)
        
        if bit is not None:
            bits.append(bit)
        elif total_count > 10:  # Only report if significant period
            print(f"  Unclear bit at sample {high_start}: HIGH={high_count}, LOW={low_count}")
    
    print(f"\nDecoded {len(bits)} bits from WS2812B stream")
    
    if len(bits) < 24:
        print(f"  Warning: Only decoded {len(bits)}/24 bits")
        return None
    
    # Convert first 24 bits to bytes (GRB order)
    bit_string = ''.join(bits[:24])
    green = int(bit_string[0:8], 2)
    red = int(bit_string[8:16], 2)
    blue = int(bit_string[16:24], 2)
    
    return (green, red, blue)

def main():
    ser = serial.Serial('COM4', 115200, timeout=1)
    time.sleep(0.5)
    
    print("=" * 70)
    print("WS2812B LED Protocol Capture Test")
    print("=" * 70)
    
    # Read current LED color
    print("\n1. Reading current RGB LED state...")
    green_reg = mcp_read(ser, 0x8100)
    red_reg = mcp_read(ser, 0x8101)
    blue_reg = mcp_read(ser, 0x8102)
    print(f"   Current: G=0x{green_reg:02X}, R=0x{red_reg:02X}, B=0x{blue_reg:02X}")
    
    # Set LED to a known color (RED)
    print("\n2. Setting LED to RED (G=0x00, R=0xFF, B=0x00)...")
    mcp_write(ser, 0x8100, 0x00)  # Green = 0
    mcp_write(ser, 0x8101, 0xFF)  # Red = 255
    mcp_write(ser, 0x8102, 0x00)  # Blue = 0
    
    time.sleep(0.1)  # Wait for LED to update
    
    # Arm logic analyzer
    print("\n3. Arming Logic Analyzer (1024 samples at 27 MHz)...")
    mcp_write(ser, 0x8300, 0x01)  # Arm LA
    
    # Trigger by updating LED again (forces new WS2812B transmission)
    print("\n4. Triggering capture by refreshing LED...")
    mcp_write(ser, 0x8101, 0xFF)  # Write red register again to trigger update
    time.sleep(0.01)
    
    # Read samples
    print("\n5. Reading captured samples...")
    samples = []
    for addr in range(0x8000, 0x8400, 4):
        data = mcp_read(ser, addr)
        samples.append(data)
    
    print(f"   Captured {len(samples)} samples")
    
    # Show first few samples
    print("\n6. First 16 samples (32-bit hex):")
    for i in range(min(16, len(samples))):
        print(f"   Sample {i:3d}: 0x{samples[i]:08X}")
    
    # Decode WS2812B from bit 31 (top bit where we duplicated rgb_led)
    print("\n7. Decoding WS2812B protocol from bit 31...")
    result = decode_ws2812b_samples(samples, bit_index=31)
    
    if result:
        green, red, blue = result
        print(f"\n   Decoded: G=0x{green:02X}, R=0x{red:02X}, B=0x{blue:02X}")
        print(f"   Expected: G=0x00, R=0xFF, B=0x00")
        
        if green == 0x00 and red == 0xFF and blue == 0x00:
            print("\n   ✓ SUCCESS: Captured data matches RED!")
        else:
            print(f"\n   ✗ MISMATCH: Got different values")
            print(f"     Difference: G={green-0x00:+d}, R={red-0xFF:+d}, B={blue-0x00:+d}")
    else:
        print("\n   ✗ Failed to decode WS2812B protocol")
        print("   Trying bit 7 (lower duplicate)...")
        result = decode_ws2812b_samples(samples, bit_index=7)
        if result:
            green, red, blue = result
            print(f"\n   Decoded: G=0x{green:02X}, R=0x{red:02X}, B=0x{blue:02X}")
    
    # Show bit transition statistics
    print("\n8. Signal analysis (bit 31):")
    rgb_led_samples = [(sample >> 31) & 1 for sample in samples]
    transitions = sum(1 for i in range(len(rgb_led_samples)-1) 
                     if rgb_led_samples[i] != rgb_led_samples[i+1])
    ones = sum(rgb_led_samples)
    zeros = len(rgb_led_samples) - ones
    print(f"   Total samples: {len(rgb_led_samples)}")
    print(f"   HIGH samples: {ones} ({100*ones/len(rgb_led_samples):.1f}%)")
    print(f"   LOW samples: {zeros} ({100*zeros/len(rgb_led_samples):.1f}%)")
    print(f"   Transitions: {transitions}")
    print(f"   Expected transitions: ~48 (24 bits × 2)")

if __name__ == '__main__':
    main()
