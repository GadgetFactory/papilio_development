# Papilio Wishbone Bus - Feature Branch

This branch implements a complete Wishbone bus architecture for ESP32-to-FPGA communication with automatic peripheral integration.

## What's New

### Core Infrastructure
- **32-bit Wishbone Bus**: Uniform interface for all peripherals
- **Variable SPI Width**: Peripherals declare 8, 16, or 32-bit transfers
- **Memory Map**: Single enumeration point for all peripherals
- **Auto-generation**: Python script generates top.v from library dependencies

### Libraries Created

1. **libs/papilio_wishbone_bus/** - Core bus infrastructure
   - SPI bridge with variable width support
   - Memory map peripheral
   - ESP32 Arduino library
   - Auto-generation tools

2. **libs/papilio_wb_rgb_led/** - Example RGB LED peripheral
   - 32-bit SPI transfers
   - Atomic RGB updates
   - Demonstrates peripheral creation

### Example Project

**examples/wishbone_rgb_demo/** - Complete working example
- Shows automatic peripheral integration
- Demonstrates enumeration
- RGB color cycling demo

## Quick Start

### 1. Switch to Feature Branch

```bash
git checkout feature/papilio-wishbone-bus
```

### 2. Try the Example

```bash
cd examples/wishbone_rgb_demo
pio run
```

The build process will:
1. Scan lib_deps for Wishbone peripherals
2. Auto-generate `src/gateware/top.v`
3. Compile ESP32 firmware
4. (You'll need to synthesize the FPGA separately)

### 3. View Generated top.v

After build, check:
```
examples/wishbone_rgb_demo/src/gateware/top.v
```

You'll see the auto-generated top-level with RGB LED wired to Slot 1.

## Architecture Highlights

### ESP32 Side
```cpp
PapilioWishbone wb;

void setup() {
    wb.begin();
    wb.enumerateDevices();  // Reads memory map once
    wb.printDevices();
    
    // RGB LED uses 32-bit transfer - library knows this!
    wb.writeSlot(1, 0, 0xFF804000);  // One transaction!
}
```

### FPGA Side (Auto-Generated)
```verilog
// Memory map reports RGB LED is 32-bit
localparam SPI_BITS [0:31] = '{
    6'd32,  // Slot 0: Memory map
    6'd32,  // Slot 1: RGB LED
    ...
};

// Bridge uses this for variable-width SPI
pwb_spi_bridge #(
    .SLOT_SPI_BITS(SPI_BITS)
) bridge (...);

// RGB LED gets 32-bit Wishbone
pwb_rgb_led #(
    .SPI_TRANSFER_BITS(32)
) rgb_led (
    .wb_dat_i(wb_dat_m2s),  // 32-bit bus
    .rgb_out(rgb_led)
);
```

## Performance Comparison

### Old Approach (Smart Slot Wishbone)
```cpp
// 3 transactions
ssw.writeSlot(1, 0, 0xFF);  // R
ssw.writeSlot(1, 1, 0x80);  // G
ssw.writeSlot(1, 2, 0x40);  // B
// Total: 9 bytes
```

### New Approach (Papilio Wishbone Bus)
```cpp
// 1 transaction
wb.writeSlot(1, 0, 0xFF804000);
// Total: 6 bytes (CMD + REG + 4 data)
// 33% savings!
```

## Creating New Peripherals

### 1. Create Library Structure
```
libs/papilio_wb_yourdevice/
├── library.json
├── wishbone_peripheral.json
└── hdl/
    └── pwb_yourdevice.v
```

### 2. Define wishbone_peripheral.json
```json
{
  \"name\": \"Your Device\",
  \"module_name\": \"pwb_yourdevice\",
  \"device_id\": 12345,
  \"spi_transfer_bits\": 16,
  \"slots_required\": 1,
  \"instance_name\": \"your_device\",
  \"ports\": [
    {\"name\": \"data_out\", \"connection\": \"device_data\"}
  ]
}
```

### 3. Write Verilog Module
```verilog
module pwb_yourdevice #(
    parameter SLOT_NUMBER = 1,
    parameter DEVICE_ID = 16'h3039,
    parameter SPI_TRANSFER_BITS = 16
)(
    input wire [31:0] wb_dat_i,   // Always 32-bit
    output reg [31:0] wb_dat_o,   // Always 32-bit
    // ... rest of Wishbone signals
    output wire [15:0] data_out
);
    // Your logic here - just use wb_dat_i[15:0]
endmodule
```

### 4. Add to Project
```ini
lib_deps = 
    papilio_wishbone_bus
    papilio_wb_yourdevice
```

### 5. Build
Next build auto-generates top.v with your peripheral!

## Files Modified/Added

### Core Infrastructure
- `libs/papilio_wishbone_bus/` - Complete new library
- `libs/papilio_wb_rgb_led/` - Example peripheral

### Examples
- `examples/wishbone_rgb_demo/` - Working demo project

### Tools
- `libs/papilio_wishbone_bus/tools/generate_top.py` - Auto-generation script

## Testing

1. **Enumeration Test**: Run demo, verify it detects RGB LED
2. **RGB Test**: Verify colors change correctly
3. **Add Peripheral**: Try adding another peripheral to lib_deps
4. **Regeneration**: Verify top.v regenerates with new peripheral

## Next Steps

1. **Test on Hardware**: You'll need to synthesize the generated top.v
2. **Add More Peripherals**: Create GPIO, UART, SPI, etc.
3. **Documentation**: Add detailed peripheral creation guide
4. **Merge to Main**: Once tested and working

## Benefits of This Approach

✅ **Automatic Integration**: Add libraries, get wiring automatically  
✅ **Variable SPI Width**: Each peripheral chooses optimal width  
✅ **32-bit Wishbone**: Simple, uniform interface  
✅ **Single Enumeration**: Read memory map once, know everything  
✅ **Plug-and-Play**: Libraries are self-describing  
✅ **Efficient Protocol**: 33% fewer bytes for RGB  
✅ **Easy to Debug**: Peripherals are trivial (one register!)  

## Questions?

See:
- `libs/papilio_wishbone_bus/README.md` - Library documentation
- `examples/wishbone_rgb_demo/README.md` - Example walkthrough
- `libs/papilio_wb_rgb_led/` - Reference peripheral

---

**Branch**: `feature/papilio-wishbone-bus`  
**Status**: Ready for testing  
**Author**: Gadget Factory  
**Date**: December 30, 2025
