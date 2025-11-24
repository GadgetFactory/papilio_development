/*
  Papilio Arcade HDMI LCD Demo
  
  Demonstrates LCD-style text display on HDMI output using the HDMILiquidCrystal class.
  This example mimics the classic Arduino LiquidCrystal library but outputs to HDMI.
  
  Features:
  - 16x2 LCD emulation on 80x26 HDMI text display
  - Scrolling text demo
  - Compatible with LiquidCrystal API
  
  Hardware:
  - Papilio Arcade board with ESP32-S3 and FPGA
  - HDMI output connected to monitor
  
  Created 2025
  by Jack Gassett
  http://www.gadgetfactory.net
  
  This example code is in the public domain.
*/

#include <SPI.h>
#include <HDMIController.h>
#include <HDMILiquidCrystal.h>

// SPI Pin Configuration for ESP32-S3
#define SPI_CLK   12
#define SPI_MOSI  11
#define SPI_MISO  9
#define SPI_CS    10

SPIClass *fpgaSPI = NULL;
HDMIController *hdmi = NULL;
HDMILiquidCrystal *lcd = NULL;

// Scrolling text buffers (longer than display)
String line1 = "PAPILIO LCD DEMO    ";  // Add spaces for smooth scrolling
String line2 = "HDMI TEXT MODE!     ";
int scrollPos = 0;

void setup() {
  Serial.begin(115200);
  
  // Wait for FPGA to fully configure after power-on
  delay(5000);
  
  Serial.println("Papilio HDMI LCD Demo");
  
  // Initialize SPI
  fpgaSPI = new SPIClass(HSPI);
  fpgaSPI->begin(SPI_CLK, SPI_MISO, SPI_MOSI, SPI_CS);
  pinMode(SPI_CS, OUTPUT);
  digitalWrite(SPI_CS, HIGH);
  
  delay(500);
  
  // Initialize HDMI controller
  hdmi = new HDMIController(fpgaSPI, SPI_CS, SPI_CLK, SPI_MOSI, SPI_MISO);
  hdmi->begin();
  delay(100);
  
  // Create LCD interface with 16 columns and 2 rows
  lcd = new HDMILiquidCrystal(hdmi, 16, 2);
  lcd->begin(16, 2);
  
  // Set colors (white text on blue background)
  lcd->setColor(HDMI_COLOR_WHITE, HDMI_COLOR_BLUE);
  
  // Clear the LCD screen
  lcd->clear();
  delay(100);
  
  // Display initial message
  lcd->setCursor(0, 0);
  lcd->print("PAPILIO LCD DEMO");
  lcd->setCursor(0, 1);
  lcd->print("HDMI TEXT MODE!");
  
  Serial.println("LCD initialized and displaying message");
  
  delay(3000);
}

void loop() {
  // Software scrolling by rewriting the display
  scrollPos++;
  if (scrollPos >= line1.length()) {
    scrollPos = 0;
  }
  
  // Display shifted text
  lcd->setCursor(0, 0);
  for (int i = 0; i < 16; i++) {
    int charPos = (scrollPos + i) % line1.length();
    lcd->write(line1[charPos]);
  }
  
  lcd->setCursor(0, 1);
  for (int i = 0; i < 16; i++) {
    int charPos = (scrollPos + i) % line2.length();
    lcd->write(line2[charPos]);
  }
  
  delay(300);
}
