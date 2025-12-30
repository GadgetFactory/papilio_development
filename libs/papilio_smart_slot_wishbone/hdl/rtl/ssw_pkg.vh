// ssw_pkg.vh - Smart Slot Wishbone Package
// Protocol definitions and constants

`ifndef SSW_PKG_VH
`define SSW_PKG_VH

// =============================================================================
// Protocol Constants
// =============================================================================

// Command byte structure: [7:RW] [6:5:MODE] [4:0:MODE_DATA]
`define SSW_CMD_READ        1'b0
`define SSW_CMD_WRITE       1'b1

`define SSW_MODE_SLOT       2'b00
`define SSW_MODE_EXTENDED   2'b01
`define SSW_MODE_LARGE      2'b10
`define SSW_MODE_RESERVED   2'b11

// Burst mode flag (in bit 3 of CMD byte)
`define SSW_BURST_FLAG      3

// Address space limits
`define SSW_SLOT_COUNT      32
`define SSW_SLOT_SIZE       256
`define SSW_SLOT_ADDR_BITS  13      // 8KB total (32 * 256)
`define SSW_EXT_ADDR_BITS   16      // 64KB
`define SSW_LARGE_ADDR_BITS 24      // 16MB

// Transaction sizes
`define SSW_SLOT_BYTES      3       // CMD + REG + DATA
`define SSW_EXT_BYTES       4       // CMD + ADDR_H + ADDR_L + DATA
`define SSW_LARGE_BYTES     5       // CMD + ADDR[23:16] + ADDR[15:8] + ADDR[7:0] + DATA
`define SSW_BURST_HDR       2       // COUNT_H + COUNT_L

// =============================================================================
// Device ID Registry
// =============================================================================

`define SSW_DEVID_SYSTEM    16'h5359  // "SY"stem
`define SSW_DEVID_RGB_LED   16'h4C45  // "LE"d
`define SSW_DEVID_SID       16'h5349  // "SI"d
`define SSW_DEVID_YM2149    16'h594D  // "YM"2149
`define SSW_DEVID_LOGIC_AN  16'h4C41  // "LA"nalyzer
`define SSW_DEVID_VIDEO     16'h5649  // "VI"deo
`define SSW_DEVID_AUDIO_MIX 16'h414D  // "AM"ixer
`define SSW_DEVID_GPIO      16'h4750  // "GP"io
`define SSW_DEVID_UART      16'h5541  // "UA"rt
`define SSW_DEVID_SPI       16'h5350  // "SP"i
`define SSW_DEVID_I2C       16'h4943  // "IC"
`define SSW_DEVID_PWM       16'h5057  // "PW"m
`define SSW_DEVID_TIMER     16'h544D  // "TM"er
`define SSW_DEVID_DMA       16'h444D  // "DM"a
`define SSW_DEVID_FRAMEBUF  16'h4642  // "FB"
`define SSW_DEVID_EMPTY     16'hFFFF  // Empty slot

// =============================================================================
// System Control Registers (Slot 0)
// =============================================================================

`define SSW_SYS_VERSION     8'h00   // Version register
`define SSW_SYS_CAPABILITIES 8'h01  // Capability flags
`define SSW_SYS_SLOT_COUNT  8'h02   // Number of populated slots
`define SSW_SYS_MEM_SIZE    8'h03   // Large memory size (in MB)

// Device enumeration area (one 16-bit ID per slot)
`define SSW_SYS_DEV_ID_BASE 8'h10   // 0x10-0x2F: Device IDs for slots 0-15
                                     // 0x30-0x4F: Device IDs for slots 16-31

// =============================================================================
// Helper Macros
// =============================================================================

// Extract mode from command byte
`define SSW_GET_MODE(cmd)   (cmd[6:5])
`define SSW_GET_RW(cmd)     (cmd[7])
`define SSW_GET_SLOT(cmd)   (cmd[4:0])
`define SSW_GET_BANK(cmd)   (cmd[4:0])
`define SSW_IS_BURST(cmd)   (cmd[`SSW_BURST_FLAG])

// Build command byte
`define SSW_BUILD_CMD(rw, mode, data) {rw, mode, data}

// Address construction for slot mode
`define SSW_SLOT_ADDR(slot, reg) {{(`SSW_LARGE_ADDR_BITS-`SSW_SLOT_ADDR_BITS){1'b0}}, \
                                   {3'b000, slot, reg}}

`endif // SSW_PKG_VH
