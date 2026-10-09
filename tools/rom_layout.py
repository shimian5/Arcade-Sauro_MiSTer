"""ROM download layout for the Sauro core (source of truth for images and MRA files).

Offsets and sizes follow rtl/sauro_core.sv. File names, sizes and CRCs are from MAME 0.257
sauro.cpp (docs/reference/mame). Split sets keep shared ROMs in the parent zip under the
parent's file names, so each part names the zip that holds it.
"""
import binascii, hashlib, pathlib, zipfile

IMAGE_SIZE = 0x59400

# (zip, file name, image offset, size, crc32)
_SAURO_COMMON = [
	("sauro", "sauro-3.bin",    0x10000, 0x8000, 0x0d501e1b),   # audio CPU
	("sauro", "82s137-3.bin",   0x58000, 0x0400, 0xd52c4cd0),   # red PROM
	("sauro", "82s137-2.bin",   0x58400, 0x0400, 0xc3e96d5d),   # green PROM
	("sauro", "82s137-1.bin",   0x58800, 0x0400, 0xbdfcf00c),   # blue PROM
	("sauro", "sp0256-al2.bin", 0x58c00, 0x0800, 0xb504ac15),   # SP0256 internal ROM
]

SETS = {
	"sauro": dict(tricky=0, title="Sauro", parts=[
		("sauro", "sauro-2.bin",  0x00000, 0x8000, 0x2e356e2d),
		("sauro", "sauro-1.bin",  0x08000, 0x8000, 0x95d03e5e),
		("sauro", "sauro-6.bin",  0x18000, 0x8000, 0x4b77cb0f),
		("sauro", "sauro-7.bin",  0x20000, 0x8000, 0x187da060),
		("sauro", "sauro-4.bin",  0x28000, 0x8000, 0x9b617cda),
		("sauro", "sauro-5.bin",  0x30000, 0x8000, 0xa6e2640d),
		("sauro", "sauro-8.bin",  0x38000, 0x8000, 0xe08b5d5e),
		("sauro", "sauro-9.bin",  0x40000, 0x8000, 0x7c707195),
		("sauro", "sauro-10.bin", 0x48000, 0x8000, 0xc93380d1),
		("sauro", "sauro-11.bin", 0x50000, 0x8000, 0xf47982a8),
	] + _SAURO_COMMON),
	"seawolft": dict(tricky=0, title="Sea Wolf (Tecfri)", parent="sauro", parts=[
		("seawolft", "1.bin",       0x00000, 0x8000, 0xbd8bd328),
		("seawolft", "2.bin",       0x08000, 0x8000, 0x870b05ef),
		("sauro",    "sauro-6.bin", 0x18000, 0x8000, 0x4b77cb0f),
		("seawolft", "3.bin",       0x20000, 0x8000, 0x883bb7d1),
		("sauro",    "sauro-4.bin", 0x28000, 0x8000, 0x9b617cda),
		("sauro",    "sauro-5.bin", 0x30000, 0x8000, 0xa6e2640d),
		("seawolft", "10.bin",      0x38000, 0x8000, 0xb93f5487),
		("seawolft", "9.bin",       0x40000, 0x8000, 0x0964ac95),
		("seawolft", "8.bin",       0x48000, 0x8000, 0xe71726a9),
		("seawolft", "7.bin",       0x50000, 0x8000, 0x8a700276),
	] + _SAURO_COMMON),
	"trckydoc": dict(tricky=1, title="Tricky Doc", parts=[
		("trckydoc", "trckydoc.d9", 0x00000, 0x8000, 0xc6242fc3),
		("trckydoc", "trckydoc.b9", 0x08000, 0x8000, 0x8645c840),
		("trckydoc", "trckydoc.e6", 0x18000, 0x8000, 0xec326392),
		("trckydoc", "trckydoc.g6", 0x20000, 0x8000, 0x6a65c088),
		("trckydoc", "trckydoc.h1", 0x38000, 0x4000, 0x8b73cbf3),
		("trckydoc", "trckydoc.e1", 0x3c000, 0x4000, 0x841be98e),
		("trckydoc", "trckydoc.c1", 0x40000, 0x4000, 0x1d25574b),
		("trckydoc", "trckydoc.a1", 0x44000, 0x4000, 0x436c59ba),
		("trckydoc", "tdclr3.prm",  0x58000, 0x0100, 0x671d0140),
		("trckydoc", "tdclr2.prm",  0x58400, 0x0100, 0x874f9050),
		("trckydoc", "tdclr1.prm",  0x58800, 0x0100, 0x57f127b0),
	]),
}

def build_image(rom_dir, name):
	"""Assemble the download image from MAME zips, verifying every file's size and CRC."""
	image = bytearray(IMAGE_SIZE)
	zips = {}
	for zname, fname, off, size, crc in SETS[name]["parts"]:
		z = zips.setdefault(zname, zipfile.ZipFile(pathlib.Path(rom_dir) / f"{zname}.zip"))
		data = z.read(fname)
		if len(data) != size or binascii.crc32(data) != crc:
			raise SystemExit(f"{zname}/{fname}: size/CRC mismatch (got {len(data):#x}, {binascii.crc32(data):08x})")
		image[off:off + size] = data
	return bytes(image)

def image_md5(image):
	return hashlib.md5(image).hexdigest()
