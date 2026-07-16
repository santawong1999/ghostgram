#!/usr/bin/env python3
"""Inject LC_LOAD_DYLIB into an ARM64 Mach-O binary."""
import struct, sys

with open(sys.argv[1], 'rb') as f:
    data = bytearray(f.read())

# Mach-O header (64-bit): magic(4) + cputype(4) + cpusubtype(4) + filetype(4) + ncmds(4) + sizeofcmds(4) + flags(4) + reserved(4) = 32 bytes
magic = struct.unpack_from('<I', data, 0)[0]
MH_MAGIC_64 = 0xfeedfacf
MH_CIGAM_64 = 0xcffaedfe
is_swap = magic == MH_CIGAM_64

if magic not in (MH_MAGIC_64, MH_CIGAM_64):
    print(f"Not a 64-bit Mach-O: magic={magic:#x}")
    sys.exit(1)

def r(off, fmt):
    if is_swap and fmt == '<I': fmt = '>I'
    elif is_swap and fmt == '>I': fmt = '<I'
    return struct.unpack_from(fmt, data, off)[0]

dylib_path = sys.argv[2].encode() + b'\x00'
while len(dylib_path) % 4:
    dylib_path += b'\x00'

cmd_size = 24 + len(dylib_path)
cmd = struct.pack('<II', 0x0C, cmd_size)
cmd += struct.pack('<IIII', 24, 0, 0, 0)
cmd += dylib_path

ncmds = r(16, '<I')
sizeofcmds = r(20, '<I')

struct.pack_into('<I', data, 20, sizeofcmds + cmd_size)
struct.pack_into('<I', data, 16, ncmds + 1)

insert_offset = 32 + sizeofcmds
data[insert_offset:insert_offset] = cmd

with open(sys.argv[1] + '_patched', 'wb') as f:
    f.write(bytes(data))

import os
os.chmod(sys.argv[1] + '_patched', 0o755)
print(f"Injected dylib into arm64 Mach-O ({ncmds + 1} load commands, {sizeofcmds + cmd_size} bytes)")
