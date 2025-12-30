// PapilioWishbone.h
// ESP32 library for Papilio Wishbone Bus

#ifndef PAPILIO_WISHBONE_H
#define PAPILIO_WISHBONE_H

#include <Arduino.h>
#include <SPI.h>

// Protocol constants
#define PWB_CMD_READ        0x00
#define PWB_CMD_WRITE       0x80

#define PWB_MODE_SLOT       0x00
#define PWB_MODE_EXTENDED   0x20
#define PWB_MODE_LARGE      0x40

// Device IDs
#define PWB_DEVID_SYSTEM    0x5359
#define PWB_DEVID_RGB_LED   0x4C45
#define PWB_DEVID_GPIO      0x4750
#define PWB_DEVID_EMPTY     0xFFFF

// Memory map registers
#define PWB_REG_VERSION     0x00
#define PWB_REG_SLOT_COUNT  0x01
#define PWB_REG_CAPABILITIES 0x02
#define PWB_REG_DESC_BASE   0x08

class PapilioWishbone {
public:
    PapilioWishbone(SPIClass* spiPort = &SPI, int8_t csPin = SS);
    
    // Initialization
    bool begin(uint32_t spiFrequency = 20000000);
    void end();
    
    // Slot mode (variable width based on enumeration)
    void writeSlot(uint8_t slot, uint8_t reg, uint32_t data);
    uint32_t readSlot(uint8_t slot, uint8_t reg);
    
    // Extended mode (always 32-bit)
    void writeExtended(uint16_t addr, uint32_t data);
    uint32_t readExtended(uint16_t addr);
    
    // Large mode (always 32-bit)
    void writeLarge(uint32_t addr, uint32_t data);
    uint32_t readLarge(uint32_t addr);
    
    // Device enumeration
    bool enumerateDevices();
    uint8_t getSlotCount();
    uint16_t getDeviceID(uint8_t slot);
    uint8_t getSPIBits(uint8_t slot);
    const char* getDeviceName(uint16_t deviceID);
    void printDevices();
    
    // System info
    uint8_t getVersion();
    uint8_t getCapabilities();
    
    // Debug
    void setDebug(bool enable) { _debug = enable; }
    uint32_t getTransactionCount() { return _txCount; }
    void resetTransactionCount() { _txCount = 0; }
    
private:
    SPIClass* _spi;
    int8_t _csPin;
    uint32_t _spiFrequency;
    bool _debug;
    uint32_t _txCount;
    
    // Device enumeration cache
    struct SlotInfo {
        uint16_t deviceID;
        uint8_t spiBits;  // 8, 16, or 32
        uint8_t flags;
    };
    
    uint8_t _slotCount;
    SlotInfo _slots[32];
    
    // Helper functions
    void beginTransaction();
    void endTransaction();
    uint8_t transfer(uint8_t data);
    uint16_t transfer16(uint16_t data);
    uint32_t transfer32(uint32_t data);
};

#endif // PAPILIO_WISHBONE_H
