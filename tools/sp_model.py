"""Sample-count model of the SP0256 microsequencer (port of MAME 0.257 sp0256.cpp micro()/lpc12 timing).
Variants of the excitation timing:
  mame : impulse spacing per+1, interp once per period (MAME as written)
  doc  : impulse spacing per (Zbiciak/CPCWiki: 'pitch=91: one HIGH sample followed by 90 zero samples'),
         interp once per period, noise/pause 64
  ivo  : ivoice.vhd as written: spacing per, interp every sample, PAUSE only clears AM (PR/IA/IP stale)
Usage: python -I sp_model.py al2rom.hex [variant] [allophones...]
"""
import re, sys, pathlib

SRC = pathlib.Path(__file__).resolve().parents[2] / "docs" / "reference" / "mame" / "sp0256.cpp"
txt = SRC.read_text()
SYM = dict(AM=0, PR=1, B0=2, F0=3, B1=4, F1=5, B2=6, F2=7, B3=8, F3=9, B4=10, F4=11, B5=12, F5=13, IA=14, IP=15)
body = txt[txt.index("sp0256_datafmt[] ="):txt.index("sp0256_df_idx")]
DF = []
for m in re.finditer(r"/\*\s+\d+ \*/\s*(?:CR\(\s*([^)]*)\)|0,)", body):
	if m.group(1) is None: DF.append([0] * 7); continue
	a = [int(SYM.get(x.strip(), x.strip()) if x.strip() in SYM else x.strip()) for x in m.group(1).split(",")]
	DF.append(a)  # len, shf, prm, delta, field, clr5, clra
idxb = txt[txt.index("sp0256_df_idx[16 * 8]"):]
idxb = idxb[idxb.index("{") + 1:idxb.index("};")]
IDX = [int(x) for x in re.findall(r"-?\d+", re.sub(r"/\*.*?\*/", "", idxb))]
assert len(DF) == 177 and len(IDX) == 128, (len(DF), len(IDX))

def bitrev(v, n):
	return int(f"{v:0{n}b}"[::-1], 2)

class SP:
	def __init__(s, rom, var):
		s.rom, s.var = rom, var
	def getb(s, n):
		i = (s.pc >> 3) - 0x1000
		d = (s.rom[(i + 1) % 2048] << 8 | s.rom[i % 2048]) >> (s.pc & 7)
		s.pc += n
		return d & ((1 << n) - 1)
	def run(s, allo, r=None, trace=False):
		"""returns total samples for one allophone, plus frame list"""
		s.pc = (allo << 4) | (0x1000 << 3)
		s.r = [0] * 16 if r is None else r
		page, stack, mode = 0x1000 << 3, 0, 0
		total, frames = 0, []
		while True:
			immed4, op = s.getb(4), s.getb(4)
			rep, xfer = 0, False
			if op == 0:
				if immed4: page = bitrev(immed4, 4) << 15  # bitrev32(immed4)>>13
				else:
					if not stack:
						if s.var == "ivo": total += s.r[1] or 64  # ivoice: halting RTS still runs sGENE for a period
						break
					s.pc, stack, xfer = stack, 0, True
			elif op in (0xE, 0xD):
				btrg = page | (bitrev(immed4, 4) << 11) | (bitrev(s.getb(8), 8) << 3)
				if op == 0xD: stack = (s.pc + 7) & ~7
				s.pc, xfer = btrg, True
			elif op == 1:
				mode = ((immed4 & 8) >> 2) | (immed4 & 4) | ((immed4 & 3) << 4)
			else:
				rep = immed4 | (mode & 0x30)
			if op != 1: mode &= 0xF
			if (xfer or not rep) and s.var == "ivo": total += s.r[1] or 64  # ivoice: control op runs sGENE for a period
			if xfer or not rep: continue
			i = (op << 3) | (mode & 6)
			for k in range(IDX[i], IDX[i + 1] + 1):
				ln, sh, prm, de, fi, c5, ca = DF[k]
				if ca and not (s.var[:3] == "ivo" and op == 0xF): s.r = [0] * 16
				if ca and s.var[:3] == "ivo" and op == 0xF: s.r[0] = 0
				if c5: s.r[12] = s.r[13] = 0
				if not ln: continue
				v = s.getb(ln)
				if de and v & (1 << (ln - 1)): v -= 1 << ln
				v = (v << sh) & 0xFF
				if fi: s.r[prm] = (s.r[prm] & ~(0xFF << sh) & 0xFF) | v
				elif de: s.r[prm] = (s.r[prm] + v) & 0xFF
				else: s.r[prm] = v
			if op == 0xF and s.var[:3] != "ivo": s.r[1] = 64
			n = s.frame(rep)
			frames.append((op, rep, s.r[1], s.r[14], s.r[15], n))
			total += n
		return total, frames
	def frame(s, rep):
		r, var = s.r, s.var
		if var[:3] == "ivo":
			# ivoice: count reload PR-1 at pulse (PR samples/period), 64 for noise; repeat counted in periods;
			# IP/IA added to PR/AM every sample (sGENE2/sGENE4)
			n, cnt = 0, 0
			periods = 0
			while True:
				pr = r[1]
				if cnt == 0:
					periods += 1
					if periods > rep: break
				if pr == 0: cnt = cnt - 1 if cnt > 0 else 63
				else: cnt = cnt - 1 if cnt > 0 else pr - 1
				r[1] = (r[1] + r[15]) & 0xFF
				r[0] = (r[0] + r[14]) & 0xFF
				n += 1
			return n
		rpt, cnt, per, n = rep + 1, 0, r[1], 0
		interp = r[14] or r[15]
		plus = 1 if var == "mame" else 0
		while True:
			do = False
			if per:
				if cnt <= 0:
					cnt += per - 1 + plus if plus == 0 else per
					rpt -= 1; do = interp
					if plus == 0: pass
				else: cnt -= 1
			else:
				cnt -= 1
				if cnt <= 0: cnt, do = 64, interp; rpt -= 1
			if do:
				r[0] = (r[0] + r[14]) & 0xFF; r[1] = (r[1] + r[15]) & 0xFF; per = r[1]
			if rpt <= 0: break
			n += 1
		return n

if __name__ == "__main__":
	rom = [int(l, 16) for l in open(sys.argv[1]).read().split()]
	var = sys.argv[2] if len(sys.argv) > 2 else "mame"
	al = [int(a, 16) for a in sys.argv[3:]] or [0x28, 0x14, 0x00, 0x29, 0x04, 0x38, 0x1b, 0x07, 0x2d, 0x3b, 0x2c, 0x0d, 0x37, 0x0c]
	sp = SP(rom, var)
	sp.r = [0] * 16
	for a in al:
		t, fr = sp.run(a, sp.r if var == 'ivo' else None)
		print(f"{a:02x} {t:6d} samp {t / 12820.5 * 1000:7.1f} ms  " + " ".join(f"[op{o:x} r{rp} p{p} ia{ia} ip{ip} n{n}]" for o, rp, p, ia, ip, n in fr))
