#!/usr/bin/env python3
"""Extract arm64 slice from FAT Mach-O binary."""
import struct, sys

with open(sys.argv[1], 'rb') as f:
    data = bytearray(f.read())

if data[:4] == b'\xcf\xfa\xed\xfe':
    n = struct.unpack_from('<I', data, 4)[0]
    off = 8
    for i in range(n):
        cpu = struct.unpack_from('<I', data, off)[0]
        arch_off = struct.unpack_from('<I', data, off + 8)[0]
        arch_size = struct.unpack_from('<I', data, off + 12)[0]
        if cpu == 12:
            with open(sys.argv[2], 'wb') as f:
                f.write(bytes(data[arch_off:arch_off + arch_size]))
            print(f"Extracted arm64 slice from offset {arch_off}, size {arch_size}")
            sys.exit(0)
        off += 20
else:
    import shutil
    shutil.copy2(sys.argv[1], sys.argv[2])
    print("Not FAT, copied as-is")
    sys.exit(0)

print("ARM64 slice not found")
sys.exit(1)
