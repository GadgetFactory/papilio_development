/*
  Gadget Factory
  Papilio Arcade Board - MCP Debug Interface with JTAG Bridge
  
  Features:
  - USB CDC Serial for logging and MCP commands
  - USB JTAG routed to GPIO pins for FPGA programming
  - Direct Wishbone bus read/write via SPI
  - FPGA can be programmed via openFPGALoader through USB JTAG
  
  Hardware:
  - Papilio Arcade board with ESP32-S3 and FPGA
  - HDMI output (via FPGA framebuffer)
  
  Based on: https://github.com/emard/esp32s3-jtag
*/

#include <SPI.h>
#include "soc/usb_serial_jtag_reg.h"
#include "soc/gpio_sig_map.h"
#include "esp_rom_gpio.h"
#include "hal/usb_serial_jtag_ll.h"

// ============================================================================
// Pin Configuration
// ============================================================================

// SPI pins for Wishbone communication
#define SPI_CLK   12
#define SPI_MOSI  11
#define SPI_MISO  9    // FPGA pin C11
#define SPI_CS    10

// JTAG pins routed to FPGA
// TODO: Adjust these pins based on your PCB routing
#define PIN_TCK   6
#define PIN_TMS   8
#define PIN_TDI   7
#define PIN_TDO   5
#define PIN_SRST  13   // Active low reset to FPGA (was GPIO 9, swapped with MISO)

// LED for status
#ifndef LED_BUILTIN
#define LED_BUILTIN 48
#endif
#define LED_ON  LOW
#define LED_OFF HIGH

// SPI instance
SPIClass* fpgaSPI = nullptr;

// Global state
String mcpBuffer = "";
bool usb_was_connected = false;
bool jtag_enabled = false;

// ============================================================================
// USB JTAG Bridge Functions
// ============================================================================

void route_usb_jtag_to_gpio() {
  Serial.println("[JTAG] Routing USB JTAG to FPGA pins...");
  
  pinMode(PIN_TCK, OUTPUT);
  pinMode(PIN_TMS, OUTPUT);
  pinMode(PIN_TDI, OUTPUT);
  pinMode(PIN_TDO, INPUT);
  pinMode(PIN_SRST, OUTPUT);
  digitalWrite(PIN_SRST, HIGH);  // Keep FPGA out of reset
  
  // Enable JTAG bridge in USB peripheral
  WRITE_PERI_REG(USB_SERIAL_JTAG_CONF0_REG,
    READ_PERI_REG(USB_SERIAL_JTAG_CONF0_REG)
    | USB_SERIAL_JTAG_USB_JTAG_BRIDGE_EN);
  
  // Route signals through GPIO matrix
  esp_rom_gpio_connect_out_signal(PIN_TCK,  USB_JTAG_TCK_IDX, false, false);
  esp_rom_gpio_connect_out_signal(PIN_TMS,  USB_JTAG_TMS_IDX, false, false);
  esp_rom_gpio_connect_out_signal(PIN_TDI,  USB_JTAG_TDI_IDX, false, false);
  esp_rom_gpio_connect_out_signal(PIN_SRST, USB_JTAG_TRST_IDX, false, false);
  esp_rom_gpio_connect_in_signal(PIN_TDO,   USB_JTAG_TDO_BRIDGE_IDX, false);
  
  jtag_enabled = true;
  digitalWrite(LED_BUILTIN, LED_ON);
  Serial.println("[JTAG] Bridge enabled - FPGA ready for programming");
}

void unroute_usb_jtag_to_gpio() {
  Serial.println("[JTAG] Disabling USB JTAG bridge...");
  
  // Disable JTAG bridge
  WRITE_PERI_REG(USB_SERIAL_JTAG_CONF0_REG,
    READ_PERI_REG(USB_SERIAL_JTAG_CONF0_REG)
    & ~USB_SERIAL_JTAG_USB_JTAG_BRIDGE_EN);
  
  // Release pins
  pinMode(PIN_TCK,  INPUT);
  pinMode(PIN_TMS,  INPUT);
  pinMode(PIN_TDI,  INPUT);
  pinMode(PIN_TDO,  INPUT);
  pinMode(PIN_SRST, INPUT);
  
  jtag_enabled = false;
  digitalWrite(LED_BUILTIN, LED_OFF);
  Serial.println("[JTAG] Bridge disabled");
}

// ============================================================================
// Wishbone SPI Functions
// ============================================================================

void wishboneWrite(uint16_t address, uint8_t data) {
  fpgaSPI->beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
  digitalWrite(SPI_CS, LOW);
  delayMicroseconds(1);
  fpgaSPI->transfer(0x01);                    // CMD_WRITE
  fpgaSPI->transfer((address >> 8) & 0xFF);   // Address high byte
  fpgaSPI->transfer(address & 0xFF);          // Address low byte
  fpgaSPI->transfer(data);                    // Data
  delayMicroseconds(1);
  digitalWrite(SPI_CS, HIGH);
  fpgaSPI->endTransaction();
  delayMicroseconds(10);
}

uint8_t wishboneRead(uint16_t address) {
  uint8_t result = 0;
  fpgaSPI->beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
  digitalWrite(SPI_CS, LOW);
  delayMicroseconds(1);
  fpgaSPI->transfer(0x00);                    // CMD_READ
  fpgaSPI->transfer((address >> 8) & 0xFF);   // Address high byte
  fpgaSPI->transfer(address & 0xFF);          // Address low byte
  // Wait for Wishbone read to complete before clocking out result
  // At 27MHz FPGA clock, 10us = 270 cycles, plenty of time
  delayMicroseconds(10);
  
  result = fpgaSPI->transfer(0x00);           // Read result
  delayMicroseconds(1);
  digitalWrite(SPI_CS, HIGH);
  fpgaSPI->endTransaction();
  return result;
}

// ============================================================================
// MCP Command Processing
// ============================================================================

void mcpSendResponse(const char* response) {
  Serial.println(response);
}

void mcpProcessCommand(String cmd) {
  cmd.trim();
  if (cmd.length() == 0) return;
  
  Serial.print("[MCP] ");
  Serial.println(cmd);
  
  char cmdType = cmd.charAt(0);
  
  switch (cmdType) {
    case 'W':
    case 'w': {
      // Write command: W AAAA DD
      if (cmd.length() >= 9) {
        uint16_t addr = strtol(cmd.substring(2, 6).c_str(), NULL, 16);
        uint8_t data = strtol(cmd.substring(7, 9).c_str(), NULL, 16);
        wishboneWrite(addr, data);
        char response[64];
        snprintf(response, sizeof(response), "OK W %04X=%02X", addr, data);
        mcpSendResponse(response);
      } else {
        mcpSendResponse("ERR: W AAAA DD");
      }
      break;
    }
    
    case 'R':
    case 'r': {
      // Read command: R AAAA
      if (cmd.length() >= 6) {
        uint16_t addr = strtol(cmd.substring(2, 6).c_str(), NULL, 16);
        uint8_t data = wishboneRead(addr);
        char response[64];
        snprintf(response, sizeof(response), "OK R %04X=%02X", addr, data);
        mcpSendResponse(response);
      } else {
        mcpSendResponse("ERR: R AAAA");
      }
      break;
    }
    
    case 'M':
    case 'm': {
      // Multi-read command: M AAAA NN (read NN bytes starting at AAAA)
      if (cmd.length() >= 9) {
        uint16_t addr = strtol(cmd.substring(2, 6).c_str(), NULL, 16);
        uint8_t count = strtol(cmd.substring(7, 9).c_str(), NULL, 16);
        if (count > 64) count = 64;  // Limit to 64 bytes
        
        Serial.printf("OK M %04X:", addr);
        for (int i = 0; i < count; i++) {
          uint8_t data = wishboneRead(addr + i);
          Serial.printf(" %02X", data);
        }
        Serial.println();
      } else {
        mcpSendResponse("ERR: M AAAA NN");
      }
      break;
    }
    
    case 'D':
    case 'd': {
      // Dump debug registers
      mcpSendResponse("=== DEBUG DUMP ===");
      Serial.printf("JTAG Bridge: %s\n", jtag_enabled ? "ENABLED" : "disabled");
      Serial.printf("USB Connected: %s\n", usb_serial_jtag_ll_txfifo_writable() ? "YES" : "NO");
      mcpSendResponse("--- RGB LED (0x0000-0x000F) ---");
      for (uint16_t i = 0; i < 4; i++) {
        uint8_t data = wishboneRead(i);
        Serial.printf("  [%04X] = %02X\n", i, data);
      }
      mcpSendResponse("--- Framebuffer samples ---");
      for (uint16_t i = 0; i < 16; i++) {
        uint16_t addr = i * 4;
        uint8_t data = wishboneRead(addr);
        Serial.printf("  [%04X] = %02X\n", addr, data);
      }
      mcpSendResponse("=== END DUMP ===");
      break;
    }
    
    case 'F':
    case 'f': {
      // Fill framebuffer: F CC (fill with color CC)
      if (cmd.length() >= 4) {
        uint8_t color = strtol(cmd.substring(2, 4).c_str(), NULL, 16);
        Serial.printf("Filling framebuffer with 0x%02X...\n", color);
        for (uint16_t pixel = 0; pixel < 19200; pixel++) {
          // Word-aligned addressing: pixel * 4
          uint16_t addr = (pixel << 2) & 0x7FFF;
          wishboneWrite(addr, color);
          if ((pixel % 1000) == 0) {
            Serial.printf("  %d/19200\n", pixel);
          }
        }
        mcpSendResponse("OK FILL DONE");
      } else {
        mcpSendResponse("ERR: F CC");
      }
      break;
    }
    
    case 'P':
    case 'p': {
      // Put pixel: P XXXX YYYY CC (x, y, color in hex)
      if (cmd.length() >= 14) {
        uint16_t x = strtol(cmd.substring(2, 6).c_str(), NULL, 16);
        uint16_t y = strtol(cmd.substring(7, 11).c_str(), NULL, 16);
        uint8_t color = strtol(cmd.substring(12, 14).c_str(), NULL, 16);
        if (x < 160 && y < 120) {
          uint16_t pixel = y * 160 + x;
          uint16_t addr = (pixel << 2) & 0x7FFF;
          wishboneWrite(addr, color);
          char response[64];
          snprintf(response, sizeof(response), "OK P %d,%d=%02X (addr=%04X)", x, y, color, addr);
          mcpSendResponse(response);
        } else {
          mcpSendResponse("ERR: X<160 Y<120");
        }
      } else {
        mcpSendResponse("ERR: P XXXX YYYY CC");
      }
      break;
    }
    
    case 'T':
    case 't': {
      // Test pattern
      mcpSendResponse("DRAWING TEST PATTERN...");
      // Draw horizontal gradient
      for (uint16_t y = 0; y < 120; y++) {
        for (uint16_t x = 0; x < 160; x++) {
          uint8_t color = (x >> 1) & 0xFF;  // Gradient based on X
          uint16_t pixel = y * 160 + x;
          uint16_t addr = (pixel << 2) & 0x7FFF;
          wishboneWrite(addr, color);
        }
        if ((y % 20) == 0) {
          Serial.printf("  Row %d/120\n", y);
        }
      }
      mcpSendResponse("OK TEST DONE");
      break;
    }
    
    case 'J':
    case 'j': {
      // JTAG control: J 1 = enable, J 0 = disable
      if (cmd.length() >= 3) {
        char action = cmd.charAt(2);
        if (action == '1' || action == 'e' || action == 'E') {
          route_usb_jtag_to_gpio();
        } else if (action == '0' || action == 'd' || action == 'D') {
          unroute_usb_jtag_to_gpio();
        } else {
          Serial.printf("JTAG Bridge: %s\n", jtag_enabled ? "ENABLED" : "disabled");
        }
      } else {
        Serial.printf("JTAG Bridge: %s\n", jtag_enabled ? "ENABLED" : "disabled");
      }
      break;
    }
    
    case 'H':
    case 'h':
    case '?': {
      // Help
      mcpSendResponse("=== PAPILIO MCP DEBUG + JTAG ===");
      mcpSendResponse("W AAAA DD     - Write DD to addr AAAA");
      mcpSendResponse("R AAAA        - Read from addr AAAA");
      mcpSendResponse("M AAAA NN     - Read NN bytes from AAAA");
      mcpSendResponse("D             - Dump debug registers");
      mcpSendResponse("F CC          - Fill framebuffer with CC");
      mcpSendResponse("P XXXX YYYY CC - Put pixel");
      mcpSendResponse("T             - Draw test pattern");
      mcpSendResponse("J [1|0]       - Enable/disable JTAG bridge");
      mcpSendResponse("G             - GPIO debug (read MISO pin)");
      mcpSendResponse("H             - This help");
      mcpSendResponse("(All values in hex)");
      Serial.printf("JTAG: TCK=%d TMS=%d TDI=%d TDO=%d SRST=%d\n", 
                    PIN_TCK, PIN_TMS, PIN_TDI, PIN_TDO, PIN_SRST);
      break;
    }
    
    case 'G':
    case 'g': {
      // GPIO debug - slow toggle test
      Serial.println("=== FPGA LOOPBACK - SLOW TOGGLE TEST ===");
      Serial.printf("ESP32: MOSI=GPIO%d  MISO=GPIO%d\n", SPI_MOSI, SPI_MISO);
      Serial.printf("FPGA:  MOSI=B11     MISO=C11\n");
      Serial.println("FPGA should have: assign esp_miso = esp_mosi;");
      Serial.println();
      
      // JTAG disabled for debugging
      // unroute_usb_jtag_to_gpio();
      
      // First test: can we pull MISO low with internal pulldown?
      Serial.println("--- Test 0: Internal pulldown test ---");
      pinMode(SPI_MISO, INPUT_PULLDOWN);
      delay(10);
      Serial.printf("  MISO with PULLDOWN: %d\n", digitalRead(SPI_MISO));
      pinMode(SPI_MISO, INPUT_PULLUP);
      delay(10);
      Serial.printf("  MISO with PULLUP: %d\n", digitalRead(SPI_MISO));
      pinMode(SPI_MISO, INPUT);
      delay(10);
      Serial.printf("  MISO floating: %d\n", digitalRead(SPI_MISO));
      
      // Configure pins manually
      pinMode(SPI_MOSI, OUTPUT);
      pinMode(SPI_MISO, INPUT_PULLDOWN);
      pinMode(SPI_CS, OUTPUT);
      pinMode(SPI_CLK, OUTPUT);
      
      digitalWrite(SPI_CS, LOW);   // Enable FPGA
      digitalWrite(SPI_CLK, LOW);
      
      Serial.println("--- Test 1: Toggle MOSI, read MISO ---");
      for (int i = 0; i < 10; i++) {
        int mosi_val = i % 2;
        digitalWrite(SPI_MOSI, mosi_val);
        delay(100);  // Wait 100ms for signal to propagate
        int miso_val = digitalRead(SPI_MISO);
        Serial.printf("  MOSI=%d -> MISO=%d  %s\n", mosi_val, miso_val, 
                      (mosi_val == miso_val) ? "OK" : "FAIL");
      }
      
      digitalWrite(SPI_CS, HIGH);  // Disable FPGA
      
      // JTAG disabled for debugging
      // route_usb_jtag_to_gpio();
      
      // Re-init SPI
      fpgaSPI->begin(SPI_CLK, SPI_MISO, SPI_MOSI, SPI_CS);
      
      Serial.println("=== END TEST ===");
      break;
    }
    
    default:
      mcpSendResponse("ERR: Unknown command (H for help)");
      break;
  }
}

// ============================================================================
// Setup and Loop
// ============================================================================

void setup() {
  // Initialize LED
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LED_OFF);
  
  // Initialize USB Serial (CDC)
  Serial.begin(115200);
  
  // Wait for USB enumeration
  delay(2000);
  
  Serial.println();
  Serial.println("===========================================");
  Serial.println("Papilio Arcade - MCP Debug + JTAG Bridge");
  Serial.println("===========================================");
  Serial.println();
  Serial.printf("JTAG Pins: TCK=%d TMS=%d TDI=%d TDO=%d SRST=%d\n", 
                PIN_TCK, PIN_TMS, PIN_TDI, PIN_TDO, PIN_SRST);
  Serial.printf("SPI Pins:  CLK=%d MOSI=%d MISO=%d CS=%d\n",
                SPI_CLK, SPI_MOSI, SPI_MISO, SPI_CS);
  Serial.println();
  
  // Initialize SPI for FPGA Wishbone communication
  pinMode(SPI_CS, OUTPUT);
  digitalWrite(SPI_CS, HIGH);
  
  // Explicitly configure MISO as input with no pull
  pinMode(SPI_MISO, INPUT);
  
  fpgaSPI = new SPIClass(HSPI);
  fpgaSPI->begin(SPI_CLK, SPI_MISO, SPI_MOSI, SPI_CS);
  
  // Debug: Check MISO pin state after SPI init
  Serial.printf("SPI initialized. MISO pin %d state: %d\n", SPI_MISO, digitalRead(SPI_MISO));
  Serial.println("SPI initialized for Wishbone communication");
  Serial.println();
  
  // JTAG bridge disabled for debugging - use J 1 to enable manually
  // route_usb_jtag_to_gpio();
  
  Serial.println();
  Serial.println("Ready! Type H for help.");
  Serial.println("Use openFPGALoader to program FPGA via USB JTAG.");
  Serial.println();
}

void loop() {
  // JTAG auto-enable disabled for debugging
  // bool usb_is_connected = usb_serial_jtag_ll_txfifo_writable();
  // if (usb_was_connected == false && usb_is_connected == true) {
  //   if (!jtag_enabled) {
  //     route_usb_jtag_to_gpio();
  //   }
  // }
  // usb_was_connected = usb_is_connected;
  
  // Process MCP commands from USB Serial
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n' || c == '\r') {
      if (mcpBuffer.length() > 0) {
        mcpProcessCommand(mcpBuffer);
        mcpBuffer = "";
      }
    } else {
      if (mcpBuffer.length() < 256) {
        mcpBuffer += c;
      }
    }
  }
  
  delay(1);
}
