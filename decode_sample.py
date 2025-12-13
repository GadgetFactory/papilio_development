#!/usr/bin/env python3
"""
Decode the captured samples to see what signals are active
"""

# Sample value we're seeing
sample = 0x20202020

print("Decoding sample value: 0x{:08X} = 0b{:032b}\n".format(sample, sample))

# From top.v la_probe_signals definition:
signals = [
    # [0:7] - bits 0-7
    "wb_cyc", "wb_stb", "wb_we", "wb_ack", "wb_adr[15]", "wb_adr[14]", "wb_adr[13]", "wb_adr[12]",
    # [8:11] - bits 8-11
    "esp_cs_n", "esp_clk", "esp_mosi", "esp_miso",
    # [12:15] - bits 12-15
    "video_mode[1]", "video_mode[0]", "hdmi_rst_n", "pix_clk",
    # [16:31] - bits 16-31
    "clk_27mhz", "rst", "rgb_led", "audio_left",
    "sid_selected", "ym2149_selected", "la_selected", "rgb_led_selected",
    "mode_ctrl_sel", "tp_sel", "text_sel", "fb_sel",
    "bit28", "bit29", "bit30", "bit31"
]

print("Active signals:")
for i in range(32):
    if (sample >> i) & 1:
        print(f"  Bit {i:2d}: {signals[i]}")

print("\nSignals by group:")
print(f"  Wishbone: CYC={(sample>>0)&1} STB={(sample>>1)&1} WE={(sample>>2)&1} ACK={(sample>>3)&1}")
print(f"  WB Address[15:12]: 0x{(sample>>4)&0xF:X}")
print(f"  SPI: CS_N={(sample>>8)&1} CLK={(sample>>9)&1} MOSI={(sample>>10)&1} MISO={(sample>>11)&1}")
print(f"  System: CLK_27MHz={(sample>>16)&1}")
