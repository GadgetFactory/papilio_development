// PapilioWishbone.cpp
// ESP32 library for Papilio Wishbone Bus

#include "PapilioWishbone.h"

PapilioWishbone::PapilioWishbone(SPIClass* spiPort, int8_t csPin)
    : _spi(spiPort), _csPin(csPin), _spiFrequency(20000000),
      _debug(false), _txCount(0), _slotCount(0) {
    // Initialize slot info
    for (int i = 0; i < 32; i++) {
        _slots[i].deviceID = PWB_DEVID_EMPTY;
        _slots[i].spiBits = 8;
        _slots[i].flags = 0;
    }
}

bool PapilioWishbone::begin(uint32_t spiFrequency) {
    _spiFrequency = spiFrequency;
    
    // Initialize CS pin
    pinMode(_csPin, OUTPUT);
    digitalWrite(_csPin, HIGH);
    
    // Initialize SPI
    _spi->begin();
    
    // Test communication by reading version
    uint8_t version = getVersion();
    if (_debug) {
        Serial.printf("PWB Version: 0x%02X\n", version);
    }
    
    return true;
}

void PapilioWishbone::end() {
    _spi->end();
}

// =============================================================================
// Slot Mode (Variable Width)
// =============================================================================

void PapilioWishbone::writeSlot(uint8_t slot, uint8_t reg, uint32_t data) {
    if (slot >= 32) return;
    
    uint8_t spiBits = _slots[slot].spiBits;
    
    beginTransaction();
    
    uint8_t cmd = PWB_CMD_WRITE | PWB_MODE_SLOT | (slot & 0x1F);
    transfer(cmd);
    transfer(reg);
    
    // Send data based on slot's SPI width
    switch(spiBits) {
        case 8:
            transfer((uint8_t)data);
            break;
        case 16:
            transfer16((uint16_t)data);
            break;
        case 32:
            transfer32(data);
            break;
        default:
            transfer((uint8_t)data);
    }
    
    endTransaction();
    _txCount++;
}

uint32_t PapilioWishbone::readSlot(uint8_t slot, uint8_t reg) {
    if (slot >= 32) return 0;
    
    uint8_t spiBits = _slots[slot].spiBits;
    
    beginTransaction();
    
    uint8_t cmd = PWB_CMD_READ | PWB_MODE_SLOT | (slot & 0x1F);
    transfer(cmd);
    transfer(reg);
    
    uint32_t result = 0;
    
    // Read data based on slot's SPI width
    switch(spiBits) {
        case 8:
            result = transfer(0x00);
            break;
        case 16:
            result = transfer16(0x0000);
            break;
        case 32:
            result = transfer32(0x00000000);
            break;
        default:
            result = transfer(0x00);
    }
    
    endTransaction();
    _txCount++;
    
    return result;
}

// =============================================================================
// Extended Mode (32-bit)
// =============================================================================

void PapilioWishbone::writeExtended(uint16_t addr, uint32_t data) {
    beginTransaction();
    
    uint8_t cmd = PWB_CMD_WRITE | PWB_MODE_EXTENDED;
    transfer(cmd);
    transfer((addr >> 8) & 0xFF);
    transfer(addr & 0xFF);
    transfer32(data);
    
    endTransaction();
    _txCount++;
}

uint32_t PapilioWishbone::readExtended(uint16_t addr) {
    beginTransaction();
    
    uint8_t cmd = PWB_CMD_READ | PWB_MODE_EXTENDED;
    transfer(cmd);
    transfer((addr >> 8) & 0xFF);
    transfer(addr & 0xFF);
    uint32_t result = transfer32(0);
    
    endTransaction();
    _txCount++;
    
    return result;
}

// =============================================================================
// Large Mode (32-bit)
// =============================================================================

void PapilioWishbone::writeLarge(uint32_t addr, uint32_t data) {
    beginTransaction();
    
    uint8_t cmd = PWB_CMD_WRITE | PWB_MODE_LARGE | ((addr >> 20) & 0x1F);
    transfer(cmd);
    transfer((addr >> 16) & 0xFF);
    transfer((addr >> 8) & 0xFF);
    transfer(addr & 0xFF);
    transfer32(data);
    
    endTransaction();
    _txCount++;
}

uint32_t PapilioWishbone::readLarge(uint32_t addr) {
    beginTransaction();
    
    uint8_t cmd = PWB_CMD_READ | PWB_MODE_LARGE | ((addr >> 20) & 0x1F);
    transfer(cmd);
    transfer((addr >> 16) & 0xFF);
    transfer((addr >> 8) & 0xFF);
    transfer(addr & 0xFF);
    uint32_t result = transfer32(0);
    
    endTransaction();
    _txCount++;
    
    return result;
}

// =============================================================================
// Device Enumeration
// =============================================================================

bool PapilioWishbone::enumerateDevices() {
    // Slot 0 is always the memory map, use 32-bit reads
    _slots[0].deviceID = PWB_DEVID_SYSTEM;
    _slots[0].spiBits = 32;
    _slots[0].flags = 0;
    
    // Read slot count
    uint32_t slotCountReg = readSlot(0, PWB_REG_SLOT_COUNT);
    _slotCount = slotCountReg & 0xFF;
    
    if (_slotCount > 32) {
        _slotCount = 32;  // Sanity check
    }
    
    if (_debug) {
        Serial.printf("Found %d slots\n", _slotCount);
    }
    
    // Read all device descriptors
    for (uint8_t i = 0; i < _slotCount; i++) {
        // Each slot has 2 words, starting at 0x08
        uint32_t desc = readSlot(0, PWB_REG_DESC_BASE + (i * 2));
        
        _slots[i].deviceID = (desc >> 16) & 0xFFFF;
        _slots[i].spiBits = (desc >> 8) & 0x3F;
        _slots[i].flags = desc & 0xFF;
        
        if (_debug) {
            Serial.printf("Slot %d: ID=0x%04X, SPI=%d bits\n", 
                         i, _slots[i].deviceID, _slots[i].spiBits);
        }
    }
    
    return true;
}

uint8_t PapilioWishbone::getSlotCount() {
    return _slotCount;
}

uint16_t PapilioWishbone::getDeviceID(uint8_t slot) {
    if (slot < 32) {
        return _slots[slot].deviceID;
    }
    return PWB_DEVID_EMPTY;
}

uint8_t PapilioWishbone::getSPIBits(uint8_t slot) {
    if (slot < 32) {
        return _slots[slot].spiBits;
    }
    return 8;
}

const char* PapilioWishbone::getDeviceName(uint16_t deviceID) {
    switch (deviceID) {
        case PWB_DEVID_SYSTEM:  return "System";
        case PWB_DEVID_RGB_LED: return "RGB LED";
        case PWB_DEVID_GPIO:    return "GPIO";
        case PWB_DEVID_EMPTY:   return "Empty";
        default:                return "Unknown";
    }
}

void PapilioWishbone::printDevices() {
    Serial.println("=== Papilio Wishbone Bus Devices ===");
    Serial.printf("Slots populated: %d\n", _slotCount);
    Serial.println();
    
    for (uint8_t i = 0; i < _slotCount; i++) {
        uint16_t id = _slots[i].deviceID;
        if (id != PWB_DEVID_EMPTY) {
            Serial.printf("Slot %2d: %s (0x%04X) - %d-bit SPI\n", 
                         i, getDeviceName(id), id, _slots[i].spiBits);
        }
    }
}

// =============================================================================
// System Info
// =============================================================================

uint8_t PapilioWishbone::getVersion() {
    // Read version using 32-bit (slot 0 always uses 32-bit)
    _slots[0].spiBits = 32;  // Ensure it's set
    uint32_t ver = readSlot(0, PWB_REG_VERSION);
    return ver & 0xFF;
}

uint8_t PapilioWishbone::getCapabilities() {
    uint32_t cap = readSlot(0, PWB_REG_CAPABILITIES);
    return cap & 0xFF;
}

// =============================================================================
// Helper Functions
// =============================================================================

void PapilioWishbone::beginTransaction() {
    _spi->beginTransaction(SPISettings(_spiFrequency, MSBFIRST, SPI_MODE0));
    digitalWrite(_csPin, LOW);
}

void PapilioWishbone::endTransaction() {
    digitalWrite(_csPin, HIGH);
    _spi->endTransaction();
}

uint8_t PapilioWishbone::transfer(uint8_t data) {
    return _spi->transfer(data);
}

uint16_t PapilioWishbone::transfer16(uint16_t data) {
    return _spi->transfer16(data);
}

uint32_t PapilioWishbone::transfer32(uint32_t data) {
    return _spi->transfer32(data);
}
