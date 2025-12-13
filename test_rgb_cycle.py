#!/usr/bin/env python3
"""Rapid LED color changes to test visibility and generate WS2812B traffic"""

import serial
import time

ser = serial.Serial('COM4', 115200, timeout=1)
time.sleep(0.5)

print("RGB LED Color Test - Watch the physical LED!")
print("=" * 60)

colors = [
    ("RED",    0x00, 0xFF, 0x00),
    ("GREEN",  0xFF, 0x00, 0x00),
    ("BLUE",   0x00, 0x00, 0xFF),
    ("YELLOW", 0xFF, 0xFF, 0x00),
    ("CYAN",   0xFF, 0x00, 0xFF),
    ("MAGENTA",0x00, 0xFF, 0xFF),
    ("WHITE",  0xFF, 0xFF, 0xFF),
    ("OFF",    0x00, 0x00, 0x00),
]

for name, g, r, b in colors:
    print(f"\nSetting LED to {name:8s} (G=0x{g:02X}, R=0x{r:02X}, B=0x{b:02X})...")
    
    ser.read(ser.in_waiting)
    ser.write(f"W 8100 {g:02X}\n".encode())
    time.sleep(0.02)
    
    ser.read(ser.in_waiting)
    ser.write(f"W 8101 {r:02X}\n".encode())
    time.sleep(0.02)
    
    ser.read(ser.in_waiting)
    ser.write(f"W 8102 {b:02X}\n".encode())
    time.sleep(0.5)  # Hold each color for 0.5 seconds

print("\nCycling complete. Did you see all the colors?")
ser.close()
