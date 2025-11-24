# Papilio Development Environment

Full-featured development repository for Papilio Arcade board with FPGA and ESP32-S3.

## Structure

- **src/**: Firmware and gateware source files
  - **papliio_arcade_template.ino**: ESP32-S3 firmware
  - **gateware/**: FPGA HDL source files
- **libs/**: Wishbone peripheral libraries (as git submodules)
  - **papilio_hdmi/**: HDMI controller with text mode support
- **docs/**: Documentation and integration guides

## Features

- 720p@60Hz HDMI output
- Text mode: 80x26 characters (16x16 pixel characters)
- Wishbone bus interface for peripheral integration
- Professional demo display with system information

## Building

### FPGA Gateware
```bash
make flash-fpga
```

### ESP32 Firmware
```bash
make upload
```

## Development Workflow

This repository includes all Wishbone libraries as submodules for active development. 

For testing individual library integration, see [papilio_arcade_template](https://github.com/GadgetFactory/papilio_arcade_template).

## Submodules

Clone with submodules:
```bash
git clone --recurse-submodules https://github.com/GadgetFactory/papilio_development.git
```

Update submodules:
```bash
git submodule update --remote
```

## Hardware

- **FPGA**: Gowin GW2A-LV18PG256C8/I7
- **MCU**: ESP32-S3 WROOM-1
- **Video**: HDMI output via TMDS
- **Interface**: Wishbone bus between ESP32 and FPGA

## License

See individual library repositories for licensing information.
