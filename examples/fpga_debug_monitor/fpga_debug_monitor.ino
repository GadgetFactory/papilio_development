// FPGA Debug Monitor for Papilio Arcade Board
// Reads debug registers from FPGA via Wishbone and outputs to USB CDC
//
// Debug registers at 0x8000-0x800B:
//   0x8000-0x8003: debug_status (h_cnt, v_cnt, frame_count)
//   0x8004-0x8007: debug_wb (write_count, last_addr)
//   0x8008-0x800B: debug_read (read_count, last_read_addr)

#include <Arduino.h>
#include <SPI.h>
#include "WishboneSPI.h"
#include "HQVGA.h"

// ESP32-S3 SPI pins for FPGA connection
#define SPI_MOSI 11
#define SPI_MISO 13
#define SPI_SCK  12
#define SPI_CS   10

// Debug register base address
#define DEBUG_REG_BASE 0x8000

// HQVGA instance
HQVGA* vga;

// SPI instance
SPIClass fpgaSPI(HSPI);

// Read a 32-bit debug value from 4 consecutive bytes
uint32_t readDebugReg32(uint16_t base_addr) {
    uint32_t value = 0;
    value |= (uint32_t)wishboneRead16(base_addr + 0);
    value |= (uint32_t)wishboneRead16(base_addr + 1) << 8;
    value |= (uint32_t)wishboneRead16(base_addr + 2) << 16;
    value |= (uint32_t)wishboneRead16(base_addr + 3) << 24;
    return value;
}

void setup() {
    // Initialize USB Serial for debug output
    Serial.begin(115200);
    while (!Serial && millis() < 3000); // Wait up to 3 seconds for serial
    
    Serial.println();
    Serial.println("=== FPGA Debug Monitor ===");
    Serial.println("Papilio Arcade Board - Framebuffer Debug");
    Serial.println();
    
    // Initialize SPI for FPGA communication
    fpgaSPI.begin(SPI_SCK, SPI_MISO, SPI_MOSI, SPI_CS);
    wishboneInit(&fpgaSPI, SPI_CS);
    
    // Initialize HQVGA with 8MHz SPI, uses same SPI pins
    vga = new HQVGA(&fpgaSPI, SPI_CS);
    vga->begin();
    
    // Fill screen with test pattern
    Serial.println("Drawing test pattern...");
    vga->clear(0);  // Black background
    
    // Draw some colored pixels to test
    for (int y = 0; y < 120; y++) {
        for (int x = 0; x < 160; x++) {
            // Create gradient pattern
            uint8_t r = (x * 7) / 159;  // 0-7
            uint8_t g = (y * 7) / 119;  // 0-7
            uint8_t b = 1;
            uint8_t color = (r << 5) | (g << 2) | b;
            vga->setPixel(x, y, color);
        }
    }
    
    // Draw text
    vga->printtext(10, 10, "DEBUG TEST", 0xFF, 0x00);
    
    Serial.println("Test pattern drawn. Starting debug monitor...");
    Serial.println();
    Serial.println("Register Map:");
    Serial.println("  0x8000-0x8003: h_cnt[7:0], h_cnt[11:4], v_cnt[7:0], frame_low");
    Serial.println("  0x8004-0x8007: last_addr_low, last_addr_hi, wr_cnt_low, wr_cnt_hi");
    Serial.println("  0x8008-0x800B: last_rd_low, last_rd_hi, rd_cnt_low, rd_cnt_hi");
    Serial.println();
}

void loop() {
    static unsigned long lastPrint = 0;
    
    // Print debug info every 2 seconds
    if (millis() - lastPrint > 2000) {
        lastPrint = millis();
        
        // Read all debug registers
        uint32_t debug_status = readDebugReg32(DEBUG_REG_BASE + 0x00);
        uint32_t debug_wb = readDebugReg32(DEBUG_REG_BASE + 0x04);
        uint32_t debug_read = readDebugReg32(DEBUG_REG_BASE + 0x08);
        
        // Extract fields from debug_status
        // Format: {frame_count[15:0], 4'd0, v_cnt[11:4], 4'd0, h_cnt[11:4]}
        uint16_t h_cnt_sample = (debug_status & 0xFF) << 4;
        uint16_t v_cnt_sample = ((debug_status >> 8) & 0xFF) << 4;
        uint16_t frame_count = (debug_status >> 16) & 0xFFFF;
        
        // Extract fields from debug_wb
        // Format: {write_count[15:0], last_addr[15:0]}
        uint16_t last_addr = debug_wb & 0xFFFF;
        uint16_t write_count = (debug_wb >> 16) & 0xFFFF;
        
        // Extract fields from debug_read
        // Format: {read_count[15:0], last_read_addr[15:0]}
        uint16_t last_read_addr = debug_read & 0xFFFF;
        uint16_t read_count = (debug_read >> 16) & 0xFFFF;
        
        Serial.println("--- FPGA Debug Status ---");
        Serial.printf("  Frame Count:   %u\n", frame_count);
        Serial.printf("  H Count (snap): %u\n", h_cnt_sample);
        Serial.printf("  V Count (snap): %u\n", v_cnt_sample);
        Serial.println();
        Serial.printf("  WB Write Count: %u\n", write_count);
        Serial.printf("  Last Write Addr: 0x%04X (%u)\n", last_addr, last_addr);
        Serial.println();
        Serial.printf("  FB Read Count:  %u (low 16 bits)\n", read_count);
        Serial.printf("  Last Read Addr: 0x%04X (%u)\n", last_read_addr, last_read_addr);
        Serial.println();
        
        // Raw register values
        Serial.printf("  Raw: status=0x%08X wb=0x%08X read=0x%08X\n", 
                      debug_status, debug_wb, debug_read);
        Serial.println("-------------------------");
        Serial.println();
    }
}
