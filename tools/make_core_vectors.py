"""Write simulation vectors for sim/tb_core.sv: the assembled download image as hex, plus
MAME's expected frame (RRGGBB) for each requested interrupt count from existing dumps.

Usage: python -I tools/make_core_vectors.py <romdir> <set> <outdir> [<dump.bin> ...]
Dumps are simulation/frames/<prefix><set>_<N>.bin; N is the interrupt-entry count.
"""
import pathlib, re, sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import rom_layout as rl

W, H = 240, 224

def main():
	rom_dir, name, outdir = sys.argv[1:4]
	out = pathlib.Path(outdir)
	out.mkdir(parents=True, exist_ok=True)
	image = rl.build_image(rom_dir, name)
	(out / f"{name}_image.hex").write_text("".join(f"{b:02x}\n" for b in image))
	args = []
	for dump in sys.argv[4:]:
		n = int(re.search(r"_(\d+)\.bin$", dump).group(1))
		d = open(dump, "rb").read()
		px = d[8208:8208 + W * H * 4]
		lines = "".join(f"{px[i*4+2]:02x}{px[i*4+1]:02x}{px[i*4]:02x}\n" for i in range(W * H))
		(out / f"{name}_expected_{n}.hex").write_text(lines)
		args.append(f"+F{len(args)}={n}")
	print(f"image md5 {rl.image_md5(image)} tricky={rl.SETS[name]['tricky']}")
	print(" ".join(args + (["+TRICKY"] if rl.SETS[name]["tricky"] else [])))

main()
