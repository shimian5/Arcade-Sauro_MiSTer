"""Turn a MAME frame dump into Verilator test vectors for sim/tb_video.sv.

Writes into <outdir>: spr/bgv/bgc/fgv/fgc.hex (1 KB each), bg/fg/spr_gfx.hex, prom_r/g/b.hex,
plusargs.txt (register values and options), expected.hex (240x224, RRGGBB per pixel, taken
straight from MAME's rendered frame).

Usage: python -I tools/prep_video_vectors.py <romdir> <set> <dump.bin> <outdir>
"""
import os, pathlib, sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import video_ref as vr

def hexfile(path, data):
	pathlib.Path(path).write_text("".join(f"{b:02x}\n" for b in data))

def main():
	rom_dir, name, dump, outdir = sys.argv[1:5]
	out = pathlib.Path(outdir)
	out.mkdir(parents=True, exist_ok=True)
	cfg = dict(vr.SETS[name])
	z = vr.Zips(rom_dir, name, *(["sauro"] if name == "seawolft" else []))
	bg = vr.load_region(z, cfg["bg"], 0x10000)
	fg = vr.load_region(z, cfg["fg"], 0x10000) if cfg["fg"] else bytearray(0x10000)
	spr = vr.load_region(z, cfg["spr"], 0x20000 if not cfg["tricky"] else 0x10000)
	if cfg["tricky"]:
		spr = spr + bytearray(0x10000)
	proms = vr.load_region(z, cfg["proms"], 0xc00)
	d = open(dump, "rb").read()
	ram = d[:8192]
	bgs, fgs, latch = d[8192], d[8193], d[8194]
	hexfile(out / "spr.hex", ram[0x0800:0x0c00])
	hexfile(out / "bgv.hex", ram[0x1000:0x1400])
	hexfile(out / "bgc.hex", ram[0x1400:0x1800])
	hexfile(out / "fgv.hex", ram[0x1800:0x1c00])
	hexfile(out / "fgc.hex", ram[0x1c00:0x2000])
	hexfile(out / "bg.hex", bg)
	hexfile(out / "fg.hex", fg)
	hexfile(out / "spr_gfx.hex", spr)
	hexfile(out / "prom_r.hex", proms[0x000:0x400])
	hexfile(out / "prom_g.hex", proms[0x400:0x800])
	hexfile(out / "prom_b.hex", proms[0x800:0xc00])
	tricky = cfg["tricky"]
	bank = 0 if tricky else ((latch >> 5) & 3)
	flip = (latch >> (1 if tricky else 0)) & 1
	if flip:
		raise SystemExit("flip_screen set in dump: not supported")
	args = f"+BG={bgs} +FG={fgs} +BANK={bank}" + (" +TRICKY" if tricky else "")
	(out / "plusargs.txt").write_text(args + "\n")
	px = d[8208:8208 + vr.W * vr.H * 4]
	lines = []
	for i in range(vr.W * vr.H):
		b, g, r = px[i * 4:i * 4 + 3]
		lines.append(f"{r:02x}{g:02x}{b:02x}\n")
	(out / "expected.hex").write_text("".join(lines))
	print("wrote", out, args)

main()
