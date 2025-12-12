#!/usr/bin/env python3
"""
Test SUMP Logic Analyzer via MCP Passthrough
==============================================

This script tests the SUMP logic analyzer by:
1. Enabling MCP SUMP passthrough mode
2. Sending SUMP protocol commands
3. Capturing and displaying data
4. Returning to normal MCP mode

Usage:
    python test_sump_mcp.py COM4
"""

import serial
import time
import sys
import struct

class SUMPAnalyzer:
    """SUMP2 Logic Analyzer Protocol Handler"""
    
    # SUMP Commands
    CMD_RESET = 0x00
    CMD_ARM = 0x01
    CMD_ID = 0x02
    CMD_XON = 0x11
    CMD_XOFF = 0x13
    CMD_GET_METADATA = 0x04
    
    # Long commands (0x8X - 0xCX)
    CMD_SET_DIVIDER = 0x80
    CMD_SET_READ_DELAY = 0x81
    CMD_SET_FLAGS = 0x82
    CMD_SET_TRIGGER_MASK_0 = 0xC0
    CMD_SET_TRIGGER_VALUE_0 = 0xC1
    CMD_SET_TRIGGER_CONFIG_0 = 0xC2
    
    def __init__(self, port, baudrate=115200):
        self.ser = serial.Serial(port, baudrate, timeout=2)
        time.sleep(0.1)
        
    def enable_sump_mode(self):
        """Enable MCP SUMP passthrough"""
        print("[MCP] Enabling SUMP passthrough mode...")
        self.ser.write(b'S 1\n')
        time.sleep(0.5)
        response = self.ser.read(self.ser.in_waiting)
        print(response.decode('utf-8', errors='ignore'))
        
    def disable_sump_mode(self):
        """Disable SUMP mode (requires reset or Ctrl+C)"""
        print("\n[MCP] To disable SUMP mode, press ESP32 reset button")
        
    def send_command(self, cmd, data=None):
        """Send a SUMP command"""
        if data is None:
            # Short command
            self.ser.write(bytes([cmd]))
        else:
            # Long command (5 bytes: cmd + 4 bytes data, MSB first)
            packet = bytes([cmd]) + struct.pack('>I', data)
            self.ser.write(packet)
        time.sleep(0.01)
        
    def reset(self):
        """Reset the logic analyzer"""
        print("  Sending RESET...")
        for _ in range(5):
            self.send_command(self.CMD_RESET)
            time.sleep(0.05)  # Pause between RESET commands
        time.sleep(0.1)
        
    def get_id(self):
        """Get device ID (should return 'SLA1' or '1ALS')"""
        print("  Sending ID query...")
        self.send_command(self.CMD_ID)
        time.sleep(0.2)
        response = self.ser.read(4)
        if len(response) > 0:
            print(f"  Received {len(response)} bytes: {response.hex()} = {[hex(b) for b in response]}")
        if len(response) == 4:
            print(f"  Device ID: {response.hex()} ({response})")
            return response
        else:
            print(f"  No ID response (got {len(response)} bytes)")
            return None
            
    def configure_capture(self, sample_rate_divider=0, read_delay=0, flags=0):
        """Configure capture parameters
        
        Args:
            sample_rate_divider: Clock divider (0 = full speed, 27 MHz)
            read_delay: Pre-trigger samples (0 = all post-trigger)
            flags: Configuration flags
        """
        print(f"  Setting divider={sample_rate_divider}, delay={read_delay}, flags={flags:#x}")
        self.send_command(self.CMD_SET_DIVIDER, sample_rate_divider)
        self.send_command(self.CMD_SET_READ_DELAY, read_delay)
        self.send_command(self.CMD_SET_FLAGS, flags)
        
    def set_trigger(self, mask=0, value=0, config=0):
        """Set trigger configuration
        
        Args:
            mask: Trigger mask (1 = check bit, 0 = ignore)
            value: Trigger value
            config: Trigger config (0 = disabled, serial/parallel, level/edge)
        """
        print(f"  Setting trigger: mask={mask:#x}, value={value:#x}, config={config:#x}")
        self.send_command(self.CMD_SET_TRIGGER_MASK_0, mask)
        self.send_command(self.CMD_SET_TRIGGER_VALUE_0, value)
        self.send_command(self.CMD_SET_TRIGGER_CONFIG_0, config)
        
    def arm(self):
        """Arm the logic analyzer (start capture)"""
        print("  Arming capture...")
        self.send_command(self.CMD_ARM)
        
    def read_samples(self, num_samples, bytes_per_sample=4):
        """Read captured samples
        
        Args:
            num_samples: Number of samples to read
            bytes_per_sample: Bytes per sample (4 for 32-bit capture)
            
        Returns:
            List of sample tuples (byte0, byte1, byte2, byte3)
        """
        print(f"  Reading {num_samples} samples ({num_samples * bytes_per_sample} bytes)...")
        total_bytes = num_samples * bytes_per_sample
        data = bytearray()
        
        # Read with timeout
        deadline = time.time() + 5.0  # 5 second timeout
        while len(data) < total_bytes and time.time() < deadline:
            chunk = self.ser.read(min(1024, total_bytes - len(data)))
            data.extend(chunk)
            if len(chunk) == 0:
                time.sleep(0.01)
                
        if len(data) < total_bytes:
            print(f"  WARNING: Only received {len(data)}/{total_bytes} bytes")
            
        # Parse samples
        samples = []
        for i in range(0, len(data), bytes_per_sample):
            if i + bytes_per_sample <= len(data):
                sample = tuple(data[i:i+bytes_per_sample])
                samples.append(sample)
                
        return samples
        
    def display_samples(self, samples, max_display=32):
        """Display captured samples in a readable format"""
        print(f"\n  Captured {len(samples)} samples:")
        print("  " + "=" * 70)
        print("  Idx  | Byte3 Byte2 Byte1 Byte0 | Bits 31-0")
        print("  " + "-" * 70)
        
        for i, sample in enumerate(samples[:max_display]):
            b0, b1, b2, b3 = sample
            bits = (b3 << 24) | (b2 << 16) | (b1 << 8) | b0
            print(f"  {i:4d} | {b3:02X}    {b2:02X}    {b1:02X}    {b0:02X}   | {bits:032b}")
            
        if len(samples) > max_display:
            print(f"  ... ({len(samples) - max_display} more samples)")
        print("  " + "=" * 70)
        
    def close(self):
        """Close serial connection"""
        self.ser.close()

def test_sump_capture(port):
    """Run a complete SUMP capture test"""
    print(f"\n{'='*70}")
    print("SUMP Logic Analyzer Test via MCP Passthrough")
    print(f"{'='*70}\n")
    
    analyzer = SUMPAnalyzer(port)
    
    try:
        # Step 1: Enable SUMP mode
        analyzer.enable_sump_mode()
        time.sleep(0.5)
        
        # Step 2: Reset analyzer
        print("\n[SUMP] Resetting analyzer...")
        analyzer.reset()
        
        # Step 3: Get device ID
        print("\n[SUMP] Querying device ID...")
        device_id = analyzer.get_id()
        if not device_id:
            print("  WARNING: No device ID received. Continuing anyway...")
        
        # Step 4: Configure capture
        print("\n[SUMP] Configuring capture...")
        analyzer.configure_capture(
            sample_rate_divider=0,  # Full speed (27 MHz)
            read_delay=0,           # All post-trigger
            flags=0                 # Default flags
        )
        
        # Step 5: Set trigger (disabled for immediate capture)
        print("\n[SUMP] Setting trigger (disabled)...")
        analyzer.set_trigger(
            mask=0x00000000,   # No trigger mask (captures immediately)
            value=0x00000000,
            config=0x00000000  # Trigger disabled
        )
        
        # Step 6: Arm and capture
        print("\n[SUMP] Starting capture...")
        analyzer.arm()
        
        print("  Waiting for capture to complete...")
        time.sleep(1.0)  # Give time for capture
        
        # Step 7: Read samples
        print("\n[SUMP] Reading captured data...")
        samples = analyzer.read_samples(num_samples=64, bytes_per_sample=4)
        
        # Step 8: Display results
        if samples:
            analyzer.display_samples(samples)
            
            # Decode Wishbone signals (based on top.v mapping)
            print("\n[SUMP] Wishbone Signal Decode:")
            print("  " + "=" * 70)
            print("  Idx  | CMD  | WB_ADDR | WB_DATA | FLAGS")
            print("  " + "-" * 70)
            for i, (b0, b1, b2, b3) in enumerate(samples[:16]):
                print(f"  {i:4d} | {b3:02X}   | {b2:02X}      | {b1:02X}      | {b0:02X}")
            if len(samples) > 16:
                print(f"  ... ({len(samples) - 16} more samples)")
            print("  " + "=" * 70)
            
            print("\n✅ SUCCESS: Captured data from SUMP logic analyzer!")
        else:
            print("\n❌ FAILED: No samples received")
            
    except KeyboardInterrupt:
        print("\n\nTest interrupted by user")
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
    finally:
        analyzer.disable_sump_mode()
        analyzer.close()
        
    print(f"\n{'='*70}")
    print("Test Complete")
    print(f"{'='*70}\n")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python test_sump_mcp.py <COM_PORT>")
        print("Example: python test_sump_mcp.py COM4")
        sys.exit(1)
        
    port = sys.argv[1]
    test_sump_capture(port)
