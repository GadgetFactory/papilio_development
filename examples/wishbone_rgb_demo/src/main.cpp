// PWB2 RGB Demo - Test Papilio Wishbone Bus 2
// Tests device enumeration and RGB LED control

#include <Arduino.h>
#include <PapilioWishbone2.h>

// SPI pins for Papilio hardware
#define SPI_CLK   12
#define SPI_MOSI  11
#define SPI_MISO  9
#define SPI_CS    10

// Create PWB2 instance
PapilioWishbone2 pwb2(SPI_CS);

int rgbSlot = -1;

void setup() {
    Serial.begin(115200);
    delay(2000);
    
    Serial.println("\n===== PWB2 RGB Demo =====\n");
    
    // Configure custom SPI pins
    SPI.begin(SPI_CLK, SPI_MISO, SPI_MOSI, SPI_CS);
    
    // Initialize PWB2 (lower speed for testing)
    Serial.println("Initializing PWB2...");
    pwb2.setDebug(true);  // Enable debug before begin
    if (!pwb2.begin(1000000)) {  // 1 MHz for initial testing
        Serial.println("ERROR: PWB2 initialization failed!");
        Serial.println("\nCheck connections:");
        Serial.printf("  SCLK: GPIO %d -> FPGA\n", SPI_CLK);
        Serial.printf("  MOSI: GPIO %d -> FPGA\n", SPI_MOSI);
        Serial.printf("  MISO: GPIO %d -> FPGA\n", SPI_MISO);
        Serial.printf("  CS:   GPIO %d -> FPGA\n", SPI_CS);
        Serial.println("\nTrying basic SPI test...");
        
        // Try a simple read to see what we get
        digitalWrite(SPI_CS, LOW);
        delay(1);
        uint8_t test = SPI.transfer(0x00);
        delay(1);
        digitalWrite(SPI_CS, HIGH);
        Serial.printf("SPI test byte: 0x%02X\n", test);
        
        while (1) delay(1000);
    }
    
    Serial.println("PWB2 initialized successfully!");
    
    // Already enabled above
    // pwb2.setDebug(true);
    
    // Enumerate devices
    Serial.println("\nEnumerating devices...");
    pwb2.enumerateDevices();
    pwb2.printDevices(Serial);
    
    // Find RGB LED (device ID 0x4C45)
    Serial.println("\nSearching for RGB LED peripheral...");
    for (int slot = 0; slot < 32; slot++) {
        uint16_t devId = pwb2.getDeviceId(slot);
        if (devId == 0x4C45) {
            rgbSlot = slot;
            Serial.printf("RGB LED found at slot %d\n", rgbSlot);
            break;
        }
    }
    
    if (rgbSlot < 0) {
        Serial.println("ERROR: RGB LED peripheral not found!");
        Serial.println("Make sure the FPGA is programmed with PWB2 RGB LED peripheral");
        while (1) delay(1000);
    }
    
    Serial.println("\nStarting color cycle demo...");
    Serial.println("The RGB LED should cycle through colors\n");
}

void loop() {
    static int step = 0;
    static unsigned long lastChange = 0;
    
    // Only run if we found the RGB LED
    if (rgbSlot < 0) return;
    
    // Change color every second
    if (millis() - lastChange < 1000) return;
    lastChange = millis();
    
    // Cycle through colors
    switch (step) {
        case 0:  // Red
            Serial.println("Color: RED");
            pwb2.writeSlot8(rgbSlot, 0, 255);  // Red
            pwb2.writeSlot8(rgbSlot, 1, 0);    // Green
            pwb2.writeSlot8(rgbSlot, 2, 0);    // Blue
            break;
            
        case 1:  // Green
            Serial.println("Color: GREEN");
            pwb2.writeSlot8(rgbSlot, 0, 0);
            pwb2.writeSlot8(rgbSlot, 1, 255);
            pwb2.writeSlot8(rgbSlot, 2, 0);
            break;
            
        case 2:  // Blue
            Serial.println("Color: BLUE");
            pwb2.writeSlot8(rgbSlot, 0, 0);
            pwb2.writeSlot8(rgbSlot, 1, 0);
            pwb2.writeSlot8(rgbSlot, 2, 255);
            break;
            
        case 3:  // Yellow
            Serial.println("Color: YELLOW");
            pwb2.writeSlot8(rgbSlot, 0, 255);
            pwb2.writeSlot8(rgbSlot, 1, 255);
            pwb2.writeSlot8(rgbSlot, 2, 0);
            break;
            
        case 4:  // Cyan
            Serial.println("Color: CYAN");
            pwb2.writeSlot8(rgbSlot, 0, 0);
            pwb2.writeSlot8(rgbSlot, 1, 255);
            pwb2.writeSlot8(rgbSlot, 2, 255);
            break;
            
        case 5:  // Magenta
            Serial.println("Color: MAGENTA");
            pwb2.writeSlot8(rgbSlot, 0, 255);
            pwb2.writeSlot8(rgbSlot, 1, 0);
            pwb2.writeSlot8(rgbSlot, 2, 255);
            break;
            
        case 6:  // White
            Serial.println("Color: WHITE");
            pwb2.writeSlot8(rgbSlot, 0, 255);
            pwb2.writeSlot8(rgbSlot, 1, 255);
            pwb2.writeSlot8(rgbSlot, 2, 255);
            break;
            
        case 7:  // Off
            Serial.println("Color: OFF");
            pwb2.writeSlot8(rgbSlot, 0, 0);
            pwb2.writeSlot8(rgbSlot, 1, 0);
            pwb2.writeSlot8(rgbSlot, 2, 0);
            break;
    }
    
    step = (step + 1) % 8;
    
    // Print transaction statistics every 8 cycles
    if (step == 0) {
        Serial.printf("\nStatistics: %d transactions\n\n", pwb2.getTransactionCount());
    }
}
