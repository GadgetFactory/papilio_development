# Makefile for papilio_arcade_template
# Targets:
#   make all         -> build firmware and gateware
#   make firmware    -> build firmware (PlatformIO)
#   make upload      -> build + upload firmware to MCU
#   make monitor     -> open serial monitor (COM4, 115200)
#   make clean       -> clean firmware build and remove gateware impl
#   make gateware    -> run Gowin build (synthesis + PNR)
#   make synth       -> alias for gateware
#   make flash-fpga  -> flash FPGA bitstream using pesptool

# Paths (override on command line if needed)
PIO ?= C:\\Users\\jackg\\.platformio\\penv\\Scripts\\platformio.exe
GW_SH ?= gw_sh.exe
PESPTOOL ?= C:\\Users\\jackg\\.espressif\\python_env\\idf5.5_py3.11_env\\Scripts\\pesptool.exe
GATEWARE_DIR := src/gateware
FPGA_BIN := $(GATEWARE_DIR)/impl/pnr/papilio_arcade_template.bin

.PHONY: all firmware upload monitor clean gateware synth flash-fpga

all: firmware gateware

firmware:
	"$(PIO)" run

upload: firmware
	"$(PIO)" run --target upload

monitor:
	"$(PIO)" device monitor --port COM4 --baud 115200

clean:
	"$(PIO)" run --target clean
	@powershell -NoProfile -Command "if (Test-Path '$(GATEWARE_DIR)\\impl') { Remove-Item -LiteralPath '$(GATEWARE_DIR)\\impl' -Recurse -Force }"

gateware:
	cd $(GATEWARE_DIR) && $(GW_SH) build.tcl

synth: gateware

flash-fpga: gateware
	"$(PESPTOOL)" $(FPGA_BIN)
