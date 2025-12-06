import shutil, os, sys
from pathlib import Path
from SCons.Script import Import
Import("env")

# Mapping from environment name to example sketch relative path
ENV_MAP = {
    'text_mode_test': 'libs/papilio_hdmi/examples/text_mode_test/text_mode_test.ino',
    'spaceinvaders_hdmi': 'libs/papilio_hdmi/examples/spaceinvaders_hdmi/spaceinvaders_hdmi.ino',
    'spaceinvaders_hqvga': 'libs/papilio_hdmi/examples/spaceinvaders_hqvga/spaceinvaders_hqvga.ino',
    'bricks_hqvga': 'libs/papilio_hdmi/examples/bricks_hqvga/bricks_hqvga.ino',
    'vga_lcd_demo': 'libs/papilio_hdmi/examples/vga_lcd_demo/vga_lcd_demo.ino',
    'gfx_demo': 'libs/papilio_hdmi/examples/gfx_demo/gfx_demo.ino',
    'lvgl_demo': 'libs/papilio_hdmi/examples/lvgl_demo/lvgl_demo.ino',
    'u8g2_demo': 'libs/papilio_hdmi/examples/u8g2_demo/u8g2_demo.ino',
    'tft_espi_demo': 'libs/papilio_hdmi/examples/tft_espi_demo/tft_espi_demo.ino',
    'imagedec_demo': 'libs/papilio_hdmi/examples/imagedec_demo/imagedec_demo.ino',
    'butterfly_fullscreen': 'libs/papilio_hdmi/examples/butterfly_fullscreen/butterfly_fullscreen.ino',
    'video_modes_demo': 'libs/papilio_hdmi/examples/video_modes_demo/video_modes_demo.ino',
    'test_pattern_demo': 'libs/papilio_hdmi/examples/test_pattern_demo/test_pattern_demo.ino',
    'mcp_debug_firmware': 'libs/papilio_mcp_server/examples/mcp_debug_simple/mcp_debug_simple.ino',
    'mcp_breakpoint_demo': 'libs/papilio_mcp_server/examples/mcp_breakpoint_demo/mcp_breakpoint_demo.ino',
    # Audio examples
    'sid_demo': 'libs/papilio_audio/examples/sid_demo/sid_demo.ino',
    'sid_player': 'libs/papilio_audio/examples/sid_player/sid_player.ino',
    'sid_player_fs': 'libs/papilio_audio/examples/sid_player_fs/sid_player_fs.ino',
    'ym2149_demo': 'libs/papilio_audio/examples/ym2149_demo/ym2149_demo.ino',
    'ym_player_demo': 'libs/papilio_audio/examples/ym_player_demo/ym_player_demo.ino',
    'pokey_demo': 'libs/papilio_audio/examples/pokey_demo/pokey_demo.ino',
}

# __file__ may not be defined in PlatformIO pre scripts; fallback to CWD
PROJECT_ROOT = Path(os.getcwd())
SRC_DIR = PROJECT_ROOT / 'src'
TARGET_FILE = SRC_DIR / '__active_example.ino'
TEMPLATE_FILE = SRC_DIR / 'papliio_arcade_template.ino'
TEMPLATE_BACKUP = SRC_DIR / 'papliio_arcade_template.ino.disabled'

pioenv = env.get('PIOENV')
if not pioenv:
    print('[examples_select] PIOENV missing in env; skipping example selection.')
    sys.exit(0)

example_rel = ENV_MAP.get(pioenv)
if not example_rel:
    print(f'[examples_select] No example mapping for env {pioenv}; skipping.')
    sys.exit(0)

source_path = PROJECT_ROOT / example_rel
if not source_path.exists():
    print(f'[examples_select] Example sketch not found: {source_path}')
    sys.exit(1)

# Ensure src directory exists
SRC_DIR.mkdir(exist_ok=True)

# Clean up any leftover files from interrupted builds
if TARGET_FILE.exists():
    TARGET_FILE.unlink()
    print(f'[examples_select] Cleaned up leftover {TARGET_FILE.name}')

# Also clean up any .cpp version that PlatformIO may have created
target_cpp = SRC_DIR / '__active_example.ino.cpp'
if target_cpp.exists():
    target_cpp.unlink()
    print(f'[examples_select] Cleaned up leftover {target_cpp.name}')

# Restore template if it was left in disabled state
if TEMPLATE_BACKUP.exists() and not TEMPLATE_FILE.exists():
    TEMPLATE_BACKUP.rename(TEMPLATE_FILE)
    print(f'[examples_select] Restored template from previous interrupted build')

# Temporarily rename template so Arduino builder doesn't see two .ino files
if TEMPLATE_FILE.exists() and not TEMPLATE_BACKUP.exists():
    TEMPLATE_FILE.rename(TEMPLATE_BACKUP)
    print(f'[examples_select] Renamed template -> {TEMPLATE_BACKUP.name}')

# Copy (overwrite) the example sketch into src
shutil.copy2(source_path, TARGET_FILE)
print(f'[examples_select] Copied {source_path} -> {TARGET_FILE}')

# Register a post-build action to restore the template
def restore_template(source, target, env):
    if TEMPLATE_BACKUP.exists() and not TEMPLATE_FILE.exists():
        TEMPLATE_BACKUP.rename(TEMPLATE_FILE)
        print(f'[examples_select] Restored template from backup')
    # Clean up active example copy
    if TARGET_FILE.exists():
        TARGET_FILE.unlink()
        print(f'[examples_select] Removed {TARGET_FILE.name}')

env.AddPostAction("$PROGPATH", restore_template)
