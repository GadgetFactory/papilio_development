// ESP32-S3 Arduino Example for Controlling FPGA RGB LED via SPI
// Controls RGB LED via Wishbone SPI interface

#include <SPI.h>
#include "RGBLed.h"
#include <HDMIController.h>

// SPI Pin Configuration for ESP32-S3
// Adjust these pins based on your actual hardware connections
#define SPI_CLK   12   // SCK - connects to FPGA esp_clk
#define SPI_MOSI  11   // MOSI - connects to FPGA esp_mosi
#define SPI_MISO  9   // MISO - connects from FPGA esp_miso
#define SPI_CS    10   // CS - connects to FPGA esp_cs_n

SPIClass * fpgaSPI = NULL;
HDMIController *hdmi = NULL;

void setup() {
  Serial.begin(115200);
  delay(5000);
  Serial.println("ESP32-S3 FPGA RGB LED Control Example");
  
  // Initialize SPI for FPGA communication
  fpgaSPI = new SPIClass(HSPI);
  fpgaSPI->begin(SPI_CLK, SPI_MISO, SPI_MOSI, SPI_CS);

  // Configure CS pin
  pinMode(SPI_CS, OUTPUT);
  digitalWrite(SPI_CS, HIGH);  // CS idle high
  // Initialize RGB LED library (it will initialize the Wishbone SPI helper)
  RGBLed::begin(fpgaSPI, SPI_CS);

  // Wait for FPGA to be ready after power-up
  Serial.println("Waiting for FPGA to initialize...");
  delay(1000);
  
  // Initialize HDMI controller (make it persistent so it remains active)
  hdmi = new HDMIController(fpgaSPI, SPI_CS, SPI_CLK, SPI_MOSI, SPI_MISO);
  if (hdmi) {
    hdmi->begin();
    
    Serial.println("Testing Wishbone communication...");
    
    // Enable text mode FIRST before writing data
    Serial.print("Pattern mode before: ");
    Serial.println(hdmi->getVideoPattern(), HEX);
    
    hdmi->enableTextMode();
    delay(100);
    
    Serial.print("Pattern mode after: ");
    Serial.println(hdmi->getVideoPattern(), HEX);
    
    // Clear entire screen - fill all 2080 positions (80*26)
    Serial.println("Clearing screen...");
    for (int row = 0; row < 26; row++) {
      hdmi->setCursor(0, row);
      for (int col = 0; col < 80; col++) {
        hdmi->writeChar(' ');
      }
    }
    
    // Write nice welcome screen
    Serial.println("Writing welcome screen...");
    
    // Title bar
    hdmi->setCursor(0, 0);
    hdmi->print("================================================================================");
    
    hdmi->setCursor(28, 1);
    hdmi->print("Papilio Arcade HDMI");
    
    hdmi->setCursor(0, 2);
    hdmi->print("================================================================================");
    
    // System info
    hdmi->setCursor(2, 4);
    hdmi->print("ESP32-S3 Dual Core @ 240MHz");
    
    hdmi->setCursor(2, 5);
    hdmi->print("Gowin GW2A FPGA with 720p HDMI Output");
    
    hdmi->setCursor(2, 6);
    hdmi->print("80x26 Text Mode  :  16x16 Pixel Characters");
    
    // Separator
    hdmi->setCursor(0, 8);
    hdmi->print("--------------------------------------------------------------------------------");
    
    // Font demo
    hdmi->setCursor(2, 10);
    hdmi->print("Font: ABCDEFGHIJKLMNOPQRSTUVWXYZ");
    
    hdmi->setCursor(8, 11);
    hdmi->print("abcdefghijklmnopqrstuvwxyz");
    
    hdmi->setCursor(8, 12);
    hdmi->print("0123456789 !:");
    
    // Status area
    hdmi->setCursor(0, 14);
    hdmi->print("--------------------------------------------------------------------------------");
    
    hdmi->setCursor(2, 16);
    hdmi->print("Status: READY");
    
    hdmi->setCursor(2, 18);
    hdmi->print("Counter:");
    
    // Footer
    hdmi->setCursor(0, 24);
    hdmi->print("--------------------------------------------------------------------------------");
    hdmi->setCursor(25, 25);
    hdmi->print("github.com/GadgetFactory");
    
    Serial.println("HDMI: Welcome screen displayed");
  } else {
    Serial.println("HDMI: failed to allocate controller");
  }

  Serial.println("SPI initialized");
  delay(100);

  // Set RGB LED to green
  RGBLed::setColor(RGBLed::COLOR_GREEN);
  Serial.println("LED set to GREEN");
}

void loop() {
  static int counter = 0;
  static unsigned long lastUpdate = 0;
  
  unsigned long now = millis();
  
  // Update counter on screen every second
  if (now - lastUpdate >= 1000) {
    lastUpdate = now;
    
    if (hdmi) {
      char buf[20];
      snprintf(buf, sizeof(buf), "%d      ", counter);
      hdmi->setCursor(11, 18);
      hdmi->print(buf);
      
      // Simple animation - rotating indicator using available characters
      const char spinner[] = {".:oO"};
      char spin_char[2] = {spinner[counter % 4], '\0'};
      hdmi->setCursor(77, 16);
      hdmi->print(spin_char);
      
      Serial.print("Counter: ");
      Serial.println(counter);
    }
    
    counter++;
    
    // Cycle LED colors
    if (counter % 3 == 0) {
      RGBLed::setColor(RGBLed::COLOR_RED);
    } else if (counter % 3 == 1) {
      RGBLed::setColor(RGBLed::COLOR_GREEN);
    } else {
      RGBLed::setColor(RGBLed::COLOR_BLUE);
    }
  }
  
  delay(10);  // Small delay to not overwhelm the loop
}

