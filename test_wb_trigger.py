#!/usr/bin/env python3
"""Trigger on RGB LED Wishbone write and capture transaction"""

import serial
import time

def mcp_write(ser, address, data):
    """Write to Wishbone address via MCP text command"""
    ser.read(ser.in_waiting)
    cmd = f"W {address:04X} {data:02X}\n"
    ser.write(cmd.encode())
    time.sleep(0.05)
    response = ser.read(ser.in_waiting)
    return response.decode('utf-8', errors='ignore')

def mcp_read(ser, address):
    """Read from Wishbone address via MCP text command"""
    ser.read(ser.in_waiting)
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
    except:
        pass
    return None

def decode_sample(sample):
    """Decode captured sample into signal states
    [31:24] = wb_cyc_o, wb_stb_o, wb_we_o, wb_ack_i, wb_adr_o[15:12]
    [23:8]  = wb_adr_o[11:0], wb_dat_o[7:4]
    [7:0]   = rgb_led_selected, sid_selected, ym2149_selected, la_selected, wb_dat_o[3:0]
    """
    # Extract fields
    wb_cyc = (sample >> 31) & 1
    wb_stb = (sample >> 30) & 1
    wb_we = (sample >> 29) & 1
    wb_ack = (sample >> 28) & 1
    wb_adr_hi = (sample >> 24) & 0x0F
    wb_adr_mid = (sample >> 12) & 0x0FFF
    wb_dat_hi = (sample >> 8) & 0x0F
    wb_dat_lo = sample & 0x0F
    
    rgb_led_sel = (sample >> 7) & 1
    sid_sel = (sample >> 6) & 1
    ym_sel = (sample >> 5) & 1
    la_sel = (sample >> 4) & 1
    
    addr = (wb_adr_hi << 12) | wb_adr_mid
    data = (wb_dat_hi << 4) | wb_dat_lo
    
    return {
        'cyc': wb_cyc,
        'stb': wb_stb,
        'we': wb_we,
        'ack': wb_ack,
        'addr': addr,
        'data': data,
        'rgb_sel': rgb_led_sel,
        'sid_sel': sid_sel,
        'ym_sel': ym_sel,
        'la_sel': la_sel
    }

def main():
    ser = serial.Serial('COM4', 115200, timeout=1)
    time.sleep(0.5)
    
    print("Logic Analyzer - Wishbone RGB LED Transaction Capture")
    print("=" * 70)
    
    LA_BASE = 0x8300
    RGB_LED_BASE = 0x8100
    
    REG_CONTROL = LA_BASE + 0x00
    REG_STATUS = LA_BASE + 0x01
    REG_DEVICE_ID_0 = LA_BASE + 0x02
    REG_TRIGGER_MASK_0 = LA_BASE + 0x10
    REG_TRIGGER_VALUE_0 = LA_BASE + 0x18
    REG_SAMPLE_BASE = LA_BASE + 0x80
    
    print("\n1. Verifying LA device ID...")
    id0 = mcp_read(ser, REG_DEVICE_ID_0)
    id1 = mcp_read(ser, REG_DEVICE_ID_0 + 1)
    if id0 == 0x53 and id1 == 0x55:
        print(f"   ✓ Device ID: 0x5355 ('SU')")
    else:
        print(f"   ✗ Failed")
        return
    
    print("\n2. Configuring trigger...")
    print("   Trigger on: wb_stb_o = 1 (bit 30)")
    
    # Set trigger mask (bit 30 = wb_stb_o)
    # Byte 3 of mask (bits 31:24) includes bit 30
    trigger_mask_byte3 = 0x40  # bit 30 (wb_stb in bit position 6 of byte 3)
    mcp_write(ser, REG_TRIGGER_MASK_0 + 3, trigger_mask_byte3)
    
    # Set trigger value (wb_stb_o should be 1)
    trigger_value_byte3 = 0x40
    mcp_write(ser, REG_TRIGGER_VALUE_0 + 3, trigger_value_byte3)
    
    print(f"   Trigger mask byte 3: 0x{trigger_mask_byte3:02X}")
    print(f"   Trigger value byte 3: 0x{trigger_value_byte3:02X}")
    
    print("\n3. Arming logic analyzer and immediately writing to RGB LED...")
    # Arm LA
    mcp_write(ser, REG_CONTROL, 0x01)
    time.sleep(0.05)
    
    # Immediately write to RGB LED without checking status
    print("   Writing RED (0xFF, 0x00, 0x00) to RGB LED at 0x8100-0x8102...")
    mcp_write(ser, RGB_LED_BASE, 0xFF)  # Red
    mcp_write(ser, RGB_LED_BASE + 1, 0x00)  # Green
    mcp_write(ser, RGB_LED_BASE + 2, 0x00)  # Blue
    
    time.sleep(0.3)
    
    print("\n4. Checking capture status...")
    status = mcp_read(ser, REG_STATUS)
    status_val = status if status is not None else 0
    triggered = status_val & 0x80
    print(f"   Status: 0x{status_val:02X}")
    if triggered:
        print("   ✓ Triggered!")
    else:
        print("   ⚠ Not triggered")
    
    print("\n5. Reading captured samples (first 64 samples)...")
    samples_bytes = []
    for i in range(256):  # Read 256 bytes to get 64 complete 32-bit samples
        addr = REG_SAMPLE_BASE + (i % 128)
        value = mcp_read(ser, addr)
        if value is not None:
            samples_bytes.append(value)
        else:
            samples_bytes.append(0)
        time.sleep(0.02)
    
    # Reconstruct 32-bit samples from bytes
    samples_32bit = []
    for i in range(0, len(samples_bytes), 4):
        if i + 3 < len(samples_bytes):
            sample = (samples_bytes[i] << 24) | (samples_bytes[i+1] << 16) | \
                     (samples_bytes[i+2] << 8) | samples_bytes[i+3]
            samples_32bit.append(sample)
    
    print(f"\n   Captured {len(samples_32bit)} complete 32-bit samples")
    print("\n   Sample | CYC STB WE ACK | Address | Data | RGB SID YM  LA  | Hex Value")
    print("   " + "-" * 76)
    
    for idx in range(min(32, len(samples_32bit))):
        s = decode_sample(samples_32bit[idx])
        print(f"   {idx:4d}   |  {s['cyc']}   {s['stb']}   {s['we']}  {s['ack']}  | "
              f"0x{s['addr']:04X}  | 0x{s['data']:02X} |  {s['rgb_sel']}   {s['sid_sel']}   {s['ym_sel']}   {s['la_sel']}  | "
              f"0x{samples_32bit[idx]:08X}")
    
    print("\n6. Finding Wishbone transactions (STB=1)...")
    transactions = []
    for idx, s in enumerate([decode_sample(samp) for samp in samples_32bit]):
        if s['stb'] == 1:
            transactions.append((idx, s))
    
    if transactions:
        print(f"   Found {len(transactions)} transaction(s):")
        for idx, s in transactions[:10]:  # Show first 10
            op = "WRITE" if s['we'] else "READ"
            peripheral = "RGB_LED" if s['rgb_sel'] else ("SID" if s['sid_sel'] else 
                        ("YM2149" if s['ym_sel'] else ("LA" if s['la_sel'] else "OTHER")))
            print(f"   Sample {idx:4d}: {op:5s} to {peripheral:7s} @ 0x{s['addr']:04X} = 0x{s['data']:02X}, ACK={s['ack']}")
    else:
        print("   No transactions found in capture")
    
    print("\n" + "=" * 70)
    print("Capture complete!")
    
    ser.close()

if __name__ == "__main__":
    main()
