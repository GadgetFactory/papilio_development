#!/usr/bin/env python3
"""
Visualize full Wishbone bus capture with all signals.
Reads all 4 bytes of each 32-bit sample.
"""

import serial
import time

def mcp_write(ser, address, data):
    """Write to MCP register"""
    cmd = bytes([
        0x02,  # Write command
        (address >> 8) & 0xFF,
        address & 0xFF,
        data & 0xFF
    ])
    ser.write(cmd)
    # Read ACK
    ack = ser.read(1)
    time.sleep(0.001)

def mcp_read(ser, address):
    """Read from MCP register"""
    cmd = bytes([
        0x03,  # Read command
        (address >> 8) & 0xFF,
        address & 0xFF
    ])
    ser.write(cmd)
    response = ser.read(1)
    return response[0] if response else 0xFF

def read_full_sample(ser, sample_idx):
    """Read all 4 bytes of a 32-bit sample"""
    base_addr = 0x8380 + (sample_idx * 4)
    byte0 = mcp_read(ser, base_addr + 0)  # [7:0]
    byte1 = mcp_read(ser, base_addr + 1)  # [15:8]
    byte2 = mcp_read(ser, base_addr + 2)  # [23:16]
    byte3 = mcp_read(ser, base_addr + 3)  # [31:24]
    return (byte3 << 24) | (byte2 << 16) | (byte1 << 8) | byte0

def decode_sample(sample):
    """Decode all signals from 32-bit sample"""
    # [31:24] = wb_dat_o[7:0]
    wb_dat = (sample >> 24) & 0xFF
    
    # [23:16] = Control signals
    ctrl_byte = (sample >> 16) & 0xFF
    wb_cyc = (ctrl_byte >> 7) & 1
    wb_stb = (ctrl_byte >> 6) & 1
    wb_we = (ctrl_byte >> 5) & 1
    wb_ack = (ctrl_byte >> 4) & 1
    rgb_sel = (ctrl_byte >> 3) & 1
    sid_sel = (ctrl_byte >> 2) & 1
    ym_sel = (ctrl_byte >> 1) & 1
    la_sel = (ctrl_byte >> 0) & 1
    
    # [15:8] = wb_adr_o[7:0]
    wb_adr = (sample >> 8) & 0xFF
    
    # [7:0] = Debug signals
    debug_byte = sample & 0xFF
    rgb_led = (debug_byte >> 7) & 1
    esp_cs = (debug_byte >> 6) & 1
    esp_clk = (debug_byte >> 5) & 1
    esp_mosi = (debug_byte >> 4) & 1
    esp_miso = (debug_byte >> 3) & 1
    clk_27 = (debug_byte >> 2) & 1
    rst = (debug_byte >> 1) & 1
    audio = (debug_byte >> 0) & 1
    
    return {
        'wb_dat': wb_dat,
        'wb_cyc': wb_cyc,
        'wb_stb': wb_stb,
        'wb_we': wb_we,
        'wb_ack': wb_ack,
        'rgb_sel': rgb_sel,
        'wb_adr': wb_adr,
        'rgb_led': rgb_led,
    }

def main():
    # Open serial port
    ser = serial.Serial('COM4', 115200, timeout=1)
    time.sleep(0.1)
    
    print("Wishbone Bus Visualization")
    print("=" * 80)
    
    # 1. Set LED to GREEN baseline
    print("1. Setting LED to GREEN...")
    mcp_write(ser, 0x8100, 0xFF)  # G = 255
    mcp_write(ser, 0x8101, 0x00)  # R = 0
    mcp_write(ser, 0x8102, 0x00)  # B = 0
    time.sleep(0.1)
    
    # 2. Configure trigger: wb_dat_o = 0xAB (on bits [31:24])
    print("2. Configuring trigger (wb_dat_o = 0xAB)...")
    # trigger_mask [31:24] = 0xFF (check data bus)
    mcp_write(ser, 0x8304, 0x00)  # mask [7:0]
    mcp_write(ser, 0x8305, 0x00)  # mask [15:8]
    mcp_write(ser, 0x8306, 0x00)  # mask [23:16]
    mcp_write(ser, 0x8307, 0xFF)  # mask [31:24] = check wb_dat_o
    
    # trigger_value [31:24] = 0xAB
    mcp_write(ser, 0x8308, 0x00)  # value [7:0]
    mcp_write(ser, 0x8309, 0x00)  # value [15:8]
    mcp_write(ser, 0x830A, 0x00)  # value [23:16]
    mcp_write(ser, 0x830B, 0xAB)  # value [31:24] = unique value
    
    # 3. Arm LA
    print("3. Arming LA...")
    mcp_write(ser, 0x8300, 0x01)  # ARM command
    time.sleep(0.01)
    
    # 4. Trigger with unique value
    print("4. Writing unique value (R = 0xAB)...")
    mcp_write(ser, 0x8101, 0xAB)  # Write to Red register
    time.sleep(0.05)
    
    # Check status
    status = mcp_read(ser, 0x8300)
    print(f"   Status: 0x{status:02X}", end="")
    if status & 0x04:
        print(" (TRIGGERED!)")
    else:
        print(" (not triggered)")
        return
    
    # 5. Read captured samples (read 128 samples = 512 bytes)
    print("\n5. Reading captured samples...")
    num_samples = 128
    samples = []
    for i in range(num_samples):
        sample = read_full_sample(ser, i)
        samples.append(sample)
    print(f"   Read {num_samples} samples\n")
    
    # 6. Find interesting transitions
    print("6. Analyzing capture...")
    trigger_idx = None
    wb_transactions = []
    
    for i, sample in enumerate(samples):
        decoded = decode_sample(sample)
        
        # Find where 0xAB appears (trigger point)
        if decoded['wb_dat'] == 0xAB and trigger_idx is None:
            trigger_idx = i
        
        # Find Wishbone transactions (cyc && stb)
        if decoded['wb_cyc'] and decoded['wb_stb']:
            wb_transactions.append((i, decoded))
    
    if trigger_idx is not None:
        print(f"   ✓ Trigger point at sample {trigger_idx}")
    print(f"   ✓ Found {len(wb_transactions)} Wishbone transactions")
    
    # 7. Display samples around trigger
    print(f"\n7. Samples around trigger (showing samples {max(0,trigger_idx-10)} to {min(len(samples),trigger_idx+20)}):")
    print("=" * 80)
    print("Idx  | Data | Adr  | C S W A | RGB | LED | Details")
    print("-----+------+------+---------+-----+-----+---------------------------")
    
    start = max(0, trigger_idx - 10) if trigger_idx else 0
    end = min(len(samples), trigger_idx + 20) if trigger_idx else min(30, len(samples))
    
    for i in range(start, end):
        d = decode_sample(samples[i])
        marker = " <--TRIG" if i == trigger_idx else ""
        trans = " [WB]" if d['wb_cyc'] and d['wb_stb'] else ""
        led_marker = " [LED!]" if d['rgb_led'] else ""
        
        print(f"{i:4} | 0x{d['wb_dat']:02X} | 0x{d['wb_adr']:02X} | "
              f"{d['wb_cyc']} {d['wb_stb']} {d['wb_we']} {d['wb_ack']} | "
              f"{d['rgb_sel']:3} | {d['rgb_led']:3} | "
              f"{trans}{led_marker}{marker}")
    
    # 8. Show WS2812B activity
    print("\n8. Checking for WS2812B LED activity (rgb_led pin)...")
    led_active = sum(1 for s in samples if decode_sample(s)['rgb_led'])
    if led_active > 0:
        print(f"   ✓ rgb_led active in {led_active}/{len(samples)} samples")
        # Find transitions
        prev_led = 0
        transitions = []
        for i, sample in enumerate(samples):
            led = decode_sample(sample)['rgb_led']
            if led != prev_led:
                transitions.append((i, prev_led, led))
                prev_led = led
        
        if transitions:
            print(f"   ✓ Found {len(transitions)} transitions:")
            for idx, prev, curr in transitions[:10]:  # Show first 10
                print(f"      Sample {idx}: {'HIGH->LOW' if prev else 'LOW->HIGH'}")
    else:
        print("   ✗ No WS2812B activity detected")
    
    print("\n" + "=" * 80)
    print("Analysis complete!")
    
    ser.close()

if __name__ == "__main__":
    main()
