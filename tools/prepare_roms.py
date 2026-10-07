"""Assemble local ROM images for simulation from MAME zips (never committed).

Writes simulation/roms/<set>_main.hex (64 KB program image, one hex byte per line).
Usage: python -I tools/prepare_roms.py <romdir>
"""
import pathlib, sys, zipfile

LAYOUT = {  # set -> [(file, offset)] for the main CPU program image
	"sauro":    [("sauro-2.bin", 0x0000), ("sauro-1.bin", 0x8000)],
	"seawolft": [("1.bin", 0x0000), ("2.bin", 0x8000)],
	"trckydoc": [("trckydoc.d9", 0x0000), ("trckydoc.b9", 0x8000)],
}

def main(rom_dir):
	out = pathlib.Path(__file__).resolve().parent.parent / "simulation" / "roms"
	out.mkdir(parents=True, exist_ok=True)
	for name, parts in LAYOUT.items():
		image = bytearray(0x10000)
		with zipfile.ZipFile(pathlib.Path(rom_dir) / f"{name}.zip") as z:
			for fname, off in parts:
				data = z.read(fname)
				image[off:off + len(data)] = data
		(out / f"{name}_main.hex").write_text("".join(f"{b:02x}\n" for b in image))
		print(name, "ok")

if __name__ == "__main__":
	main(sys.argv[1])
