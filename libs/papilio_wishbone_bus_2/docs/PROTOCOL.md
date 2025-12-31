# PWB2 Protocol Specification

## Version

Protocol Version: 2.0 (0x20)

## Physical Layer

- **Interface**: SPI Mode 0 (CPOL=0, CPHA=0)
- **Clock Speed**: Up to 40 MHz (20 MHz recommended)
- **Data Width**: 8 bits per SPI transfer
- **Byte Order**: MSB first (big-endian)
- **Chip Select**: Active low

## Command Byte Format

Every transaction begins with a command byte:

```
[7:RW] [6:5:MODE] [4:RSVD] [3:BURST] [2:0:MODE_DATA]

Bit 7:     R/W (0=Read, 1=Write)
Bits 6-5:  Mode select
           00 = Slot mode
           01 = Extended mode
           10 = Large mode
           11 = Reserved
Bit 4:     Reserved (must be 0)
Bit 3:     Burst flag (0=Single, 1=Burst)
Bits 2-0:  Mode-specific data
```

## Transaction Formats

### Tier 1: Slot Mode (Peripheral Registers)

**Address Space**: 0x00_0000 to 0x00_1FFF (8KB total)
- 32 slots × 256 bytes per slot
- Slot address: `{000, slot[4:0], register[7:0]}`

**Single Write (variable width):**
```
[CMD] [REG] [DATA...]

CMD:  [1|00|0|SLOT[4:0]]
REG:  Register offset (0-255)
DATA: 1, 2, or 4 bytes depending on peripheral's SPI width
      - 8-bit:  1 byte
      - 16-bit: 2 bytes (MSB first)
      - 32-bit: 4 bytes (MSB first)
```

**Single Read:**
```
[CMD] [REG] [DUMMY...] -> [DATA...]

CMD:   [0|00|0|SLOT[4:0]]
REG:   Register offset
DUMMY: Dummy bytes while FPGA prepares data
DATA:  1, 2, or 4 bytes depending on SPI width
```

**Burst Write:**
```
[CMD] [REG] [COUNT_H] [COUNT_L] [DATA...]

CMD:   [1|00|1|SLOT[4:0]]
REG:   Starting register offset
COUNT: 16-bit word count (number of 32-bit words)
DATA:  COUNT × 4 bytes (always 32-bit words)
       Address auto-increments by 4 each word
```

**Burst Read:**
```
[CMD] [REG] [COUNT_H] [COUNT_L] -> [DATA...]

CMD:   [0|00|1|SLOT[4:0]]
REG:   Starting register offset
COUNT: 16-bit word count
DATA:  COUNT × 4 bytes
```

**Examples:**
```
Write 0xFF to slot 1, register 0x05:
  [0x81] [0x05] [0xFF]

Write 0x1234 (16-bit) to slot 2, register 0x10:
  [0x82] [0x10] [0x12] [0x34]

Write 0xDEADBEEF (32-bit) to slot 3, register 0x20:
  [0x83] [0x20] [0xDE] [0xAD] [0xBE] [0xEF]

Burst write 3 words to slot 4, starting at register 0x00:
  [0x8C] [0x00] [0x00] [0x03] [word0] [word1] [word2]
  where each word is 4 bytes MSB first
```

### Tier 2: Extended Mode (On-chip Memory)

**Address Space**: 0x00_2000 to 0x00_FFFF (56KB)
- Always 32-bit transfers
- For BRAM framebuffers, audio buffers, etc.

**Single Write:**
```
[CMD] [ADDR_H] [ADDR_L] [DATA0] [DATA1] [DATA2] [DATA3]

CMD:    [1|01|0|000]
ADDR:   16-bit address (0x2000-0xFFFF)
DATA:   32-bit data (MSB first)
```

**Single Read:**
```
[CMD] [ADDR_H] [ADDR_L] -> [DATA0] [DATA1] [DATA2] [DATA3]

CMD:    [0|01|0|000]
ADDR:   16-bit address
DATA:   32-bit data
```

**Burst Write:**
```
[CMD] [ADDR_H] [ADDR_L] [COUNT_H] [COUNT_L] [DATA...]

CMD:    [1|01|1|000]
ADDR:   Starting address
COUNT:  Word count
DATA:   COUNT × 4 bytes
```

**Burst Read:**
```
[CMD] [ADDR_H] [ADDR_L] [COUNT_H] [COUNT_L] -> [DATA...]

CMD:    [0|01|1|000]
ADDR:   Starting address
COUNT:  Word count
DATA:   COUNT × 4 bytes
```

### Tier 3: Large Mode (External DDR/SDRAM)

**Address Space**: 0x01_0000 to 0xFF_FFFF (16MB - 64KB)
- Always 32-bit transfers
- For external DDR framebuffers, large datasets

**Single Write:**
```
[CMD] [ADDR[23:16]] [ADDR[15:8]] [ADDR[7:0]] [DATA0-3]

CMD:    [1|10|0|000]
ADDR:   24-bit address
DATA:   32-bit data (MSB first)
```

**Single Read:**
```
[CMD] [ADDR[23:16]] [ADDR[15:8]] [ADDR[7:0]] -> [DATA0-3]

CMD:    [0|10|0|000]
ADDR:   24-bit address
DATA:   32-bit data
```

**Burst Write:**
```
[CMD] [ADDR[23:16]] [ADDR[15:8]] [ADDR[7:0]] [COUNT_H] [COUNT_L] [DATA...]

CMD:    [1|10|1|000]
ADDR:   24-bit starting address
COUNT:  16-bit word count
DATA:   COUNT × 4 bytes
```

**Burst Read:**
```
[CMD] [ADDR[23:16]] [ADDR[15:8]] [ADDR[7:0]] [COUNT_H] [COUNT_L] -> [DATA...]

CMD:    [0|10|1|000]
ADDR:   24-bit starting address
COUNT:  16-bit word count
DATA:   COUNT × 4 bytes
```

## System Registers (Slot 0)

Slot 0 is reserved for system control and memory map:

```
0x00: DEVICE_ID_L     - System device ID low byte (0x59)
0x01: DEVICE_ID_H     - System device ID high byte (0x53)
0x02: VERSION         - Protocol version (0x20 for v2.0)
0x03: SLOT_COUNT      - Number of slots in use
0x04: CAPABILITIES    - Feature flags (32-bit when read as 32-bit)
0x05: STATUS          - System status (0x01 = ready)
0x06-0x0F: Reserved

Memory Map (16 bytes per slot):
0x10-0x1F: Slot 0 info
0x20-0x2F: Slot 1 info
...
0xF0-0xFF: Slot 30 info
(Slot 31 at 0x100, but only first 256 bytes accessible in slot mode)

Per-slot info (16 bytes):
+0: Device ID low byte
+1: Device ID high byte
+2: SPI width (8, 16, or 32)
+3: Flags (reserved)
+4-15: Reserved
```

## Capability Flags

```
Bit 0: Burst mode support
Bit 1: Extended memory support
Bit 2: Large memory support
Bit 3: DMA support
Bits 4-31: Reserved
```

## Timing

### SPI Timing (Mode 0)
- Data sampled on rising edge of SCLK
- Data shifted on falling edge of SCLK
- CS must be low for entire transaction
- Minimum CS high time between transactions: 100ns

### Wishbone Timing
- All Wishbone transactions are pipelined
- ACK expected within reasonable time (implementation-dependent)
- Burst transactions auto-increment address

## Error Handling

- Invalid command bytes ignored (no response)
- Out-of-range addresses return 0x00000000 for reads
- Out-of-range writes are ignored
- Burst count of 0 is treated as 65536

## Performance Characteristics

### Overhead Analysis

**Single 32-bit slot write:**
- Command: 1 byte
- Register: 1 byte
- Data: 4 bytes
- **Total: 6 bytes** = 48 bits @ 20MHz = 2.4µs

**Burst slot write (N words):**
- Command: 1 byte
- Register: 1 byte
- Count: 2 bytes
- Data: N × 4 bytes
- **Total: 4 + 4N bytes**
- Overhead: 4 bytes fixed

**Efficiency:**
- Single writes: 67% efficient (4 data / 6 total)
- Burst (N=256): 99.6% efficient (1024 data / 1028 total)

### Comparison with Previous Protocols

| Protocol | Single Write | Burst 1KB | Efficiency |
|----------|-------------|-----------|------------|
| PWB2 | 6 bytes | 1028 bytes | 99.6% |
| SSW | 3 bytes (8-bit) | 1027 bytes | 99.7% |
| PWB v1 | 7 bytes | N/A | - |

PWB2 provides near-optimal efficiency with the flexibility of 32-bit native width.

## Standard Device IDs

```
0x5359 - System control (Slot 0)
0x4C45 - RGB LED
0x4750 - GPIO
0x5349 - SID audio chip
0x594D - YM2149 audio chip
0x504B - POKEY audio chip
0x4844 - HDMI controller
0x4642 - Framebuffer
0x5350 - SPI master
0x4932 - I2C master
0x5541 - UART
0x544D - Timer
0x5057 - PWM controller
0x0000 - Empty slot
```

## Future Extensions

Reserved command byte values (mode 11) allow for future protocol extensions without breaking compatibility.

Possible future features:
- DMA descriptors
- Interrupt support
- Multi-master arbitration
- Compressed data transfers
