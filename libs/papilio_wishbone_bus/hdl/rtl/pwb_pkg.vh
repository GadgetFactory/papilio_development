// pwb_pkg.vh - Papilio Wishbone Bus Package
// Protocol definitions and constants

`ifndef PWB_PKG_VH
`define PWB_PKG_VH

// =============================================================================
// Protocol Constants  
// =============================================================================

// Command byte structure: [7:RW] [6:5:MODE] [4:0:MODE_DATA]
`define PWB_CMD_READ        1'b0
`define PWB_CMD_WRITE       1'b1

`define PWB_MODE_SLOT       2'b00
`define PWB_MODE_EXTENDED   2'b01
`define PWB_MODE_LARGE      2'b10
`define PWB_MODE_RESERVED   2'b11

// Burst mode flag (in bit 3 of CMD byte)
`define PWB_BURST_FLAG      3

// Address space limits
`define PWB_SLOT_COUNT      32
`define PWB_SLOT_SIZE       256
`define PWB_SLOT_ADDR_BITS  13      // 8KB total (32 * 256)

// Wishbone bus width
`define PWB_DATA_WIDTH      32

// SPI transfer widths (in bits)
`define PWB_SPI_WIDTH_8     6'd8
`define PWB_SPI_WIDTH_16    6'd16
`define PWB_SPI_WIDTH_32    6'd32

// =============================================================================
// Device ID Registry
// =============================================================================

`define PWB_DEVID_SYSTEM    16'h5359  // "SY"stem
`define PWB_DEVID_RGB_LED   16'h4C45  // "LE"d
`define PWB_DEVID_GPIO      16'h4750  // "GP"io
`define PWB_DEVID_SID       16'h5349  // "SI"d
`define PWB_DEVID_YM2149    16'h594D  // "YM"2149
`define PWB_DEVID_VIDEO     16'h5649  // "VI"deo
`define PWB_DEVID_UART      16'h5541  // "UA"rt
`define PWB_DEVID_SPI       16'h5350  // "SP"i
`define PWB_DEVID_I2C       16'h4943  // "IC"
`define PWB_DEVID_PWM       16'h5057  // "PW"m
`define PWB_DEVID_EMPTY     16'hFFFF  // Empty slot

// =============================================================================
// Memory Map Registers (Slot 0)
// =============================================================================

`define PWB_REG_VERSION     8'h00   // Version register
`define PWB_REG_SLOT_COUNT  8'h01   // Number of slots
`define PWB_REG_CAPABILITIES 8'h02  // Capability flags  
`define PWB_REG_RESERVED    8'h03   // Reserved

// Device descriptors start at 0x08
// Each descriptor is 2x 32-bit words (8 bytes)
`define PWB_REG_DESC_BASE   8'h08

// Descriptor format:
// Word 0 [31:16]: Device ID
//        [15:8]:  SPI transfer bits (8, 16, or 32)
//        [7:0]:   Flags/reserved
// Word 1:        Reserved

// =============================================================================
// Helper Macros
// =============================================================================

// Extract fields from command byte
`define PWB_GET_MODE(cmd)   (cmd[6:5])
`define PWB_GET_RW(cmd)     (cmd[7])
`define PWB_GET_SLOT(cmd)   (cmd[4:0])
`define PWB_IS_BURST(cmd)   (cmd[`PWB_BURST_FLAG])

// Build command byte
`define PWB_BUILD_CMD(rw, mode, data) {rw, mode, data}

// Address construction for slot mode
`define PWB_SLOT_ADDR(slot, reg) {19'b0, slot[4:0], reg[7:0]}

// Padding helpers for 32-bit data
`define PWB_PAD_8(data)  {24'h000000, data[7:0]}
`define PWB_PAD_16(data) {16'h0000, data[15:0]}
`define PWB_PAD_24(data) {8'h00, data[23:0]}

`endif // PWB_PKG_VH
