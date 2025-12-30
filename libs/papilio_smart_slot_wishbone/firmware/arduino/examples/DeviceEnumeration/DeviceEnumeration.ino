/*
 * DeviceEnumeration.ino
 * 
 * Demonstrates Smart Slot Wishbone device enumeration.
 * Shows how to discover and identify FPGA peripherals at runtime.
 */

#include <SmartSlotWishbone.h>

SmartSlotWishbone ssw;

void setup() {
    Serial.begin(115200);
    while (!Serial) delay(10);
    
    Serial.println("Smart Slot Wishbone - Device Enumeration");
    Serial.println("=========================================");
    Serial.println();
    
    ssw.begin();
    
    // Read system information
    Serial.println("System Information:");
    Serial.println("------------------");
    Serial.printf("Protocol Version: 0x%02X\n", ssw.getVersion());
    Serial.printf("Capabilities:     0x%02X\n", ssw.getCapabilities());
    Serial.printf("Total Slots:      %d\n", ssw.getSlotCount());
    Serial.printf("External Memory:  %d MB\n", ssw.getMemorySize());
    Serial.println();
    
    // Enumerate all devices
    Serial.println("Enumerating devices...");
    uint8_t deviceCount = ssw.enumerateDevices();
    Serial.println();
    
    if (deviceCount == 0) {
        Serial.println("No devices found!");
        return;
    }
    
    // Print detailed device information
    ssw.printDevices();
    
    // Search for specific devices
    Serial.println("\nSearching for specific devices:");
    Serial.println("------------------------------");
    
    DeviceInfo* rgbLed = ssw.findDevice(SSW_DEVID_RGB_LED);
    if (rgbLed) {
        Serial.printf("✓ RGB LED found at slot %d\n", rgbLed->slot);
    } else {
        Serial.println("✗ RGB LED not found");
    }
    
    DeviceInfo* sid = ssw.findDevice(SSW_DEVID_SID);
    if (sid) {
        Serial.printf("✓ SID 6581 found at slot %d\n", sid->slot);
    } else {
        Serial.println("✗ SID 6581 not found");
    }
    
    DeviceInfo* ym2149 = ssw.findDevice(SSW_DEVID_YM2149);
    if (ym2149) {
        Serial.printf("✓ YM2149 found at slot %d\n", ym2149->slot);
    } else {
        Serial.println("✗ YM2149 not found");
    }
    
    DeviceInfo* video = ssw.findDevice(SSW_DEVID_VIDEO);
    if (video) {
        Serial.printf("✓ Video controller found at slot %d\n", video->slot);
    } else {
        Serial.println("✗ Video controller not found");
    }
    
    DeviceInfo* logicAnalyzer = ssw.findDevice(SSW_DEVID_LOGIC_AN);
    if (logicAnalyzer) {
        Serial.printf("✓ Logic Analyzer found at slot %d\n", logicAnalyzer->slot);
    } else {
        Serial.println("✗ Logic Analyzer not found");
    }
    
    Serial.println();
    Serial.println("Enumeration complete!");
}

void loop() {
    // Print a device summary every 5 seconds
    static unsigned long lastPrint = 0;
    
    if (millis() - lastPrint > 5000) {
        lastPrint = millis();
        
        Serial.println("\n--- Device Summary ---");
        ssw.printDevices();
    }
}
