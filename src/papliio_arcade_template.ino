/*
  Gadget Factory
  Papilio Arcade Board - HQVGA Color Bar Example
  
  Original HQVGA by Alvaro Lopes <alvieboy@alvie.com>
  ESP32-S3 port by Jack Gassett
  
  Hardware:
  - Papilio Arcade board with ESP32-S3 and FPGA
  - HDMI output (via FPGA framebuffer)
*/

#include <SPI.h>
#include <HQVGA.h>

// SPI Pin Configuration for ESP32-S3
#define SPI_CLK   12
#define SPI_MOSI  11
#define SPI_MISO  9
#define SPI_CS    10

int textarea = 20;
int colors[] = {RED, GREEN, BLUE, YELLOW, PURPLE, CYAN, WHITE, BLACK};

void setup() {
  Serial.begin(115200);
  
  // Wait for FPGA to configure
  delay(3000);
  
  Serial.println("Papilio Arcade HQVGA Color Bar Test");
  Serial.println("Original HQVGA by Alvaro Lopes");
  Serial.println("ESP32-S3 port by Jack Gassett");
  
  // Initialize HQVGA with default SPI pins
  VGA.begin(nullptr, SPI_CS, SPI_CLK, SPI_MOSI, SPI_MISO);
  
  Serial.println("HQVGA initialized");
  
  int width = VGA.getHSize();
  int height = VGA.getVSize();
  int column = width / 8;
  
  // Clear screen
  VGA.clear();
  VGA.setBackgroundColor(BLACK);
  
  // Print title text
  VGA.setColor(RED);
  VGA.printtext(25, 0, "Papilio/ESP32");
  VGA.printtext(25, 10, "Color Bar Test");
  
  // Draw color bars
  for (int i = 0; i < 8; i++) {
    VGA.setColor(colors[i]);
    VGA.drawRect(i * column, textarea, column, height - textarea);
    Serial.printf("Drawing bar %d at x=%d\n", i, i * column);
  }
  
  Serial.println("Color Bar test complete!");
}

void loop() {
  // Nothing to do in loop
  delay(1000);
}
