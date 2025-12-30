/*
 * SmartSlotWishbone.h - Smart Slot Wishbone Arduino Library
 * 
 * Three-tier addressing for ESP32-to-FPGA communication:
 * - Tier 1 (Slot):     3 bytes - Control registers (32 slots × 256 bytes)
 * - Tier 2 (Extended): 4 bytes - On-chip memory (64KB)
 * - Tier 3 (Large):    5 bytes - External DDR/SDRAM (16MB)
 */

#ifndef SMART_SLOT_WISHBONE_H
#define SMART_SLOT_WISHBONE_H

#include <Arduino.h>
#include <SPI.h>

// Protocol constants
#define SSW_CMD_READ        0x00
#define SSW_CMD_WRITE       0x80

#define SSW_MODE_SLOT       0x00  // Bits [6:5] = 00
#define SSW_MODE_EXTENDED   0x20  // Bits [6:5] = 01
#define SSW_MODE_LARGE      0x40  // Bits [6:5] = 10

#define SSW_BURST_FLAG      0x08  // Bit [3]

// Device IDs
#define SSW_DEVID_SYSTEM    0x5359  // "SY"stem
#define SSW_DEVID_RGB_LED   0x4C45  // "LE"d
#define SSW_DEVID_SID       0x5349  // "SI"d
#define SSW_DEVID_YM2149    0x594D  // "YM"2149
#define SSW_DEVID_LOGIC_AN  0x4C41  // "LA"nalyzer
#define SSW_DEVID_VIDEO     0x5649  // "VI"deo
#define SSW_DEVID_EMPTY     0xFFFF  // Empty slot

// System registers
#define SSW_SYS_VERSION     0x00
#define SSW_SYS_CAPABILITIES 0x01
#define SSW_SYS_SLOT_COUNT  0x02
#define SSW_SYS_MEM_SIZE    0x03
#define SSW_SYS_DEV_ID_BASE 0x10

struct DeviceInfo {
    uint8_t slot;
    uint16_t deviceId;
    const char* name;
};

class SmartSlotWishbone {
private:
    SPIClass* _spi;
    int _csPin;
    uint32_t _spiFreq;
    
    DeviceInfo _devices[32];
    uint8_t _deviceCount;
    
    // Helper to get device name from ID
    const char* getDeviceName(uint16_t deviceId);
    
public:
    SmartSlotWishbone(SPIClass* spi = &SPI, int csPin = SS, uint32_t freq = 20000000);
    
    // Initialization
    void begin();
    void end();
    
    // Device enumeration
    uint8_t enumerateDevices();
    DeviceInfo* getDevice(uint8_t slot);
    DeviceInfo* findDevice(uint16_t deviceId);
    void printDevices();
    
    // System information
    uint8_t getVersion();
    uint8_t getCapabilities();
    uint8_t getSlotCount();
    uint8_t getMemorySize();  // In MB
    
    // Tier 1: Slot mode - 3 bytes (for peripherals)
    void writeSlot(uint8_t slot, uint8_t reg, uint8_t data);
    uint8_t readSlot(uint8_t slot, uint8_t reg);
    void writeSlotBurst(uint8_t slot, uint8_t startReg, const uint8_t* data, uint16_t count);
    void readSlotBurst(uint8_t slot, uint8_t startReg, uint8_t* data, uint16_t count);
    
    // Tier 2: Extended mode - 4 bytes (for on-chip buffers)
    void writeExtended(uint16_t addr, uint8_t data);
    uint8_t readExtended(uint16_t addr);
    void writeExtendedBurst(uint16_t addr, const uint8_t* data, uint16_t count);
    void readExtendedBurst(uint16_t addr, uint8_t* data, uint16_t count);
    
    // Tier 3: Large memory mode - 5 bytes (for DDR/SDRAM)
    void writeLarge(uint32_t addr, uint8_t data);
    uint8_t readLarge(uint32_t addr);
    void writeLargeBurst(uint32_t addr, const uint8_t* data, uint32_t count);
    void readLargeBurst(uint32_t addr, uint8_t* data, uint32_t count);
    
    // High-level helpers
    void setRGB(uint8_t slot, uint8_t r, uint8_t g, uint8_t b);
    void updateFramebuffer(uint16_t addr, const uint8_t* pixels, uint32_t size);
    void updateLargeFramebuffer(uint32_t addr, const uint8_t* pixels, uint32_t size);
};

#endif // SMART_SLOT_WISHBONE_H
