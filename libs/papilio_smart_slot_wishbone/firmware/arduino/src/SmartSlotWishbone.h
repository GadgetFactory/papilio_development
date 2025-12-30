// SmartSlotWishbone.h
// ESP32 library for Smart Slot Wishbone protocol

#ifndef SMART_SLOT_WISHBONE_H
#define SMART_SLOT_WISHBONE_H

#include <Arduino.h>
#include <SPI.h>

// Protocol constants
#define SSW_CMD_READ        0x00
#define SSW_CMD_WRITE       0x80

#define SSW_MODE_SLOT       0x00
#define SSW_MODE_EXTENDED   0x20
#define SSW_MODE_LARGE      0x40
#define SSW_MODE_RESERVED   0x60

#define SSW_BURST_FLAG      0x08

// Device IDs
#define SSW_DEVID_SYSTEM    0x5359  // "SY"stem
#define SSW_DEVID_RGB_LED   0x4C45  // "LE"d
#define SSW_DEVID_SID       0x5349  // "SI"d
#define SSW_DEVID_YM2149    0x594D  // "YM"2149
#define SSW_DEVID_LOGIC_AN  0x4C41  // "LA"nalyzer
#define SSW_DEVID_VIDEO     0x5649  // "VI"deo
#define SSW_DEVID_GPIO      0x4750  // "GP"io
#define SSW_DEVID_EMPTY     0xFFFF

// System registers (Slot 0)
#define SSW_SYS_VERSION     0x00
#define SSW_SYS_CAPABILITIES 0x01
#define SSW_SYS_SLOT_COUNT  0x02
#define SSW_SYS_MEM_SIZE    0x03
#define SSW_SYS_DEV_ID_BASE 0x10

class SmartSlotWishbone {
public:
    SmartSlotWishbone(SPIClass* spiPort = &SPI, int8_t csPin = SS);
    
    // Initialization
    bool begin(uint32_t spiFrequency = 20000000);
    void end();
    
    // Tier 1: Slot mode (3 bytes) - For control registers
    void writeSlot(uint8_t slot, uint8_t reg, uint8_t data);
    uint8_t readSlot(uint8_t slot, uint8_t reg);
    void writeSlotBurst(uint8_t slot, uint8_t startReg, const uint8_t* data, uint16_t count);
    void readSlotBurst(uint8_t slot, uint8_t startReg, uint8_t* data, uint16_t count);
    
    // Tier 2: Extended mode (4 bytes) - For on-chip memory
    void writeExtended(uint16_t addr, uint8_t data);
    uint8_t readExtended(uint16_t addr);
    void writeExtendedBurst(uint16_t addr, const uint8_t* data, uint16_t count);
    void readExtendedBurst(uint16_t addr, uint8_t* data, uint16_t count);
    
    // Tier 3: Large memory mode (5 bytes) - For DDR/SDRAM
    void writeLarge(uint32_t addr, uint8_t data);
    uint8_t readLarge(uint32_t addr);
    void writeLargeBurst(uint32_t addr, const uint8_t* data, uint32_t count);
    void readLargeBurst(uint32_t addr, uint8_t* data, uint32_t count);
    
    // Device enumeration
    bool enumerateDevices();
    uint8_t getSlotCount();
    uint16_t getDeviceID(uint8_t slot);
    const char* getDeviceName(uint16_t deviceID);
    void printDevices();
    
    // System info
    uint8_t getVersion();
    uint8_t getCapabilities();
    uint8_t getMemorySize();  // In MB
    
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
    uint8_t _slotCount;
    uint16_t _deviceIDs[32];
    
    // Helper functions
    void beginTransaction();
    void endTransaction();
    uint8_t transfer(uint8_t data);
    void transfer(const uint8_t* txData, uint8_t* rxData, size_t len);
    
    // Low-level protocol
    void writeCommand(uint8_t cmd);
    void writeAddress16(uint16_t addr);
    void writeAddress24(uint32_t addr);
    void writeBurstCount(uint16_t count);
};

#endif // SMART_SLOT_WISHBONE_H
