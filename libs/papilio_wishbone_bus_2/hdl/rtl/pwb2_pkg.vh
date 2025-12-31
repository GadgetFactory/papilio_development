// pwb2_pkg.vh - Papilio Wishbone Bus 2 Package
// Protocol constants, macros, and definitions

`ifndef PWB2_PKG_VH
`define PWB2_PKG_VH

// =============================================================================
// Protocol Version
// =============================================================================
`define PWB2_VERSION 8'h20  // Version 2.0

// =============================================================================
// Command Byte Format
// =============================================================================
// [7:RW] [6:5:MODE] [4:RSVD] [3:BURST] [2:0:MODE_DATA]

// Bit positions
`define PWB2_CMD_RW_BIT     7
`define PWB2_CMD_MODE_MSB   6
`define PWB2_CMD_MODE_LSB   5
`define PWB2_CMD_BURST_BIT  3

// Mode values
`define PWB2_MODE_SLOT      2'b00
`define PWB2_MODE_EXTENDED  2'b01
`define PWB2_MODE_LARGE     2'b10
`define PWB2_MODE_RESERVED  2'b11

// Access types
`define PWB2_ACCESS_READ    1'b0
`define PWB2_ACCESS_WRITE   1'b1

// =============================================================================
// Address Space
// =============================================================================
`define PWB2_SLOT_SIZE      8'd256      // 256 bytes per slot
`define PWB2_NUM_SLOTS      5'd32       // 32 slots (0-31)
`define PWB2_SLOT_BITS      5           // 5 bits for slot number

// Address ranges
`define PWB2_ADDR_SLOT_START    24'h000000
`define PWB2_ADDR_SLOT_END      24'h001FFF  // 8KB
`define PWB2_ADDR_EXT_START     24'h002000
`define PWB2_ADDR_EXT_END       24'h00FFFF  // 56KB
`define PWB2_ADDR_LARGE_START   24'h010000
`define PWB2_ADDR_LARGE_END     24'hFFFFFF  // 16MB

// =============================================================================
// SPI Transfer Widths
// =============================================================================
`define PWB2_SPI_WIDTH_8    6'd8
`define PWB2_SPI_WIDTH_16   6'd16
`define PWB2_SPI_WIDTH_32   6'd32

// =============================================================================
// System Control (Slot 0) Register Map
// =============================================================================
`define PWB2_REG_DEVICE_ID_L    8'h00
`define PWB2_REG_DEVICE_ID_H    8'h01
`define PWB2_REG_VERSION        8'h02
`define PWB2_REG_SLOT_COUNT     8'h03
`define PWB2_REG_CAPABILITIES   8'h04
`define PWB2_REG_STATUS         8'h05

// Capability flags
`define PWB2_CAP_BURST          0
`define PWB2_CAP_EXTENDED       1
`define PWB2_CAP_LARGE          2
`define PWB2_CAP_DMA            3

// Memory map starts at 0x10 (16 bytes per slot)
`define PWB2_MEMMAP_START       8'h10
`define PWB2_MEMMAP_SLOT_SIZE   4'd16

// Per-slot memory map offsets (from MEMMAP_START + slot*16)
`define PWB2_MEMMAP_DEVID_L     4'd0
`define PWB2_MEMMAP_DEVID_H     4'd1
`define PWB2_MEMMAP_SPI_WIDTH   4'd2
`define PWB2_MEMMAP_FLAGS       4'd3

// =============================================================================
// Standard Device IDs
// =============================================================================
`define PWB2_DEVID_SYSTEM       16'h5359  // 'SY' - System control
`define PWB2_DEVID_RGB_LED      16'h4C45  // 'LE' - LED
`define PWB2_DEVID_GPIO         16'h4750  // 'GP' - GPIO
`define PWB2_DEVID_SID          16'h5349  // 'SI' - SID audio
`define PWB2_DEVID_YM2149       16'h594D  // 'YM' - YM2149 audio
`define PWB2_DEVID_POKEY        16'h504B  // 'PK' - POKEY audio
`define PWB2_DEVID_HDMI         16'h4844  // 'HD' - HDMI
`define PWB2_DEVID_FRAMEBUF     16'h4642  // 'FB' - Framebuffer
`define PWB2_DEVID_SPI_MASTER   16'h5350  // 'SP' - SPI master
`define PWB2_DEVID_I2C_MASTER   16'h4932  // 'I2' - I2C master
`define PWB2_DEVID_UART         16'h5541  // 'UA' - UART
`define PWB2_DEVID_TIMER        16'h544D  // 'TM' - Timer
`define PWB2_DEVID_PWM          16'h5057  // 'PW' - PWM
`define PWB2_DEVID_EMPTY        16'h0000  // Empty slot

// =============================================================================
// Helper Macros
// =============================================================================

// Extract fields from command byte
`define PWB2_GET_RW(cmd)        cmd[`PWB2_CMD_RW_BIT]
`define PWB2_GET_MODE(cmd)      cmd[`PWB2_CMD_MODE_MSB:`PWB2_CMD_MODE_LSB]
`define PWB2_GET_BURST(cmd)     cmd[`PWB2_CMD_BURST_BIT]
`define PWB2_GET_SLOT(cmd)      cmd[4:0]

// Build command byte
`define PWB2_BUILD_CMD(rw, mode, burst, data) \
    {rw, mode, 1'b0, burst, data[2:0]}

// Check if address is in range
`define PWB2_IS_SLOT(addr)      (addr < `PWB2_ADDR_EXT_START)
`define PWB2_IS_EXTENDED(addr)  ((addr >= `PWB2_ADDR_EXT_START) && (addr < `PWB2_ADDR_LARGE_START))
`define PWB2_IS_LARGE(addr)     (addr >= `PWB2_ADDR_LARGE_START)

// Extract slot number from address
`define PWB2_ADDR_TO_SLOT(addr) addr[12:8]

// =============================================================================
// Timing Parameters (for testbench)
// =============================================================================
`define PWB2_SPI_HALF_PERIOD    10  // 50 MHz SPI clock (adjust as needed)
`define PWB2_WB_TIMEOUT         1000 // Wishbone timeout cycles

`endif // PWB2_PKG_VH
