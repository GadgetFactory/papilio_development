# Smart Slot Wishbone Protocol Specification

## Overview

Smart Slot Wishbone (SSW) is a three-tier addressing architecture for efficient ESP32-to-FPGA communication over SPI. It provides:

- **Tier 1 (Slot Mode)**: 3-byte transactions for peripheral registers
- **Tier 2 (Extended Mode)**: 4-byte transactions for on-chip memory
- **Tier 3 (Large Mode)**: 5-byte transactions for external DDR/SDRAM
- **Burst Mode**: Efficient bulk transfers with 80%+ overhead reduction

## Address Space

```
0x000000 - 0x001FFF (8KB)   : Tier 1 - Slot mode (32 slots × 256 bytes)
0x002000 - 0x00FFFF (56KB)  : Tier 2 - Extended mode (on-chip BRAM)
0x010000 - 0xFFFFFF (~16MB) : Tier 3 - Large mode (external memory)
```

## Command Byte Format

```
[7:RW] [6:5:MODE] [4:3:FLAGS] [2:0:MODE_DATA]

RW (bit 7):
  0 = Read
  1 = Write

MODE (bits 6:5):
  00 = Slot mode (Tier 1)
  01 = Extended mode (Tier 2)
  10 = Large mode (Tier 3)
  11 = Reserved

FLAGS (bits 4:3):
  Bit 3: Burst mode enable
  Bit 4: Reserved

MODE_DATA (bits 2:0 or 4:0):
  Slot mode: Slot number (5 bits, bits 4:0)
  Large mode: Memory bank (5 bits, bits 4:0)
  Extended mode: Reserved (bits 2:0)
```

## Transaction Formats

### Slot Mode (3 bytes)

For accessing peripheral registers in slots 0-31.

**Write Transaction:**
```
Byte 0: [1][00][slot[4:0]]     CMD: Write, Slot mode, Slot number
Byte 1: [register[7:0]]        Register offset within slot
Byte 2: [data[7:0]]            Data to write
```

**Read Transaction:**
```
TX Byte 0: [0][00][slot[4:0]]  CMD: Read, Slot mode, Slot number
TX Byte 1: [register[7:0]]     Register offset within slot
TX Byte 2: [0x00]              Dummy byte
RX Byte 3: [data[7:0]]         Data read from register
```

**Address Mapping:**
```
Physical Address = {3'b000, slot[4:0], register[7:0]}

Examples:
  Slot 0, Reg 0x00  -> 0x000000
  Slot 1, Reg 0x00  -> 0x000100
  Slot 1, Reg 0xFF  -> 0x0001FF
  Slot 31, Reg 0xFF -> 0x001FFF
```

### Extended Mode (4 bytes)

For accessing on-chip BRAM (0x0000-0xFFFF).

**Write Transaction:**
```
Byte 0: [1][01][000]           CMD: Write, Extended mode
Byte 1: [addr[15:8]]           Address high byte
Byte 2: [addr[7:0]]            Address low byte
Byte 3: [data[7:0]]            Data to write
```

**Read Transaction:**
```
TX Byte 0: [0][01][000]        CMD: Read, Extended mode
TX Byte 1: [addr[15:8]]        Address high byte
TX Byte 2: [addr[7:0]]         Address low byte
TX Byte 3: [0x00]              Dummy byte
RX Byte 4: [data[7:0]]         Data read
```

### Large Mode (5 bytes)

For accessing external DDR/SDRAM (0x000000-0xFFFFFF).

**Write Transaction:**
```
Byte 0: [1][10][bank[4:0]]     CMD: Write, Large mode, Bank number
Byte 1: [addr[23:16]]          Address bits 23:16
Byte 2: [addr[15:8]]           Address bits 15:8
Byte 3: [addr[7:0]]            Address bits 7:0
Byte 4: [data[7:0]]            Data to write
```

**Read Transaction:**
```
TX Byte 0: [0][10][bank[4:0]]  CMD: Read, Large mode, Bank number
TX Byte 1: [addr[23:16]]       Address bits 23:16
TX Byte 2: [addr[15:8]]        Address bits 15:8
TX Byte 3: [addr[7:0]]         Address bits 7:0
TX Byte 4: [0x00]              Dummy byte
RX Byte 5: [data[7:0]]         Data read
```

## Burst Mode

Burst mode dramatically reduces overhead for sequential transfers.

**Burst Write (Slot Mode Example):**
```
Byte 0:     [1][00][1][slot]   CMD: Write, Slot mode, Burst, Slot number
Byte 1:     [start_reg[7:0]]   Starting register
Byte 2:     [count[15:8]]      Byte count high
Byte 3:     [count[7:0]]       Byte count low
Byte 4..N:  [data[7:0]] × N   Data bytes (N = count)
```

**Burst Read (Extended Mode Example):**
```
TX Byte 0:    [0][01][1][000]  CMD: Read, Extended mode, Burst
TX Byte 1:    [addr[15:8]]     Start address high
TX Byte 2:    [addr[7:0]]      Start address low
TX Byte 3:    [count[15:8]]    Byte count high
TX Byte 4:    [count[7:0]]     Byte count low
TX Byte 5:    [0x00]           Dummy byte
RX Byte 6..N: [data[7:0]] × N Data bytes (N = count)
```

**Burst Behavior:**
- Address auto-increments after each byte
- Maximum burst length: 65,535 bytes per transaction
- Bursts can cross register/address boundaries
- For >64KB transfers, split into multiple bursts

## Performance Comparison

### RGB LED Update (3 bytes of data)

**Single writes (current flat addressing):**
```
[CMD][ADDR_H][ADDR_L][DATA] × 3 = 12 bytes total
```

**Slot mode writes:**
```
[CMD][REG][DATA] × 3 = 9 bytes total
25% improvement
```

### Framebuffer Update (153,600 bytes)

**Single writes:**
```
4 bytes overhead × 153,600 = 614,400 bytes total
```

**Burst mode:**
```
4 bytes header + 2 bytes count + 153,600 data = 153,606 bytes
75% reduction in overhead!
```

### Large DDR Transfer (4MB)

**Single writes:**
```
5 bytes × 4,194,304 = 20,971,520 bytes
```

**Burst mode (64KB chunks):**
```
(5 + 2) × 64 chunks + 4,194,304 data = 4,194,752 bytes
80% overhead reduction!
```

## SPI Timing

**Clock Mode:** SPI Mode 0 (CPOL=0, CPHA=0)
- Data sampled on rising edge of SCLK
- Data changes on falling edge of SCLK
- CS active low

**Recommended Frequencies:**
- 20 MHz: Standard operation
- 40 MHz: High-speed (if FPGA supports)
- 80 MHz: Maximum (ESP32 limit, requires careful PCB layout)

**Transfer Rates:**
```
At 20 MHz:
  Theoretical: 2.5 MB/s
  Practical:   ~2.0 MB/s (accounting for CS overhead)
  
At 40 MHz:
  Theoretical: 5.0 MB/s
  Practical:   ~4.0 MB/s
```

## System Control Slot (Slot 0)

Slot 0 is reserved for system control and device enumeration.

**Registers:**
```
0x00: VERSION          - Protocol version (read-only)
0x01: CAPABILITIES     - Feature flags (read-only)
0x02: SLOT_COUNT       - Number of populated slots (read-only)
0x03: MEM_SIZE         - External memory size in MB (read-only)
0x10-0x2F: Device IDs  - 16-bit device IDs for slots 0-15
0x30-0x4F: Device IDs  - 16-bit device IDs for slots 16-31
```

**Device ID Format:**
```
Each device occupies 2 bytes (big-endian):
  Byte 0: ID high byte
  Byte 1: ID low byte
  
Example - Reading device ID for slot 5:
  Read slot 0, reg 0x1A (0x10 + 5*2) -> High byte
  Read slot 0, reg 0x1B (0x10 + 5*2 + 1) -> Low byte
```

## Error Handling

**Invalid Command:**
- Bridge enters ERROR state
- No Wishbone transaction generated
- Waits for CS deassert to return to IDLE

**Timeout:**
- If Wishbone slave doesn't ACK within reasonable time
- Bridge should timeout and deassert wb_cyc
- Return error status via debug output

**Address Out of Range:**
- Depends on decoder implementation
- Can return dummy data or signal error
- Recommended: Return 0xFF for reads, ignore writes

## Future Extensions

### Mode 11 (Reserved) - Ultra-Large Memory

Could support 32-bit addressing for 4GB address space:
```
Byte 0: [RW][11][flags]
Byte 1-4: [addr[31:0]]
Byte 5: [data[7:0]]

Total: 6 bytes per transaction
```

### Enhanced Features
- DMA support with dedicated DMA slot
- Interrupt notification via separate GPIO
- Multi-byte data width (16-bit, 32-bit)
- Compressed burst modes
- Transaction checksums for reliability
