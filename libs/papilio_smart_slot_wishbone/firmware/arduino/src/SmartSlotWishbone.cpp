/*
 * SmartSlotWishbone.cpp - Smart Slot Wishbone Arduino Library Implementation
 */

#include "SmartSlotWishbone.h"

SmartSlotWishbone::SmartSlotWishbone(SPIClass* spi, int csPin, uint32_t freq)
    : _spi(spi), _csPin(csPin), _spiFreq(freq), _deviceCount(0) {
}

void SmartSlotWishbone::begin() {
    pinMode(_csPin, OUTPUT);
    digitalWrite(_csPin, HIGH);
    
    _spi->begin();
}

void SmartSlotWishbone::end() {
    _spi->end();
}

const char* SmartSlotWishbone::getDeviceName(uint16_t deviceId) {
    switch (deviceId) {
        case SSW_DEVID_SYSTEM:    return "System";
        case SSW_DEVID_RGB_LED:   return "RGB LED";
        case SSW_DEVID_SID:       return "SID 6581";
        case SSW_DEVID_YM2149:    return "YM2149";
        case SSW_DEVID_LOGIC_AN:  return "Logic Analyzer";
        case SSW_DEVID_VIDEO:     return "Video";
        case SSW_DEVID_EMPTY:     return "Empty";
        default:                  return "Unknown";
    }
}

// =============================================================================
// Device Enumeration
// =============================================================================

uint8_t SmartSlotWishbone::enumerateDevices() {
    _deviceCount = 0;
    
    // Read device IDs from system slot
    for (uint8_t slot = 0; slot < 32; slot++) {
        uint8_t regAddr = SSW_SYS_DEV_ID_BASE + (slot * 2);
        uint16_t deviceId = (readSlot(0, regAddr) << 8) | readSlot(0, regAddr + 1);
        
        if (deviceId != SSW_DEVID_EMPTY) {
            _devices[_deviceCount].slot = slot;
            _devices[_deviceCount].deviceId = deviceId;
            _devices[_deviceCount].name = getDeviceName(deviceId);
            _deviceCount++;
        }
    }
    
    return _deviceCount;
}

DeviceInfo* SmartSlotWishbone::getDevice(uint8_t slot) {
    for (uint8_t i = 0; i < _deviceCount; i++) {
        if (_devices[i].slot == slot) {
            return &_devices[i];
        }
    }
    return nullptr;
}

DeviceInfo* SmartSlotWishbone::findDevice(uint16_t deviceId) {
    for (uint8_t i = 0; i < _deviceCount; i++) {
        if (_devices[i].deviceId == deviceId) {
            return &_devices[i];
        }
    }
    return nullptr;
}

void SmartSlotWishbone::printDevices() {
    Serial.println("Smart Slot Wishbone Devices:");
    Serial.println("==============================");
    
    for (uint8_t i = 0; i < _deviceCount; i++) {
        Serial.printf("Slot %2d: %s (ID: 0x%04X)\n", 
                     _devices[i].slot, 
                     _devices[i].name,
                     _devices[i].deviceId);
    }
    
    Serial.println();
}

// =============================================================================
// System Information
// =============================================================================

uint8_t SmartSlotWishbone::getVersion() {
    return readSlot(0, SSW_SYS_VERSION);
}

uint8_t SmartSlotWishbone::getCapabilities() {
    return readSlot(0, SSW_SYS_CAPABILITIES);
}

uint8_t SmartSlotWishbone::getSlotCount() {
    return readSlot(0, SSW_SYS_SLOT_COUNT);
}

uint8_t SmartSlotWishbone::getMemorySize() {
    return readSlot(0, SSW_SYS_MEM_SIZE);
}

// =============================================================================
// Tier 1: Slot Mode (3 bytes)
// =============================================================================

void SmartSlotWishbone::writeSlot(uint8_t slot, uint8_t reg, uint8_t data) {
    _spi->beginTransaction(SPISettings(_spiFreq, MSBFIRST, SPI_MODE0));
    digitalWrite(_csPin, LOW);
    
    _spi->transfer(SSW_CMD_WRITE | SSW_MODE_SLOT | (slot & 0x1F));
    _spi->transfer(reg);
    _spi->transfer(data);
    
    digitalWrite(_csPin, HIGH);
    _spi->endTransaction();
}

uint8_t SmartSlotWishbone::readSlot(uint8_t slot, uint8_t reg) {
    _spi->beginTransaction(SPISettings(_spiFreq, MSBFIRST, SPI_MODE0));
    digitalWrite(_csPin, LOW);
    
    _spi->transfer(SSW_CMD_READ | SSW_MODE_SLOT | (slot & 0x1F));
    _spi->transfer(reg);
    _spi->transfer(0x00);  // Dummy byte
    uint8_t data = _spi->transfer(0x00);  // Read data
    
    digitalWrite(_csPin, HIGH);
    _spi->endTransaction();
    
    return data;
}

void SmartSlotWishbone::writeSlotBurst(uint8_t slot, uint8_t startReg, 
                                       const uint8_t* data, uint16_t count) {
    _spi->beginTransaction(SPISettings(_spiFreq, MSBFIRST, SPI_MODE0));
    digitalWrite(_csPin, LOW);
    
    uint8_t cmd = SSW_CMD_WRITE | SSW_MODE_SLOT | SSW_BURST_FLAG | (slot & 0x1F);
    _spi->transfer(cmd);
    _spi->transfer(startReg);
    _spi->transfer16(count);  // Burst count
    
    // Use DMA if available
    _spi->writeBytes(data, count);
    
    digitalWrite(_csPin, HIGH);
    _spi->endTransaction();
}

void SmartSlotWishbone::readSlotBurst(uint8_t slot, uint8_t startReg, 
                                      uint8_t* data, uint16_t count) {
    _spi->beginTransaction(SPISettings(_spiFreq, MSBFIRST, SPI_MODE0));
    digitalWrite(_csPin, LOW);
    
    uint8_t cmd = SSW_CMD_READ | SSW_MODE_SLOT | SSW_BURST_FLAG | (slot & 0x1F);
    _spi->transfer(cmd);
    _spi->transfer(startReg);
    _spi->transfer16(count);  // Burst count
    _spi->transfer(0x00);  // Dummy byte to start read
    
    // Read data
    for (uint16_t i = 0; i < count; i++) {
        data[i] = _spi->transfer(0x00);
    }
    
    digitalWrite(_csPin, HIGH);
    _spi->endTransaction();
}

// =============================================================================
// Tier 2: Extended Mode (4 bytes)
// =============================================================================

void SmartSlotWishbone::writeExtended(uint16_t addr, uint8_t data) {
    _spi->beginTransaction(SPISettings(_spiFreq, MSBFIRST, SPI_MODE0));
    digitalWrite(_csPin, LOW);
    
    _spi->transfer(SSW_CMD_WRITE | SSW_MODE_EXTENDED);
    _spi->transfer16(addr);
    _spi->transfer(data);
    
    digitalWrite(_csPin, HIGH);
    _spi->endTransaction();
}

uint8_t SmartSlotWishbone::readExtended(uint16_t addr) {
    _spi->beginTransaction(SPISettings(_spiFreq, MSBFIRST, SPI_MODE0));
    digitalWrite(_csPin, LOW);
    
    _spi->transfer(SSW_CMD_READ | SSW_MODE_EXTENDED);
    _spi->transfer16(addr);
    _spi->transfer(0x00);  // Dummy byte
    uint8_t data = _spi->transfer(0x00);  // Read data
    
    digitalWrite(_csPin, HIGH);
    _spi->endTransaction();
    
    return data;
}

void SmartSlotWishbone::writeExtendedBurst(uint16_t addr, const uint8_t* data, uint16_t count) {
    _spi->beginTransaction(SPISettings(_spiFreq, MSBFIRST, SPI_MODE0));
    digitalWrite(_csPin, LOW);
    
    uint8_t cmd = SSW_CMD_WRITE | SSW_MODE_EXTENDED | SSW_BURST_FLAG;
    _spi->transfer(cmd);
    _spi->transfer16(addr);
    _spi->transfer16(count);
    
    _spi->writeBytes(data, count);
    
    digitalWrite(_csPin, HIGH);
    _spi->endTransaction();
}

void SmartSlotWishbone::readExtendedBurst(uint16_t addr, uint8_t* data, uint16_t count) {
    _spi->beginTransaction(SPISettings(_spiFreq, MSBFIRST, SPI_MODE0));
    digitalWrite(_csPin, LOW);
    
    uint8_t cmd = SSW_CMD_READ | SSW_MODE_EXTENDED | SSW_BURST_FLAG;
    _spi->transfer(cmd);
    _spi->transfer16(addr);
    _spi->transfer16(count);
    _spi->transfer(0x00);  // Dummy byte
    
    for (uint16_t i = 0; i < count; i++) {
        data[i] = _spi->transfer(0x00);
    }
    
    digitalWrite(_csPin, HIGH);
    _spi->endTransaction();
}

// =============================================================================
// Tier 3: Large Memory Mode (5 bytes)
// =============================================================================

void SmartSlotWishbone::writeLarge(uint32_t addr, uint8_t data) {
    _spi->beginTransaction(SPISettings(_spiFreq, MSBFIRST, SPI_MODE0));
    digitalWrite(_csPin, LOW);
    
    uint8_t bank = (addr >> 20) & 0x1F;
    _spi->transfer(SSW_CMD_WRITE | SSW_MODE_LARGE | bank);
    _spi->transfer((addr >> 16) & 0xFF);
    _spi->transfer((addr >> 8) & 0xFF);
    _spi->transfer(addr & 0xFF);
    _spi->transfer(data);
    
    digitalWrite(_csPin, HIGH);
    _spi->endTransaction();
}

uint8_t SmartSlotWishbone::readLarge(uint32_t addr) {
    _spi->beginTransaction(SPISettings(_spiFreq, MSBFIRST, SPI_MODE0));
    digitalWrite(_csPin, LOW);
    
    uint8_t bank = (addr >> 20) & 0x1F;
    _spi->transfer(SSW_CMD_READ | SSW_MODE_LARGE | bank);
    _spi->transfer((addr >> 16) & 0xFF);
    _spi->transfer((addr >> 8) & 0xFF);
    _spi->transfer(addr & 0xFF);
    _spi->transfer(0x00);  // Dummy byte
    uint8_t data = _spi->transfer(0x00);  // Read data
    
    digitalWrite(_csPin, HIGH);
    _spi->endTransaction();
    
    return data;
}

void SmartSlotWishbone::writeLargeBurst(uint32_t addr, const uint8_t* data, uint32_t count) {
    // Split into 64KB chunks if necessary (SPI transaction limit)
    uint32_t remaining = count;
    uint32_t offset = 0;
    
    while (remaining > 0) {
        uint16_t chunkSize = (remaining > 65535) ? 65535 : remaining;
        
        _spi->beginTransaction(SPISettings(_spiFreq, MSBFIRST, SPI_MODE0));
        digitalWrite(_csPin, LOW);
        
        uint32_t currentAddr = addr + offset;
        uint8_t bank = (currentAddr >> 20) & 0x1F;
        uint8_t cmd = SSW_CMD_WRITE | SSW_MODE_LARGE | SSW_BURST_FLAG | bank;
        
        _spi->transfer(cmd);
        _spi->transfer((currentAddr >> 16) & 0xFF);
        _spi->transfer((currentAddr >> 8) & 0xFF);
        _spi->transfer(currentAddr & 0xFF);
        _spi->transfer16(chunkSize);
        
        _spi->writeBytes(data + offset, chunkSize);
        
        digitalWrite(_csPin, HIGH);
        _spi->endTransaction();
        
        remaining -= chunkSize;
        offset += chunkSize;
    }
}

void SmartSlotWishbone::readLargeBurst(uint32_t addr, uint8_t* data, uint32_t count) {
    // Split into 64KB chunks if necessary
    uint32_t remaining = count;
    uint32_t offset = 0;
    
    while (remaining > 0) {
        uint16_t chunkSize = (remaining > 65535) ? 65535 : remaining;
        
        _spi->beginTransaction(SPISettings(_spiFreq, MSBFIRST, SPI_MODE0));
        digitalWrite(_csPin, LOW);
        
        uint32_t currentAddr = addr + offset;
        uint8_t bank = (currentAddr >> 20) & 0x1F;
        uint8_t cmd = SSW_CMD_READ | SSW_MODE_LARGE | SSW_BURST_FLAG | bank;
        
        _spi->transfer(cmd);
        _spi->transfer((currentAddr >> 16) & 0xFF);
        _spi->transfer((currentAddr >> 8) & 0xFF);
        _spi->transfer(currentAddr & 0xFF);
        _spi->transfer16(chunkSize);
        _spi->transfer(0x00);  // Dummy byte
        
        for (uint16_t i = 0; i < chunkSize; i++) {
            data[offset + i] = _spi->transfer(0x00);
        }
        
        digitalWrite(_csPin, HIGH);
        _spi->endTransaction();
        
        remaining -= chunkSize;
        offset += chunkSize;
    }
}

// =============================================================================
// High-Level Helpers
// =============================================================================

void SmartSlotWishbone::setRGB(uint8_t slot, uint8_t r, uint8_t g, uint8_t b) {
    writeSlot(slot, 0, r);
    writeSlot(slot, 1, g);
    writeSlot(slot, 2, b);
}

void SmartSlotWishbone::updateFramebuffer(uint16_t addr, const uint8_t* pixels, uint32_t size) {
    if (size <= 65535) {
        writeExtendedBurst(addr, pixels, size);
    } else {
        // Split into chunks
        uint32_t remaining = size;
        uint32_t offset = 0;
        while (remaining > 0) {
            uint16_t chunk = (remaining > 65535) ? 65535 : remaining;
            writeExtendedBurst(addr + offset, pixels + offset, chunk);
            remaining -= chunk;
            offset += chunk;
        }
    }
}

void SmartSlotWishbone::updateLargeFramebuffer(uint32_t addr, const uint8_t* pixels, uint32_t size) {
    writeLargeBurst(addr, pixels, size);
}
