#!/usr/bin/env python3
"""Test Logic Analyzer via MCP protocol"""

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
    time.sleep(0.1)
    response = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
    
    try:
        if '=' in response:
            value_str = response.split('=')[1].strip().split()[0]
            return int(value_str, 16)
        elif ':' in response:
            value_str = response.split(':')[1].strip().split()[0]
            return int(value_str, 16)
    except Exception as e:
        print(f"    Parse error: {e}, response: {repr(response)}")
    return None

def main():
    ser = serial.Serial('COM4', 115200, timeout=1)
    time.sleep(0.5)
    
    print("Logic Analyzer Test via MCP")
    print("=" * 60)
    
    # LA base address
    LA_BASE = 0x8300
    
    # Register offsets (from wb_logic_analyzer.v)
    REG_DEVICE_ID_0 = LA_BASE + 0x02  # Should be 0x53 ('S')
    REG_DEVICE_ID_1 = LA_BASE + 0x03  # Should be 0x55 ('U')
    REG_CONTROL = LA_BASE + 0x00
    REG_STATUS = LA_BASE + 0x01
    REG_SAMPLE_BASE = LA_BASE + 0x80  # Sample window starts at 0x80
    
    print("\n1. Reading Device ID...")
    id0 = mcp_read(ser, REG_DEVICE_ID_0)
    id1 = mcp_read(ser, REG_DEVICE_ID_1)
    
    if id0 is not None and id1 is not None:
        device_id = (id0 << 8) | id1
        print(f"   Device ID: 0x{device_id:04X}")
        if id0 == 0x53 and id1 == 0x55:
            print(f"   ✓ Correct! ('SU' = SUMP)")
        else:
            print(f"   ✗ Expected 0x5355 ('SU'), got 0x{device_id:04X}")
    else:
        print(f"   ✗ Failed to read device ID")
        print(f"   ID0: {id0}, ID1: {id1}")
        return
    
    print("\n2. Reading initial status...")
    status = mcp_read(ser, REG_STATUS)
    if status is not None:
        print(f"   Status: 0x{status:02X}")
        print(f"   - Triggered: {'Yes' if status & 0x80 else 'No'}")
    else:
        print(f"   ✗ Failed to read status")
    
    print("\n3. Arming the logic analyzer...")
    # Control register: bit 0 = arm
    mcp_write(ser, REG_CONTROL, 0x01)
    time.sleep(0.1)
    
    print("   Reading status after arming...")
    status = mcp_read(ser, REG_STATUS)
    if status is not None:
        print(f"   Status: 0x{status:02X}")
        print(f"   - Triggered: {'Yes' if status & 0x80 else 'No'}")
    
    print("\n4. Waiting for trigger (will trigger immediately)...")
    time.sleep(0.2)
    
    status = mcp_read(ser, REG_STATUS)
    if status is not None:
        print(f"   Status: 0x{status:02X}")
        triggered = status & 0x80
        print(f"   - Triggered: {'Yes' if triggered else 'No'}")
        
        if triggered:
            print("   ✓ Capture complete!")
        else:
            print("   ⚠ Not triggered yet")
    
    print("\n5. Reading captured samples (full 128 byte window)...")
    print("   Capturing all samples from 0x8380-0x83FF...")
    
    samples = []
    for i in range(128):
        addr = REG_SAMPLE_BASE + i
        value = mcp_read(ser, addr)
        if value is not None:
            samples.append(value)
        else:
            samples.append(0)
        
        # Print progress every 16 samples
        if (i + 1) % 16 == 0:
            print(f"   Read {i + 1}/128 samples...")
        time.sleep(0.02)
    
    print("\n   All 128 samples:")
    print("   Addr     | Value | Addr     | Value | Addr     | Value | Addr     | Value")
    print("   " + "-" * 76)
    for row in range(32):  # 128 samples / 4 columns = 32 rows
        line = "   "
        for col in range(4):
            idx = row * 4 + col
            if idx < len(samples):
                addr = REG_SAMPLE_BASE + idx
                value = samples[idx]
                line += f"0x{addr:04X} | 0x{value:02X}  | "
        print(line.rstrip(" | "))
    
    print(f"\n   Total samples captured: {len(samples)}")
    print(f"   Value range: 0x{min(samples):02X} to 0x{max(samples):02X}")
    
    print("\n6. Re-arming and reading a few more samples...")
    mcp_write(ser, REG_CONTROL, 0x01)
    time.sleep(0.2)
    
    status = mcp_read(ser, REG_STATUS)
    if status and (status & 0x80):
        print("   ✓ Second capture complete!")
        print("\n   First 8 samples from second capture:")
        for i in range(8):
            addr = REG_SAMPLE_BASE + i
            value = mcp_read(ser, addr)
            if value is not None:
                print(f"   Sample {i}: 0x{value:02X} = {value:08b}")
            time.sleep(0.05)
    
    print("\n" + "=" * 60)
    print("Logic Analyzer test complete!")
    print("\nNote: The LA captures 32-bit samples but we're reading")
    print("8-bit chunks via the Wishbone interface.")
    
    ser.close()

if __name__ == "__main__":
    main()
