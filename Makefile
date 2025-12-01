# Makefile for papilio_arcade_template
# Targets:
#   make all         -> build firmware and gateware
#   make firmware    -> build firmware (PlatformIO)
#   make upload      -> build + upload firmware to MCU
#   make monitor     -> open serial monitor (COM4, 115200)
#   make clean       -> clean firmware build and remove gateware impl
#   make gateware    -> run Gowin build (synthesis + PNR)
#   make synth       -> alias for gateware
#   make flash-fpga  -> build gateware + flash FPGA bitstream
#   make upload-fpga -> flash FPGA bitstream only (no rebuild)
#   make install-platformio -> install/update PlatformIO via pip
#   make example EXAMPLE=<env> -> build PlatformIO environment (e.g. spaceinvaders_hdmi)
#   make example-upload EXAMPLE=<env> -> build + upload selected environment
#   make list-examples -> list available example environments
#   make papilio_arcade -> build main template
#   make papilio_arcade-upload -> build + upload main template

# Paths (override on command line if needed)
PIO ?= C:\\Users\\jackg\\.platformio\\penv\\Scripts\\platformio.exe
GW_SH ?= gw_sh.exe
PESPTOOL ?= C:\\Users\\jackg\\.espressif\\python_env\\idf5.5_py3.11_env\\Scripts\\pesptool.exe
GATEWARE_DIR := src/gateware
FPGA_BIN := $(GATEWARE_DIR)/impl/pnr/papilio_arcade_template.bin

.PHONY: all firmware upload monitor clean gateware synth flash-fpga upload-fpga
.PHONY: install-platformio example example-upload list-examples

all: firmware gateware

firmware:
	"$(PIO)" run -e papilio_arcade

upload: firmware
	"$(PIO)" run -e papilio_arcade --target upload

monitor:
	"$(PIO)" device monitor --port COM4 --baud 115200

clean:
	"$(PIO)" run --target clean
	@powershell -NoProfile -Command "if (Test-Path '$(GATEWARE_DIR)\\impl') { Remove-Item -LiteralPath '$(GATEWARE_DIR)\\impl' -Recurse -Force }"

gateware:
	cd $(GATEWARE_DIR) && $(GW_SH) build.tcl

synth: gateware

flash-fpga: gateware
	"$(PESPTOOL)" --port COM4 write-flash 0x100000 $(FPGA_BIN)

upload-fpga:
	"$(PESPTOOL)" --port COM4 write-flash 0x100000 $(FPGA_BIN)

# ------------------------------------------------------------------------------
# PlatformIO example support
# ------------------------------------------------------------------------------
# Define known example environments. Keep in sync with platformio.ini.
EXAMPLE_ENVS := text_mode_test spaceinvaders_hdmi mcp_debug_firmware

# Install / update PlatformIO (if 'pio' not in PATH, use explicit python -m pip)
install-platformio:
	python -m pip install -U platformio

# List available example environments
list-examples:
	@echo "Available example environments:" && for %e in ($(EXAMPLE_ENVS)) do @echo \t%e

# Build an example: make example EXAMPLE=spaceinvaders_hdmi
example:
	@if [ "$(EXAMPLE)" = "" ]; then echo "Specify EXAMPLE=<env>. Available: $(EXAMPLE_ENVS)"; exit 1; fi
	"$(PIO)" run -e $(EXAMPLE)

# Upload an example: make example-upload EXAMPLE=spaceinvaders_hdmi
example-upload:
	@if [ "$(EXAMPLE)" = "" ]; then echo "Specify EXAMPLE=<env>. Available: $(EXAMPLE_ENVS)"; exit 1; fi
	"$(PIO)" run -e $(EXAMPLE) --target upload

# Convenience shortcuts for each example (optional; allow tab completion)
text_mode_test: 
	"$(PIO)" run -e text_mode_test

text_mode_test-upload:
	"$(PIO)" run -e text_mode_test --target upload

spaceinvaders_hdmi:
	"$(PIO)" run -e spaceinvaders_hdmi

spaceinvaders_hdmi-upload:
	"$(PIO)" run -e spaceinvaders_hdmi --target upload

mcp_debug_firmware:
	"$(PIO)" run -e mcp_debug_firmware

mcp_debug_firmware-upload:
	"$(PIO)" run -e mcp_debug_firmware --target upload

papilio_arcade:
	"$(PIO)" run -e papilio_arcade

papilio_arcade-upload:
	"$(PIO)" run -e papilio_arcade --target upload
