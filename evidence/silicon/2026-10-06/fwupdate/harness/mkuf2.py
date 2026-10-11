#!/usr/bin/env python3
"""mkuf2.py OUT.uf2 ADDR:FILE|ADDR:ff:LEN ...  -- one RP2040 UF2 from several pieces.

Used for the first flash of a Phase 1.3 node: bootloader at 0x10000000, an
explicitly ERASED (0xFF) bootloader-state sector at 0x10007000 (otherwise whatever
old code lies there could read as a swap request), and the v1 application at
0x10008000. UF2 format (Microsoft): 512-byte blocks, 256-byte payloads, family ID
0xE48BFF56 (RP2040). Addresses must be 256-byte aligned.
"""
import struct
import sys

MAGIC0, MAGIC1, MAGIC_END = 0x0A324655, 0x9E5D5157, 0x0AB16F30
FLAG_FAMILY = 0x00002000
RP2040 = 0xE48BFF56


def pieces(args):
    for a in args:
        addr_s, rest = a.split(':', 1)  # a Windows path may contain ':'
        addr = int(addr_s, 16)
        if rest.startswith('ff:'):
            data = b'\xff' * int(rest[3:], 0)
        else:
            data = open(rest, 'rb').read()
        assert addr % 256 == 0, hex(addr)
        yield addr, data


def main():
    out, args = sys.argv[1], sys.argv[2:]
    pages = []
    for addr, data in pieces(args):
        # RP2040-E14 (datasheet 2.8.4.2): a partially filled 4 KiB sector anywhere but
        # at the end may not be written correctly. Pad every piece to whole sectors
        # (elf2uf2 does the same). Without this the bootrom dropped the application
        # pages after the 8 KiB bootloader (7 failed boots, 2026-10-06/07).
        assert addr % 4096 == 0, f'piece at {addr:#x} must start on a 4 KiB sector'
        data += b'\xff' * (-len(data) % 4096)
        for off in range(0, len(data), 256):
            pages.append((addr + off, data[off:off + 256]))
    addrs = [a for a, _ in pages]
    assert len(addrs) == len(set(addrs)), 'overlapping pieces'
    with open(out, 'wb') as f:
        for i, (addr, chunk) in enumerate(pages):
            hdr = struct.pack('<IIIIIIII', MAGIC0, MAGIC1, FLAG_FAMILY, addr, 256, i, len(pages), RP2040)
            f.write(hdr + chunk + b'\x00' * (476 - 256) + struct.pack('<I', MAGIC_END))
    print(f'{out}: {len(pages)} blocks, {min(addrs):#x}..{max(addrs) + 256:#x}')


if __name__ == '__main__':
    main()
