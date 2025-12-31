// PapilioWishbone2.h - ESP32 library for PWB2 communication
// Three-tier addressing with burst mode support

#ifndef PAPILIO_WISHBONE2_H
#define PAPILIO_WISHBONE2_H

#include <Arduino.h>
#include <SPI.h>

// PWB2 Protocol Constants
#define PWB2_VERSION            0x20

// Command byte bits
#define PWB2_CMD_WRITE          0x80
#define PWB2_CMD_READ           0x00
#define PWB2_CMD_MODE_SLOT      0x00
#define PWB2_CMD_MODE_EXTENDED  0x20
#define PWB2_CMD_MODE_LARGE     0x40
#define PWB2_CMD_BURST          0x08

// Device IDs
#define PWB2_DEVID_SYSTEM       0x5359
#define PWB2_DEVID_RGB_LED      0x4C45
#define PWB2_DEVID_GPIO         0x4750
#define PWB2_DEVID_EMPTY        0x0000

// System registers (Slot 0)
#define PWB2_REG_DEVICE_ID_L    0x00
#define PWB2_REG_DEVICE_ID_H    0x01
#define PWB2_REG_VERSION        0x02
#define PWB2_REG_SLOT_COUNT     0x03
#define PWB2_REG_CAPABILITIES   0x04
#define PWB2_REG_STATUS         0x05
#define PWB2_MEMMAP_START       0x10

// SPI settings
#define PWB2_SPI_CLOCK_HZ       20000000  // 20 MHz default
#define PWB2_SPI_MODE           SPI_MODE0
#define PWB2_SPI_BIT_ORDER      MSBFIRST

// Device info structure
struct PWB2DeviceInfo {
    uint16_t deviceId;
    uint8_t spiWidth;
    uint8_t flags;
    bool isEmpty() const { return deviceId == PWB2_DEVID_EMPTY; }
};

class PapilioWishbone2 {
public:
    PapilioWishbone2(int8_t cs_pin = SS, SPIClass* spi = &SPI);
    
    // =========================================================================
    // Initialization
    // =========================================================================
    bool begin(uint32_t spi_clock_hz = PWB2_SPI_CLOCK_HZ);
    void end();
    
    // =========================================================================
    // Device Enumeration
    // =========================================================================
    bool enumerateDevices();
    void printDevices(Stream& stream = Serial);
    uint8_t getSlotCount() const { return _slotCount; }
    uint16_t getDeviceId(uint8_t slot) const;
    uint8_t getSpiWidth(uint8_t slot) const;
    PWB2DeviceInfo getDeviceInfo(uint8_t slot) const;
    
    // =========================================================================
    // Tier 1: Slot Access (Peripheral Registers)
    // =========================================================================
    
    // 8-bit slot access
    bool writeSlot8(uint8_t slot, uint8_t reg, uint8_t data);
    uint8_t readSlot8(uint8_t slot, uint8_t reg);
    
    // 16-bit slot access
    bool writeSlot16(uint8_t slot, uint8_t reg, uint16_t data);
    uint16_t readSlot16(uint8_t slot, uint8_t reg);
    
    // 32-bit slot access
    bool writeSlot32(uint8_t slot, uint8_t reg, uint32_t data);
    uint32_t readSlot32(uint8_t slot, uint8_t reg);
    
    // Slot burst mode (always 32-bit words)
    bool writeSlotBurst(uint8_t slot, uint8_t start_reg, const uint32_t* data, uint16_t word_count);
    bool readSlotBurst(uint8_t slot, uint8_t start_reg, uint32_t* data, uint16_t word_count);
    
    // =========================================================================
    // Tier 2: Extended Mode (On-chip Memory, always 32-bit)
    // =========================================================================
    bool writeExtended(uint16_t address, uint32_t data);
    uint32_t readExtended(uint16_t address);
    bool writeExtendedBurst(uint16_t start_addr, const uint32_t* data, uint16_t word_count);
    bool readExtendedBurst(uint16_t start_addr, uint32_t* data, uint16_t word_count);
    
    // =========================================================================
    // Tier 3: Large Mode (External DDR/SDRAM, always 32-bit)
    // =========================================================================
    bool writeLarge(uint32_t address, uint32_t data);
    uint32_t readLarge(uint32_t address);
    bool writeLargeBurst(uint32_t start_addr, const uint32_t* data, uint16_t word_count);
    bool readLargeBurst(uint32_t start_addr, uint32_t* data, uint16_t word_count);
    
    // =========================================================================
    // Statistics
    // =========================================================================
    uint32_t getTransactionCount() const { return _txCount; }
    void resetStatistics() { _txCount = 0; }
    
    // =========================================================================
    // Debug
    // =========================================================================
    void setDebug(bool enable) { _debug = enable; }
    bool getDebug() const { return _debug; }

private:
    // SPI interface
    SPIClass* _spi;
    int8_t _csPin;
    uint32_t _spiClock;
    SPISettings _spiSettings;
    
    // Device information
    PWB2DeviceInfo _devices[32];
    uint8_t _slotCount;
    uint8_t _version;
    uint32_t _capabilities;
    
    // Statistics
    uint32_t _txCount;
    bool _debug;
    
    // Low-level SPI helpers
    void csAssert();
    void csDeassert();
    uint8_t spiTransfer(uint8_t data);
    void spiTransferBuf(uint8_t* buf, size_t len);
    
    // Protocol helpers
    uint8_t buildCommand(bool is_write, uint8_t mode, bool burst, uint8_t data);
    void write32MSBFirst(uint32_t value);
    uint32_t read32MSBFirst();
};

#endif // PAPILIO_WISHBONE2_H
