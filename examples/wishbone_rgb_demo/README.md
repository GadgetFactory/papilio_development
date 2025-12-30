# Wishbone RGB Demo

Demonstrates the Papilio Wishbone Bus with automatic peripheral integration.

## Features Demonstrated

- Automatic enumeration of peripherals
- Variable SPI width (32-bit for RGB LED)
- Single transaction RGB updates (atomic)
- Auto-generated top.v from library dependencies

## How It Works

1. **PlatformIO reads platformio.ini** and sees dependencies:
   - `papilio_wishbone_bus` (core bus infrastructure)
   - `papilio_wb_rgb_led` (RGB LED peripheral)

2. **generate_top.py runs** as pre-build script:
   - Scans lib_deps for Wishbone peripherals
   - Reads `wishbone_peripheral.json` from each
   - Generates `src/gateware/top.v` automatically

3. **FPGA synthesis** includes generated top.v:
   - Memory map configured for 2 slots (System + RGB)
   - Bridge configured for 32-bit SPI to RGB LED
   - All wiring done automatically

4. **ESP32 code** uses the bus:
   - Enumerates devices
   - Sees RGB LED is 32-bit SPI
   - Sends colors in single transaction

## Building

```bash
cd examples/wishbone_rgb_demo
pio run
```

## Output

The `generate_top.py` script will create:

```
src/gateware/top.v
```

With contents showing the RGB LED peripheral wired to Slot 1.

## Adding More Peripherals

Just add to `lib_deps` in platformio.ini:

```ini
lib_deps = 
    papilio_wishbone_bus
    papilio_wb_rgb_led
    papilio_wb_gpio      # Add GPIO
    papilio_wb_uart      # Add UART
```

The next build will automatically regenerate top.v with all peripherals!
