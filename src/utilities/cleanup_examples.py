"""
Cleanup script for papilio_arcade base environment.
Removes any leftover __active_example.ino files from previous example builds.
"""
import os
from pathlib import Path

PROJECT_ROOT = Path(os.getcwd())
SRC_DIR = PROJECT_ROOT / 'src'
TARGET_FILE = SRC_DIR / '__active_example.ino'
TARGET_CPP = SRC_DIR / '__active_example.ino.cpp'
TEMPLATE_FILE = SRC_DIR / 'papliio_arcade_template.ino'
TEMPLATE_BACKUP = SRC_DIR / 'papliio_arcade_template.ino.disabled'

# Clean up leftover example files
if TARGET_FILE.exists():
    TARGET_FILE.unlink()
    print(f'[cleanup] Removed leftover {TARGET_FILE.name}')

if TARGET_CPP.exists():
    TARGET_CPP.unlink()
    print(f'[cleanup] Removed leftover {TARGET_CPP.name}')

# Restore template if it was left disabled
if TEMPLATE_BACKUP.exists() and not TEMPLATE_FILE.exists():
    TEMPLATE_BACKUP.rename(TEMPLATE_FILE)
    print(f'[cleanup] Restored template from {TEMPLATE_BACKUP.name}')
