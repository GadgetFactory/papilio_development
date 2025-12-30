/*
 * FramebufferUpdate.ino
 * 
 * Demonstrates framebuffer updates using:
 * - Extended mode burst for on-chip framebuffer (Tier 2)
 * - Large mode burst for DDR framebuffer (Tier 3)
 */

#include <SmartSlotWishbone.h>

SmartSlotWishbone ssw;

// Framebuffer settings
#define FB_WIDTH  320
#define FB_HEIGHT 240
#define FB_SIZE   (FB_WIDTH * FB_HEIGHT * 2)  // 16-bit RGB565

// On-chip framebuffer address (Tier 2)
#define ONCHIP_FB_ADDR  0x2000

// External DDR framebuffer address (Tier 3)
#define DDR_FB_ADDR     0x010000

void setup() {
    Serial.begin(115200);
    while (!Serial) delay(10);
    
    Serial.println("Smart Slot Wishbone - Framebuffer Example");
    Serial.println("==========================================");
    
    ssw.begin();
    
    Serial.println("\nDrawing test pattern to on-chip framebuffer...");
    drawTestPattern(ONCHIP_FB_ADDR, true);
    
    Serial.println("Drawing gradient to DDR framebuffer...");
    drawGradient(DDR_FB_ADDR, false);
    
    Serial.println("\nDone!");
}

void loop() {
    // Animate colors
    static uint8_t frame = 0;
    
    // Create animated gradient
    uint8_t line[FB_WIDTH * 2];  // One line of RGB565
    
    for (int y = 0; y < FB_HEIGHT; y++) {
        for (int x = 0; x < FB_WIDTH; x++) {
            uint8_t r = (x + frame) & 0x1F;
            uint8_t g = (y + frame) & 0x3F;
            uint8_t b = ((x + y + frame) / 2) & 0x1F;
            
            uint16_t color = (r << 11) | (g << 5) | b;
            line[x * 2] = color >> 8;
            line[x * 2 + 1] = color & 0xFF;
        }
        
        // Update one line at a time
        ssw.writeExtendedBurst(ONCHIP_FB_ADDR + (y * FB_WIDTH * 2), line, FB_WIDTH * 2);
    }
    
    frame++;
    
    Serial.printf("Frame %d\r", frame);
}

void drawTestPattern(uint32_t fbAddr, bool useExtended) {
    // Draw color bars
    uint8_t line[FB_WIDTH * 2];
    
    for (int y = 0; y < FB_HEIGHT; y++) {
        uint8_t barWidth = FB_WIDTH / 8;
        
        for (int x = 0; x < FB_WIDTH; x++) {
            uint8_t bar = x / barWidth;
            uint16_t color;
            
            switch (bar) {
                case 0: color = 0xF800; break;  // Red
                case 1: color = 0x07E0; break;  // Green
                case 2: color = 0x001F; break;  // Blue
                case 3: color = 0xFFE0; break;  // Yellow
                case 4: color = 0xF81F; break;  // Magenta
                case 5: color = 0x07FF; break;  // Cyan
                case 6: color = 0xFFFF; break;  // White
                default: color = 0x0000; break; // Black
            }
            
            line[x * 2] = color >> 8;
            line[x * 2 + 1] = color & 0xFF;
        }
        
        if (useExtended) {
            ssw.writeExtendedBurst(fbAddr + (y * FB_WIDTH * 2), line, FB_WIDTH * 2);
        } else {
            ssw.writeLargeBurst(fbAddr + (y * FB_WIDTH * 2), line, FB_WIDTH * 2);
        }
        
        if (y % 30 == 0) {
            Serial.printf("  Progress: %d%%\r", (y * 100) / FB_HEIGHT);
        }
    }
    
    Serial.println("  Progress: 100%  ");
}

void drawGradient(uint32_t fbAddr, bool useExtended) {
    // Draw smooth gradient
    uint8_t line[FB_WIDTH * 2];
    
    for (int y = 0; y < FB_HEIGHT; y++) {
        for (int x = 0; x < FB_WIDTH; x++) {
            uint8_t r = (x * 31) / FB_WIDTH;
            uint8_t g = (y * 63) / FB_HEIGHT;
            uint8_t b = ((x + y) * 31) / (FB_WIDTH + FB_HEIGHT);
            
            uint16_t color = (r << 11) | (g << 5) | b;
            line[x * 2] = color >> 8;
            line[x * 2 + 1] = color & 0xFF;
        }
        
        if (useExtended) {
            ssw.writeExtendedBurst(fbAddr + (y * FB_WIDTH * 2), line, FB_WIDTH * 2);
        } else {
            ssw.writeLargeBurst(fbAddr + (y * FB_WIDTH * 2), line, FB_WIDTH * 2);
        }
        
        if (y % 30 == 0) {
            Serial.printf("  Progress: %d%%\r", (y * 100) / FB_HEIGHT);
        }
    }
    
    Serial.println("  Progress: 100%  ");
}
