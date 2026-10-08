"""Per-allophone durations for the same allophone sequences under MAME's SP0256, ivoice.vhd (Intv_MiSTer) and
Speech256 (trcwm), derived from the times at which the driver wrote each byte.

MAME and ivoice hold one allophone ahead (the chip accepts the next byte as soon as it starts the current one),
so write k+2 happens when allophone k ends: duration(k) = t(w[k+2]) - t(w[k+1]); the first is t(w[2]) - t(w[0]).
Speech256 has no look-ahead: write k+1 happens when allophone k ends: duration(k) = t(w[k+1]) - t(w[k]).
The last two (MAME, ivoice) or last one (Speech256) allophones of a sequence have no end marker.

Reads: simulation/audio/mame_speech_seq<q>.txt, simulation/ivoice/writes_seq<q>.txt, simulation/speech_<q>.log
Usage: python -I tools/speech_timing.py
"""
import pathlib, re

SEQS = {0: "28 28 14 00 29 04 38 20 00".split(), 1: "1b 07 2d 20 00".split(), 2: "28 3b 2c 0d 3b 37 0d 0c 29 00".split()}
root = pathlib.Path(__file__).resolve().parent.parent / "simulation"

def read_mame(q):
	return [float(m.group(1)) * 1000 for m in (re.match(r"([\d.]+) write", l) for l in open(root / "audio" / f"mame_speech_seq{q}.txt")) if m]

def read_ivoice(q):
	f = root / "ivoice" / f"writes_seq{q}.txt"
	return [int(m.group(1)) / 1000 for m in (re.match(r"(\d+) us write", l) for l in open(f)) if m] if f.exists() else []

def read_s256(q):
	return [int(m.group(1)) / 1000 for m in (re.match(r"write \w+ at (\d+) us", l) for l in open(root / f"speech_{q}.log")) if m]

def durations(t, ahead):
	d = {}
	if ahead:
		if len(t) > 2: d[0] = t[2] - t[0]
		for k in range(1, len(t) - 2): d[k] = t[k + 2] - t[k + 1]
	else:
		for k in range(len(t) - 1): d[k] = t[k + 1] - t[k]
	return d

for q, seq in SEQS.items():
	m, i, s = durations(read_mame(q), True), durations(read_ivoice(q), True), durations(read_s256(q), False)
	print(f"sequence {q}: {' '.join(seq)}")
	print(f"  {'idx':>3} {'allo':>4} {'MAME ms':>8} {'ivoice ms':>10} {'iv/MAME':>8} {'Speech256 ms':>13} {'s256/MAME':>10}")
	for k in range(len(seq)):
		a = m.get(k); b = i.get(k); c = s.get(k)
		f = lambda v: f"{v:8.1f}" if v is not None else "       -"
		r = lambda x, y: f"{x / y:8.2f}" if x is not None and y else "       -"
		print(f"  {k:>3} {seq[k]:>4} {f(a)} {f(b):>10} {r(b, a):>8} {f(c):>13} {r(c, a):>10}")
