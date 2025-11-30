/*
  Papilio Arcade - Simple Demo
  ============================
  
  Cycles through HDMI video patterns and RGB LED colors.
  Press any key in Serial Monitor to manually advance.
  
  Hardware: Papilio Arcade board with ESP32-S3 and FPGA
*/

#include <HDMIController.h>

// Pin Configuration
#define SPI_CLK   12
#define SPI_MOSI  11
#define SPI_MISO  9
#define SPI_CS    10

// HDMI Controller
HDMIController* hdmi = nullptr;

// State
int currentPattern = 0;
int currentColor = 0;
unsigned long lastUpdate = 0;

// Pattern and color names for display
const char* patternNames[] = {"Color Bars", "Grid", "Grayscale", "Text Mode"};
const char* colorNames[] = {"Red", "Green", "Blue", "Yellow", "Cyan", "Magenta", "White", "Off"};

void setup() {
  Serial.begin(115200);
  delay(2000);
  
  Serial.println("\n=== Papilio Arcade Demo ===\n");
  
  // Initialize HDMI controller
  hdmi = new HDMIController(nullptr, SPI_CS, SPI_CLK, SPI_MOSI, SPI_MISO);
  hdmi->begin();
  
  Serial.println("Ready! Auto-cycling every 3 seconds.");
  Serial.println("Press any key to advance manually.\n");
  
  updateDisplay();
}

void updateDisplay() {
  // Set video pattern (0-3)
  hdmi->setVideoPattern(currentPattern);
  
  // Set LED color based on currentColor
  switch (currentColor) {
    case 0: hdmi->setLEDColorRGB(30, 0, 0);   break;  // Red
    case 1: hdmi->setLEDColorRGB(0, 30, 0);   break;  // Green
    case 2: hdmi->setLEDColorRGB(0, 0, 30);   break;  // Blue
    case 3: hdmi->setLEDColorRGB(30, 30, 0);  break;  // Yellow
    case 4: hdmi->setLEDColorRGB(0, 30, 30);  break;  // Cyan
    case 5: hdmi->setLEDColorRGB(30, 0, 30);  break;  // Magenta
    case 6: hdmi->setLEDColorRGB(20, 20, 20); break;  // White
    case 7: hdmi->setLEDColorRGB(0, 0, 0);    break;  // Off
  }
  
  // If text mode, show some text
  if (currentPattern == 3) {
    hdmi->clearScreen();
    hdmi->setTextColor(HDMI_COLOR_LIGHT_CYAN, HDMI_COLOR_BLUE);
    hdmi->setCursor(25, 12);
    hdmi->writeString("PAPILIO ARCADE");
  }
  
  Serial.printf("Pattern: %s | LED: %s\n", 
                patternNames[currentPattern], 
                colorNames[currentColor]);
}

void loop() {
  // Manual advance on key press
  if (Serial.available()) {
    Serial.read();
    currentPattern = (currentPattern + 1) % 4;
    currentColor = (currentColor + 1) % 8;
    updateDisplay();
    lastUpdate = millis();
  }
  
  // Auto-cycle every 3 seconds
  if (millis() - lastUpdate >= 3000) {
    currentPattern = (currentPattern + 1) % 4;
    currentColor = (currentColor + 1) % 8;
    updateDisplay();
    lastUpdate = millis();
  }
  
  delay(10);
}
