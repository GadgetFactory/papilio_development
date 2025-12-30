# Papilio Wishbone Bus

A modern Wishbone bus architecture for ESP32-to-FPGA communication with automatic peripheral integration.

## Features

- **32-bit Wishbone Bus**: Uniform interface for all peripherals
- **Variable SPI Width**: Peripherals declare 8, 16, or 32-bit SPI transfers
- **Memory Map**: Single-point enumeration of all peripherals
- **Automatic Integration**: Python script generates top-level from library.json files
- **Plug-and-Play**: Add peripherals by including their library

## Quick Start

### 1. Add to platformio.ini

```ini
[env:papilio]
platform = espressif32
board = esp32dev
framework = arduino

lib_deps =
    papilio_wishbone_bus
    papilio_wb_rgb_led
    papilio_wb_gpio

extra_scripts = 
    pre:libs/papilio_wishbone_bus/tools/generate_top.py
```

### 2. ESP32 Code

```cpp
#include <PapilioWishbone.h>

PapilioWishbone wb;

void setup() {
    wb.begin();
    wb.enumerateDevices();
    wb.printDevices();
    
    // Write to RGB LED
    wb.writeSlot(1, 0, 0xFF8040);
}
```

### 3. Build

The `generate_top.py` script automatically:
- Scans lib_deps for Wishbone peripherals
- Reads their library.json metadata
- Generates top.v with all peripherals wired
- Configures memory map

## Directory Structure

```
libs/papilio_wishbone_bus/
├── README.md
├── library.json          # PlatformIO library metadata
├── hdl/
│   ├── rtl/
│   │   ├── pwb_pkg.vh           # Protocol definitions
│   │   ├── pwb_spi_bridge.v     # SPI to Wishbone bridge
│   │   ├── pwb_memory_map.v     # Memory map peripheral
│   │   └── pwb_interconnect.v   # Wishbone interconnect
│   └── templates/
│       └── top_template.v       # Template for generation
├── firmware/
│   ├── arduino/
│   │   ├── library.properties
│   │   └── src/
│   │       ├── PapilioWishbone.h
│   │       └── PapilioWishbone.cpp
│   └── examples/
└── tools/
    ├── generate_top.py          # Automatic top-level generator
    └── device_registry.json     # Standard device IDs
```

## Creating Peripherals

See [Creating Peripherals Guide](docs/CREATING_PERIPHERALS.md)

## License

MIT License
