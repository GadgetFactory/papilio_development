# Timing constraints for Papilio Wishbone RGB Demo

# Main clock constraint (27 MHz)
create_clock -name clk -period 37.04 [get_ports {clk}]

# SPI clock from ESP32 (async, max ~20 MHz)
create_clock -name esp_sclk -period 50 [get_ports {esp_sclk}]
set_clock_groups -asynchronous -group [get_clocks {clk}] -group [get_clocks {esp_sclk}]