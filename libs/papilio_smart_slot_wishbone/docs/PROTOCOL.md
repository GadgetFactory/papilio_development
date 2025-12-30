# Smart Slot Wishbone Protocol Specification

## Overview

Smart Slot Wishbone (SSW) is a three-tier addressing protocol designed for efficient ESP32-to-FPGA communication over SPI. It provides optimized access to both small peripherals and large external memory.

## Protocol Version

Current version: 1.0

## Physical Layer

- **Interface**: SPI Mode 0 (CPOL=0, CPHA=0)
- **Clock Speed**: Up to 40 MHz
- **Data Width**: 8 bits per transaction
- **Byte Order**: MSB first

## Command Byte Format

Every transaction begins with a command byte:

```
[7:RW] [6:5:MODE] [4:3:FLAGS] [2:0:MODE_DATA]

Bit 7:     R/W (0=Read, 1=Write)
Bits 6-5:  Mode select
Bit 3:     Burst flag (0=Single, 1=Burst)
Bits 4,2-0: Mode-specific data
```

### Mode Values

| Mode | Value | Description | Address Space |
|------|-------|-------------|---------------|
| Slot | 00 | Peripheral slots | 0x000000-0x001FFF (8KB) |
| Extended | 01 | On-chip memory | 0x002000-0x00FFFF (56KB) |
| Large | 10 | External DDR/SDRAM | 0x010000-0xFFFFFF (16MB) |
| Reserved | 11 | Future use | - |

## Transaction Formats

### Tier 1: Slot Mode (3 bytes)

**Purpose**: Access to peripheral control registers

**Command byte**: `[7:RW] [6:5:00] [4:RSVD] [3:BURST] [2:0:SLOT[4:2]]`

**Single access**:
```
[CMD] [REG] [DATA]

CMD:  [RW|00|0|SLOT[4:0]]
REG:  8-bit register offset
DATA: 8-bit data (write) or dummy byte (read)
```

**Burst access**:
```
[CMD] [REG] [COUNT_H] [COUNT_L] [DATA...]

CMD:  [RW|00|1|SLOT[4:0]]  // Burst flag set
REG:  Starting register offset
COUNT: 16-bit byte count
DATA: COUNT bytes of data
```

**Address calculation**: `ADDR = {000, SLOT[4:0], REG[7:0]}`

**Examples**:
```
Write to slot 1, register 0x05, data 0xFF:
  [0x81] [0x05] [0xFF]
  
Read from slot 2, register 0x10:
  [0x02] [0x10] [0x00]
  
Burst write 5 bytes to slot 3, starting at register 0x20:
  [0x8B] [0x20] [0x00] [0x05] [0xAA] [0xBB] [0xCC] [0xDD] [0xEE]
```

### Tier 2: Extended Mode (4 bytes)

**Purpose**: Access to on-chip BRAM (framebuffers, audio buffers)

**Command byte**: `[7:RW] [6:5:01] [4:RSVD] [3:BURST] [2:0:FLAGS]`

**Single access**:
```
[CMD] [ADDR_H] [ADDR_L] [DATA]

CMD:    [RW|01|0|000]
ADDR_H: Address bits [15:8]
ADDR_L: Address bits [7:0]
DATA:   8-bit data
```

**Burst access**:
```
[CMD] [ADDR_H] [ADDR_L] [COUNT_H] [COUNT_L] [DATA...]

CMD:  [RW|01|1|000]  // Burst flag set
ADDR: 16-bit address
COUNT: 16-bit byte count
DATA: COUNT bytes of data
```

**Examples**:
```
Write to address 0x2000, data 0x42:
  [0xA0] [0x20] [0x00] [0x42]
  
Read from address 0x5A3C:
  [0x20] [0x5A] [0x3C] [0x00]
  
Burst write 256 bytes to address 0x3000:
  [0xA8] [0x30] [0x00] [0x01] [0x00] [DATA×256]
```

### Tier 3: Large Memory Mode (5 bytes)

**Purpose**: Access to external DDR/SDRAM (large framebuffers, textures)

**Command byte**: `[7:RW] [6:5:10] [4:RSVD] [3:BURST] [2:0:BANK[4:2]]`

**Single access**:
```
[CMD] [ADDR_H] [ADDR_M] [ADDR_L] [DATA]

CMD:    [RW|10|0|BANK[4:0]]
ADDR_H: Address bits [23:16]
ADDR_M: Address bits [15:8]
ADDR_L: Address bits [7:0]
DATA:   8-bit data
```

**Burst access**:
```
[CMD] [ADDR_H] [ADDR_M] [ADDR_L] [COUNT_H] [COUNT_L] [DATA...]

CMD:  [RW|10|1|BANK[4:0]]  // Burst flag set
ADDR: 24-bit address
COUNT: 16-bit byte count (max 65535)
DATA: COUNT bytes of data
```

**Examples**:
```
Write to address 0x010000, data 0x55:
  [0xC0] [0x01] [0x00] [0x00] [0x55]
  
Read from address 0x123456:
  [0x40] [0x12] [0x34] [0x56] [0x00]
  
Burst write 1024 bytes to address 0x050000:
  [0xC8] [0x05] [0x00] [0x00] [0x04] [0x00] [DATA×1024]
```

## Address Space Map

```
0x000000 ├─ Tier 1: Slot Mode (8KB)
         │  Slot 0:  0x000000-0x0000FF (System Control)
         │  Slot 1:  0x000100-0x0001FF (RGB LED)
         │  Slot 2:  0x000200-0x0002FF (SID 6581)
         │  Slot 3:  0x000300-0x0003FF (YM2149)
         │  ...
0x001FFF │  Slot 31: 0x001F00-0x001FFF
         │
0x002000 ├─ Tier 2: Extended Mode (56KB)
         │  Small framebuffer (32KB)
         │  Audio buffers (8KB)
         │  Logic analyzer RAM (8KB)
         │  Reserved (8KB)
0x00FFFF │
         │
0x010000 ├─ Tier 3: Large Memory Mode (16MB)
         │  Bank 0: Large framebuffer (1MB)
         │  Bank 1: Texture cache (1MB)
         │  Bank 2: Audio samples (1MB)
         │  Banks 3-31: Reserved (13MB)
0xFFFFFF └─
```

## System Control Registers (Slot 0)

| Offset | Register | Access | Description |
|--------|----------|--------|-------------|
| 0x00 | VERSION | R | Protocol version |
| 0x01 | CAPABILITIES | R | Capability flags |
| 0x02 | SLOT_COUNT | R | Number of populated slots |
| 0x03 | MEM_SIZE | R | External memory size (MB) |
| 0x04-0x0F | Reserved | - | - |
| 0x10-0x2F | DEV_ID_0..15 | R | Device IDs for slots 0-15 (16-bit) |
| 0x30-0x4F | DEV_ID_16..31 | R | Device IDs for slots 16-31 (16-bit) |

### Capability Flags (0x01)

```
Bit 0: Slot mode supported
Bit 1: Extended mode supported
Bit 2: Large mode supported
Bit 3: Burst mode supported
Bit 4: External DDR present
Bit 5: External SDRAM present
Bits 6-7: Reserved
```

## Device ID Registry

| ID | ASCII | Device |
|----|-------|--------|
| 0x5359 | "SY" | System Control |
| 0x4C45 | "LE" | RGB LED |
| 0x5349 | "SI" | SID 6581 Audio |
| 0x594D | "YM" | YM2149 Audio |
| 0x4C41 | "LA" | Logic Analyzer |
| 0x5649 | "VI" | Video Controller |
| 0x414D | "AM" | Audio Mixer |
| 0x4750 | "GP" | GPIO |
| 0x5541 | "UA" | UART |
| 0x5350 | "SP" | SPI |
| 0x4943 | "IC" | I2C |
| 0x5057 | "PW" | PWM |
| 0x544D | "TM" | Timer |
| 0x444D | "DM" | DMA Controller |
| 0x4642 | "FB" | Framebuffer |
| 0xFFFF | - | Empty Slot |

## Performance Characteristics

### Transaction Overhead

| Mode | Single | Burst (N bytes) | Efficiency |
|------|--------|-----------------|------------|
| Slot | 3 bytes | 5 + N bytes | ~40% overhead for N=10 |
| Extended | 4 bytes | 6 + N bytes | ~6% overhead for N=100 |
| Large | 5 bytes | 7 + N bytes | ~0.7% overhead for N=1000 |

### Example: 1MB Framebuffer Update

- **Single writes**: 5 × 1,048,576 = 5,242,880 bytes
- **Burst write**: 7 + 1,048,576 = 1,048,583 bytes
- **Efficiency gain**: 80% reduction in SPI traffic!

### Timing

At 20 MHz SPI:
- Slot access: ~1.2 μs per byte
- Extended access: ~1.6 μs per byte
- Large access: ~2.0 μs per byte
- Burst mode: ~0.4 μs per byte (after header)

## Error Handling

- Invalid mode: Returns 0xFF on read
- Out-of-range address: No response (timeout)
- Burst overflow: Wraps within current tier
- CS deassert: Aborts current transaction

## Implementation Notes

1. **Clock Domain Crossing**: SPI clock is asynchronous to system clock
2. **Synchronization**: Use 3-stage synchronizer for SPI signals
3. **Wishbone Interface**: Single-cycle ACK for on-chip, multi-cycle for DDR
4. **Burst Auto-increment**: Address increments automatically
5. **CS Requirements**: CS must be deasserted between transactions

## Future Extensions

- Mode 11: Ultra-large mode (32-bit addressing, 4GB space)
- DMA capabilities
- Interrupt support
- Write protection
