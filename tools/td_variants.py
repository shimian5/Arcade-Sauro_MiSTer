"""Render a Tricky Doc frame dump under both readings of sprite attribute bit 3 and write PNGs.

  variant A (MAME 0.288):  bit 3 = flip y, sprite at y = 236 - b0
  variant B (MAME 0.257):  bit 3 = move the sprite up by 6 pixels (y = 236 - (b0 + 6)), no flip

Colours use the PROMs and MAME's 14/31/67/143 weighting for both, so the images differ only in the
sprites. Writes <prefix>_A.png, <prefix>_B.png, <prefix>_diff.png (changed pixels in magenta) and prints
the sprites that use bit 3.
Usage: python -I tools/td_variants.py <romdir> <dump.bin> <prefix>
"""
import pathlib, sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import video_ref as vr

def level(n):
	return (14 if n & 1 else 0) + (31 if n & 2 else 0) + (67 if n & 4 else 0) + (143 if n & 8 else 0)

def main():
	rom_dir, dump, prefix = sys.argv[1:4]
	cfg = dict(vr.SETS["trckydoc"])
	z = vr.Zips(rom_dir, "trckydoc")
	cfg["bg_gfx"] = vr.load_region(z, cfg["bg"], 0x10000)
	cfg["fg_gfx"] = None
	cfg["spr_gfx"] = vr.load_region(z, cfg["spr"], cfg["spr_size"])
	cfg["quarter"] = cfg["spr_size"] // 4
	proms = vr.load_region(z, cfg["proms"], 0xc00)
	d = open(dump, "rb").read()
	ram, regs = d[:8192], (d[8192], d[8193], d[8194])
	imgs = {}
	for name, hack in (("A", False), ("B", True)):
		pens = vr.render(cfg, ram, regs, hack)
		imgs[name] = [[tuple(level(proms[ch * 0x400 + pens[y][x]] & 15) for ch in range(3)) for x in range(vr.W)] for y in range(vr.H)]
		vr.write_png(f"{prefix}_{name}.png", imgs[name])
	diff = [[(255, 0, 255) if imgs["A"][y][x] != imgs["B"][y][x] else tuple(c // 3 for c in imgs["A"][y][x]) for x in range(vr.W)] for y in range(vr.H)]
	vr.write_png(f"{prefix}_diff.png", diff)
	import os
	if os.environ.get("CROP"):   # "x0,y0,x1,y1,scale": zoomed A | B side by side
		x0, y0, x1, y1, k = (int(v) for v in os.environ["CROP"].split(","))
		def zoom(img):
			return [[img[y][x] for x in range(x0, x1) for _ in range(k)] for y in range(y0, y1) for _ in range(k)]
		za, zb = zoom(imgs["A"]), zoom(imgs["B"])
		sep = [(255, 255, 255)] * 4
		side = [ra + sep + rb for ra, rb in zip(za, zb)]
		save_w, save_h = vr.W, vr.H
		vr.W, vr.H = len(side[0]), len(side)
		vr.write_png(f"{prefix}_zoom.png", side)
		vr.W, vr.H = save_w, save_h
	n = sum(1 for y in range(vr.H) for x in range(vr.W) if imgs["A"][y][x] != imgs["B"][y][x])
	print(f"{pathlib.Path(dump).name}: {n} pixels differ between the two readings")
	spr = ram[0x800:0xc00]
	for offs in range(3, 0x3ff, 4):
		at = spr[offs + 3]
		if at & 8:
			sx = spr[offs + 2] - 2
			if at & 2:
				if sx > 0xc0: sx -= 256
			elif sx < 0x40:
				continue
			sy = 236 - spr[offs]
			if -16 < sy < 240 and -16 < sx < 256:
				print(f"  bit-3 sprite: code {spr[offs + 1] + ((at & 1) << 8)}, x={sx - 8}, y={sy - 16} (visible-area coordinates), flipx={bool(at & 4)}")

main()
