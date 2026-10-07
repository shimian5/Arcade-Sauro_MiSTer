"""Compare machine RAM from the RTL (tb_core *_ram.hex) with a MAME dump_frame.lua dump.
Layout of the RTL file: work RAM 2048, sprite 1024, bg vram 1024, bg cram 1024, fg vram 1024,
fg cram 1024, then bg scroll, fg scroll, latch. MAME dump: E000-FFFF then regs.
Usage: python -I tools/compare_ram.py <rtl_ram.hex> <mame_dump.bin>
"""
import sys
rtl = [int(l, 16) for l in open(sys.argv[1]) if l.strip()]
d = open(sys.argv[2], "rb").read()
mram = d[:8192]
regions = [("work RAM E000", 0, 0x0000, 2048), ("sprite RAM E800", 2048, 0x0800, 1024), ("bg vram F000", 3072, 0x1000, 1024),
           ("bg cram F400", 4096, 0x1400, 1024), ("fg vram F800", 5120, 0x1800, 1024), ("fg cram FC00", 6144, 0x1c00, 1024)]
ok = True
for name, roff, moff, n in regions:
	diffs = [i for i in range(n) if rtl[roff + i] != mram[moff + i]]
	print(f"{name}: {len(diffs)} differ" + (f" (first offsets {[hex(i) for i in diffs[:6]]}, rtl {[rtl[roff+i] for i in diffs[:6]]} mame {[mram[moff+i] for i in diffs[:6]]})" if diffs else ""))
	ok = ok and not diffs
print(f"regs rtl bg={rtl[7168]:02x} fg={rtl[7169]:02x} latch={rtl[7170]:02x}; mame bg={d[8192]:02x} fg={d[8193]:02x} latch={d[8194]:02x}")
sys.exit(0 if ok else 1)
