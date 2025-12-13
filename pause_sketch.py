#!/usr/bin/env python3
"""Pause the Arduino sketch via serial"""

import serial
import time

ser = serial.Serial('COM4', 115200, timeout=1)
time.sleep(0.1)

# Send pause command (Ctrl+P or similar)
print("Sending pause command...")
ser.write(b'p')  # Try 'p' for pause
time.sleep(0.5)

ser.close()
print("Pause command sent")
