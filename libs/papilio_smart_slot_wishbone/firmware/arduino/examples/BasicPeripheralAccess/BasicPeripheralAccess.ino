/*
 * BasicPeripheralAccess.ino
 * 
 * Demonstrates basic Smart Slot Wishbone usage with peripheral slots.
 * Shows how to write to RGB LED and read/write to simple registers.
 */

#include <SmartSlotWishbone.h>

// Create SSW instance
SmartSlotWishbone ssw;

// Define slot numbers (must match FPGA design)
#define SLOT_SYSTEM     0
#define SLOT_RGB_LED    1
#define SLOT_SID        2

void setup() {
    Serial.begin(115200);
    while (!Serial) delay(10);
    
    Serial.println("Smart Slot Wishbone - Basic Example");
    Serial.println("===================================");
    
    // Initialize SSW
    if (!ssw.begin()) {
        Serial.println("ERROR: Failed to initialize SSW!");
        while(1) delay(1000);
    }
    
    Serial.println("SSW initialized successfully");
    
    // Read system info
    uint8_t version = ssw.getVersion();
    Serial.printf("System version: 0x%02X\n", version);
    
    // Enumerate devices
    ssw.enumerateDevices();
    ssw.printDevices();
    
    Serial.println("\nStarting demo...");
}

void loop() {
    // Cycle through colors on RGB LED (Slot 1)
    
    // Red
    Serial.println("Red");
    ssw.writeSlot(SLOT_RGB_LED, 0, 255);  // R
    ssw.writeSlot(SLOT_RGB_LED, 1, 0);    // G
    ssw.writeSlot(SLOT_RGB_LED, 2, 0);    // B
    delay(1000);
    
    // Green
    Serial.println("Green");
    ssw.writeSlot(SLOT_RGB_LED, 0, 0);    // R
    ssw.writeSlot(SLOT_RGB_LED, 1, 255);  // G
    ssw.writeSlot(SLOT_RGB_LED, 2, 0);    // B
    delay(1000);
    
    // Blue
    Serial.println("Blue");
    ssw.writeSlot(SLOT_RGB_LED, 0, 0);    // R
    ssw.writeSlot(SLOT_RGB_LED, 1, 0);    // G
    ssw.writeSlot(SLOT_RGB_LED, 2, 255);  // B
    delay(1000);
    
    // White
    Serial.println("White");
    ssw.writeSlot(SLOT_RGB_LED, 0, 255);  // R
    ssw.writeSlot(SLOT_RGB_LED, 1, 255);  // G
    ssw.writeSlot(SLOT_RGB_LED, 2, 255);  // B
    delay(1000);
    
    // Off
    Serial.println("Off");
    ssw.writeSlot(SLOT_RGB_LED, 0, 0);    // R
    ssw.writeSlot(SLOT_RGB_LED, 1, 0);    // G
    ssw.writeSlot(SLOT_RGB_LED, 2, 0);    // B
    delay(1000);
    
    // Show transaction count
    Serial.printf("Transactions: %lu\n\n", ssw.getTransactionCount());
}
