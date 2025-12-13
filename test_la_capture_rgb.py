#!/usr/bin/env python3
"""Trigger logic analyzer on RGB LED Wishbone write and capture transaction"""

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

def main():
    ser = serial.Serial('COM4', 115200, timeout=1)
    time.sleep(0.5)
    
    print("Logic Analyzer - Capture RGB LED Wishbone Transaction")
    print("=" * 60)
    print("\nProbe signal mapping (32 bits):")
    print("  [31:28] = wb_cyc, wb_stb, wb_we, wb_ack, wb_adr[15:12]")
    print("  [23:16] = wb_adr[11:4]")
    print("  [15:8]  = wb_adr[3:0], chip selects")
    print("  [7:0]   = wb_dat_o[7:0]")
    
    LA_BASE = 0x8300
    REG_CONTROL = LA_BASE + 0x00
    REG_STATUS = LA_BASE + 0x01
    REG_DEVICE_ID_0 = LA_BASE + 0x02
    REG_SAMPLE_BASE = LA_BASE + 0x80
    
    print("\n1. Verifying LA...")
    id0 = mcp_read(ser, REG_DEVICE_ID_0)
    id1 = mcp_read(ser, REG_DEVICE_ID_0 + 1)
    if id0 == 0x53 and id1 == 0x55:
        print(f"   ✓ Device ID: 'SU'")
    else:
        print(f"   ✗ Unexpected ID")
        return
    
    print("\n2. Setting LED to GREEN (initial state)...")
    mcp_write(ser, 0x8100, 0xFF)  # G = 255 (for WS2812B GRB order)
    mcp_write(ser, 0x8101, 0x00)  # R = 0
    mcp_write(ser, 0x8102, 0x00)  # B = 0
    time.sleep(0.3)
    print("   LED should be GREEN")
    
    print("\n3. Arming logic analyzer and immediately writing...")
    print("   Arming LA...")
    mcp_write(ser, REG_CONTROL, 0x01)
    # Immediately write to RGB LED with minimal delay
    time.sleep(0.05)
    
    print("   Writing RED to trigger capture...")
    mcp_write(ser, 0x8101, 0xFF)  # R = 255 - just write one register
    time.sleep(0.1)
    print("   LED should be RED")
    
    print("\n5. Checking trigger status...")
    status = mcp_read(ser, REG_STATUS)
    if status and (status & 0x80):
        print(f"   ✓ Triggered! (status: 0x{status:02X})")
    else:
        print(f"   ⚠ Not triggered (status: 0x{status:02X if status else 0:02X})")
    
    print("\n6. Reading first 32 captured samples...")
    print("   Looking for Wishbone activity patterns...")
    print("\n   Sample | Bits [31:24] | Bits [23:16] | Bits [15:8] | Bits [7:0]")
    print("   " + "-" * 70)
    
    samples = []
    for i in range(32):
        value = mcp_read(ser, REG_SAMPLE_BASE + i)
        if value is not None:
            samples.append(value)
        else:
            samples.append(0)
        time.sleep(0.02)
    
    # Display samples in groups of 4 bytes (32-bit samples)
    for i in range(0, 32, 4):
        byte3 = samples[i]     # [31:24]
        byte2 = samples[i+1]   # [23:16]
        byte1 = samples[i+2]   # [15:8]
        byte0 = samples[i+3]   # [7:0]
        
        sample_num = i // 4
        print(f"   {sample_num:4d}   |   {byte3:08b}   | {byte2:08b}   | {byte1:08b}  | {byte0:08b}")
        print(f"          |   0x{byte3:02X}       | 0x{byte2:02X}       | 0x{byte1:02X}      | 0x{byte0:02X}")
        
        # Decode key signals from byte3 [31:24]
        wb_cyc = (byte3 >> 7) & 1
        wb_stb = (byte3 >> 6) & 1
        wb_we = (byte3 >> 5) & 1
        wb_ack = (byte3 >> 4) & 1
        
        if wb_stb and wb_we:
            # Reconstruct address from bytes
            addr_hi = byte3 & 0x0F
            addr_mid = byte2
            addr_lo = (byte1 >> 4) & 0x0F
            address = (addr_hi << 12) | (addr_mid << 4) | addr_lo
            data = byte0
            print(f"          → WB WRITE: addr=0x{address:04X}, data=0x{data:02X}, ack={wb_ack}")
        
        print()
    
    print("=" * 60)
    print("Capture complete!")
    print("\nLook for patterns with wb_stb=1, wb_we=1 (write operations)")
    print("Address 0x8100-0x8102 = RGB LED registers")
    
    ser.close()

if __name__ == "__main__":
    main()
