#!/usr/bin/env python3
"""Inject LC_LOAD_DYLIB into an ARM64 Mach-O binary."""
import struct, sys

with open(sys.argv[1], 'rb') as f:
    data = bytearray(f.read())

dylib_path = sys.argv[2].encode() + b'\x00'
while len(dylib_path) % 4:
    dylib_path += b'\x00'

cmd_size = 24 + len(dylib_path)
cmd = struct.pack('<II', 0x0C, cmd_size)
cmd += struct.pack('<IIII', 24, 0, 0, 0)
cmd += dylib_path

ncmds = struct.unpack_from('<I', data, 4)[0]
sizeofcmds = struct.unpack_from('<I', data, 8)[0]

data[8:12] = struct.pack('<I', sizeofcmds + cmd_size)
data[4:8] = struct.pack('<I', ncmds + 1)

insert_offset = 8 + sizeofcmds
data[insert_offset:insert_offset] = cmd

with open(sys.argv[1] + '_patched', 'wb') as f:
    f.write(bytes(data))

import os
os.chmod(sys.argv[1] + '_patched', 0o755)
print(f"Injected dylib: {sys.argv[2]}")
