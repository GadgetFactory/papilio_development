// Wishbone RGB Demo - Simple SPI Test
// Tests basic SPI connectivity with constant pattern

#include <Arduino.h>
#include <SPI.h>

// SPI pins for Papilio hardware
#define SPI_CLK   12
#define SPI_MOSI  11
#define SPI_MISO  9
#define SPI_CS    10

void setup() {
    Serial.begin(115200);
    delay(2000);
    
    Serial.println("\n=== SPI Simple Connectivity Test ===\n");
    
    // Configure SPI
    pinMode(SPI_CS, OUTPUT);
    digitalWrite(SPI_CS, HIGH);
    SPI.begin(SPI_CLK, SPI_MISO, SPI_MOSI, SPI_CS);
    SPI.setFrequency(1000000);  // 1 MHz
    SPI.setDataMode(SPI_MODE0);
    
    Serial.println("Testing basic SPI communication...");
    Serial.println("FPGA should output constant 0xA5 pattern\n");
    
    // Test multiple bytes
    bool all_passed = true;
    for (int i = 0; i < 10; i++) {
        digitalWrite(SPI_CS, LOW);
        delayMicroseconds(10);
        uint8_t received = SPI.transfer(0x00);
        delayMicroseconds(10);
        digitalWrite(SPI_CS, HIGH);
        
        bool passed = (received == 0xA5);
        Serial.printf("Test %d: received 0x%02X [%s]\n", i+1, received, passed ? "PASS" : "FAIL");
        
        if (!passed) all_passed = false;
        delay(100);
    }
    
    Serial.println();
    if (all_passed) {
        Serial.println("SUCCESS: SPI communication working!");
    } else {
        Serial.println("FAILURE: Check connections:");
        Serial.printf("  SCLK: GPIO %d -> FPGA pin A11\n", SPI_CLK);
        Serial.printf("  MOSI: GPIO %d -> FPGA pin B11\n", SPI_MOSI);
        Serial.printf("  MISO: GPIO %d <- FPGA pin C11\n", SPI_MISO);
        Serial.printf("  CS:   GPIO %d -> FPGA pin A12\n", SPI_CS);
    }
}

void loop() {
    delay(1000);
}
