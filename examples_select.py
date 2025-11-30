import shutil, os, sys
from pathlib import Path
from SCons.Script import Import
Import("env")

# Mapping from environment name to example sketch relative path
ENV_MAP = {
    'text_mode_test': 'examples/text_mode_test/text_mode_test.ino',
    'spaceinvaders_hdmi': 'examples/spaceinvaders_hdmi/spaceinvaders_hdmi.ino',
    'fpga_debug_monitor': 'examples/fpga_debug_monitor/fpga_debug_monitor.ino',
}

# __file__ may not be defined in PlatformIO pre scripts; fallback to CWD
PROJECT_ROOT = Path(os.getcwd())
SRC_DIR = PROJECT_ROOT / 'src'
TARGET_FILE = SRC_DIR / '__active_example.ino'

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

# Copy (overwrite) the example sketch into src
shutil.copy2(source_path, TARGET_FILE)
print(f'[examples_select] Copied {source_path} -> {TARGET_FILE}')
