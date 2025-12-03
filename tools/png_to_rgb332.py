#!/usr/bin/env python3
"""
Convert PNG image to RGB332 C header for HQVGA framebuffer.
Reads from local file or URL, resizes to fit 160x120, and outputs C array.
"""

import requests
from PIL import Image
from io import BytesIO
import sys
import os

def rgb_to_rgb332(r, g, b):
    """Convert 8-bit RGB to RGB332 (3-3-2 bits)"""
    r3 = (r >> 5) & 0x07
    g3 = (g >> 5) & 0x07
    b2 = (b >> 6) & 0x03
    return (r3 << 5) | (g3 << 2) | b2

def convert_image(source, output_file, max_width=160, max_height=120):
    """Load image from file or URL and convert to RGB332 C header"""
    
    # Check if source is a file or URL
    if os.path.exists(source):
        print(f"Loading from file: {source}")
        img = Image.open(source)
    else:
        print(f"Downloading: {source}")
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        response = requests.get(source, headers=headers, timeout=30)
        response.raise_for_status()
        img = Image.open(BytesIO(response.content))
    
    print(f"Original size: {img.size}, mode: {img.mode}")
    
    # Convert to RGBA if needed
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # Calculate scaling to fit in max dimensions while preserving aspect ratio
    w, h = img.size
    scale = min(max_width / w, max_height / h)
    new_w = int(w * scale)
    new_h = int(h * scale)
    
    # Resize with high quality
    img = img.resize((new_w, new_h), Image.LANCZOS)
    print(f"Resized to: {img.size}")
    
    # Center in framebuffer
    offset_x = (max_width - new_w) // 2
    offset_y = (max_height - new_h) // 2
    
    # Create full framebuffer with black background
    framebuffer = [[0 for _ in range(max_width)] for _ in range(max_height)]
    
    # Convert pixels
    pixels = img.load()
    for y in range(new_h):
        for x in range(new_w):
            r, g, b, a = pixels[x, y]
            if a > 128:  # Not transparent
                framebuffer[offset_y + y][offset_x + x] = rgb_to_rgb332(r, g, b)
    
    # Write C header
    with open(output_file, 'w') as f:
        f.write(f"// Auto-generated RGB332 image data\n")
        f.write(f"// Original: {url}\n")
        f.write(f"// Size: {max_width}x{max_height}\n\n")
        f.write(f"#define IMAGE_WIDTH {max_width}\n")
        f.write(f"#define IMAGE_HEIGHT {max_height}\n\n")
        f.write("const uint8_t imageData[IMAGE_HEIGHT][IMAGE_WIDTH] = {\n")
        
        for y in range(max_height):
            f.write("    {")
            for x in range(max_width):
                if x > 0:
                    f.write(",")
                f.write(f"0x{framebuffer[y][x]:02X}")
            f.write("},\n")
        
        f.write("};\n")
    
    print(f"Written to: {output_file}")

if __name__ == "__main__":
    url = "https://png.pngtree.com/png-clipart/20240824/original/pngtree-flying-red-butterfly-on-transparent-background-png-image_15840222.png"
    output = "butterfly_image.h"
    
    if len(sys.argv) > 1:
        url = sys.argv[1]
    if len(sys.argv) > 2:
        output = sys.argv[2]
    
    convert_image(url, output)
