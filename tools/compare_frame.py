"""Compare the RTL frame (RRGGBB lines) with MAME's expected frame, pixel for pixel.
Usage: python -I tools/compare_frame.py <expected.hex> <rtl_frame.hex> [png_prefix]
"""
import struct, sys, zlib

W, H = 240, 224

def read(path):
	return [int(l, 16) for l in open(path) if l.strip()]

def png(path, rows):
	raw = b"".join(b"\x00" + bytes(v for p in row for v in p) for row in rows)
	def chunk(t, d):
		c = struct.pack(">I", len(d)) + t + d
		return c + struct.pack(">I", zlib.crc32(t + d))
	open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
		+ chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))

exp, got = read(sys.argv[1]), read(sys.argv[2])
if len(exp) != W * H or len(got) != W * H:
	print(f"FAIL: sizes expected {len(exp)} rtl {len(got)}"); sys.exit(1)
bad = [i for i in range(W * H) if exp[i] != got[i]]
print(f"{'PASS' if not bad else 'FAIL'}: {len(bad)} of {W * H} pixels differ")
for i in bad[:8]:
	print(f"  x={i % W} y={i // W} expected {exp[i]:06x} rtl {got[i]:06x}")
if len(sys.argv) > 3:
	rgb = lambda v: ((v >> 16) & 255, (v >> 8) & 255, v & 255)
	png(sys.argv[3] + "_rtl.png", [[rgb(got[y * W + x]) for x in range(W)] for y in range(H)])
	png(sys.argv[3] + "_diff.png", [[(255, 0, 255) if exp[y * W + x] != got[y * W + x] else tuple(c // 3 for c in rgb(exp[y * W + x]))
		for x in range(W)] for y in range(H)])
sys.exit(1 if bad else 0)
