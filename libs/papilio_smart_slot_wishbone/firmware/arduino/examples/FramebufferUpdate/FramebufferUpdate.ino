/*
 * FramebufferUpdate.ino
 * 
 * Demonstrates efficient framebuffer updates using burst mode.
 * Shows performance comparison between single writes and burst writes.
 */

#include <SmartSlotWishbone.h>

// Create SSW instance
SmartSlotWishbone ssw;

// Framebuffer settings
#define FB_WIDTH  320
#define FB_HEIGHT 240
#define FB_SIZE   (FB_WIDTH * FB_HEIGHT * 2)  // 16-bit color
#define FB_ADDR   0x2000  // Starts at 0x2000 in extended mode

uint8_t framebuffer[1024];  // Small test buffer

void setup() {
    Serial.begin(115200);
    while (!Serial) delay(10);
    
    Serial.println("Smart Slot Wishbone - Framebuffer Example");
    Serial.println("=========================================");
    
    // Initialize SSW
    if (!ssw.begin(40000000)) {  // 40 MHz for faster transfers
        Serial.println("ERROR: Failed to initialize SSW!");
        while(1) delay(1000);
    }
    
    Serial.println("SSW initialized successfully");
    ssw.setDebug(true);
    
    // Create test pattern
    for (int i = 0; i < sizeof(framebuffer); i++) {
        framebuffer[i] = i & 0xFF;
    }
    
    // Performance comparison
    performanceTest();
}

void loop() {
    // Fill framebuffer with different patterns
    
    // Horizontal stripes
    Serial.println("\nDrawing horizontal stripes...");
    for (int i = 0; i < sizeof(framebuffer); i++) {
        framebuffer[i] = (i / 64) * 32;
    }
    updateFramebuffer();
    delay(2000);
    
    // Vertical stripes
    Serial.println("Drawing vertical stripes...");
    for (int i = 0; i < sizeof(framebuffer); i++) {
        framebuffer[i] = (i % 64) * 4;
    }
    updateFramebuffer();
    delay(2000);
    
    // Checkerboard
    Serial.println("Drawing checkerboard...");
    for (int i = 0; i < sizeof(framebuffer); i++) {
        int x = i % 32;
        int y = i / 32;
        framebuffer[i] = ((x/8 + y/8) & 1) ? 255 : 0;
    }
    updateFramebuffer();
    delay(2000);
}

void updateFramebuffer() {
    unsigned long start = micros();
    
    // Use burst mode for efficiency
    ssw.writeExtendedBurst(FB_ADDR, framebuffer, sizeof(framebuffer));
    
    unsigned long elapsed = micros() - start;
    float rate = (sizeof(framebuffer) / (elapsed / 1000000.0)) / 1024.0;
    
    Serial.printf("Updated %d bytes in %lu us (%.2f KB/s)\n", 
                  sizeof(framebuffer), elapsed, rate);
}

void performanceTest() {
    Serial.println("\n=== Performance Test ===");
    
    // Test 1: Single writes
    Serial.println("\nTest 1: Single writes (100 bytes)");
    ssw.resetTransactionCount();
    unsigned long start = micros();
    
    for (int i = 0; i < 100; i++) {
        ssw.writeExtended(FB_ADDR + i, framebuffer[i]);
    }
    
    unsigned long elapsed1 = micros() - start;
    Serial.printf("Time: %lu us\n", elapsed1);
    Serial.printf("Transactions: %lu\n", ssw.getTransactionCount());
    Serial.printf("Rate: %.2f KB/s\n", (100.0 / (elapsed1 / 1000000.0)) / 1024.0);
    
    // Test 2: Burst write
    Serial.println("\nTest 2: Burst write (100 bytes)");
    ssw.resetTransactionCount();
    start = micros();
    
    ssw.writeExtendedBurst(FB_ADDR, framebuffer, 100);
    
    unsigned long elapsed2 = micros() - start;
    Serial.printf("Time: %lu us\n", elapsed2);
    Serial.printf("Transactions: %lu\n", ssw.getTransactionCount());
    Serial.printf("Rate: %.2f KB/s\n", (100.0 / (elapsed2 / 1000000.0)) / 1024.0);
    
    // Show speedup
    float speedup = (float)elapsed1 / (float)elapsed2;
    Serial.printf("\nBurst mode speedup: %.1fx\n", speedup);
    Serial.printf("Efficiency gain: %.1f%%\n", (speedup - 1.0) * 100.0);
}
