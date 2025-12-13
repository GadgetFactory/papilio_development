/*
  Papilio Arcade - UART passthrough

  Minimal sketch: forward bytes bidirectionally between USB Serial
  (host) and Serial1 (FPGA UART pins). No other functionality.
*/

// SUMP UART pins - Original working configuration
#define SUMP_RX_GPIO 4 // Connects to J11
#define SUMP_TX_GPIO 3 // Connects to F10

void setup() {
  // USB serial to host
  Serial.begin(115200);
  // delay(5000);
  // Serial.println("UART passthrough: USB <-> FPGA (Serial1)");

  // // Hardware UART to FPGA - explicitly map pins
  Serial1.begin(115200, SERIAL_8N1, SUMP_RX_GPIO, SUMP_TX_GPIO);
  // Serial.println("Serial1 ready at 115200 (RX=3, TX=4)");

  // // Send SUMP ID query (0x02) and print response
  // Serial.println("Sending SUMP ID query (0x02) to FPGA...");
  // Serial1.write(0x02);

  // unsigned long start = millis();
  // while (millis() - start < 200) {
  //   while (Serial1.available()) {
  //     uint8_t b = Serial1.read();
  //     Serial.printf("0x%02X ", b);
  //     Serial.write(b);
  //   }
  // }
  // Serial.println();
}

// unsigned long last_test_send = 0;

void loop() {
  // // USB -> FPGA (and local host commands)
  // while (Serial.available()) {
  //   uint8_t c = Serial.read();
  //   if (c == 'i' || c == 'I') {
  //     // Host requested ID query
  //     Serial.println("\nQuerying FPGA ID...");
  //     Serial1.write(0x02);
  //     unsigned long start = millis();
  //     while (millis() - start < 200) {
  //       while (Serial1.available()) {
  //         uint8_t b = Serial1.read();
  //         Serial.printf("0x%02X ", b);
  //         Serial.write(b);
  //       }
  //     }
  //     Serial.println();
  //   } else {
  //     Serial1.write(c);
  //   }
  // }

  // // Periodic self-test: send 0x55 every 1s and look for response
  // if (millis() - last_test_send > 1000) {
  //   last_test_send = millis();
  //   Serial.println("Sending test frame 0x55 to Serial1...");
  //   Serial1.write(0x55);
  //   unsigned long start = millis();
  //   bool got = false;
  //   while (millis() - start < 200) {
  //     while (Serial1.available()) {
  //       uint8_t b = Serial1.read();
  //       Serial.printf("Response: 0x%02X\n", b);
  //       got = true;
  //     }
  //   }
  //   if (!got) Serial.println("No response to test frame");
  // }

  // FPGA -> USB
  // while (Serial1.available()) {
  //   uint8_t c = Serial1.read();
  //   Serial.write(c);
  // }

  if (Serial1.available()) {
   Serial.write(Serial1.read()); 
  }
  if (Serial.available()) {
   Serial1.write(Serial.read()); 
  }  


  // delay(1);
}

