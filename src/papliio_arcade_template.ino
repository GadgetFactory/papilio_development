/*
  Papilio Arcade - Simple Demo
  ============================
  
  Cycles through HDMI video patterns and RGB LED colors.
  Press any key in Serial Monitor to manually advance.
  
  Hardware: Papilio Arcade board with ESP32-S3 and FPGA
  
  MCP Debug: Uncomment the line below to enable MCP debug interface.
  This allows AI assistants (via MCP server) to read/write FPGA registers.
  
  Note: The MCP debug interface uses the same Serial port with protocol framing.
  A future enhancement could add dual USB CDC support for separate channels.
*/

#define PAPILIO_MCP_ENABLED  // Uncomment to enable MCP debug interface
#include <PapilioMCP.h>

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
int cycleCount = 0;  // Track cycles for breakpoint demo
unsigned long lastUpdate = 0;

// Pattern and color names for display
const char* patternNames[] = {"Color Bars", "Grid", "Grayscale", "Text Mode", "Framebuffer Bars"};
const char* colorNames[] = {"Red", "Green", "Blue", "Yellow", "Cyan", "Magenta", "White", "Off"};

void setup() {
  Serial.begin(115200);
  
  delay(2000);
  
  Serial.println("\n=== Papilio Arcade Demo ===\n");
  
  // Initialize HDMI controller
  hdmi = new HDMIController(nullptr, SPI_CS, SPI_CLK, SPI_MOSI, SPI_MISO);
  hdmi->begin();
  
  // Initialize MCP debug (does nothing if PAPILIO_MCP_ENABLED not defined)
  PapilioMCP.begin();
  
  Serial.println("Ready! Auto-cycling every 3 seconds.");
  Serial.println("Press any key to advance manually.\n");
  
  updateDisplay();
}

void updateDisplay() {
  // Set video pattern (0-4)
  if (currentPattern < 4) {
    hdmi->setVideoMode(VIDEO_MODE_TEST_PATTERN);
    hdmi->setVideoPattern(currentPattern);
  } else if (currentPattern == 4) {
    // Framebuffer color bars
    Serial.println("Drawing framebuffer color bars...");
    hdmi->enableFramebuffer();
    hdmi->drawColorBars();
    Serial.println("Done!");
  }
  
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
  
  // If text mode, show demo text
  if (currentPattern == 3) {
    hdmi->clearScreen();
    
    // Header with colored background
    hdmi->setTextColor(HDMI_COLOR_YELLOW, HDMI_COLOR_BLUE);
    hdmi->setCursor(33, 2);
    hdmi->writeString("PAPILIO ARCADE");
    
    // Subtitle
    hdmi->setTextColor(HDMI_COLOR_WHITE, HDMI_COLOR_BLACK);
    hdmi->setCursor(28, 4);
    hdmi->writeString("ESP32-S3 + Gowin FPGA");
    
    // Feature list with colors
    hdmi->setTextColor(HDMI_COLOR_LIGHT_GREEN, HDMI_COLOR_BLACK);
    hdmi->setCursor(20, 7);
    hdmi->writeString("Video Modes:");
    
    hdmi->setTextColor(HDMI_COLOR_LIGHT_CYAN, HDMI_COLOR_BLACK);
    hdmi->setCursor(22, 9);
    hdmi->writeString("- 720p HDMI Output");
    hdmi->setCursor(22, 10);
    hdmi->writeString("- Test Patterns");
    hdmi->setCursor(22, 11);
    hdmi->writeString("- 80x30 Text Mode (this!)");
    hdmi->setCursor(22, 12);
    hdmi->writeString("- 160x120 Framebuffer");
    
    // Color palette demo
    hdmi->setTextColor(HDMI_COLOR_LIGHT_MAGENTA, HDMI_COLOR_BLACK);
    hdmi->setCursor(20, 15);
    hdmi->writeString("CGA 16-Color Palette:");
    
    // Show all 16 colors
    for (int i = 0; i < 16; i++) {
      hdmi->setTextColor(i, HDMI_COLOR_BLACK);
      hdmi->setCursor(22 + (i % 8) * 4, 17 + (i / 8));
      hdmi->writeString("##");
    }
    
    // Footer
    hdmi->setTextColor(HDMI_COLOR_DARK_GRAY, HDMI_COLOR_BLACK);
    hdmi->setCursor(25, 22);
    hdmi->writeString("gadgetfactory.net");
  }
  
  Serial.printf("Pattern: %s | LED: %s\n", 
                patternNames[currentPattern], 
                colorNames[currentColor]);
}

void loop() {
  // Process MCP debug commands (does nothing if not enabled)
  PapilioMCP.update();
  
  // Skip sketch logic when MCP is paused (allows MCP full control)
  if (PapilioMCP.isPaused()) {
    delay(10);
    return;
  }
  
  // Manual advance on key press (Note: when MCP is enabled, serial input goes to MCP)
  // To use breakpoints, add PapilioMCP.breakpoint("name") at strategic points in your code
  if (Serial.available()) {
    Serial.read();
    // Example breakpoint - uncomment to pause here before update:
    // PapilioMCP.breakpoint("manual_advance");
    currentPattern = (currentPattern + 1) % 5;  // Now 5 patterns (0-4)
    currentColor = (currentColor + 1) % 8;
    updateDisplay();
    lastUpdate = millis();
  }
  
  // Auto-cycle every 3 seconds
  if (millis() - lastUpdate >= 3000) {
    cycleCount++;
    
    // Breakpoint demo: pause every 4th cycle to let MCP inspect state
    // Uncomment to test: if (cycleCount % 4 == 0) PapilioMCP.breakpoint("cycle_4");
    
    currentPattern = (currentPattern + 1) % 5;  // Now 5 patterns (0-4)
    currentColor = (currentColor + 1) % 8;
    updateDisplay();
    lastUpdate = millis();
  }
  
  delay(10);
}
