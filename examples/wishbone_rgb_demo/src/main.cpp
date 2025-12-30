// Wishbone RGB Demo
// Demonstrates Papilio Wishbone Bus with automatic peripheral integration

#include <Arduino.h>
#include <PapilioWishbone.h>

PapilioWishbone wb;

void setup() {
    Serial.begin(115200);
    delay(1000);
    
    Serial.println("\n=== Papilio Wishbone Bus Demo ===");
    
    // Initialize Wishbone bus
    if (!wb.begin(20000000)) {
        Serial.println("ERROR: Wishbone initialization failed!");
        while(1) delay(1000);
    }
    
    Serial.println("Wishbone bus initialized");
    
    // Enumerate all devices
    Serial.println("\nEnumerating devices...");
    wb.setDebug(true);
    wb.enumerateDevices();
    wb.setDebug(false);
    
    wb.printDevices();
    
    Serial.println("\nStarting RGB demo...");
}

void loop() {
    // Cycle through colors
    
    // Red
    Serial.println("Red");
    wb.writeSlot(1, 0, 0xFF000000);  // RGB in upper 24 bits
    delay(1000);
    
    // Green
    Serial.println("Green");
    wb.writeSlot(1, 0, 0x00FF0000);
    delay(1000);
    
    // Blue
    Serial.println("Blue");
    wb.writeSlot(1, 0, 0x0000FF00);
    delay(1000);
    
    // Yellow
    Serial.println("Yellow");
    wb.writeSlot(1, 0, 0xFFFF0000);
    delay(1000);
    
    // Cyan
    Serial.println("Cyan");
    wb.writeSlot(1, 0, 0x00FFFF00);
    delay(1000);
    
    // Magenta
    Serial.println("Magenta");
    wb.writeSlot(1, 0, 0xFF00FF00);
    delay(1000);
    
    // White
    Serial.println("White");
    wb.writeSlot(1, 0, 0xFFFFFF00);
    delay(1000);
    
    // Off
    Serial.println("Off");
    wb.writeSlot(1, 0, 0x00000000);
    delay(1000);
    
    Serial.printf("\nTransactions: %lu\n\n", wb.getTransactionCount());
}
