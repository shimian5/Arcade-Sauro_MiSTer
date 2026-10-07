"""Generate the MRA files from tools/rom_layout.py (offsets, sizes, CRCs) and the real ROM zips.

The assembled-image MD5 is computed from the actual ROM files, so a wrong CRC, size or offset
fails here instead of on hardware. Output: releases/*.mra (no ROM payloads are written).
Usage: python -I tools/make_mra.py <romdir> [outdir]
"""
import datetime, pathlib, sys
from xml.sax.saxutils import escape

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import rom_layout as rl

# Test builds carry a leading "_" so they sort to the top of the MiSTer menu; remove it for release.
META = {
	"sauro":    dict(file="_Sauro.mra",              year=1987, category="Shooter", zips="sauro.zip"),
	"seawolft": dict(file="_Sea Wolf (Tecfri).mra",  year=1987, category="Shooter", zips="seawolft.zip|sauro.zip"),
	"trckydoc": dict(file="_Tricky Doc.mra",         year=1987, category="Platform", zips="trckydoc.zip"),
}

# DIP switches from MAME's INPUT_PORTS tecfri (bit n of DSW1 = bit n, DSW2 = bit 8+n; values listed
# in increasing numeric order). Default bytes 66 / 2F are MAME's defaults.
DIPS = [
	('1',   "Service",        "Off,On"),
	('2',   "Demo Sounds",    "Off,On"),
	('3',   "Cabinet",        "Cocktail,Upright"),
	('4',   "Free Play",      "Off,On"),
	('5,6', "Difficulty",     "Very Hard,Hard,Easy,Very Easy"),
	('7',   "Allow Continue", "No,Yes"),
	('8',   "Freeze",         "Off,On"),
	('9,10',  "Coin A",       "4C/1C,3C/1C,2C/1C,1C/1C"),
	('11,12', "Coin B",       "1C/5C,1C/4C,1C/3C,1C/2C"),
	('13,14', "Lives",        "5,4,3,2"),
]

def parts_xml(name, image_size):
	out, pos = [], 0
	for zname, fname, off, size, crc in sorted(rl.SETS[name]["parts"], key=lambda p: p[2]):
		if off > pos:
			out.append(f'\t\t<part repeat="0x{off - pos:X}">00</part>')
		out.append(f'\t\t<part name="{escape(fname)}" crc="{crc:08x}" length="0x{size:X}" />')
		pos = off + size
	if pos < image_size:
		out.append(f'\t\t<part repeat="0x{image_size - pos:X}">00</part>')
	return "\n".join(out)

def main():
	rom_dir = sys.argv[1]
	out_dir = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else pathlib.Path(__file__).resolve().parent.parent / "releases"
	out_dir.mkdir(parents=True, exist_ok=True)
	stamp = datetime.date.today().strftime("%Y%m%d")
	for name, meta in META.items():
		image = rl.build_image(rom_dir, name)
		md5 = rl.image_md5(image)
		dips = "\n".join(f'\t\t<dip bits="{b}" name="{n}" ids="{ids}" />' for b, n, ids in DIPS)
		text = f"""<?xml version='1.0' encoding='utf-8'?>
<misterromdescription>
	<name>{escape(rl.SETS[name]['title'])}</name>
	<setname>{name}</setname>
	<mratimestamp>{stamp}</mratimestamp>
	<mameversion>0257</mameversion>
	<year>{meta['year']}</year>
	<manufacturer>Tecfri</manufacturer>
	<category>{meta['category']}</category>
	<rbf>Tecfri</rbf>
	<rotation>horizontal</rotation>
	<!--Development core: video and game CPU implemented; sound and NVRAM saving are not yet implemented.-->
	<romstruct>00000-0FFFF: main CPU; 10000-17FFF: audio CPU; 18000-27FFF: bg tiles; 28000-37FFF: fg tiles; 38000-57FFF: sprites; 58000-58BFF: colour PROMs R,G,B; 58C00-593FF: SP0256 ROM.</romstruct>
	<rom index="0" zip="{meta['zips']}" md5="{md5}" type="split">
{parts_xml(name, rl.IMAGE_SIZE)}
	</rom>
	<rom index="1"><part>{rl.SETS[name]['tricky']:02X}</part></rom>
	<switches default="66,2F" base="1" page_id="1" page_name="Switches">
{dips}
	</switches>
	<buttons names="Button 1,Button 2,Start 1P,Start 2P,Coin,Pause" default="A,B,Start,Select,R,L" />
</misterromdescription>
"""
		(out_dir / meta["file"]).write_text(text, encoding="utf-8")
		print(f"{meta['file']}: image md5 {md5}")

main()
