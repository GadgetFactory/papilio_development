#!/usr/bin/env python3
"""
Test the logic analyzer via the MCP server
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'libs', 'papilio_mcp_server', 'server'))

from papilio_mcp_server import PapilioController
from logic_analyzer_tool import LogicAnalyzerTool

def main():
    print("=" * 60)
    print("Logic Analyzer MCP Integration Test")
    print("=" * 60)
    
    try:
        # Create controller
        print("\n1. Connecting to hardware...")
        controller = PapilioController(port='COM4', baud=115200)
        if not controller.connect():
            print("✗ Failed to connect")
            return 1
        print("✓ Connected")
        
        # Create logic analyzer
        print("\n2. Initializing logic analyzer...")
        la = LogicAnalyzerTool(controller)
        
        # Get status
        print("\n3. Getting status...")
        status = la.get_status()
        print(f"   State: {status['state_name']}")
        print(f"   Device ID: {status['device_id']}")
        print(f"   Channels: {status['channels']}")
        print(f"   Depth: {status['depth']} samples")
        
        # Reset
        print("\n4. Resetting...")
        la.reset()
        
        # Configure for simple capture (no trigger)
        print("\n5. Configuring capture...")
        config = la.configure(
            trigger_mask=0x00000000,    # No trigger
            trigger_value=0x00000000,
            samples=64,                  # Capture 64 samples
            post_trigger=0,
            divider=26                   # ~1 MHz sample rate
        )
        print(f"   Samples: {config['samples']}")
        print(f"   Divider: {config['divider']}")
        
        # Arm and capture
        print("\n6. Arming...")
        la.arm()
        
        print("7. Capturing...")
        samples = la.capture(timeout=2.0)
        
        if samples:
            print(f"\n✓ SUCCESS! Captured {len(samples)} samples")
            print("\nFirst 10 samples:")
            for i, sample in enumerate(samples[:10]):
                print(f"  Sample {i:3d}: 0x{sample:08X}")
            
            # Export to VCD
            print("\n8. Exporting to VCD...")
            result = la.export_vcd(samples, "test_capture.vcd")
            print(f"   Saved to {result['filename']}")
            print(f"   View with: gtkwave {result['filename']}")
            
            # Analyze some signals
            print("\n9. Signal Analysis:")
            print("   Checking for activity...")
            
            # Check if any signals changed
            if len(samples) > 1:
                changes = {}
                for i in range(32):
                    mask = 1 << i
                    changed = False
                    for j in range(1, len(samples)):
                        if (samples[j] & mask) != (samples[j-1] & mask):
                            changed = True
                            break
                    if changed:
                        changes[i] = True
                
                if changes:
                    print(f"   {len(changes)} signals showed activity:")
                    for ch in sorted(changes.keys())[:10]:
                        print(f"     - Channel {ch}: {LogicAnalyzerTool.CHANNEL_NAMES[ch]}")
                else:
                    print("   No signal changes detected (all static)")
        else:
            print("\n✗ Capture failed or timed out")
            return 1
            
    except Exception as e:
        print(f"\n✗ ERROR: {e}")
        import traceback
        traceback.print_exc()
        return 1
    finally:
        if 'controller' in locals():
            controller.disconnect()
    
    print("\n" + "=" * 60)
    print("Test completed successfully!")
    print("=" * 60)
    return 0

if __name__ == '__main__':
    sys.exit(main())
