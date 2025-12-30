/*
 * DeviceEnumeration.ino
 * 
 * Demonstrates device enumeration and auto-discovery of FPGA peripherals.
 * Shows how to detect what devices are present in each slot.
 */

#include <SmartSlotWishbone.h>

// Create SSW instance
SmartSlotWishbone ssw;

void setup() {
    Serial.begin(115200);
    while (!Serial) delay(10);
    
    Serial.println("Smart Slot Wishbone - Device Enumeration");
    Serial.println("========================================");
    
    // Initialize SSW
    if (!ssw.begin()) {
        Serial.println("ERROR: Failed to initialize SSW!");
        while(1) delay(1000);
    }
    
    Serial.println("SSW initialized successfully\n");
    
    // Get system information
    uint8_t version = ssw.getVersion();
    uint8_t caps = ssw.getCapabilities();
    uint8_t memSize = ssw.getMemorySize();
    
    Serial.println("=== System Information ===");
    Serial.printf("Version: 0x%02X\n", version);
    Serial.printf("Capabilities: 0x%02X\n", caps);
    Serial.printf("Memory Size: %d MB\n", memSize);
    Serial.println();
    
    // Enumerate all devices
    Serial.println("Enumerating devices...");
    if (ssw.enumerateDevices()) {
        Serial.println("Enumeration complete!\n");
        ssw.printDevices();
    } else {
        Serial.println("ERROR: Enumeration failed!");
    }
    
    // Show detailed device info
    Serial.println("\n=== Detailed Device Information ===");
    uint8_t slotCount = ssw.getSlotCount();
    
    for (uint8_t i = 0; i < slotCount; i++) {
        uint16_t devID = ssw.getDeviceID(i);
        
        if (devID != SSW_DEVID_EMPTY) {
            Serial.printf("\nSlot %d:\n", i);
            Serial.printf("  Device ID: 0x%04X\n", devID);
            Serial.printf("  Name: %s\n", ssw.getDeviceName(devID));
            Serial.printf("  Address: 0x%04X - 0x%04X\n", 
                         i * 256, (i + 1) * 256 - 1);
            
            // Try to read first register
            uint8_t reg0 = ssw.readSlot(i, 0);
            Serial.printf("  Register 0: 0x%02X\n", reg0);
        }
    }
    
    Serial.println("\n=== Enumeration Complete ===");
}

void loop() {
    // Nothing to do in loop
    delay(1000);
}
