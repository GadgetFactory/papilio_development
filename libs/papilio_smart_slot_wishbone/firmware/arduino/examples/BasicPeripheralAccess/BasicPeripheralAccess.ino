/*
 * BasicPeripheralAccess.ino
 * 
 * Demonstrates basic Smart Slot Wishbone usage:
 * - Device enumeration
 * - Reading system information
 * - Writing to peripheral slots (RGB LED)
 * - Reading from slots
 */

#include <SmartSlotWishbone.h>

// Create SSW instance
// Default: SPI, CS=SS, 20MHz
SmartSlotWishbone ssw;

void setup() {
    Serial.begin(115200);
    while (!Serial) delay(10);
    
    Serial.println("Smart Slot Wishbone - Basic Example");
    Serial.println("====================================");
    Serial.println();
    
    // Initialize
    ssw.begin();
    
    // Get system information
    Serial.println("System Information:");
    Serial.printf("  Version: 0x%02X\n", ssw.getVersion());
    Serial.printf("  Capabilities: 0x%02X\n", ssw.getCapabilities());
    Serial.printf("  Slot Count: %d\n", ssw.getSlotCount());
    Serial.printf("  Memory Size: %d MB\n", ssw.getMemorySize());
    Serial.println();
    
    // Enumerate devices
    Serial.println("Enumerating devices...");
    uint8_t count = ssw.enumerateDevices();
    Serial.printf("Found %d devices\n\n", count);
    
    ssw.printDevices();
    
    // Find RGB LED
    DeviceInfo* rgbLed = ssw.findDevice(SSW_DEVID_RGB_LED);
    if (rgbLed) {
        Serial.printf("RGB LED found at slot %d\n", rgbLed->slot);
        
        // Cycle through colors
        Serial.println("Cycling RGB colors...");
        
        Serial.println("  Red");
        ssw.setRGB(rgbLed->slot, 255, 0, 0);
        delay(1000);
        
        Serial.println("  Green");
        ssw.setRGB(rgbLed->slot, 0, 255, 0);
        delay(1000);
        
        Serial.println("  Blue");
        ssw.setRGB(rgbLed->slot, 0, 0, 255);
        delay(1000);
        
        Serial.println("  White");
        ssw.setRGB(rgbLed->slot, 255, 255, 255);
        delay(1000);
        
        Serial.println("  Off");
        ssw.setRGB(rgbLed->slot, 0, 0, 0);
    } else {
        Serial.println("RGB LED not found");
    }
    
    Serial.println();
    Serial.println("Setup complete!");
}

void loop() {
    // Rainbow effect on RGB LED
    DeviceInfo* rgbLed = ssw.findDevice(SSW_DEVID_RGB_LED);
    if (rgbLed) {
        static uint8_t hue = 0;
        
        // Simple HSV to RGB conversion
        uint8_t r, g, b;
        uint8_t region = hue / 43;
        uint8_t remainder = (hue - (region * 43)) * 6;
        
        switch (region) {
            case 0: r = 255; g = remainder; b = 0; break;
            case 1: r = 255 - remainder; g = 255; b = 0; break;
            case 2: r = 0; g = 255; b = remainder; break;
            case 3: r = 0; g = 255 - remainder; b = 255; break;
            case 4: r = remainder; g = 0; b = 255; break;
            default: r = 255; g = 0; b = 255 - remainder; break;
        }
        
        ssw.setRGB(rgbLed->slot, r, g, b);
        
        hue++;
        delay(20);
    }
}
