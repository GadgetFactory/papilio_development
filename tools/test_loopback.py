#!/usr/bin/env python3
"""
FPGA UART Loopback Test
========================

Test if ESP32 can receive data from FPGA TX pin by sending test data
and checking if it echoes back through the SUMP UART.
"""

import serial
import time
import sys

def test_fpga_tx_to_esp32_rx(port):
    print(f"\n{'='*70}")
    print("FPGA TX → ESP32 RX Loopback Test")
    print(f"{'='*70}\n")
    
    print("Configuration:")
    print("  ESP32 GPIO4 (RX) ← FPGA F10 (TX)")
    print("  ESP32 GPIO3 (TX) → FPGA J11 (RX)")
    print()
    
    ser = serial.Serial(port, 115200, timeout=2)
    time.sleep(0.1)
    
    try:
        # Enable SUMP passthrough
        print("[1] Enabling MCP SUMP passthrough...")
        ser.write(b'S 1\n')
        time.sleep(0.5)
        response = ser.read(ser.in_waiting)
        print(response.decode('utf-8', errors='ignore'))
        
        # Clear buffer
        ser.reset_input_buffer()
        time.sleep(0.1)
        
        # Send SUMP RESET - this should cause FPGA to respond
        print("\n[2] Sending SUMP RESET (0x00) - FPGA should echo or respond...")
        for i in range(5):
            ser.write(bytes([0x00]))
            time.sleep(0.02)
        
        time.sleep(0.3)
        response = ser.read(ser.in_waiting)
        if response:
            print(f"    ✅ Received {len(response)} bytes from FPGA:")
            print(f"       Hex: {response.hex()}")
            print(f"       ASCII: {response}")
        else:
            print(f"    ❌ No response from FPGA")
            
        # Send ID query
        print("\n[3] Sending SUMP ID query (0x02)...")
        ser.write(bytes([0x02]))
        time.sleep(0.5)
        response = ser.read(ser.in_waiting)
        
        if response and len(response) >= 4:
            print(f"    ✅ Received {len(response)} bytes:")
            print(f"       Hex: {response.hex()}")
            # SUMP ID should be "SLA1" (0x534C4131) or "1ALS" reversed
            if len(response) >= 4:
                id_bytes = response[:4]
                print(f"       ID: {id_bytes.hex()} = {id_bytes}")
        elif response:
            print(f"    ⚠️  Partial response: {len(response)} bytes")
            print(f"       Hex: {response.hex()}")
            print(f"       ASCII: {response}")
        else:
            print(f"    ❌ No ID response from FPGA")
            
        # Try sending some test patterns
        print("\n[4] Sending test byte patterns...")
        test_patterns = [
            bytes([0x55]),  # Alternating bits
            bytes([0xAA]),  # Alternating bits (inverted)
            bytes([0xFF]),  # All ones
            bytes([0x00]),  # All zeros
        ]
        
        for pattern in test_patterns:
            ser.reset_input_buffer()
            ser.write(pattern)
            time.sleep(0.1)
            response = ser.read(ser.in_waiting)
            print(f"    Sent: 0x{pattern.hex():>2} -> Received: {len(response)} bytes", end="")
            if response:
                print(f" (0x{response.hex()})")
            else:
                print()
                
        # Long wait to see if FPGA sends anything spontaneously
        print("\n[5] Waiting 2 seconds for any spontaneous FPGA output...")
        ser.reset_input_buffer()
        time.sleep(2)
        response = ser.read(ser.in_waiting)
        if response:
            print(f"    ✅ Received {len(response)} bytes:")
            print(f"       Hex: {response.hex()}")
            print(f"       ASCII: {response}")
        else:
            print(f"    No spontaneous output")
            
        print(f"\n{'='*70}")
        print("Summary:")
        print(f"{'='*70}")
        
        if response and len(response) > 0:
            print("✅ FPGA TX → ESP32 RX communication detected")
            print("   FPGA UART is working and ESP32 can receive data")
        else:
            print("❌ No FPGA transmission detected")
            print("\nPossible issues:")
            print("  1. FPGA bitstream not loaded or UART not running")
            print("  2. FPGA F10 (TX) not connected to ESP32 GPIO4 (RX)")
            print("  3. Incorrect pin mapping in constraints")
            print("  4. UART baud rate mismatch")
            
    except KeyboardInterrupt:
        print("\n\nTest interrupted")
    finally:
        ser.close()
        print("\n[6] Test complete - reset ESP32 to exit SUMP mode\n")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python test_loopback.py <COM_PORT>")
        print("Example: python test_loopback.py COM4")
        sys.exit(1)
        
    test_fpga_tx_to_esp32_rx(sys.argv[1])
