"""Independent Python model of the Tecfri video rules in MAME's sauro.cpp.

Renders pen indices (0..1023) for a frame dump written by sim/mame/dump_frame.lua and
checks them against MAME's rendered colours. MAME's palette output is resistor-weighted
(not a plain 4-bit expansion), so the check does not assume a DAC curve: it requires
that every PROM nibble level maps to ONE 8-bit value per channel across the whole
frame. A wrong tile, sprite or palette index breaks that functional dependency.

Usage: python -I tools/video_ref.py <romdir> <set> <dump.bin> [--flipy-hack]
  --flipy-hack  Tricky Doc sprite attr bit 3 = y+6 (MAME 0.257) instead of flipy (0.288)
Env: SCROLL_SIGN (default 1: source x = x + scroll), DEBUG=1 (bad 16x16 cells),
     PNG=<prefix> (write <prefix>_mame.png and <prefix>_model.png)
"""
import collections, os, pathlib, struct, sys, zipfile, zlib

SCROLL_SIGN = int(os.environ.get("SCROLL_SIGN", "1"))
BG_OFF = int(os.environ.get("BG_OFF", "0"))
FG_OFF = int(os.environ.get("FG_OFF", "0"))
SPR_DX = int(os.environ.get("SPR_DX", "0"))
SPR_DY = int(os.environ.get("SPR_DY", "0"))
W, H = 240, 224
X0, Y0 = 8, 16   # visarea origin inside the 256x256 MAME bitmap

SETS = {
	"sauro": dict(tricky=False,
		bg=[("sauro-6.bin", 0), ("sauro-7.bin", 0x8000)],
		fg=[("sauro-4.bin", 0), ("sauro-5.bin", 0x8000)],
		spr=[("sauro-8.bin", 0), ("sauro-9.bin", 0x8000), ("sauro-10.bin", 0x10000), ("sauro-11.bin", 0x18000)],
		spr_size=0x20000,
		proms=[("82s137-3.bin", 0), ("82s137-2.bin", 0x400), ("82s137-1.bin", 0x800)]),
	"seawolft": dict(tricky=False,
		# shared ROMs live in the parent zip under the parent's names (split set)
		bg=[("sauro-6.bin", 0), ("3.bin", 0x8000)],
		fg=[("sauro-4.bin", 0), ("sauro-5.bin", 0x8000)],
		spr=[("10.bin", 0), ("9.bin", 0x8000), ("8.bin", 0x10000), ("7.bin", 0x18000)],
		spr_size=0x20000,
		proms=[("82s137-3.bin", 0), ("82s137-2.bin", 0x400), ("82s137-1.bin", 0x800)]),
	"trckydoc": dict(tricky=True,
		bg=[("trckydoc.e6", 0), ("trckydoc.g6", 0x8000)],
		fg=None,
		spr=[("trckydoc.h1", 0), ("trckydoc.e1", 0x4000), ("trckydoc.c1", 0x8000), ("trckydoc.a1", 0xc000)],
		spr_size=0x10000,
		proms=[("tdclr3.prm", 0), ("tdclr2.prm", 0x400), ("tdclr1.prm", 0x800)]),
}

class Zips:
	"""A set's zip plus its parent: split sets keep shared ROMs only in the parent."""
	def __init__(self, rom_dir, *names):
		self.zs = [zipfile.ZipFile(pathlib.Path(rom_dir) / f"{n}.zip") for n in names]
	def read(self, name):
		for z in self.zs:
			if name in z.namelist():
				return z.read(name)
		raise KeyError(name)

def load_region(z, parts, size):
	buf = bytearray(size)
	for name, off in parts:
		d = z.read(name)
		buf[off:off + len(d)] = d
	return buf

def tile_pixel(gfx, code, x, y):
	"""8x8 4bpp chars: 32 bytes/char, 4 bytes/row, high nibble first."""
	b = gfx[code * 32 + y * 4 + (x >> 1)]
	return (b >> 4) if (x & 1) == 0 else (b & 15)

def sprite_pixel(spr, quarter, code, x, y):
	"""16x16 sprites: row r comes from quarter (3 - r%4) at code*32 + (r//4)*8; x pairs swapped."""
	n = x ^ 1
	b = spr[(3 - (y & 3)) * quarter + code * 32 + (y >> 2) * 8 + (n >> 1)]
	return (b >> 4) if (n & 1) == 0 else (b & 15)

def render(cfg, ram, regs, flipy_hack=False):
	tricky = cfg["tricky"]
	bg_scroll, fg_scroll_raw, latch = regs
	bank = 0 if tricky else (((latch >> 5) & 1) << 4) | (((latch >> 6) & 1) << 5)
	flip = (latch >> (1 if tricky else 0)) & 1
	if flip:
		raise SystemExit("flip_screen set in dump: not modelled yet")
	spr_ram = ram[0x0800:0x0c00]
	bgv, bgc = ram[0x1000:0x1400], ram[0x1400:0x1800]
	fgv, fgc = ram[0x1800:0x1c00], ram[0x1c00:0x2000]
	scroll_map = [2, 1, 4, 3, 6, 5, 0, 7]
	fg_scroll = (fg_scroll_raw & 0xf8) | scroll_map[fg_scroll_raw & 7] if os.environ.get("FGPERM", "1") == "1" else fg_scroll_raw
	bitmap = [[-1] * 256 for _ in range(256)]   # pen index per pixel, -1 = undrawn

	def layer(vram, cram, gfx, scroll, transparent):
		for y in range(256):
			for x in range(256):
				sx = (x + SCROLL_SIGN * scroll) & 255
				col, row = sx >> 3, y >> 3
				idx = col * 32 + row      # TILEMAP_SCAN_COLS
				attr = cram[idx]
				code = vram[idx] + ((attr & 7) << 8)
				color = ((attr >> 4) & 15) | bank
				tx = sx & 7
				if attr & 8:
					tx = 7 - tx
				p = tile_pixel(gfx, code, tx, y & 7)
				if transparent and p == 0:
					continue
				bitmap[y][x] = color * 16 + p
	layer(bgv, bgc, cfg["bg_gfx"], bg_scroll + BG_OFF, False)  # noqa
	if cfg["fg_gfx"] is not None:
		layer(fgv, fgc, cfg["fg_gfx"], fg_scroll + FG_OFF, True)

	for offs in range(3, 0x400 - 1, 4):
		sy = spr_ram[offs]
		attr = spr_ram[offs + 3]
		if tricky:
			if flipy_hack and (attr & 8):
				sy += 6
			code = spr_ram[offs + 1] + ((attr & 1) << 8)
			sx = spr_ram[offs + 2] - 2
			color = (attr >> 4) & 15
			sy = 236 - sy
			ext = attr & 2
			flipx, flipy = bool(attr & 4), bool(attr & 8) and not flipy_hack
		else:
			if sy == 0xf8:
				continue
			code = spr_ram[offs + 1] + ((attr & 3) << 8)
			sx = spr_ram[offs + 2]
			sy = 236 - sy
			color = ((attr >> 4) & 15) | bank
			ext = attr & 8
			flipx, flipy = bool(attr & 4), False
		if ext:
			if sx > 0xc0:
				sx = sx - 256 if sx >= 128 else sx     # int8 sign extension
		else:
			if sx < 0x40:
				continue
		sx += SPR_DX
		sy += SPR_DY
		for yy in range(16):
			py = sy + yy
			if not (0 <= py < 256):
				continue
			for xx in range(16):
				px = sx + xx
				if not (0 <= px < 256):
					continue
				p = sprite_pixel(cfg["spr_gfx"], cfg["quarter"], code,
					15 - xx if flipx else xx, 15 - yy if flipy else yy)
				if p:
					bitmap[py][px] = color * 16 + p
	return [[bitmap[Y0 + y][X0 + x] for x in range(W)] for y in range(H)]

def write_png(path, rows):
	raw = b"".join(b"\x00" + bytes(v for px_ in row for v in px_) for row in rows)
	def chunk(t, d):
		c = struct.pack(">I", len(d)) + t + d
		return c + struct.pack(">I", zlib.crc32(t + d))
	with open(path, "wb") as f:
		f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
			+ chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))

def main():
	rom_dir, name, dump = sys.argv[1], sys.argv[2], sys.argv[3]
	cfg = dict(SETS[name])
	if True:
		z = Zips(rom_dir, name, *(["sauro"] if name == "seawolft" else []))
		cfg["bg_gfx"] = load_region(z, cfg["bg"], 0x10000)
		cfg["fg_gfx"] = load_region(z, cfg["fg"], 0x10000) if cfg["fg"] else None
		cfg["spr_gfx"] = load_region(z, cfg["spr"], cfg["spr_size"])
		cfg["quarter"] = cfg["spr_size"] // 4
		proms = load_region(z, cfg["proms"], 0xc00)
	d = open(dump, "rb").read()
	ram = d[:8192]
	regs = (d[8192], d[8193], d[8194])
	px = d[8208:8208 + W * H * 4]
	pens = render(cfg, ram, regs, "--flipy-hack" in sys.argv)

	def mame_rgb(x, y):
		b, g, r = px[(y * W + x) * 4:(y * W + x) * 4 + 3]
		return (r, g, b)

	# Functional dependency: (channel, PROM nibble) -> observed 8-bit value, per channel
	maps = [collections.defaultdict(collections.Counter) for _ in range(3)]
	undrawn = 0
	for y in range(H):
		for x in range(W):
			pen = pens[y][x]
			if pen < 0:
				undrawn += 1
				continue
			for ch, val in enumerate(mame_rgb(x, y)):
				maps[ch][proms[ch * 0x400 + pen] & 15][val] += 1
	lut = [{k: c.most_common(1)[0][0] for k, c in m.items()} for m in maps]
	bad_cells = collections.Counter()
	bad = 0
	for y in range(H):
		for x in range(W):
			pen = pens[y][x]
			if pen < 0:
				continue
			for ch, val in enumerate(mame_rgb(x, y)):
				if lut[ch][proms[ch * 0x400 + pen] & 15] != val:
					bad += 1
					bad_cells[(y // 16, x // 16)] += 1
	if os.environ.get("DEBUG"):
		print("bad 16x16 cells (row,col):count", sorted(bad_cells.items()))
	if os.environ.get("PNG"):
		write_png(os.environ["PNG"] + "_mame.png", [[mame_rgb(x, y) for x in range(W)] for y in range(H)])
		write_png(os.environ["PNG"] + "_model.png", [[tuple(lut[ch].get(proms[ch * 0x400 + max(pens[y][x], 0)] & 15, 128)
			for ch in range(3)) for x in range(W)] for y in range(H)])
	if os.environ.get("PNG"):
		def diff_px(x, y):
			pen = pens[y][x]
			bad_px = pen >= 0 and any(lut[ch][proms[ch * 0x400 + pen] & 15] != v for ch, v in enumerate(mame_rgb(x, y)))
			return (255, 0, 255) if bad_px else tuple(v // 3 for v in mame_rgb(x, y))
		write_png(os.environ["PNG"] + "_diff.png", [[diff_px(x, y) for x in range(W)] for y in range(H)])
	total = (W * H - undrawn) * 3
	print(f"{name} {pathlib.Path(dump).name}: undrawn pixels {undrawn}, inconsistent channel samples {bad}/{total}")
	for ch, m in zip("RGB", lut):
		print(ch, dict(sorted(m.items())))
	sys.exit(1 if bad or undrawn else 0)

if __name__ == "__main__":
	main()
