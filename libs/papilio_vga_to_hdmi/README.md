# Papilio VGA to HDMI Adapter Library

VGA to HDMI converter module for Papilio Arcade Board. This library provides pure gateware conversion from standard VGA RGB signals to HDMI TMDS differential outputs.

## Features

- **Direct VGA to HDMI Conversion** - No CPU intervention required
- **Standard VGA Input** - Accepts any VGA timing (hsync, vsync, RGB)
- **HDMI TMDS Output** - Full TMDS encoding with differential pairs
- **Flexible Timing** - Works with any VGA resolution/refresh rate
- **Clock Generation** - Integrated PLL for TMDS serial clock
- **Pure Gateware** - No firmware/API needed, just connect signals

## Supported Resolutions

The converter works with any VGA timing. Common configurations:

| Resolution | Refresh | Pixel Clock | Serial Clock | Notes |
|------------|---------|-------------|--------------|-------|
| 640x480 | 60Hz | 25.175 MHz | 125.875 MHz | Standard VGA |
| 800x600 | 72Hz | 50.000 MHz | 250.000 MHz | HQVGA uses this |
| 1024x768 | 60Hz | 65.000 MHz | 325.000 MHz | XGA |
| 1280x720 | 60Hz | 74.250 MHz | 371.250 MHz | 720p HDMI |

## Hardware Requirements

- **FPGA:** Gowin GW2A-18C or compatible
- **I/O Bank:** 1.8V for LVCMOS18D differential pairs
- **Resources:** ~500 LUTs, 1 PLL for serial clock
- **Input:** VGA signals (hsync, vsync, R[7:0], G[7:0], B[7:0])
- **Output:** HDMI TMDS differential pairs (CLK + 3 data channels)

## Gateware Integration

### Module Interface

```verilog
module vga_to_hdmi (
    // VGA inputs
    input wire clk_pixel,       // VGA pixel clock (e.g., 25MHz, 50MHz, 74.25MHz)
    input wire rst_n,           // Active low reset
    input wire vga_hsync,       // VGA horizontal sync
    input wire vga_vsync,       // VGA vertical sync
    input wire vga_de,          // VGA display enable (active video)
    input wire [7:0] vga_r,     // VGA red (8-bit)
    input wire [7:0] vga_g,     // VGA green (8-bit)
    input wire [7:0] vga_b,     // VGA blue (8-bit)
    
    // HDMI outputs
    output wire hdmi_clk_p,     // HDMI clock positive
    output wire hdmi_clk_n,     // HDMI clock negative
    output wire [2:0] hdmi_d_p, // HDMI data positive {r,g,b}
    output wire [2:0] hdmi_d_n  // HDMI data negative {r,g,b}
);
```

### Integration Example

```verilog
// In your top-level module
wire vga_hsync, vga_vsync, vga_de;
wire [7:0] vga_r, vga_g, vga_b;

// Your VGA source (e.g., HQVGA controller)
HQVGA my_vga (
    // ... wishbone interface ...
    .vga_hsync(vga_hsync),
    .vga_vsync(vga_vsync),
    .vga_r(vga_r),
    .vga_g(vga_g),
    .vga_b(vga_b)
    // ...
);

// VGA to HDMI converter
vga_to_hdmi adapter (
    .clk_pixel(vga_pixel_clk),  // Same clock as VGA source
    .rst_n(rst_n),
    .vga_hsync(vga_hsync),
    .vga_vsync(vga_vsync),
    .vga_de(vga_de),
    .vga_r(vga_r),
    .vga_g(vga_g),
    .vga_b(vga_b),
    .hdmi_clk_p(O_tmds_clk_p),
    .hdmi_clk_n(O_tmds_clk_n),
    .hdmi_d_p(O_tmds_data_p),
    .hdmi_d_n(O_tmds_data_n)
);
```

### Required Files

Add to your `.gprj` project:

```xml
<File path="libs/papilio_vga_to_hdmi/gateware/src/vga_to_hdmi.v" type="file.verilog" enable="1"/>
<File path="libs/papilio_vga_to_hdmi/gateware/src/tmds_encoder.v" type="file.verilog" enable="1"/>
<File path="libs/papilio_vga_to_hdmi/gateware/src/tmds_serializer.v" type="file.verilog" enable="1"/>
<!-- Add PLL module if needed for your clock frequency -->
```

### Pin Constraints

Add to `pins.cst`:

```tcl
// HDMI TMDS differential outputs
IO_LOC "hdmi_clk_p" H11,G11;
IO_PORT "hdmi_clk_p" IO_TYPE=LVCMOS18D PULL_MODE=NONE DRIVE=8;

IO_LOC "hdmi_d_p[0]" F15,E15;  // Blue
IO_PORT "hdmi_d_p[0]" IO_TYPE=LVCMOS18D PULL_MODE=NONE DRIVE=8;

IO_LOC "hdmi_d_p[1]" J16,J15;  // Green
IO_PORT "hdmi_d_p[1]" IO_TYPE=LVCMOS18D PULL_MODE=NONE DRIVE=8;

IO_LOC "hdmi_d_p[2]" L16,K16;  // Red
IO_PORT "hdmi_d_p[2]" IO_TYPE=LVCMOS18D PULL_MODE=NONE DRIVE=8;
```

## Architecture

```
VGA Source → VGA to HDMI Adapter → HDMI Display
             ┌─────────────────┐
VGA RGB ────→│ TMDS Encoders   │
Hsync   ────→│ (3 channels)    │──→ HDMI TMDS
Vsync   ────→│                 │    differential
Pixel Clk ──→│ PLL (×5)        │    outputs
             │ Serializer      │
             └─────────────────┘
```

**Signal Flow:**
1. VGA RGB signals enter with hsync/vsync timing
2. TMDS encoders convert 8-bit RGB to 10-bit TMDS codes
3. PLL generates 5× serial clock from pixel clock
4. Serializers convert parallel TMDS to high-speed serial
5. Differential outputs drive HDMI cable

**Clock Domains:**
- Pixel clock: From VGA source (25-75 MHz typical)
- Serial clock: 5× pixel clock (from internal PLL)

## Display Enable (DE) Signal

If your VGA source doesn't provide a `vga_de` signal, you can generate it:

```verilog
// Generate DE from hsync/vsync timing counters
reg [10:0] h_count, v_count;
wire vga_de = (h_count < H_ACTIVE) && (v_count < V_ACTIVE);
```

Or tie it high if using embedded sync in hsync/vsync.

## Usage with HQVGA Library

The HQVGA library outputs 800x600@72Hz VGA. Connect directly:

```verilog
// HQVGA provides 50MHz pixel clock
wire clk_50mhz;
wire vga_hs, vga_vs;
wire [2:0] vga_r_3bit, vga_g_3bit;
wire [1:0] vga_b_2bit;

// Expand to 8-bit RGB for HDMI
wire [7:0] hdmi_r = {vga_r_3bit, vga_r_3bit, vga_r_3bit[2:1]};
wire [7:0] hdmi_g = {vga_g_3bit, vga_g_3bit, vga_g_3bit[2:1]};
wire [7:0] hdmi_b = {vga_b_2bit, vga_b_2bit, vga_b_2bit, vga_b_2bit};

// Generate display enable
wire vga_de = /* your logic based on H/V counters */;

vga_to_hdmi adapter (
    .clk_pixel(clk_50mhz),
    .vga_r(hdmi_r), .vga_g(hdmi_g), .vga_b(hdmi_b),
    .vga_hsync(vga_hs), .vga_vsync(vga_vs), .vga_de(vga_de),
    // ... HDMI outputs
);
```

## Technical Details

### TMDS Encoding

- 8-bit RGB data → 10-bit TMDS codes
- DC balance maintained for reliable transmission
- Control codes for hsync/vsync during blanking
- Transition minimization for EMI reduction

### Serialization

- 10:1 serialization (10 bits per pixel clock)
- Requires 5× serial clock (TMDS specification)
- DDR output for differential signaling
- Gowin OSER10 or compatible primitives

### PLL Requirements

The adapter needs a PLL to generate the TMDS serial clock (5× pixel clock):

| Input Clock | Output Clock | Multiplier |
|-------------|--------------|------------|
| 25 MHz | 125 MHz | ×5 |
| 50 MHz | 250 MHz | ×5 |
| 74.25 MHz | 371.25 MHz | ×5 |

## Limitations

- **No Audio:** Video only (DVI-D compatible)
- **No EDID:** Display auto-detection not supported
- **No HDCP:** No content protection
- **Sync Type:** External sync only (separate hsync/vsync)

## Troubleshooting

**No display:**
- Check VGA input timing is valid
- Verify PLL locks and generates 5× clock
- Check HDMI cable connection
- Ensure LVCMOS18D I/O standard is supported

**Color issues:**
- Verify RGB bit ordering (MSB first)
- Check display enable (DE) timing
- Confirm RGB expansion from 3-bit to 8-bit

**Timing problems:**
- Use timing analyzer to verify setup/hold
- Check clock domain crossings
- Verify PLL frequency matches VGA pixel clock

## References

- [DVI 1.0 Specification](http://www.ddwg.org/)
- [HDMI Specification](https://www.hdmi.org/)
- [TMDS Encoding](https://en.wikipedia.org/wiki/Transition-minimized_differential_signaling)
- [VGA Timing Calculator](http://tinyvga.com/vga-timing)

## License

BSD-2-Clause (see repository LICENSE file)

## Support

- GitHub Issues: https://github.com/GadgetFactory/DesignLab_Examples
- Forums: http://www.gadgetfactory.net/forum
- Email: support@gadgetfactory.net
