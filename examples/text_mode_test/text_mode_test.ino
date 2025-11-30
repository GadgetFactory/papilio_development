// Simple Text Mode Test
// Tests text mode rendering by writing characters directly via Wishbone
// This bypasses the MCP server to verify the FPGA text pipeline

#include <Arduino.h>
#include <SPI.h>
#include "WishboneSPI.h"

// ESP32-S3 SPI pins for FPGA connection
#define SPI_MOSI 11
#define SPI_MISO 13
#define SPI_SCK  12
#define SPI_CS   10

// Text mode registers
#define VIDEO_MODE_REG  0x8000
#define TEXT_CURSOR_X   0x8021
#define TEXT_CURSOR_Y   0x8022
#define TEXT_COLOR      0x8023
#define TEXT_CHAR       0x8024
#define TEXT_CLEAR      0x8025

// Video modes
#define MODE_COLOR_BARS  0
#define MODE_GRID        1
#define MODE_GRAYSCALE   2
#define MODE_TEXT        3
#define MODE_FRAMEBUFFER 4

// CGA Colors
#define COLOR_BLACK       0
#define COLOR_BLUE        1
#define COLOR_GREEN       2
#define COLOR_CYAN        3
#define COLOR_RED         4
#define COLOR_MAGENTA     5
#define COLOR_BROWN       6
#define COLOR_LIGHT_GRAY  7
#define COLOR_DARK_GRAY   8
#define COLOR_LIGHT_BLUE  9
#define COLOR_LIGHT_GREEN 10
#define COLOR_LIGHT_CYAN  11
#define COLOR_LIGHT_RED   12
#define COLOR_LIGHT_MAGENTA 13
#define COLOR_YELLOW      14
#define COLOR_WHITE       15

SPIClass fpgaSPI(HSPI);

void setCursor(uint8_t x, uint8_t y) {
    wishboneWrite16(TEXT_CURSOR_X, x & 0x7F);
    wishboneWrite16(TEXT_CURSOR_Y, y & 0x1F);
}

void setColor(uint8_t fg, uint8_t bg) {
    uint8_t attr = ((bg & 0x0F) << 4) | (fg & 0x0F);
    wishboneWrite16(TEXT_COLOR, attr);
}

void writeChar(char c) {
    wishboneWrite16(TEXT_CHAR, c);
}

void writeString(const char* str) {
    while (*str) {
        writeChar(*str++);
    }
}

void clearScreen() {
    wishboneWrite16(TEXT_CLEAR, 0x01);
    delay(10);  // Give FPGA time to clear
}

void setup() {
    Serial.begin(115200);
    while (!Serial && millis() < 3000);
    
    Serial.println();
    Serial.println("=== Text Mode Test ===");
    Serial.println("Testing FPGA text rendering pipeline");
    Serial.println();
    
    // Initialize SPI
    fpgaSPI.begin(SPI_SCK, SPI_MISO, SPI_MOSI, SPI_CS);
    wishboneInit(&fpgaSPI, SPI_CS);
    
    // Set text mode
    Serial.println("Setting video mode to TEXT (mode 3)...");
    wishboneWrite16(VIDEO_MODE_REG, MODE_TEXT);
    delay(100);
    
    // Clear screen
    Serial.println("Clearing screen...");
    clearScreen();
    delay(100);
    
    // Test 1: Write "ABCD" at different positions
    Serial.println("Test 1: Writing ABCD at position (10, 5)");
    setColor(COLOR_YELLOW, COLOR_BLUE);
    setCursor(10, 5);
    writeString("ABCD");
    
    // Test 2: Write individual characters with spacing
    Serial.println("Test 2: Writing A B C D with spaces at (10, 7)");
    setColor(COLOR_WHITE, COLOR_BLACK);
    setCursor(10, 7);
    writeChar('A');
    writeChar(' ');
    writeChar('B');
    writeChar(' ');
    writeChar('C');
    writeChar(' ');
    writeChar('D');
    
    // Test 3: Write a ruler pattern
    Serial.println("Test 3: Writing ruler at (0, 10)");
    setColor(COLOR_LIGHT_GREEN, COLOR_BLACK);
    setCursor(0, 10);
    writeString("0123456789");
    writeString("0123456789");
    writeString("0123456789");
    writeString("0123456789");
    
    // Test 4: Write at column 0, row 12
    Serial.println("Test 4: Writing 'X' at column 0");
    setColor(COLOR_LIGHT_RED, COLOR_BLACK);
    setCursor(0, 12);
    writeChar('X');
    
    // Test 5: Write sequential characters
    Serial.println("Test 5: Writing alphabet at (0, 14)");
    setColor(COLOR_LIGHT_CYAN, COLOR_BLACK);
    setCursor(0, 14);
    for (char c = 'A'; c <= 'Z'; c++) {
        writeChar(c);
    }
    
    // Test 6: Write TEST centered
    Serial.println("Test 6: Writing 'TEST' centered at (38, 1)");
    setColor(COLOR_YELLOW, COLOR_BLUE);
    setCursor(38, 1);
    writeString("TEST");
    
    // Read back video mode to verify
    uint8_t mode = wishboneRead16(VIDEO_MODE_REG);
    Serial.printf("Video mode readback: %d\n", mode);
    
    Serial.println();
    Serial.println("Test complete! Check HDMI output for text.");
    Serial.println("Characters should NOT be doubled.");
}

void loop() {
    // Blink a character to show the system is running
    static unsigned long lastBlink = 0;
    static bool state = false;
    
    if (millis() - lastBlink > 500) {
        lastBlink = millis();
        state = !state;
        
        setCursor(79, 0);
        setColor(state ? COLOR_WHITE : COLOR_BLACK, COLOR_BLACK);
        writeChar('*');
    }
}
