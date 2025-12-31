# Papilio Wishbone Bus 2 (PWB2) - Architecture Document

## Executive Summary

Papilio Wishbone Bus 2 combines the best features from two existing libraries:
- **Smart Slot Wishbone (SSW)**: Three-tier addressing, burst mode, efficient protocol
- **Papilio Wishbone Bus (PWB)**: 32-bit native, variable SPI widths, plug-and-play generation

PWB2 provides a complete ESP32-to-FPGA communication infrastructure with:
- 32-bit native Wishbone bus internally
- Variable SPI transfer widths (8/16/32-bit) per peripheral
- Three-tier addressing (slots/extended/large) with burst support
- Automatic top-level generation from library metadata
- Memory map for device enumeration
- Use of proven GitHub libraries for SPI communication

## Key Design Principles

1. **32-bit Native Wishbone**: All peripherals use standard 32-bit Wishbone internally
2. **Variable SPI Efficiency**: Peripherals declare optimal SPI transfer size (8/16/32-bit)
3. **Three-Tier Addressing**: Efficient access to registers, on-chip memory, and external DDR
4. **Burst Mode**: High-performance bulk transfers with minimal overhead
5. **Plug-and-Play**: Automatic integration via Python script and library.json metadata
6. **Standard Components**: Use proven SPI slave cores from GitHub (e.g., Nandland, ZipCPU)

## Address Space Architecture

### Three-Tier Design

```
Tier 1 (Slot):     0x00_0000 - 0x00_1FFF (8KB)   - 32 slots × 256 bytes
Tier 2 (Extended): 0x00_2000 - 0x00_FFFF (56KB)  - On-chip BRAM
Tier 3 (Large):    0x01_0000 - 0xFF_FFFF (16MB)  - External DDR/SDRAM
```

### Slot Allocation

- **Slot 0**: System control & memory map (auto-generated)
- **Slots 1-31**: Auto-assigned peripherals (256 bytes each)

### Register Layout (Slot 0 - System Control)

```
0x00: DEVICE_ID_L     - System device ID (lower byte)
0x01: DEVICE_ID_H     - System device ID (upper byte)
0x02: VERSION         - Protocol version
0x03: SLOT_COUNT      - Total number of slots used
0x04: CAPABILITIES    - Feature flags (burst, DDR, etc.)
0x05-0x0F: Reserved

Memory Map (32 bytes per slot):
0x10: Slot 0 Device ID L
0x11: Slot 0 Device ID H
0x12: Slot 0 SPI Width
0x13: Slot 0 Flags
0x14-0x1F: Reserved

0x20: Slot 1 Device ID L
0x21: Slot 1 Device ID H
0x22: Slot 1 SPI Width
0x23: Slot 1 Flags
...
```

## Protocol Specification

### Command Byte Format

```
[7:RW] [6:5:MODE] [4:RSVD] [3:BURST] [2:0:MODE_DATA]

Bit 7:     R/W (0=Read, 1=Write)
Bits 6-5:  Mode select
           00 = Slot mode (3 bytes)
           01 = Extended mode (4 bytes)
           10 = Large mode (5 bytes)
           11 = Reserved
Bit 4:     Reserved (must be 0)
Bit 3:     Burst flag (0=Single, 1=Burst)
Bits 2-0:  Mode-specific data
```

### Transaction Formats

#### Tier 1: Slot Mode
**Single access (3 bytes + data):**
```
[CMD] [REG] [DATA0] [DATA1] [DATA2] [DATA3]

CMD:    [RW|00|0|SLOT[4:0]]
REG:    8-bit register offset (0-255)
DATA:   Variable width based on peripheral's SPI width
        - 8-bit:  1 byte
        - 16-bit: 2 bytes (MSB first)
        - 32-bit: 4 bytes (MSB first)
```

**Burst access:**
```
[CMD] [REG] [COUNT_H] [COUNT_L] [DATA...]

CMD:    [RW|00|1|SLOT[4:0]]  // Burst flag set
REG:    Starting register offset
COUNT:  16-bit count (number of 32-bit words, not bytes)
DATA:   COUNT × 4 bytes
        Auto-increment address for each word
```

#### Tier 2: Extended Mode
**Single access (4 bytes + data):**
```
[CMD] [ADDR_H] [ADDR_L] [DATA0-3]

CMD:    [RW|01|0|000]
ADDR:   16-bit address (0x2000-0xFFFF)
DATA:   Always 32-bit (4 bytes)
```

**Burst access:**
```
[CMD] [ADDR_H] [ADDR_L] [COUNT_H] [COUNT_L] [DATA...]

CMD:    [RW|01|1|000]
COUNT:  16-bit word count
DATA:   COUNT × 4 bytes
```

#### Tier 3: Large Mode
**Single access (5 bytes + data):**
```
[CMD] [ADDR[23:16]] [ADDR[15:8]] [ADDR[7:0]] [DATA0-3]

CMD:    [RW|10|0|000]
ADDR:   24-bit address (0x010000-0xFFFFFF)
DATA:   Always 32-bit (4 bytes)
```

**Burst access:**
```
[CMD] [ADDR[23:16]] [ADDR[15:8]] [ADDR[7:0]] [COUNT_H] [COUNT_L] [DATA...]

CMD:    [RW|10|1|000]
COUNT:  16-bit word count
DATA:   COUNT × 4 bytes
```

## System Architecture

### Block Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         ESP32                                │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  PapilioWishbone2 Library                            │   │
│  │  - Three-tier addressing API                         │   │
│  │  - Burst mode support                                │   │
│  │  - Device enumeration                                │   │
│  │  - DMA transfer support                              │   │
│  └─────────────────────────┬────────────────────────────┘   │
│                            │ SPI (8/16/32-bit variable)     │
└────────────────────────────┼────────────────────────────────┘
                             │
┌────────────────────────────┼────────────────────────────────┐
│                      FPGA  │                                 │
│  ┌──────────────────────────┴───────────────────────────┐   │
│  │  PWB2 SPI Bridge (GitHub SPI slave + protocol FSM)   │   │
│  │  - SPI clock domain crossing                         │   │
│  │  - Variable width support (8/16/32-bit)              │   │
│  │  - Three-tier address decode                         │   │
│  │  - Burst mode controller                             │   │
│  │  - Converts to 32-bit Wishbone                       │   │
│  └──────────────────────────┬───────────────────────────┘   │
│                             │ Wishbone 32-bit               │
│  ┌──────────────────────────┴───────────────────────────┐   │
│  │  PWB2 Interconnect                                    │   │
│  │  - Address decoding (slot/extended/large)            │   │
│  │  - One-to-many Wishbone crossbar                     │   │
│  │  - Memory map peripheral (Slot 0)                    │   │
│  └──────┬────────┬────────┬────────┬────────────────────┘   │
│         │        │        │        │                         │
│    ┌────┴───┐ ┌─┴────┐ ┌─┴────┐ ┌─┴────────┐               │
│    │ Slot 0 │ │Slot 1│ │Slot 2│ │Extended  │               │
│    │SysCtrl │ │RGB   │ │GPIO  │ │BRAM      │               │
│    │MemMap  │ │LED   │ │      │ │Controller│               │
│    └────────┘ └──────┘ └──────┘ └──────────┘               │
│         │                             │                      │
│    ┌────┴─────────────────────────────┴───────────┐         │
│    │ External DDR/SDRAM Controller (Large)        │         │
│    └───────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

### Component Descriptions

#### 1. PWB2 SPI Bridge
- **Purpose**: Convert variable-width SPI to 32-bit Wishbone
- **Implementation**: 
  - Use proven SPI slave core from GitHub (e.g., Nandland's SPI, ZipCPU's SPI slave)
  - Custom protocol FSM for three-tier addressing
  - Clock domain crossing with proper synchronization
  - Burst mode state machine
- **Features**:
  - Accepts 8/16/32-bit SPI transfers
  - Always outputs 32-bit Wishbone cycles
  - Handles byte alignment for sub-32-bit peripherals
  - Auto-increment for burst mode

#### 2. PWB2 Interconnect
- **Purpose**: Route Wishbone transactions to appropriate peripheral
- **Implementation**: Address decoder + multiplexer
- **Features**:
  - Decodes slot number (0-31)
  - Routes extended/large addresses to memory controllers
  - Combines ACK signals from all peripherals
  - Multiplexes data bus

#### 3. PWB2 Memory Map (Slot 0)
- **Purpose**: Provide device enumeration to ESP32
- **Implementation**: Read-only register bank
- **Features**:
  - System info registers (version, capabilities)
  - Per-slot info (device ID, SPI width, flags)
  - Auto-generated from library metadata

#### 4. Peripheral Slots (1-31)
- **Purpose**: User peripherals (RGB LED, GPIO, SID, etc.)
- **Implementation**: Standard 32-bit Wishbone slaves
- **Features**:
  - Each declares SPI transfer width in metadata
  - 256-byte address space per slot
  - Standard Wishbone interface

## Library Metadata Format

### library.json (PlatformIO)
```json
{
  "name": "papilio_wishbone_bus_2",
  "version": "2.0.0",
  "description": "32-bit Wishbone bus with three-tier addressing and burst mode",
  "keywords": ["wishbone", "fpga", "esp32", "pwb2"],
  "frameworks": "arduino",
  "platforms": "espressif32",
  "export": {
    "include": ["firmware/*", "hdl/*", "tools/*"]
  }
}
```

### wishbone_peripheral.json (Per Peripheral)
```json
{
  "name": "RGB LED",
  "module_name": "pwb2_rgb_led",
  "device_id": 0x4C45,
  "version": "1.0.0",
  "spi_transfer_bits": 32,
  "slots_required": 1,
  "features": ["read", "write"],
  "registers": [
    {"offset": 0, "name": "RED", "width": 8, "access": "RW"},
    {"offset": 1, "name": "GREEN", "width": 8, "access": "RW"},
    {"offset": 2, "name": "BLUE", "width": 8, "access": "RW"},
    {"offset": 3, "name": "BRIGHTNESS", "width": 8, "access": "RW"}
  ],
  "hdl_files": [
    "hdl/pwb2_rgb_led.v"
  ],
  "ports": [
    {"name": "rgb_out", "direction": "output", "width": 3, "connection": "rgb_led"}
  ]
}
```

## Python Generation Tool

### Tool: generate_pwb2_top.py

**Purpose**: Scan project libraries and auto-generate top.v

**Process**:
1. Read platformio.ini lib_deps
2. For each library, check for wishbone_peripheral.json
3. Collect metadata (device ID, SPI width, ports, etc.)
4. Auto-assign slot numbers (0 reserved, 1-31 auto)
5. Generate top.v with:
   - All peripheral instantiations
   - Wishbone interconnect
   - Memory map registers
   - Port declarations
6. Generate constants file (pwb2_config.vh)

**Features**:
- Automatic slot assignment
- Conflict detection (duplicate device IDs)
- Port mapping validation
- Memory map generation
- Error checking and validation

## Firmware API (ESP32/Arduino)

### Class: PapilioWishbone2

```cpp
class PapilioWishbone2 {
public:
    // Initialization
    bool begin(int spi_clock_mhz = 20);
    
    // Device enumeration
    bool enumerateDevices();
    void printDevices();
    uint8_t getSlotCount();
    uint16_t getDeviceId(uint8_t slot);
    uint8_t getSpiWidth(uint8_t slot);
    
    // Tier 1: Slot access (registers)
    bool writeSlot8(uint8_t slot, uint8_t reg, uint8_t data);
    bool writeSlot16(uint8_t slot, uint8_t reg, uint16_t data);
    bool writeSlot32(uint8_t slot, uint8_t reg, uint32_t data);
    uint8_t readSlot8(uint8_t slot, uint8_t reg);
    uint16_t readSlot16(uint8_t slot, uint8_t reg);
    uint32_t readSlot32(uint8_t slot, uint8_t reg);
    
    // Tier 1: Slot burst
    bool writeSlotBurst(uint8_t slot, uint8_t start_reg, 
                        const uint32_t* data, uint16_t word_count);
    bool readSlotBurst(uint8_t slot, uint8_t start_reg,
                       uint32_t* data, uint16_t word_count);
    
    // Tier 2: Extended (on-chip memory)
    bool writeExtended(uint16_t address, uint32_t data);
    uint32_t readExtended(uint16_t address);
    bool writeExtendedBurst(uint16_t start_addr,
                           const uint32_t* data, uint16_t word_count);
    bool readExtendedBurst(uint16_t start_addr,
                          uint32_t* data, uint16_t word_count);
    
    // Tier 3: Large (external DDR)
    bool writeLarge(uint32_t address, uint32_t data);
    uint32_t readLarge(uint32_t address);
    bool writeLargeBurst(uint32_t start_addr,
                        const uint32_t* data, uint16_t word_count);
    bool readLargeBurst(uint32_t start_addr,
                       uint32_t* data, uint16_t word_count);
};
```

## HDL Module Interfaces

### pwb2_spi_bridge.v
```verilog
module pwb2_spi_bridge #(
    parameter NUM_SLOTS = 32,
    parameter [5:0] SLOT_SPI_BITS [0:31] = '{default: 6'd8}
)(
    // System
    input wire clk,
    input wire rst,
    
    // SPI slave (from ESP32)
    input wire spi_sclk,
    input wire spi_mosi,
    output wire spi_miso,
    input wire spi_cs_n,
    
    // Wishbone master (to interconnect) - Always 32-bit
    output reg [23:0] wb_adr_o,
    output reg [31:0] wb_dat_o,
    input wire [31:0] wb_dat_i,
    output reg wb_cyc_o,
    output reg wb_stb_o,
    output reg wb_we_o,
    input wire wb_ack_i,
    
    // Status
    output reg [1:0] access_tier_o,
    output reg burst_mode_o,
    output reg [15:0] burst_count_o
);
```

### pwb2_interconnect.v
```verilog
module pwb2_interconnect #(
    parameter NUM_SLOTS = 32,
    parameter [15:0] DEVICE_IDS [0:31] = '{default: 16'h0000},
    parameter [5:0] SPI_WIDTHS [0:31] = '{default: 6'd8}
)(
    input wire clk,
    input wire rst,
    
    // Wishbone slave (from bridge)
    input wire [23:0] wb_adr_i,
    input wire [31:0] wb_dat_i,
    output reg [31:0] wb_dat_o,
    input wire wb_cyc_i,
    input wire wb_stb_i,
    input wire wb_we_i,
    output reg wb_ack_o,
    
    // Wishbone masters (to peripherals) - One per slot
    output wire [23:0] wb_adr_o [0:NUM_SLOTS-1],
    output wire [31:0] wb_dat_o_arr [0:NUM_SLOTS-1],
    input wire [31:0] wb_dat_i_arr [0:NUM_SLOTS-1],
    output wire [NUM_SLOTS-1:0] wb_stb_o,
    output wire wb_we_o,
    input wire [NUM_SLOTS-1:0] wb_ack_i
);
```

### Peripheral Template
```verilog
module pwb2_example_peripheral #(
    parameter SLOT_NUMBER = 1,
    parameter DEVICE_ID = 16'h0000
)(
    input wire clk,
    input wire rst,
    
    // Wishbone slave - Standard 32-bit
    input wire [7:0] wb_adr_i,      // Only lower 8 bits (256 bytes)
    input wire [31:0] wb_dat_i,     // Always 32-bit
    output reg [31:0] wb_dat_o,     // Always 32-bit
    input wire wb_stb_i,            // Strobe for this slot
    input wire wb_we_i,             // Write enable
    output reg wb_ack_i,            // Acknowledge
    
    // Peripheral-specific ports
    output wire [2:0] rgb_out
);
```

## Implementation Plan

### Phase 1: Core Infrastructure
1. ✅ Architecture document (this file)
2. Create directory structure
3. Set up library.json and metadata files
4. Create pwb2_pkg.vh with constants

### Phase 2: HDL Development
1. Integrate GitHub SPI slave core
2. Implement pwb2_spi_bridge.v
3. Implement pwb2_interconnect.v
4. Implement pwb2_memory_map.v
5. Create testbenches

### Phase 3: Firmware Development
1. Implement PapilioWishbone2 class
2. Add SPI transfer functions
3. Add enumeration support
4. Create examples

### Phase 4: Tooling
1. Implement generate_pwb2_top.py
2. Add validation and error checking
3. Create device ID registry
4. Add debug/visualization tools

### Phase 5: Documentation & Examples
1. Write integration guide
2. Create example peripheral (RGB LED)
3. Write peripheral creation guide
4. Add performance benchmarks

## Benefits Over Previous Libraries

### vs. Smart Slot Wishbone (SSW)
✅ 32-bit native Wishbone (vs 8-bit)
✅ Variable SPI widths per peripheral
✅ Automatic top-level generation
✅ Proven SPI core from GitHub
❌ More complex implementation

### vs. Papilio Wishbone Bus (PWB)
✅ Three-tier addressing (vs flat)
✅ Burst mode support
✅ Supports large external memory
✅ More efficient protocol
❌ Slightly more complex API

### Combined Benefits
✅ Best of both worlds
✅ Modern 32-bit architecture
✅ Efficient addressing
✅ Plug-and-play integration
✅ High performance burst transfers
✅ Scalable to large memory

## Next Steps

1. Review and approve architecture
2. Set up library structure
3. Begin HDL implementation
4. Create example peripheral
5. Test on hardware

## References

- [Wishbone B4 Specification](https://opencores.org/howto/wishbone)
- [Smart Slot Wishbone](../papilio_smart_slot_wishbone/README.md)
- [Papilio Wishbone Bus](../papilio_wishbone_bus/README.md)
- [Nandland SPI Core](https://github.com/nandland/spi-slave)
- [ZipCPU SPI Slave](https://github.com/ZipCPU/qspiflash)
