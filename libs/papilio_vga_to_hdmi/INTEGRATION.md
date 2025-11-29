# VGA to HDMI Adapter - Integration Guide

Complete guide for integrating the VGA to HDMI adapter into your Papilio Arcade project.

## Quick Start

This adapter converts any VGA signal to HDMI. No CPU/firmware needed - pure gateware.

### Basic Integration Steps

1. Add gateware files to project
2. Instantiate vga_to_hdmi module
3. Connect VGA source signals
4. Generate PLL for your pixel clock frequency
5. Add HDMI pin constraints
6. Build and test

## Gateware Integration

### Required Files

Add to your `.gprj` project:

```xml
<File path="libs/papilio_vga_to_hdmi/gateware/src/vga_to_hdmi.v" type="file.verilog" enable="1"/>
<File path="libs/papilio_vga_to_hdmi/gateware/src/tmds_encoder.v" type="file.verilog" enable="1"/>
<File path="libs/papilio_vga_to_hdmi/gateware/src/tmds_serializer.v" type="file.verilog" enable="1"/>
<File path="libs/papilio_vga_to_hdmi/gateware/src/tmds_pll.v" type="file.verilog" enable="1"/>
<!-- Add your generated PLL module (e.g., rPLL_50_250.v) -->
```

### Module Instantiation

```verilog
module top (
    input wire clk_27mhz,
    input wire rst_n,
    // ... other signals ...
    
    // HDMI outputs
    output wire O_tmds_clk_p,
    output wire O_tmds_clk_n,
    output wire [2:0] O_tmds_data_p,
    output wire [2:0] O_tmds_data_n
);

    // Your VGA source signals
    wire vga_pixel_clk;  // e.g., 50MHz for HQVGA
    wire vga_hsync, vga_vsync, vga_de;
    wire [7:0] vga_r, vga_g, vga_b;
    
    // ... your VGA source module here (HQVGA, etc.) ...
    
    // VGA to HDMI adapter
    vga_to_hdmi u_vga_hdmi (
        .clk_pixel(vga_pixel_clk),
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

endmodule
```

## PLL Generation

The adapter requires a PLL to generate the TMDS serial clock (5× pixel clock).

### Using Gowin IP Core Generator

1. Open Gowin IDE
2. Tools → IP Core Generator
3. Select "PLL" (rPLL)
4. Configure:
   - Input frequency: Your VGA pixel clock
   - Output frequency: 5× input (for TMDS serialization)
   - Output name: e.g., `clkout`
5. Generate IP core
6. Add generated `.v` file to your project
7. Update `tmds_pll.v` to instantiate your PLL

### Common PLL Configurations

**For HQVGA (50MHz pixel clock):**
```verilog
// Input: 50MHz, Output: 250MHz
rPLL #(
    .FCLKIN("50"),
    .IDIV_SEL(1),      // 50MHz / 2 = 25MHz
    .FBDIV_SEL(19),    // 25MHz * 20 = 500MHz
    .ODIV_SEL(2)       // 500MHz / 2 = 250MHz
) u_pll (
    .CLKIN(clkin),
    .CLKOUT(clkout),
    .LOCK(lock)
);
```

**For VGA (25MHz pixel clock):**
```verilog
// Input: 25MHz, Output: 125MHz
// Use IP generator for exact parameters
```

**For 720p HDMI (74.25MHz pixel clock):**
```verilog
// Input: 74.25MHz, Output: 371.25MHz
// Use IP generator for exact parameters
```

## Pin Constraints

Add to `pins.cst`:

```tcl
# HDMI TMDS outputs (adjust pin numbers for your board)
IO_LOC "O_tmds_clk_p" H11,G11;
IO_PORT "O_tmds_clk_p" IO_TYPE=LVCMOS18D PULL_MODE=NONE DRIVE=8;

IO_LOC "O_tmds_data_p[0]" F15,E15;  # Blue channel
IO_PORT "O_tmds_data_p[0]" IO_TYPE=LVCMOS18D PULL_MODE=NONE DRIVE=8;

IO_LOC "O_tmds_data_p[1]" J16,J15;  # Green channel
IO_PORT "O_tmds_data_p[1]" IO_TYPE=LVCMOS18D PULL_MODE=NONE DRIVE=8;

IO_LOC "O_tmds_data_p[2]" L16,K16;  # Red channel
IO_PORT "O_tmds_data_p[2]" IO_TYPE=LVCMOS18D PULL_MODE=NONE DRIVE=8;
```

**Note:** 
- Use `LVCMOS18D` for differential output
- Ensure I/O bank voltage is 1.8V
- Check your board schematic for actual pin assignments

## Integration with HQVGA

Special considerations when connecting HQVGA library:

### 1. Generate Display Enable (DE)

HQVGA provides hsync/vsync but not DE. Generate it:

```verilog
// HQVGA timing: 800x600@72Hz
localparam H_ACTIVE = 800;
localparam V_ACTIVE = 600;

reg [10:0] h_counter, v_counter;
wire vga_de = (h_counter < H_ACTIVE) && (v_counter < V_ACTIVE);

// Increment counters based on hsync/vsync edges
// ... counter logic ...
```

### 2. Expand RGB from 3/2-bit to 8-bit

HQVGA uses RGB332 format. Expand to 8-bit:

```verilog
// HQVGA outputs
wire [2:0] hqvga_r, hqvga_g;
wire [1:0] hqvga_b;

// Expand to 8-bit for HDMI
wire [7:0] hdmi_r = {hqvga_r, hqvga_r, hqvga_r[2:1]};
wire [7:0] hdmi_g = {hqvga_g, hqvga_g, hqvga_g[2:1]};
wire [7:0] hdmi_b = {hqvga_b, hqvga_b, hqvga_b, hqvga_b};
```

### 3. Complete Example

```verilog
module top (
    input wire clk_27mhz,
    input wire rst_n,
    
    // Wishbone for HQVGA control
    // ... wishbone signals ...
    
    // HDMI output
    output wire O_tmds_clk_p,
    output wire O_tmds_clk_n,
    output wire [2:0] O_tmds_data_p,
    output wire [2:0] O_tmds_data_n
);

    // Generate 50MHz for HQVGA
    wire clk_50mhz;
    wire pll_lock;
    
    rPLL_27_50 u_vga_pll (
        .clkin(clk_27mhz),
        .clkout(clk_50mhz),
        .lock(pll_lock)
    );
    
    // HQVGA controller
    wire vga_hs, vga_vs;
    wire [2:0] vga_r3, vga_g3;
    wire [1:0] vga_b2;
    
    HQVGA u_hqvga (
        // Wishbone interface
        .wishbone_in(wb_in),
        .wishbone_out(wb_out),
        // VGA outputs
        .vga_hsync(vga_hs),
        .vga_vsync(vga_vs),
        .vga_r2(vga_r3[2]),
        .vga_r1(vga_r3[1]),
        .vga_r0(vga_r3[0]),
        .vga_g2(vga_g3[2]),
        .vga_g1(vga_g3[1]),
        .vga_g0(vga_g3[0]),
        .vga_b1(vga_b2[1]),
        .vga_b0(vga_b2[0]),
        // Clock
        .clk_50Mhz(clk_50mhz),
        .wb_clk_i(clk_27mhz),
        .wb_rst_i(!rst_n)
    );
    
    // Generate display enable from timing counters
    reg [10:0] h_count, v_count;
    wire vga_de = (h_count < 800) && (v_count < 600);
    
    always @(posedge clk_50mhz) begin
        if (!rst_n) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            // Increment on hsync edges
            // TODO: Add proper hsync/vsync counter logic
        end
    end
    
    // Expand RGB to 8-bit
    wire [7:0] vga_r = {vga_r3, vga_r3, vga_r3[2:1]};
    wire [7:0] vga_g = {vga_g3, vga_g3, vga_g3[2:1]};
    wire [7:0] vga_b = {vga_b2, vga_b2, vga_b2, vga_b2};
    
    // VGA to HDMI adapter
    vga_to_hdmi u_adapter (
        .clk_pixel(clk_50mhz),
        .rst_n(rst_n && pll_lock),
        .vga_hsync(vga_hs),
        .vga_vsync(vga_vs),
        .vga_de(vga_de),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .hdmi_clk_p(O_tmds_clk_p),
        .hdmi_clk_n(O_tmds_clk_n),
        .hdmi_d_p(O_tmds_data_p),
        .hdmi_d_n(O_tmds_data_n)
    );

endmodule
```

## Resource Usage

Typical utilization on GW2A-18C:

| Resource | Usage | Percentage |
|----------|-------|------------|
| LUTs | ~500 | ~2% |
| Registers | ~200 | ~1% |
| BSRAM | 0 | 0% |
| PLLs | 1 | 25% |
| OSER10 | 4 | - |
| ELVDS_OBUF | 4 | - |

## Troubleshooting

### No HDMI Output

**Check:**
- PLL lock signal is high
- VGA source is generating valid hsync/vsync
- Pin constraints match schematic
- HDMI cable is connected and display is on

**Debug:**
```verilog
// Add ILA to monitor signals
wire [7:0] debug_signals = {
    pll_lock,
    vga_hsync,
    vga_vsync,
    vga_de,
    // ...
};
```

### Display Shows "No Signal"

**Common causes:**
- Serial clock not generated (check PLL)
- Display enable (DE) timing incorrect
- TMDS serializer not functioning

**Fix:**
- Verify PLL output frequency is exactly 5× pixel clock
- Check DE signal aligns with active video area
- Use timing analyzer to verify setup/hold

### Color Issues

**Symptoms:**
- Wrong colors
- Inverted colors
- Color channels swapped

**Fix:**
- Check RGB bit ordering (MSB vs LSB)
- Verify RGB expansion for 3-bit sources
- Confirm channel mapping: [2]=Red, [1]=Green, [0]=Blue

### Timing Violations

**If synthesis shows timing errors:**
- Add timing constraints for clock domains
- Use register pipeline stages if needed
- Reduce fan-out on critical paths

## Advanced Topics

### Adding Multiple Resolutions

Support different VGA sources:

```verilog
// Parameterized adapter
module vga_to_hdmi #(
    parameter PLL_MULT = 5  // 5x for TMDS
) (
    // ... ports ...
);
```

### Custom TMDS Encoding

Modify `tmds_encoder.v` for:
- Custom color space conversion
- Overlay/OSD support
- Color keying

### Performance Optimization

- Pipeline stages for high-frequency designs
- Gray code counters for clock domain crossing
- Registered outputs to improve timing

## References

- [DVI 1.0 Specification](http://www.ddwg.org/)
- [TMDS Encoding Wikipedia](https://en.wikipedia.org/wiki/Transition-minimized_differential_signaling)
- [Gowin OSER10 Primitive](https://www.gowinsemi.com/)
- [HQVGA Library](../papilio_hqvga/README.md)

## Support

- GitHub: https://github.com/GadgetFactory/DesignLab_Examples
- Forums: http://www.gadgetfactory.net/forum
- Email: support@gadgetfactory.net
