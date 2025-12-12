/*
  ESP32-S3 GPIO Pin Scanner for FPGA UART
  ========================================
  
  This sketch helps identify which ESP32 GPIO pins are connected to
  the FPGA SUMP UART (pins C9 and E14).
  
  It will test common UART pin combinations and report which ones work.
*/

#include <HardwareSerial>

// Test these GPIO pin combinations
struct PinPair {
  int rx;
  int tx;
  const char* name;
};

PinPair test_pins[] = {
  {16, 17, "GPIO 16/17"},
  {17, 18, "GPIO 17/18"},
  {18, 19, "GPIO 19/18"},
  {3, 46, "GPIO 3/46 (UART0 alt)"},
  {44, 43, "GPIO 44/43 (UART1 default)"},
  {15, 16, "GPIO 15/16"},
  {-1, -1, nullptr}  // Terminator
};

void setup() {
  Serial.begin(115200);
  delay(2000);
  
  Serial.println("\n=== ESP32-S3 to FPGA UART Pin Scanner ===\n");
  Serial.println("This will test various GPIO pin combinations");
  Serial.println("to find which pins connect to FPGA C9/E14\n");
  
  for (int i = 0; test_pins[i].rx != -1; i++) {
    Serial.printf("Testing %s (RX=%d, TX=%d)...\n", 
                  test_pins[i].name, test_pins[i].rx, test_pins[i].tx);
    
    // Configure Serial1 with these pins
    Serial1.begin(115200, SERIAL_8N1, test_pins[i].rx, test_pins[i].tx);
    delay(100);
    
    // Send SUMP RESET and ID query
    Serial1.write(0x00);  // RESET
    Serial1.write(0x00);
    Serial1.write(0x00);
    delay(100);
    
    Serial1.write(0x02);  // ID query
    delay(200);
    
    // Check for response
    int bytes_received = 0;
    uint8_t response[16];
    while (Serial1.available() && bytes_received < 16) {
      response[bytes_received++] = Serial1.read();
    }
    
    if (bytes_received > 0) {
      Serial.printf("  ✅ RESPONSE! Received %d bytes: ", bytes_received);
      for (int j = 0; j < bytes_received; j++) {
        Serial.printf("%02X ", response[j]);
      }
      Serial.printf(" (");
      for (int j = 0; j < bytes_received; j++) {
        Serial.printf("%c", isprint(response[j]) ? response[j] : '.');
      }
      Serial.println(")");
      Serial.println("\n🎯 FOUND WORKING PINS!");
      Serial.printf("Update PapilioMCP.h:\n");
      Serial.printf("  #define MCP_SUMP_RX %d\n", test_pins[i].rx);
      Serial.printf("  #define MCP_SUMP_TX %d\n\n", test_pins[i].tx);
    } else {
      Serial.println("  No response");
    }
    
    Serial1.end();
    delay(200);
  }
  
  Serial.println("\n=== Scan Complete ===\n");
  Serial.println("If no pins responded:");
  Serial.println("  1. Check FPGA bitstream is loaded");
  Serial.println("  2. Verify C9/E14 are the correct FPGA pins");
  Serial.println("  3. Check hardware connections");
}

void loop() {
  // Nothing - scan runs once in setup()
}
