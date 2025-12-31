// BasicPeripheralAccess.ino - PWB2 example demonstrating basic peripheral access
// Controls an RGB LED using PWB2

#include <PapilioWishbone2.h>

// Create PWB2 instance
PapilioWishbone2 pwb2;

void setup() {
    Serial.begin(115200);
    delay(1000);
    
    Serial.println("===== PWB2 Basic Peripheral Access =====");
    
    // Initialize PWB2
    if (!pwb2.begin()) {
        Serial.println("ERROR: PWB2 initialization failed!");
        while (1) delay(1000);
    }
    
    Serial.println("PWB2 initialized successfully!");
    
    // Enumerate devices
    Serial.println("\nEnumerating devices...");
    pwb2.enumerateDevices();
    pwb2.printDevices(Serial);
    
    // Find RGB LED (device ID 0x4C45)
    int rgbSlot = -1;
    for (int slot = 0; slot < 32; slot++) {
        if (pwb2.getDeviceId(slot) == 0x4C45) {
            rgbSlot = slot;
            break;
        }
    }
    
    if (rgbSlot < 0) {
        Serial.println("\nERROR: RGB LED not found!");
        while (1) delay(1000);
    }
    
    Serial.printf("\nRGB LED found at slot %d\n", rgbSlot);
    Serial.println("\nStarting color cycle...");
}

void loop() {
    static int step = 0;
    
    // Find RGB LED slot (cached from setup)
    static int rgbSlot = -1;
    if (rgbSlot < 0) {
        for (int slot = 0; slot < 32; slot++) {
            if (pwb2.getDeviceId(slot) == 0x4C45) {
                rgbSlot = slot;
                break;
            }
        }
    }
    
    if (rgbSlot < 0) return;
    
    // Cycle through colors
    switch (step) {
        case 0:  // Red
            Serial.println("RED");
            pwb2.writeSlot8(rgbSlot, 0, 255);  // Red
            pwb2.writeSlot8(rgbSlot, 1, 0);    // Green
            pwb2.writeSlot8(rgbSlot, 2, 0);    // Blue
            break;
            
        case 1:  // Green
            Serial.println("GREEN");
            pwb2.writeSlot8(rgbSlot, 0, 0);
            pwb2.writeSlot8(rgbSlot, 1, 255);
            pwb2.writeSlot8(rgbSlot, 2, 0);
            break;
            
        case 2:  // Blue
            Serial.println("BLUE");
            pwb2.writeSlot8(rgbSlot, 0, 0);
            pwb2.writeSlot8(rgbSlot, 1, 0);
            pwb2.writeSlot8(rgbSlot, 2, 255);
            break;
            
        case 3:  // Yellow
            Serial.println("YELLOW");
            pwb2.writeSlot8(rgbSlot, 0, 255);
            pwb2.writeSlot8(rgbSlot, 1, 255);
            pwb2.writeSlot8(rgbSlot, 2, 0);
            break;
            
        case 4:  // Cyan
            Serial.println("CYAN");
            pwb2.writeSlot8(rgbSlot, 0, 0);
            pwb2.writeSlot8(rgbSlot, 1, 255);
            pwb2.writeSlot8(rgbSlot, 2, 255);
            break;
            
        case 5:  // Magenta
            Serial.println("MAGENTA");
            pwb2.writeSlot8(rgbSlot, 0, 255);
            pwb2.writeSlot8(rgbSlot, 1, 0);
            pwb2.writeSlot8(rgbSlot, 2, 255);
            break;
            
        case 6:  // White
            Serial.println("WHITE");
            pwb2.writeSlot8(rgbSlot, 0, 255);
            pwb2.writeSlot8(rgbSlot, 1, 255);
            pwb2.writeSlot8(rgbSlot, 2, 255);
            break;
    }
    
    step = (step + 1) % 7;
    delay(1000);
}
