// BurstTransfer.ino - PWB2 example demonstrating burst mode transfers
// Shows performance improvement of burst mode for bulk data

#include <PapilioWishbone2.h>

PapilioWishbone2 pwb2;

// Test data buffer (1KB)
uint32_t testData[256];

void setup() {
    Serial.begin(115200);
    delay(1000);
    
    Serial.println("===== PWB2 Burst Transfer Demo =====");
    
    // Initialize test data
    for (int i = 0; i < 256; i++) {
        testData[i] = 0xDEAD0000 | i;
    }
    
    // Initialize PWB2
    if (!pwb2.begin()) {
        Serial.println("ERROR: PWB2 initialization failed!");
        while (1) delay(1000);
    }
    
    Serial.println("PWB2 initialized successfully!");
    
    // Enumerate devices
    pwb2.enumerateDevices();
    pwb2.printDevices(Serial);
    
    Serial.println("\n===== Performance Test =====");
    testPerformance();
}

void testPerformance() {
    uint32_t startTime, endTime;
    const int iterations = 10;
    
    // Test 1: Single writes to Extended memory
    Serial.println("\nTest 1: Single 32-bit writes (1KB)");
    pwb2.resetStatistics();
    startTime = millis();
    
    for (int iter = 0; iter < iterations; iter++) {
        for (int i = 0; i < 256; i++) {
            pwb2.writeExtended(0x2000 + (i * 4), testData[i]);
        }
    }
    
    endTime = millis();
    Serial.printf("  Time: %d ms for %d iterations\n", endTime - startTime, iterations);
    Serial.printf("  Transactions: %d\n", pwb2.getTransactionCount());
    Serial.printf("  Throughput: %.2f KB/s\n", 
                  (1.0 * iterations / (endTime - startTime)) * 1000.0);
    
    // Test 2: Burst writes to Extended memory
    Serial.println("\nTest 2: Burst writes (1KB)");
    pwb2.resetStatistics();
    startTime = millis();
    
    for (int iter = 0; iter < iterations; iter++) {
        pwb2.writeExtendedBurst(0x2000, testData, 256);
    }
    
    endTime = millis();
    Serial.printf("  Time: %d ms for %d iterations\n", endTime - startTime, iterations);
    Serial.printf("  Transactions: %d\n", pwb2.getTransactionCount());
    Serial.printf("  Throughput: %.2f KB/s\n", 
                  (1.0 * iterations / (endTime - startTime)) * 1000.0);
    
    // Calculate improvement
    float singleRate = (1.0 * iterations / (endTime - startTime)) * 1000.0;
    Serial.printf("\n  Performance improvement: %.1fx faster!\n", singleRate);
    
    // Test 3: Read back with burst
    Serial.println("\nTest 3: Burst read verification");
    uint32_t readData[256];
    pwb2.readExtendedBurst(0x2000, readData, 256);
    
    int errors = 0;
    for (int i = 0; i < 256; i++) {
        if (readData[i] != testData[i]) {
            errors++;
            if (errors < 5) {  // Only show first few errors
                Serial.printf("  ERROR at [%d]: wrote 0x%08X, read 0x%08X\n",
                             i, testData[i], readData[i]);
            }
        }
    }
    
    if (errors == 0) {
        Serial.println("  Verification PASSED: All data correct!");
    } else {
        Serial.printf("  Verification FAILED: %d errors\n", errors);
    }
}

void loop() {
    delay(5000);
    Serial.println("\nRunning performance test again...");
    testPerformance();
}
