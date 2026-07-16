#!/usr/bin/env python3
"""Extract arm64 slice from FAT Mach-O binary (supports both 32 and 64 bit FAT)."""
import struct, sys

with open(sys.argv[1], 'rb') as f:
    data = bytearray(f.read())

magic = struct.unpack_from('<I', data, 0)[0]
FAT_MAGIC = 0xcafebabe
FAT_MAGIC_64 = 0xcafebabf

if magic == FAT_MAGIC_64:
    n = struct.unpack_from('<I', data, 4)[0]
    off = 8
    for i in range(n):
        cpu = struct.unpack_from('<I', data, off)[0]
        arch_off = struct.unpack_from('<Q', data, off + 8)[0]
        arch_size = struct.unpack_from('<Q', data, off + 16)[0]
        if cpu == 12 or cpu == 0x0100000c:
            with open(sys.argv[2], 'wb') as f:
                f.write(bytes(data[arch_off:arch_off + arch_size]))
            print(f"Extracted arm64 slice at offset {arch_off}, size {arch_size}")
            sys.exit(0)
        off += 32
elif magic == FAT_MAGIC:
    n = struct.unpack_from('<I', data, 4)[0]
    off = 8
    for i in range(n):
        cpu = struct.unpack_from('<I', data, off)[0]
        arch_off = struct.unpack_from('<I', data, off + 8)[0]
        arch_size = struct.unpack_from('<I', data, off + 12)[0]
        if cpu == 12 or cpu == 0x0100000c:
            with open(sys.argv[2], 'wb') as f:
                f.write(bytes(data[arch_off:arch_off + arch_size]))
            print(f"Extracted arm64 slice at offset {arch_off}, size {arch_size}")
            sys.exit(0)
        off += 20
elif magic == 0xfeedface or magic == 0xfeedfacf:
    import shutil
    shutil.copy2(sys.argv[1], sys.argv[2])
    print("Already thin Mach-O, copied as-is")
    sys.exit(0)
else:
    print(f"Unknown magic: {magic:#x}")
    sys.exit(1)

print("ARM64 slice not found")
sys.exit(1)
