#!/usr/bin/env python3
"""Remove UISupportedDevices from Info.plist to make IPA compatible with all devices."""
import plistlib, sys

with open(sys.argv[1], 'rb') as f:
    plist = plistlib.load(f)

if 'UISupportedDevices' in plist:
    del plist['UISupportedDevices']
    print("Removed UISupportedDevices restriction")

with open(sys.argv[1], 'wb') as f:
    plistlib.dump(plist, f)

print("Info.plist patched for all device support")
