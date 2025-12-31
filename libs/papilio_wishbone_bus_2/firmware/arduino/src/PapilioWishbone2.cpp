// PapilioWishbone2.cpp - ESP32 library for PWB2 communication

#include "PapilioWishbone2.h"

// =============================================================================
// Constructor
// =============================================================================

PapilioWishbone2::PapilioWishbone2(int8_t cs_pin, SPIClass* spi)
    : _spi(spi), _csPin(cs_pin), _spiClock(PWB2_SPI_CLOCK_HZ),
      _slotCount(0), _version(0), _capabilities(0), _txCount(0), _debug(false)
{
    for (int i = 0; i < 32; i++) {
        _devices[i].deviceId = PWB2_DEVID_EMPTY;
        _devices[i].spiWidth = 8;
        _devices[i].flags = 0;
    }
}

// =============================================================================
// Initialization
// =============================================================================

bool PapilioWishbone2::begin(uint32_t spi_clock_hz) {
    _spiClock = spi_clock_hz;
    _spiSettings = SPISettings(_spiClock, PWB2_SPI_BIT_ORDER, PWB2_SPI_MODE);
    
    pinMode(_csPin, OUTPUT);
    csDeassert();
    
    _spi->begin();
    
    delay(10);  // Let FPGA stabilize
    
    // Read system info
    _version = readSlot8(0, PWB2_REG_VERSION);
    _slotCount = readSlot8(0, PWB2_REG_SLOT_COUNT);
    _capabilities = readSlot32(0, PWB2_REG_CAPABILITIES);
    
    if (_debug) {
        Serial.printf("[PWB2] Version: 0x%02X, Slots: %d, Caps: 0x%08X\n", 
                     _version, _slotCount, _capabilities);
    }
    
    return (_version == PWB2_VERSION);
}

void PapilioWishbone2::end() {
    _spi->end();
}

// =============================================================================
// Device Enumeration
// =============================================================================

bool PapilioWishbone2::enumerateDevices() {
    if (_debug) {
        Serial.println("[PWB2] Enumerating devices...");
    }
    
    // Read memory map for all slots
    for (uint8_t slot = 0; slot < 32; slot++) {
        uint8_t map_addr = PWB2_MEMMAP_START + (slot * 16);
        
        uint8_t devid_l = readSlot8(0, map_addr + 0);
        uint8_t devid_h = readSlot8(0, map_addr + 1);
        uint8_t spi_width = readSlot8(0, map_addr + 2);
        uint8_t flags = readSlot8(0, map_addr + 3);
        
        _devices[slot].deviceId = (devid_h << 8) | devid_l;
        _devices[slot].spiWidth = spi_width;
        _devices[slot].flags = flags;
        
        if (_debug && !_devices[slot].isEmpty()) {
            Serial.printf("[PWB2] Slot %d: DevID=0x%04X, SPI=%d-bit\n",
                         slot, _devices[slot].deviceId, _devices[slot].spiWidth);
        }
    }
    
    return true;
}

void PapilioWishbone2::printDevices(Stream& stream) {
    stream.println("===== PWB2 Device Map =====");
    stream.printf("Version: 0x%02X\n", _version);
    stream.printf("Slots Used: %d/32\n", _slotCount);
    stream.printf("Capabilities: 0x%08X\n\n", _capabilities);
    
    stream.println("Slot | Device ID | SPI Width | Name");
    stream.println("-----|-----------|-----------|-----");
    
    for (uint8_t slot = 0; slot < 32; slot++) {
        if (_devices[slot].isEmpty()) continue;
        
        stream.printf("%4d | 0x%04X    | %2d-bit    | ",
                     slot, _devices[slot].deviceId, _devices[slot].spiWidth);
        
        // Decode common device types
        switch (_devices[slot].deviceId) {
            case PWB2_DEVID_SYSTEM:  stream.println("System"); break;
            case PWB2_DEVID_RGB_LED: stream.println("RGB LED"); break;
            case PWB2_DEVID_GPIO:    stream.println("GPIO"); break;
            default:                 stream.println("Unknown"); break;
        }
    }
    
    stream.println("===========================");
}

uint16_t PapilioWishbone2::getDeviceId(uint8_t slot) const {
    if (slot < 32) return _devices[slot].deviceId;
    return PWB2_DEVID_EMPTY;
}

uint8_t PapilioWishbone2::getSpiWidth(uint8_t slot) const {
    if (slot < 32) return _devices[slot].spiWidth;
    return 8;
}

PWB2DeviceInfo PapilioWishbone2::getDeviceInfo(uint8_t slot) const {
    if (slot < 32) return _devices[slot];
    PWB2DeviceInfo empty = {PWB2_DEVID_EMPTY, 8, 0};
    return empty;
}

// =============================================================================
// Tier 1: Slot Access
// =============================================================================

bool PapilioWishbone2::writeSlot8(uint8_t slot, uint8_t reg, uint8_t data) {
    uint8_t cmd = buildCommand(true, PWB2_CMD_MODE_SLOT, false, slot);
    
    csAssert();
    spiTransfer(cmd);
    spiTransfer(reg);
    spiTransfer(data);
    csDeassert();
    
    _txCount++;
    return true;
}

uint8_t PapilioWishbone2::readSlot8(uint8_t slot, uint8_t reg) {
    uint8_t cmd = buildCommand(false, PWB2_CMD_MODE_SLOT, false, slot);
    
    csAssert();
    spiTransfer(cmd);
    spiTransfer(reg);
    uint8_t data = spiTransfer(0xFF);  // Dummy byte for read
    csDeassert();
    
    _txCount++;
    return data;
}

bool PapilioWishbone2::writeSlot16(uint8_t slot, uint8_t reg, uint16_t data) {
    uint8_t cmd = buildCommand(true, PWB2_CMD_MODE_SLOT, false, slot);
    
    csAssert();
    spiTransfer(cmd);
    spiTransfer(reg);
    spiTransfer(data >> 8);    // MSB first
    spiTransfer(data & 0xFF);
    csDeassert();
    
    _txCount++;
    return true;
}

uint16_t PapilioWishbone2::readSlot16(uint8_t slot, uint8_t reg) {
    uint8_t cmd = buildCommand(false, PWB2_CMD_MODE_SLOT, false, slot);
    
    csAssert();
    spiTransfer(cmd);
    spiTransfer(reg);
    uint16_t data = spiTransfer(0xFF) << 8;  // MSB
    data |= spiTransfer(0xFF);               // LSB
    csDeassert();
    
    _txCount++;
    return data;
}

bool PapilioWishbone2::writeSlot32(uint8_t slot, uint8_t reg, uint32_t data) {
    uint8_t cmd = buildCommand(true, PWB2_CMD_MODE_SLOT, false, slot);
    
    csAssert();
    spiTransfer(cmd);
    spiTransfer(reg);
    write32MSBFirst(data);
    csDeassert();
    
    _txCount++;
    return true;
}

uint32_t PapilioWishbone2::readSlot32(uint8_t slot, uint8_t reg) {
    uint8_t cmd = buildCommand(false, PWB2_CMD_MODE_SLOT, false, slot);
    
    csAssert();
    spiTransfer(cmd);
    spiTransfer(reg);
    uint32_t data = read32MSBFirst();
    csDeassert();
    
    _txCount++;
    return data;
}

bool PapilioWishbone2::writeSlotBurst(uint8_t slot, uint8_t start_reg, 
                                      const uint32_t* data, uint16_t word_count) {
    uint8_t cmd = buildCommand(true, PWB2_CMD_MODE_SLOT, true, slot);
    
    csAssert();
    spiTransfer(cmd);
    spiTransfer(start_reg);
    spiTransfer(word_count >> 8);    // Count high
    spiTransfer(word_count & 0xFF);  // Count low
    
    for (uint16_t i = 0; i < word_count; i++) {
        write32MSBFirst(data[i]);
    }
    
    csDeassert();
    _txCount++;
    return true;
}

bool PapilioWishbone2::readSlotBurst(uint8_t slot, uint8_t start_reg,
                                     uint32_t* data, uint16_t word_count) {
    uint8_t cmd = buildCommand(false, PWB2_CMD_MODE_SLOT, true, slot);
    
    csAssert();
    spiTransfer(cmd);
    spiTransfer(start_reg);
    spiTransfer(word_count >> 8);
    spiTransfer(word_count & 0xFF);
    
    for (uint16_t i = 0; i < word_count; i++) {
        data[i] = read32MSBFirst();
    }
    
    csDeassert();
    _txCount++;
    return true;
}

// =============================================================================
// Tier 2: Extended Mode
// =============================================================================

bool PapilioWishbone2::writeExtended(uint16_t address, uint32_t data) {
    uint8_t cmd = buildCommand(true, PWB2_CMD_MODE_EXTENDED, false, 0);
    
    csAssert();
    spiTransfer(cmd);
    spiTransfer(address >> 8);
    spiTransfer(address & 0xFF);
    write32MSBFirst(data);
    csDeassert();
    
    _txCount++;
    return true;
}

uint32_t PapilioWishbone2::readExtended(uint16_t address) {
    uint8_t cmd = buildCommand(false, PWB2_CMD_MODE_EXTENDED, false, 0);
    
    csAssert();
    spiTransfer(cmd);
    spiTransfer(address >> 8);
    spiTransfer(address & 0xFF);
    uint32_t data = read32MSBFirst();
    csDeassert();
    
    _txCount++;
    return data;
}

bool PapilioWishbone2::writeExtendedBurst(uint16_t start_addr,
                                          const uint32_t* data, uint16_t word_count) {
    uint8_t cmd = buildCommand(true, PWB2_CMD_MODE_EXTENDED, true, 0);
    
    csAssert();
    spiTransfer(cmd);
    spiTransfer(start_addr >> 8);
    spiTransfer(start_addr & 0xFF);
    spiTransfer(word_count >> 8);
    spiTransfer(word_count & 0xFF);
    
    for (uint16_t i = 0; i < word_count; i++) {
        write32MSBFirst(data[i]);
    }
    
    csDeassert();
    _txCount++;
    return true;
}

bool PapilioWishbone2::readExtendedBurst(uint16_t start_addr,
                                         uint32_t* data, uint16_t word_count) {
    uint8_t cmd = buildCommand(false, PWB2_CMD_MODE_EXTENDED, true, 0);
    
    csAssert();
    spiTransfer(cmd);
    spiTransfer(start_addr >> 8);
    spiTransfer(start_addr & 0xFF);
    spiTransfer(word_count >> 8);
    spiTransfer(word_count & 0xFF);
    
    for (uint16_t i = 0; i < word_count; i++) {
        data[i] = read32MSBFirst();
    }
    
    csDeassert();
    _txCount++;
    return true;
}

// =============================================================================
// Tier 3: Large Mode
// =============================================================================

bool PapilioWishbone2::writeLarge(uint32_t address, uint32_t data) {
    uint8_t cmd = buildCommand(true, PWB2_CMD_MODE_LARGE, false, 0);
    
    csAssert();
    spiTransfer(cmd);
    spiTransfer((address >> 16) & 0xFF);
    spiTransfer((address >> 8) & 0xFF);
    spiTransfer(address & 0xFF);
    write32MSBFirst(data);
    csDeassert();
    
    _txCount++;
    return true;
}

uint32_t PapilioWishbone2::readLarge(uint32_t address) {
    uint8_t cmd = buildCommand(false, PWB2_CMD_MODE_LARGE, false, 0);
    
    csAssert();
    spiTransfer(cmd);
    spiTransfer((address >> 16) & 0xFF);
    spiTransfer((address >> 8) & 0xFF);
    spiTransfer(address & 0xFF);
    uint32_t data = read32MSBFirst();
    csDeassert();
    
    _txCount++;
    return data;
}

bool PapilioWishbone2::writeLargeBurst(uint32_t start_addr,
                                       const uint32_t* data, uint16_t word_count) {
    uint8_t cmd = buildCommand(true, PWB2_CMD_MODE_LARGE, true, 0);
    
    csAssert();
    spiTransfer(cmd);
    spiTransfer((start_addr >> 16) & 0xFF);
    spiTransfer((start_addr >> 8) & 0xFF);
    spiTransfer(start_addr & 0xFF);
    spiTransfer(word_count >> 8);
    spiTransfer(word_count & 0xFF);
    
    for (uint16_t i = 0; i < word_count; i++) {
        write32MSBFirst(data[i]);
    }
    
    csDeassert();
    _txCount++;
    return true;
}

bool PapilioWishbone2::readLargeBurst(uint32_t start_addr,
                                      uint32_t* data, uint16_t word_count) {
    uint8_t cmd = buildCommand(false, PWB2_CMD_MODE_LARGE, true, 0);
    
    csAssert();
    spiTransfer(cmd);
    spiTransfer((start_addr >> 16) & 0xFF);
    spiTransfer((start_addr >> 8) & 0xFF);
    spiTransfer(start_addr & 0xFF);
    spiTransfer(word_count >> 8);
    spiTransfer(word_count & 0xFF);
    
    for (uint16_t i = 0; i < word_count; i++) {
        data[i] = read32MSBFirst();
    }
    
    csDeassert();
    _txCount++;
    return true;
}

// =============================================================================
// Low-level SPI Helpers
// =============================================================================

void PapilioWishbone2::csAssert() {
    digitalWrite(_csPin, LOW);
    delayMicroseconds(1);
}

void PapilioWishbone2::csDeassert() {
    delayMicroseconds(1);
    digitalWrite(_csPin, HIGH);
    delayMicroseconds(1);
}

uint8_t PapilioWishbone2::spiTransfer(uint8_t data) {
    return _spi->transfer(data);
}

void PapilioWishbone2::spiTransferBuf(uint8_t* buf, size_t len) {
    _spi->transferBytes(buf, buf, len);
}

// =============================================================================
// Protocol Helpers
// =============================================================================

uint8_t PapilioWishbone2::buildCommand(bool is_write, uint8_t mode, bool burst, uint8_t data) {
    uint8_t cmd = 0;
    if (is_write) cmd |= PWB2_CMD_WRITE;
    cmd |= mode;
    if (burst) cmd |= PWB2_CMD_BURST;
    cmd |= (data & 0x07);
    return cmd;
}

void PapilioWishbone2::write32MSBFirst(uint32_t value) {
    spiTransfer((value >> 24) & 0xFF);
    spiTransfer((value >> 16) & 0xFF);
    spiTransfer((value >> 8) & 0xFF);
    spiTransfer(value & 0xFF);
}

uint32_t PapilioWishbone2::read32MSBFirst() {
    uint32_t value = 0;
    value |= ((uint32_t)spiTransfer(0xFF) << 24);
    value |= ((uint32_t)spiTransfer(0xFF) << 16);
    value |= ((uint32_t)spiTransfer(0xFF) << 8);
    value |= spiTransfer(0xFF);
    return value;
}
