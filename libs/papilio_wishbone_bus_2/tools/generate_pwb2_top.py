#!/usr/bin/env python3
"""
generate_pwb2_top.py - Automatic top-level generator for Papilio Wishbone Bus 2

Scans PlatformIO lib_deps for PWB2-compatible peripherals and generates:
1. top.v with all peripherals instantiated
2. pwb2_config.vh with device IDs and SPI widths
"""

import json
import os
import sys
from pathlib import Path

# Try to import PlatformIO env (will fail if run standalone)
try:
    Import("env")
    IS_PLATFORMIO = True
except:
    IS_PLATFORMIO = False
    env = None

def find_pwb2_peripherals(project_dir):
    """Find all PWB2-compatible peripheral libraries"""
    peripherals = []
    
    if IS_PLATFORMIO:
        lib_deps = env.GetProjectOption("lib_deps", [])
        print(f"[PWB2] Scanning for peripherals in lib_deps: {lib_deps}")
    else:
        # Standalone mode - read from platformio.ini
        lib_deps = []
        platformio_ini = project_dir / "platformio.ini"
        if platformio_ini.exists():
            with open(platformio_ini, 'r') as f:
                in_lib_deps = False
                for line in f:
                    line_stripped = line.strip()
                    if line_stripped.startswith('lib_deps'):
                        in_lib_deps = True
                        # Check if there's a value on same line
                        if '=' in line_stripped:
                            value = line_stripped.split('=', 1)[1].strip()
                            if value:
                                lib_deps.append(value)
                        continue
                    if in_lib_deps:
                        # Stop at next section or config item
                        if line_stripped.startswith('[') or (line_stripped and '=' in line_stripped and not line.startswith(' ') and not line.startswith('\t')):
                            break
                        # Skip comments and empty lines
                        if line_stripped and not line_stripped.startswith(';') and not line_stripped.startswith('#'):
                            lib_deps.append(line_stripped)
        print(f"[PWB2] Scanning for peripherals in lib_deps: {lib_deps}")
    
    # Collect library directories
    lib_dirs = []
    
    # Check .pio/libdeps
    if IS_PLATFORMIO:
        libdeps_dir = project_dir / ".pio" / "libdeps" / env["PIOENV"]
    else:
        # Find any environment directory
        pio_libdeps = project_dir / ".pio" / "libdeps"
        if pio_libdeps.exists():
            env_dirs = [d for d in pio_libdeps.iterdir() if d.is_dir()]
            libdeps_dir = env_dirs[0] if env_dirs else None
        else:
            libdeps_dir = None
    
    if libdeps_dir and libdeps_dir.exists():
        lib_dirs.extend([d for d in libdeps_dir.iterdir() if d.is_dir()])
    
    # Check lib_extra_dirs
    if IS_PLATFORMIO:
        lib_extra_dirs = env.GetProjectOption("lib_extra_dirs", [])
    else:
        lib_extra_dirs = []
        platformio_ini = project_dir / "platformio.ini"
        if platformio_ini.exists():
            with open(platformio_ini, 'r') as f:
                in_extra_dirs = False
                for line in f:
                    line_stripped = line.strip()
                    if line_stripped.startswith('lib_extra_dirs'):
                        in_extra_dirs = True
                        # Check if there's a value on same line
                        if '=' in line_stripped:
                            value = line_stripped.split('=', 1)[1].strip()
                            if value:
                                lib_extra_dirs.append(value)
                        continue
                    if in_extra_dirs:
                        # Stop at next section or config item
                        if line_stripped.startswith('[') or (line_stripped and '=' in line_stripped and not line.startswith(' ') and not line.startswith('\t')):
                            break
                        # Skip comments and empty lines
                        if line_stripped and not line_stripped.startswith(';') and not line_stripped.startswith('#'):
                            lib_extra_dirs.append(line_stripped)
    
    for extra_dir in lib_extra_dirs:
        extra_path = Path(extra_dir)
        if not extra_path.is_absolute():
            extra_path = project_dir / extra_path
        
        if extra_path.exists():
            for lib_name in lib_deps:
                lib_path = extra_path / lib_name
                if lib_path.exists() and lib_path.is_dir():
                    lib_dirs.append(lib_path)
                    
                    # If this is PWB2 library itself, also scan its examples
                    if 'wishbone_bus' in lib_name.lower() or 'pwb2' in lib_name.lower():
                        examples_dir = lib_path / 'examples'
                        if examples_dir.exists():
                            for example in examples_dir.iterdir():
                                if example.is_dir():
                                    lib_dirs.append(example)
            
            # Also scan examples folder for pwb2_* peripherals
            for item in extra_path.iterdir():
                if item.is_dir() and item.name.startswith('pwb2_'):
                    examples_dir = item / 'examples'
                    if examples_dir.exists():
                        for example in examples_dir.iterdir():
                            if example.is_dir():
                                lib_dirs.append(example)
    
    print(f"[PWB2] Scanning {len(lib_dirs)} directories")
    for lib_dir in lib_dirs:
        print(f"[PWB2]   - {lib_dir}")
    
    # Scan each library for PWB2 peripherals
    for lib_dir in lib_dirs:
        # Check for wishbone_peripheral.json directly (for examples)
        peripheral_json = lib_dir / "wishbone_peripheral.json"
        if peripheral_json.exists():
            try:
                with open(peripheral_json, 'r') as f:
                    peripheral_data = json.load(f)
                
                peripheral_data['lib_path'] = str(lib_dir)
                peripheral_data['lib_name'] = peripheral_data.get('name', lib_dir.name)
                peripherals.append(peripheral_data)
                
                print(f"[PWB2] Found: {peripheral_data['name']} (Device ID: 0x{peripheral_data['device_id']:04X})")
            except Exception as e:
                print(f"[PWB2] Warning: Error reading {peripheral_json}: {e}")
            continue
        
        # Check for library.json (for full libraries)
        lib_json = lib_dir / "library.json"
        if not lib_json.exists():
            continue
        
        try:
            with open(lib_json, 'r') as f:
                lib_data = json.load(f)
            
            # Check for PWB2 compatibility
            if 'pwb2' in lib_data.get('keywords', []) or 'wishbone' in lib_data.get('keywords', []):
                peripheral_json = lib_dir / "wishbone_peripheral.json"
                
                if peripheral_json.exists():
                    with open(peripheral_json, 'r') as f:
                        peripheral_data = json.load(f)
                    
                    peripheral_data['lib_path'] = str(lib_dir)
                    peripheral_data['lib_name'] = lib_data.get('name', lib_dir.name)
                    peripherals.append(peripheral_data)
                    
                    print(f"[PWB2] Found: {peripheral_data['name']} (Device ID: 0x{peripheral_data['device_id']:04X})")
        
        except Exception as e:
            print(f"[PWB2] Warning: Error reading {lib_json}: {e}")
    
    print(f"[PWB2] Total peripherals found: {len(peripherals)}")
    return peripherals

def validate_peripherals(peripherals):
    """Validate peripheral configurations"""
    errors = []
    
    # Check for duplicate device IDs
    device_ids = {}
    for periph in peripherals:
        dev_id = periph['device_id']
        if dev_id in device_ids:
            errors.append(f"Duplicate device ID 0x{dev_id:04X}: {periph['name']} and {device_ids[dev_id]}")
        else:
            device_ids[dev_id] = periph['name']
    
    # Check total slots
    total_slots = 1  # Slot 0 reserved for system
    for periph in peripherals:
        total_slots += periph.get('slots_required', 1)
    
    if total_slots > 32:
        errors.append(f"Too many slots required: {total_slots} (maximum is 32)")
    
    return errors

def generate_config_vh(peripherals, output_path):
    """Generate pwb2_config.vh with device IDs and SPI widths"""
    
    config = """// pwb2_config.vh - Auto-generated configuration
// Generated by generate_pwb2_top.py - DO NOT EDIT MANUALLY

`ifndef PWB2_CONFIG_VH
`define PWB2_CONFIG_VH

`include "pwb2_pkg.vh"

// =============================================================================
// Peripheral Configuration
// =============================================================================

"""
    
    # Slot 0 is always system
    device_ids = ["`PWB2_DEVID_SYSTEM"]
    spi_widths = ["`PWB2_SPI_WIDTH_32"]
    
    current_slot = 1
    for periph in peripherals:
        num_slots = periph.get('slots_required', 1)
        dev_id = periph['device_id']
        spi_width = periph.get('spi_transfer_bits', 8)
        
        for i in range(num_slots):
            device_ids.append(f"16'h{dev_id:04X}")
            spi_widths.append(f"6'd{spi_width}")
            current_slot += 1
    
    # Fill remaining slots with EMPTY
    while current_slot < 32:
        device_ids.append("`PWB2_DEVID_EMPTY")
        spi_widths.append("`PWB2_SPI_WIDTH_8")
        current_slot += 1
    
    config += f"// Device IDs for all 32 slots\n"
    config += f"parameter [15:0] PWB2_DEVICE_IDS [0:31] = '{{\n"
    for i in range(0, 32, 4):
        config += f"    {', '.join(device_ids[i:i+4])}"
        if i < 28:
            config += ","
        config += "\n"
    config += f"}};\n\n"
    
    config += f"// SPI transfer widths for all 32 slots\n"
    config += f"parameter [5:0] PWB2_SPI_WIDTHS [0:31] = '{{\n"
    for i in range(0, 32, 8):
        config += f"    {', '.join(spi_widths[i:i+8])}"
        if i < 24:
            config += ","
        config += "\n"
    config += f"}};\n\n"
    
    config += f"// Capability flags\n"
    config += f"parameter [31:0] PWB2_CAPABILITIES = 32'h0000000F;  // Burst, Extended, Large, DMA\n\n"
    
    config += f"`endif // PWB2_CONFIG_VH\n"
    
    with open(output_path, 'w') as f:
        f.write(config)
    
    print(f"[PWB2] Generated: {output_path}")

def generate_top_v(peripherals, output_path, template_path):
    """Generate top.v with all peripherals instantiated"""
    
    # Read template
    if template_path.exists():
        with open(template_path, 'r') as f:
            template = f.read()
    else:
        # Use embedded minimal template
        template = """// top.v - Auto-generated top-level module
// Generated by generate_pwb2_top.py

`include "pwb2_pkg.vh"
`include "pwb2_config.vh"

module top (
    // System
    input wire clk,
    input wire rst,
    
    // SPI from ESP32
    input wire esp_sclk,
    input wire esp_mosi,
    output wire esp_miso,
    input wire esp_cs_n
    
    // PERIPHERAL_PORTS
);

// PERIPHERAL_WIRES

// PWB2 SPI Bridge
wire [23:0] wb_adr;
wire [31:0] wb_dat_m2s, wb_dat_s2m;
wire wb_cyc, wb_stb, wb_we, wb_ack;

pwb2_spi_bridge #(
    .NUM_SLOTS(32),
    .SLOT_SPI_BITS(PWB2_SPI_WIDTHS)
) bridge (
    .clk(clk),
    .rst(rst),
    .spi_sclk(esp_sclk),
    .spi_mosi(esp_mosi),
    .spi_miso(esp_miso),
    .spi_cs_n(esp_cs_n),
    .wb_adr_o(wb_adr),
    .wb_dat_o(wb_dat_m2s),
    .wb_dat_i(wb_dat_s2m),
    .wb_cyc_o(wb_cyc),
    .wb_stb_o(wb_stb),
    .wb_we_o(wb_we),
    .wb_ack_i(wb_ack)
);

// PWB2 Interconnect
wire [31:0] wb_slot_dat_i [0:31];
wire [31:0] wb_slot_stb;
wire [31:0] wb_slot_ack;

pwb2_interconnect #(
    .NUM_SLOTS(32),
    .DEVICE_IDS(PWB2_DEVICE_IDS),
    .SPI_WIDTHS(PWB2_SPI_WIDTHS)
) interconnect (
    .clk(clk),
    .rst(rst),
    .wb_adr_i(wb_adr),
    .wb_dat_i(wb_dat_m2s),
    .wb_dat_o(wb_dat_s2m),
    .wb_cyc_i(wb_cyc),
    .wb_stb_i(wb_stb),
    .wb_we_i(wb_we),
    .wb_ack_o(wb_ack),
    .wb_slot_adr_o(wb_adr),
    .wb_slot_dat_o(wb_dat_m2s),
    .wb_slot_dat_i(wb_slot_dat_i),
    .wb_slot_stb_o(wb_slot_stb),
    .wb_slot_we_o(wb_we),
    .wb_slot_ack_i(wb_slot_ack)
);

// Slot 0: System Memory Map
pwb2_memory_map #(
    .NUM_SLOTS(32),
    .DEVICE_IDS(PWB2_DEVICE_IDS),
    .SPI_WIDTHS(PWB2_SPI_WIDTHS),
    .CAPABILITIES(PWB2_CAPABILITIES)
) memory_map (
    .clk(clk),
    .rst(rst),
    .wb_adr_i(wb_adr[7:0]),
    .wb_dat_i(wb_dat_m2s),
    .wb_dat_o(wb_slot_dat_i[0]),
    .wb_stb_i(wb_slot_stb[0]),
    .wb_we_i(wb_we),
    .wb_ack_o(wb_slot_ack[0])
);

// PERIPHERAL_INSTANCES

endmodule
"""
    
    # Generate peripheral instances
    peripheral_ports = []
    peripheral_wires = []
    peripheral_instances = []
    
    current_slot = 1
    for periph in peripherals:
        name = periph['name']
        module = periph['module_name']
        dev_id = periph['device_id']
        spi_width = periph.get('spi_transfer_bits', 8)
        inst_name = periph.get('instance_name', module.lower())
        
        # Add ports
        if 'ports' in periph:
            for port in periph['ports']:
                direction = port.get('direction', 'output')
                width = port.get('width', 1)
                port_name = port['name']
                
                if width > 1:
                    peripheral_ports.append(f"    {direction} wire [{width-1}:0] {port_name}")
                else:
                    peripheral_ports.append(f"    {direction} wire {port_name}")
        
        # Generate instance
        instance = f"""
// Slot {current_slot}: {name}
{module} #(
    .SLOT_NUMBER({current_slot}),
    .DEVICE_ID(16'h{dev_id:04X})
) {inst_name} (
    .clk(clk),
    .rst(rst),
    .wb_adr_i(wb_adr[7:0]),
    .wb_dat_i(wb_dat_m2s),
    .wb_dat_o(wb_slot_dat_i[{current_slot}]),
    .wb_stb_i(wb_slot_stb[{current_slot}]),
    .wb_we_i(wb_we),
    .wb_ack_o(wb_slot_ack[{current_slot}])"""
        
        # Add peripheral-specific ports
        if 'ports' in periph:
            for port in periph['ports']:
                instance += f",\n    .{port['name']}({port['connection']})"
        
        instance += "\n);\n"
        peripheral_instances.append(instance)
        
        current_slot += periph.get('slots_required', 1)
    
    # Fill unused slots
    for slot in range(current_slot, 32):
        peripheral_instances.append(f"""
// Slot {slot}: Empty
assign wb_slot_dat_i[{slot}] = 32'h00000000;
assign wb_slot_ack[{slot}] = 1'b0;
""")
    
    # Replace placeholders
    if peripheral_ports:
        template = template.replace("// PERIPHERAL_PORTS", ",\n" + ",\n".join(peripheral_ports))
    else:
        template = template.replace("// PERIPHERAL_PORTS", "")
    
    template = template.replace("// PERIPHERAL_WIRES", "\n".join(peripheral_wires))
    template = template.replace("// PERIPHERAL_INSTANCES", "\n".join(peripheral_instances))
    
    with open(output_path, 'w') as f:
        f.write(template)
    
    print(f"[PWB2] Generated: {output_path}")

def main():
    """Main generation function"""
    if IS_PLATFORMIO:
        project_dir = Path(env["PROJECT_DIR"])
    else:
        # Standalone mode - use current directory or parent until we find platformio.ini
        project_dir = Path.cwd()
        while not (project_dir / "platformio.ini").exists() and project_dir != project_dir.parent:
            project_dir = project_dir.parent
        
        if not (project_dir / "platformio.ini").exists():
            print("[PWB2] ERROR: platformio.ini not found in current or parent directories")
            sys.exit(1)
    
    # Output to library's generated directory for now
    lib_dir = Path(__file__).parent.parent
    output_dir = lib_dir / "hdl" / "generated"
    output_dir.mkdir(parents=True, exist_ok=True)
    
    print("[PWB2] ========================================")
    print("[PWB2] Papilio Wishbone Bus 2 - Auto Generator")
    print("[PWB2] ========================================")
    print(f"[PWB2] Project directory: {project_dir}")
    print(f"[PWB2] Output directory: {output_dir}")
    
    # Find peripherals
    peripherals = find_pwb2_peripherals(project_dir)
    
    if not peripherals:
        print("[PWB2] No PWB2 peripherals found - skipping generation")
        return
    
    # Validate
    errors = validate_peripherals(peripherals)
    if errors:
        print("[PWB2] ERROR: Validation failed:")
        for error in errors:
            print(f"[PWB2]   - {error}")
        sys.exit(1)
    
    # Generate files
    generate_config_vh(peripherals, output_dir / "pwb2_config.vh")
    
    template_path = lib_dir / "hdl" / "templates" / "top_template.v"
    generate_top_v(peripherals, output_dir / "top.v", template_path)
    
    print("[PWB2] ========================================")
    print("[PWB2] Generation complete!")
    print("[PWB2] ========================================")

# Run when called as pre-script
if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"[PWB2] ERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
