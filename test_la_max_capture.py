#!/usr/bin/env python3
"""Capture maximum samples (1024) from Logic Analyzer via MCP"""

import serial
import time

def mcp_write(ser, address, data):
    """Write to Wishbone address via MCP text command"""
    ser.read(ser.in_waiting)  # Clear buffer
    cmd = f"W {address:04X} {data:02X}\n"
    ser.write(cmd.encode())
    time.sleep(0.05)
    response = ser.read(ser.in_waiting)
    return response.decode('utf-8', errors='ignore')

def mcp_read(ser, address):
    """Read from Wishbone address via MCP text command"""
    ser.read(ser.in_waiting)  # Clear buffer
    cmd = f"R {address:04X}\n"
    ser.write(cmd.encode())
    time.sleep(0.1)  # Increased delay
    response = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
    
    try:
        if '=' in response:
            value_str = response.split('=')[1].strip().split()[0]
            return int(value_str, 16)
        elif ':' in response:
            value_str = response.split(':')[1].strip().split()[0]
            return int(value_str, 16)
    except Exception as e:
        pass
    return None

def main():
    ser = serial.Serial('COM4', 115200, timeout=1)
    time.sleep(0.5)
    
    print("Logic Analyzer - Maximum Capture Test")
    print("=" * 60)
    
    LA_BASE = 0x8300
    REG_DEVICE_ID_0 = LA_BASE + 0x02
    REG_DEVICE_ID_1 = LA_BASE + 0x03
    REG_CONTROL = LA_BASE + 0x00
    REG_STATUS = LA_BASE + 0x01
    REG_SAMPLE_BASE = LA_BASE + 0x80
    
    print("\n1. Verifying device ID...")
    id0 = mcp_read(ser, REG_DEVICE_ID_0)
    id1 = mcp_read(ser, REG_DEVICE_ID_1)
    
    if id0 == 0x53 and id1 == 0x55:
        print(f"   ✓ Device ID: 0x{(id0 << 8) | id1:04X} ('SU')")
    else:
        print(f"   ✗ Unexpected device ID")
        return
    
    print("\n2. Arming logic analyzer...")
    mcp_write(ser, REG_CONTROL, 0x01)
    time.sleep(0.2)
    
    status = mcp_read(ser, REG_STATUS)
    if status and (status & 0x80):
        print(f"   ✓ Triggered (status: 0x{status:02X})")
    else:
        print(f"   ⚠ Status: 0x{status:02X if status else 0:02X}")
    
    print("\n3. Capturing maximum samples (1024 samples = 8 passes through window)...")
    print("   Reading 128 bytes per pass...")
    
    all_samples = []
    
    # Read through the 128-byte window 8 times to get all 1024 samples
    for pass_num in range(8):
        print(f"\n   Pass {pass_num + 1}/8...")
        pass_samples = []
        
        for i in range(128):
            addr = REG_SAMPLE_BASE + i
            value = mcp_read(ser, addr)
            if value is not None:
                pass_samples.append(value)
            else:
                pass_samples.append(0)
            
            # Reduced delay for faster capture
            time.sleep(0.02)
        
        all_samples.extend(pass_samples)
        print(f"   Captured {len(pass_samples)} samples (total: {len(all_samples)})")
        
        # Show sample from this pass
        if pass_samples:
            print(f"   Sample range: 0x{min(pass_samples):02X} to 0x{max(pass_samples):02X}")
    
    print(f"\n4. Analysis of {len(all_samples)} samples:")
    print(f"   Total samples: {len(all_samples)}")
    print(f"   Value range: 0x{min(all_samples):02X} to 0x{max(all_samples):02X}")
    
    # Show unique values
    unique_values = sorted(set(all_samples))
    print(f"   Unique values: {len(unique_values)}")
    print(f"   First 20 unique: {[f'0x{v:02X}' for v in unique_values[:20]]}")
    
    # Show pattern of first 64 samples
    print("\n5. First 64 samples:")
    for i in range(0, 64, 16):
        samples_line = " ".join([f"{all_samples[i+j]:02X}" for j in range(16)])
        print(f"   [{i:4d}-{i+15:4d}]: {samples_line}")
    
    # Show last 64 samples
    print("\n6. Last 64 samples:")
    start = len(all_samples) - 64
    for i in range(start, start + 64, 16):
        samples_line = " ".join([f"{all_samples[i+j]:02X}" for j in range(16)])
        print(f"   [{i:4d}-{i+15:4d}]: {samples_line}")
    
    print("\n" + "=" * 60)
    print("Maximum sample capture complete!")
    
    ser.close()

if __name__ == "__main__":
    main()
