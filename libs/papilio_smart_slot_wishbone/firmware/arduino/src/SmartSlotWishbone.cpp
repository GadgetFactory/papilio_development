// SmartSlotWishbone.cpp
// ESP32 library for Smart Slot Wishbone protocol

#include "SmartSlotWishbone.h"

SmartSlotWishbone::SmartSlotWishbone(SPIClass* spiPort, int8_t csPin)
    : _spi(spiPort), _csPin(csPin), _spiFrequency(20000000), 
      _debug(false), _txCount(0), _slotCount(0) {
    memset(_deviceIDs, 0xFF, sizeof(_deviceIDs));
}

bool SmartSlotWishbone::begin(uint32_t spiFrequency) {
    _spiFrequency = spiFrequency;
    
    // Initialize CS pin
    pinMode(_csPin, OUTPUT);
    digitalWrite(_csPin, HIGH);
    
    // Initialize SPI
    _spi->begin();
    
    // Test communication by reading version
    uint8_t version = getVersion();
    if (_debug) {
        Serial.printf("SSW Version: 0x%02X\n", version);
    }
    
    return true;
}

void SmartSlotWishbone::end() {
    _spi->end();
}

// =============================================================================
// Tier 1: Slot Mode (3 bytes)
// =============================================================================

void SmartSlotWishbone::writeSlot(uint8_t slot, uint8_t reg, uint8_t data) {
    beginTransaction();
    
    uint8_t cmd = SSW_CMD_WRITE | SSW_MODE_SLOT | (slot & 0x1F);
    transfer(cmd);
    transfer(reg);
    transfer(data);
    
    endTransaction();
    _txCount++;
}

uint8_t SmartSlotWishbone::readSlot(uint8_t slot, uint8_t reg) {
    beginTransaction();
    
    uint8_t cmd = SSW_CMD_READ | SSW_MODE_SLOT | (slot & 0x1F);
    transfer(cmd);
    transfer(reg);
    uint8_t data = transfer(0x00);
    
    endTransaction();
    _txCount++;
    
    return data;
}

void SmartSlotWishbone::writeSlotBurst(uint8_t slot, uint8_t startReg, 
                                       const uint8_t* data, uint16_t count) {
    beginTransaction();
    
    uint8_t cmd = SSW_CMD_WRITE | SSW_MODE_SLOT | SSW_BURST_FLAG | (slot & 0x1F);
    transfer(cmd);
    transfer(startReg);
    transfer((count >> 8) & 0xFF);  // Count high
    transfer(count & 0xFF);          // Count low
    
    // Send data
    for (uint16_t i = 0; i < count; i++) {
        transfer(data[i]);
    }
    
    endTransaction();
    _txCount++;
}

void SmartSlotWishbone::readSlotBurst(uint8_t slot, uint8_t startReg, 
                                      uint8_t* data, uint16_t count) {
    beginTransaction();
    
    uint8_t cmd = SSW_CMD_READ | SSW_MODE_SLOT | SSW_BURST_FLAG | (slot & 0x1F);
    transfer(cmd);
    transfer(startReg);
    transfer((count >> 8) & 0xFF);  // Count high
    transfer(count & 0xFF);          // Count low
    
    // Read data
    for (uint16_t i = 0; i < count; i++) {
        data[i] = transfer(0x00);
    }
    
    endTransaction();
    _txCount++;
}

// =============================================================================
// Tier 2: Extended Mode (4 bytes)
// =============================================================================

void SmartSlotWishbone::writeExtended(uint16_t addr, uint8_t data) {
    beginTransaction();
    
    uint8_t cmd = SSW_CMD_WRITE | SSW_MODE_EXTENDED;
    transfer(cmd);
    transfer((addr >> 8) & 0xFF);   // Address high
    transfer(addr & 0xFF);           // Address low
    transfer(data);
    
    endTransaction();
    _txCount++;
}

uint8_t SmartSlotWishbone::readExtended(uint16_t addr) {
    beginTransaction();
    
    uint8_t cmd = SSW_CMD_READ | SSW_MODE_EXTENDED;
    transfer(cmd);
    transfer((addr >> 8) & 0xFF);   // Address high
    transfer(addr & 0xFF);           // Address low
    uint8_t data = transfer(0x00);
    
    endTransaction();
    _txCount++;
    
    return data;
}

void SmartSlotWishbone::writeExtendedBurst(uint16_t addr, 
                                           const uint8_t* data, uint16_t count) {
    beginTransaction();
    
    uint8_t cmd = SSW_CMD_WRITE | SSW_MODE_EXTENDED | SSW_BURST_FLAG;
    transfer(cmd);
    transfer((addr >> 8) & 0xFF);    // Address high
    transfer(addr & 0xFF);            // Address low
    transfer((count >> 8) & 0xFF);   // Count high
    transfer(count & 0xFF);           // Count low
    
    // Use DMA for efficiency if available
    #ifdef ESP32
    _spi->writeBytes(data, count);
    #else
    for (uint16_t i = 0; i < count; i++) {
        transfer(data[i]);
    }
    #endif
    
    endTransaction();
    _txCount++;
}

void SmartSlotWishbone::readExtendedBurst(uint16_t addr, 
                                          uint8_t* data, uint16_t count) {
    beginTransaction();
    
    uint8_t cmd = SSW_CMD_READ | SSW_MODE_EXTENDED | SSW_BURST_FLAG;
    transfer(cmd);
    transfer((addr >> 8) & 0xFF);    // Address high
    transfer(addr & 0xFF);            // Address low
    transfer((count >> 8) & 0xFF);   // Count high
    transfer(count & 0xFF);           // Count low
    
    // Read data
    for (uint16_t i = 0; i < count; i++) {
        data[i] = transfer(0x00);
    }
    
    endTransaction();
    _txCount++;
}

// =============================================================================
// Tier 3: Large Memory Mode (5 bytes)
// =============================================================================

void SmartSlotWishbone::writeLarge(uint32_t addr, uint8_t data) {
    beginTransaction();
    
    uint8_t cmd = SSW_CMD_WRITE | SSW_MODE_LARGE | ((addr >> 20) & 0x1F);
    transfer(cmd);
    transfer((addr >> 16) & 0xFF);   // Address bits [23:16]
    transfer((addr >> 8) & 0xFF);    // Address bits [15:8]
    transfer(addr & 0xFF);            // Address bits [7:0]
    transfer(data);
    
    endTransaction();
    _txCount++;
}

uint8_t SmartSlotWishbone::readLarge(uint32_t addr) {
    beginTransaction();
    
    uint8_t cmd = SSW_CMD_READ | SSW_MODE_LARGE | ((addr >> 20) & 0x1F);
    transfer(cmd);
    transfer((addr >> 16) & 0xFF);   // Address bits [23:16]
    transfer((addr >> 8) & 0xFF);    // Address bits [15:8]
    transfer(addr & 0xFF);            // Address bits [7:0]
    uint8_t data = transfer(0x00);
    
    endTransaction();
    _txCount++;
    
    return data;
}

void SmartSlotWishbone::writeLargeBurst(uint32_t addr, 
                                        const uint8_t* data, uint32_t count) {
    // Split into chunks if count > 65535
    while (count > 0) {
        uint16_t chunkSize = (count > 65535) ? 65535 : count;
        
        beginTransaction();
        
        uint8_t cmd = SSW_CMD_WRITE | SSW_MODE_LARGE | SSW_BURST_FLAG | 
                      ((addr >> 20) & 0x1F);
        transfer(cmd);
        transfer((addr >> 16) & 0xFF);       // Address bits [23:16]
        transfer((addr >> 8) & 0xFF);        // Address bits [15:8]
        transfer(addr & 0xFF);                // Address bits [7:0]
        transfer((chunkSize >> 8) & 0xFF);   // Count high
        transfer(chunkSize & 0xFF);           // Count low
        
        // Use DMA for efficiency
        #ifdef ESP32
        _spi->writeBytes(data, chunkSize);
        #else
        for (uint16_t i = 0; i < chunkSize; i++) {
            transfer(data[i]);
        }
        #endif
        
        endTransaction();
        _txCount++;
        
        addr += chunkSize;
        data += chunkSize;
        count -= chunkSize;
    }
}

void SmartSlotWishbone::readLargeBurst(uint32_t addr, 
                                       uint8_t* data, uint32_t count) {
    // Split into chunks if count > 65535
    while (count > 0) {
        uint16_t chunkSize = (count > 65535) ? 65535 : count;
        
        beginTransaction();
        
        uint8_t cmd = SSW_CMD_READ | SSW_MODE_LARGE | SSW_BURST_FLAG | 
                      ((addr >> 20) & 0x1F);
        transfer(cmd);
        transfer((addr >> 16) & 0xFF);       // Address bits [23:16]
        transfer((addr >> 8) & 0xFF);        // Address bits [15:8]
        transfer(addr & 0xFF);                // Address bits [7:0]
        transfer((chunkSize >> 8) & 0xFF);   // Count high
        transfer(chunkSize & 0xFF);           // Count low
        
        // Read data
        for (uint16_t i = 0; i < chunkSize; i++) {
            data[i] = transfer(0x00);
        }
        
        endTransaction();
        _txCount++;
        
        addr += chunkSize;
        data += chunkSize;
        count -= chunkSize;
    }
}

// =============================================================================
// Device Enumeration
// =============================================================================

bool SmartSlotWishbone::enumerateDevices() {
    // Read slot count from system control register
    _slotCount = readSlot(0, SSW_SYS_SLOT_COUNT);
    
    if (_slotCount > 32) {
        _slotCount = 32;  // Sanity check
    }
    
    // Read device IDs for all slots
    for (uint8_t i = 0; i < _slotCount; i++) {
        // Device IDs are stored as 16-bit values at offset 0x10+
        // Read high and low bytes
        uint8_t idHigh = readSlot(0, SSW_SYS_DEV_ID_BASE + (i * 2));
        uint8_t idLow = readSlot(0, SSW_SYS_DEV_ID_BASE + (i * 2) + 1);
        _deviceIDs[i] = (idHigh << 8) | idLow;
    }
    
    return true;
}

uint8_t SmartSlotWishbone::getSlotCount() {
    return _slotCount;
}

uint16_t SmartSlotWishbone::getDeviceID(uint8_t slot) {
    if (slot < 32) {
        return _deviceIDs[slot];
    }
    return SSW_DEVID_EMPTY;
}

const char* SmartSlotWishbone::getDeviceName(uint16_t deviceID) {
    switch (deviceID) {
        case SSW_DEVID_SYSTEM:   return "System";
        case SSW_DEVID_RGB_LED:  return "RGB LED";
        case SSW_DEVID_SID:      return "SID 6581";
        case SSW_DEVID_YM2149:   return "YM2149";
        case SSW_DEVID_LOGIC_AN: return "Logic Analyzer";
        case SSW_DEVID_VIDEO:    return "Video";
        case SSW_DEVID_GPIO:     return "GPIO";
        case SSW_DEVID_EMPTY:    return "Empty";
        default:                 return "Unknown";
    }
}

void SmartSlotWishbone::printDevices() {
    Serial.println("=== Smart Slot Wishbone Devices ===");
    Serial.printf("Slots populated: %d\n", _slotCount);
    Serial.println();
    
    for (uint8_t i = 0; i < _slotCount; i++) {
        uint16_t id = _deviceIDs[i];
        if (id != SSW_DEVID_EMPTY) {
            Serial.printf("Slot %2d: 0x%04X - %s\n", i, id, getDeviceName(id));
        }
    }
}

// =============================================================================
// System Info
// =============================================================================

uint8_t SmartSlotWishbone::getVersion() {
    return readSlot(0, SSW_SYS_VERSION);
}

uint8_t SmartSlotWishbone::getCapabilities() {
    return readSlot(0, SSW_SYS_CAPABILITIES);
}

uint8_t SmartSlotWishbone::getMemorySize() {
    return readSlot(0, SSW_SYS_MEM_SIZE);
}

// =============================================================================
// Helper Functions
// =============================================================================

void SmartSlotWishbone::beginTransaction() {
    _spi->beginTransaction(SPISettings(_spiFrequency, MSBFIRST, SPI_MODE0));
    digitalWrite(_csPin, LOW);
}

void SmartSlotWishbone::endTransaction() {
    digitalWrite(_csPin, HIGH);
    _spi->endTransaction();
}

uint8_t SmartSlotWishbone::transfer(uint8_t data) {
    return _spi->transfer(data);
}

void SmartSlotWishbone::transfer(const uint8_t* txData, uint8_t* rxData, size_t len) {
    _spi->transferBytes(txData, rxData, len);
}
