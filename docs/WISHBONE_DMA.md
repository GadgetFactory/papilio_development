# Wishbone DMA Implementation

## Overview

This implementation provides professional-grade DMA (Direct Memory Access) support for the Wishbone SPI bridge, leveraging the ESP32-S3's hardware DMA capabilities combined with FPGA-side FIFO buffering for zero-latency, high-throughput data transfers.

## Architecture

### Hardware Layers

```
┌─────────────────────────────────────────────────────────────┐
│  ESP32-S3 Firmware                                          │
│  ┌────────────────┐     ┌─────────────────┐                │
│  │ Audio Decoder  │────▶│ DMA Buffer Pool │                │
│  │  (MOD/WAV)     │     │  (4x 2KB DRAM)  │                │
│  └────────────────┘     └─────────┬───────┘                │
│                                   │                         │
│                         ┌─────────▼────────┐                │
│                         │  WishboneDMA     │                │
│                         │  Task (Core 1)   │                │
│                         │  Priority: Max-1 │                │
│                         └─────────┬────────┘                │
│                                   │                         │
│                         ┌─────────▼────────┐                │
│                         │  SPI Hardware    │                │
│                         │  DMA Engine      │                │
│                         └─────────┬────────┘                │
└───────────────────────────────────┼─────────────────────────┘
                                    │ SPI (20 MHz)
┌───────────────────────────────────┼─────────────────────────┐
│  FPGA Gateware                    │                         │
│                         ┌─────────▼────────┐                │
│                         │  SPI Receiver    │                │
│                         │  (Clock Domain   │                │
│                         │   Crossing)      │                │
│                         └─────────┬────────┘                │
│                                   │                         │
│                         ┌─────────▼────────┐                │
│                         │  Async FIFO      │                │
│                         │  256 x 8-bit     │                │
│                         │  Gray Code Sync  │                │
│                         └─────────┬────────┘                │
│                                   │                         │
│                         ┌─────────▼────────┐                │
│                         │  DMA Controller  │                │
│                         │  Auto-increment  │                │
│                         │  Address Gen     │                │
│                         └─────────┬────────┘                │
│                                   │                         │
│                         ┌─────────▼────────┐                │
│                         │  Wishbone Bus    │                │
│                         │  Master          │                │
│                         └─────────┬────────┘                │
│                                   │                         │
│                         ┌─────────▼────────┐                │
│                         │  Audio FIFO/DAC  │                │
│                         └──────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

#### 1. **ESP32-S3 DMA Buffer Pool**
- **Location**: `WishboneSPI_DMA.h`
- **Features**:
  - 4 buffers × 2KB each in DMA-capable DRAM
  - Circular buffer management with FreeRTOS semaphores
  - Thread-safe allocation and deallocation
  - Zero-copy design

#### 2. **Background DMA Task**
- **Core**: Core 1 (Core 0 reserved for WiFi/system)
- **Priority**: `configMAX_PRIORITIES - 1` (highest user priority)
- **Features**:
  - Asynchronous transfer execution
  - Queue-based transfer management
  - Completion signaling via semaphore
  - Automatic retry on failure

#### 3. **FPGA Async FIFO**
- **Location**: `async_fifo.v`
- **Features**:
  - Dual-clock design (SPI clock → System clock)
  - Gray code pointer synchronization
  - Configurable depth (default 256 entries)
  - Almost-full/almost-empty flags for flow control
  - Metastability-safe clock domain crossing

#### 4. **FPGA DMA Controller**
- **Location**: `spi_wb_dma_bridge.v`
- **Features**:
  - Auto-incrementing address generator
  - Burst transfers up to 4KB
  - FIFO-based buffering
  - Status register monitoring
  - Error detection and recovery

## Protocol

### Command Set

| Command | Value | Description |
|---------|-------|-------------|
| `CMD_READ` | 0x00 | Single byte read |
| `CMD_WRITE` | 0x01 | Single byte write |
| `CMD_DMA_WRITE` | 0x02 | DMA burst write |
| `CMD_READ_STATUS` | 0x03 | Read FIFO status |
| `CMD_RESET_FIFO` | 0x04 | Reset FIFO |

### DMA Write Protocol

```
┌────────┬─────────┬─────────┬─────────┬─────────┬──────────────┐
│  CMD   │ ADDR_HI │ ADDR_LO │ LEN_HI  │ LEN_LO  │  DATA[...]   │
│  0x02  │  8-bit  │  8-bit  │  8-bit  │  8-bit  │  LEN bytes   │
└────────┴─────────┴─────────┴─────────┴─────────┴──────────────┘
```

**Example**: Write 512 bytes to address 0x8200
```
02 82 00 02 00 [512 bytes of data...]
```

### Status Register (Read with CMD 0x03)

| Bit | Name | Description |
|-----|------|-------------|
| 7 | OVERFLOW | FIFO overflow detected |
| 6 | UNDERFLOW | FIFO underflow detected |
| 5 | FULL | FIFO is full |
| 4 | EMPTY | FIFO is empty |
| 3 | ALMOST_FULL | FIFO almost full (> threshold) |
| 2 | ALMOST_EMPTY | FIFO almost empty (< threshold) |
| 1 | DMA_MODE | DMA transfer in progress |
| 0 | CS_INACTIVE | Chip select inactive |

## Performance

### Throughput

- **SPI Speed**: 20 MHz
- **Theoretical Max**: ~2.5 MB/s
- **Practical Achievable**: ~1.5-2.0 MB/s (including overhead)
- **Audio Requirement**: 176 KB/s (44.1 kHz × 16-bit × 2 channels)
- **Headroom**: ~10x safety margin

### Latency

- **DMA Setup**: < 100 μs
- **Transfer Time** (512 bytes): ~250 μs
- **Total Latency**: < 500 μs per buffer
- **Audio Buffer**: 2048 bytes = ~23 ms of audio at 44.1 kHz

### Buffer Management

- **ESP32-S3 Side**: 4 × 2KB = 8 KB total
- **FPGA Side**: 256 bytes FIFO
- **Total Buffering**: ~8.3 KB (~47 ms of audio)

## Usage

### Basic Example

```cpp
#include "WishboneSPI_DMA.h"
#include "AudioOutputWishbone_DMA.h"

// Initialize DMA controller
WishboneDMA* dma = new WishboneDMA(&SPI, CS_PIN, 20000000);

// Initialize audio output
AudioOutputWishboneDMA* audio = new AudioOutputWishboneDMA(dma);
audio->begin();

// Use with ESP8266Audio library
AudioGeneratorMOD* mod = new AudioGeneratorMOD();
mod->begin(file_source, audio);

while (mod->isRunning()) {
    mod->loop();  // Audio streams via DMA in background
}
```

### Advanced: Manual DMA Control

```cpp
// Get a buffer
uint8_t* buffer = dma->getBuffer();

// Fill buffer with data
for (int i = 0; i < 512; i++) {
    buffer[i] = my_data[i];
}

// Queue DMA transfer
dma->queueTransfer(0x8200, buffer, 512);

// Optionally wait for completion
dma->waitTransferComplete(100);  // 100ms timeout

// Check status
uint8_t status = dma->readStatus();
if (status & 0x80) {
    Serial.println("FIFO overflow!");
    dma->resetFIFO();
}
```

### Performance Monitoring

```cpp
// Get statistics
const WB_DMA_Stats& stats = dma->getStats();
Serial.printf("Transfers: %u\n", stats.transfers_completed);
Serial.printf("Throughput: %.2f KB/s\n", 
    stats.bytes_transferred / (stats.last_transfer_us / 1000.0));

// Print detailed stats
dma->printStats();
audio->printStats();
```

## Integration with Existing Code

### Backward Compatibility

The DMA implementation is **fully backward compatible**. Existing code using the simple `wishboneBurstWrite()` will continue to work:

```cpp
// Old API (still works)
wishboneBurstWrite(address, data, length);

// New DMA API (better performance)
dma->queueTransfer(address, data, length);
```

### Migration Guide

1. **Replace includes**:
   ```cpp
   // Old
   #include "AudioOutputWishbone.h"
   
   // New
   #include "AudioOutputWishbone_DMA.h"
   ```

2. **Initialize DMA controller**:
   ```cpp
   WishboneDMA* dma = new WishboneDMA(&SPI, CS_PIN, 20000000);
   ```

3. **Use DMA audio output**:
   ```cpp
   AudioOutputWishboneDMA* audio = new AudioOutputWishboneDMA(dma);
   ```

4. **Everything else stays the same!**

## Troubleshooting

### Buffer Underruns

**Symptom**: Audio glitches, `buffer_underruns` counter increasing

**Solutions**:
- Increase buffer size: `#define WB_DMA_BUFFER_SIZE 4096`
- Increase number of buffers: `#define WB_DMA_NUM_BUFFERS 8`
- Check CPU load on Core 1
- Verify SPI speed is stable

### FIFO Overflow

**Symptom**: Status register bit 7 set, audio corruption

**Solutions**:
- Reduce DMA chunk size
- Add flow control in application
- Reset FIFO: `dma->resetFIFO()`
- Check Wishbone slave can keep up

### DMA Errors

**Symptom**: `dma_errors` counter increasing

**Solutions**:
- Check SPI wiring and signal integrity
- Reduce SPI clock speed
- Verify CS pin timing
- Check power supply stability

### Performance Degradation

**Actions**:
1. Print statistics: `dma->printStats()`
2. Check max latency: `audio->getMaxLatency()`
3. Monitor FIFO status: `dma->readStatus()`
4. Verify Core 1 is not blocked by other tasks

## Implementation Notes

### ESP32-S3 DMA Requirements

- Buffers must be in **DRAM** (not IRAM or Flash)
- Buffers must be **4-byte aligned**
- Maximum DMA transfer: **4092 bytes** (SPI hardware limit)
- Use `MALLOC_CAP_DMA | MALLOC_CAP_8BIT` for allocation

### FPGA Timing

- FIFO depth sized for SPI clock domain crossing
- Gray code prevents metastability during pointer synchronization
- Almost-full/empty thresholds provide early warning
- Address auto-increment happens after ACK (prevents race conditions)

### Thread Safety

- All buffer operations protected by FreeRTOS semaphores
- DMA task runs independently on Core 1
- Main application can run on Core 0 without blocking

## Future Enhancements

1. **Adaptive Rate Control**: Dynamically adjust transfer size based on FIFO level
2. **DMA Read Support**: Implement DMA for bulk reads
3. **Scatter-Gather**: Support for fragmented buffers
4. **Priority Queues**: Multiple priority levels for transfers
5. **Error Recovery**: Automatic retry with exponential backoff

## Files

### Gateware (Verilog)
- `async_fifo.v` - Async FIFO with Gray code synchronization
- `spi_wb_dma_bridge.v` - DMA-capable SPI to Wishbone bridge

### Firmware (C++)
- `WishboneSPI_DMA.h` - DMA controller and buffer pool
- `AudioOutputWishbone_DMA.h` - DMA-optimized audio output

### Examples
- `audio_mod_player_dma.ino` - Complete MOD player demo

## References

- [ESP32-S3 Technical Reference Manual - Chapter 29: SPI](https://www.espressif.com/sites/default/files/documentation/esp32-s3_technical_reference_manual_en.pdf)
- [Wishbone B4 Specification](https://cdn.opencores.org/downloads/wbspec_b4.pdf)
- [Asynchronous FIFO Design Techniques](http://www.sunburst-design.com/papers/CummingsSNUG2002SJ_FIFO1.pdf)

## License

See project LICENSE file.
