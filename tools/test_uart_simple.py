#!/usr/bin/env python3
"""
Simple SUMP/MCP UART Test
=========================

Test if ESP32 Serial1 UART is properly connected to FPGA SUMP UART.
"""

import serial
import time
import sys

def test_uart_connection(port):
    print(f"\n{'='*70}")
    print("ESP32 Serial1 → FPGA SUMP UART Connection Test")
    print(f"{'='*70}\n")
    
    ser = serial.Serial(port, 115200, timeout=1)
    time.sleep(0.1)
    
    try:
        # Enable SUMP passthrough
        print("[1] Enabling MCP SUMP passthrough...")
        ser.write(b'S 1\n')
        time.sleep(0.5)
        response = ser.read(ser.in_waiting)
        print(response.decode('utf-8', errors='ignore'))
        
        # Clear any buffered data
        ser.reset_input_buffer()
        time.sleep(0.1)
        
        # Send RESET commands
        print("\n[2] Sending SUMP RESET commands (0x00)...")
        for i in range(5):
            ser.write(bytes([0x00]))
            time.sleep(0.05)
        print("    Sent 5x 0x00")
        
        # Check for any response
        time.sleep(0.2)
        response = ser.read(ser.in_waiting)
        print(f"    Response: {len(response)} bytes: {response.hex() if response else '(none)'}")
        
        # Send ID query
        print("\n[3] Sending SUMP ID query (0x02)...")
        ser.write(bytes([0x02]))
        time.sleep(0.3)
        response = ser.read(ser.in_waiting)
        print(f"    Response: {len(response)} bytes")
        if response:
            print(f"    Hex: {response.hex()}")
            print(f"    ASCII: {response}")
        else:
            print("    No response received")
            
        # Try ARM command
        print("\n[4] Sending SUMP ARM command (0x01)...")
        ser.write(bytes([0x01]))
        time.sleep(0.2)
        response = ser.read(ser.in_waiting)
        print(f"    Response: {len(response)} bytes: {response.hex() if response else '(none)'}")
        
        # Check if FPGA is responding at all
        print("\n[5] Testing raw byte echo...")
        test_bytes = bytes([0xAA, 0x55, 0xFF, 0x00])
        ser.write(test_bytes)
        time.sleep(0.2)
        response = ser.read(ser.in_waiting)
        print(f"    Sent: {test_bytes.hex()}")
        print(f"    Response: {len(response)} bytes: {response.hex() if response else '(none)'}")
        
        print(f"\n{'='*70}")
        print("Test Results:")
        print(f"{'='*70}")
        
        if response and len(response) > 0:
            print("✅ FPGA is responding - UART connection appears OK")
        else:
            print("❌ No FPGA response detected")
            print("\nPossible issues:")
            print("  1. ESP32 GPIO pins (17/18) not connected to FPGA pins (C9/E14)")
            print("  2. FPGA bitstream not loaded")
            print("  3. UART module in FPGA not enabled")
            print("  4. Wrong GPIO pin numbers in PapilioMCP.h")
            
    except KeyboardInterrupt:
        print("\n\nTest interrupted")
    finally:
        ser.close()
        print("\n[6] Test complete - reset ESP32 to exit SUMP mode\n")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python test_uart_simple.py <COM_PORT>")
        print("Example: python test_uart_simple.py COM4")
        sys.exit(1)
        
    test_uart_connection(sys.argv[1])
