"""Waveform match of an SP0256 candidate against MAME's speech-only capture of the same allophone sequence.

Both signals are band-limited with the same low-pass (the SP0256's 5 kHz bandwidth, datasheet) so that the candidate's
sample-and-hold stair-steps do not matter. The candidate is time-scaled by a factor s to absorb MAME's different sample
clock (MAME divides the chip clock by 336, the documentation implies 312: s about 1.077) and the best normalised
cross-correlation over (s, lag) is reported for a window starting at the first write. 1.0 means identical shape;
the sign is kept so an inverted waveform shows as negative.

Usage: python -I tools/waveform_match.py <mame.wav> <mame_first_write_s> <cand_samples.txt> <cand_first_write_s> [win_ms=60]
  cand_samples.txt: lines "<time_ns> <value>" at every change of the candidate's output (ivoice testbench log)
  or a .raw file of 16-bit LE PCM (Speech256 testbench) with its sample rate given as 5th arg (default 47994).
"""
import sys, wave
import numpy as np

FS = 48000

def lowpass(x, fc=5000.0, taps=401):
	n = np.arange(taps) - (taps - 1) / 2
	h = np.sinc(2 * fc / FS * n) * np.hamming(taps)
	h /= h.sum()
	return np.convolve(x, h, mode="same")

def load_mame(path):
	w = wave.open(path)
	return np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(float)

def candidate_fn(path, rate):
	if path.endswith(".raw"):
		v = np.frombuffer(open(path, "rb").read(), dtype="<i2").astype(float)
		t = np.arange(len(v)) / rate
		return lambda tt: v[np.clip(np.searchsorted(t, tt, side="right") - 1, 0, len(v) - 1)]
	t, v = [], []
	for line in open(path):
		a, b = line.split()
		t.append(int(a) / 1e9); v.append(float(b))
	t, v = np.array(t), np.array(v)
	return lambda tt: v[np.clip(np.searchsorted(t, tt, side="right") - 1, 0, len(v) - 1)]

def main():
	mame = load_mame(sys.argv[1]); t_m0 = float(sys.argv[2])
	cand = candidate_fn(sys.argv[3], int(sys.argv[5]) if len(sys.argv) > 5 else 47994); t_c0 = float(sys.argv[4])
	win = float(sys.argv[6]) / 1000 if len(sys.argv) > 6 else 0.060
	pad = 0.030                                                   # lag search +- 30 ms
	i0 = int((t_m0 - pad) * FS); i1 = int((t_m0 + win + 2 * pad) * FS)
	m = lowpass(mame)[i0:i1]
	tm = np.arange(i0, i1) / FS - t_m0                            # MAME time since its first write
	best = (-2, None, None)
	for s in np.arange(0.90, 1.2001, 0.0025):
		for lag_ms in np.arange(-20, 20.01, 0.25):
			tc = t_c0 + (tm - lag_ms / 1000) / s
			c = cand(tc)
			c = lowpass(c)
			sel = (tm >= 0) & (tm < win)
			a, b = m[sel], c[sel]
			a = a - a.mean(); b = b - b.mean()
			d = np.linalg.norm(a) * np.linalg.norm(b)
			if d == 0: continue
			r = float(np.dot(a, b) / d)
			if abs(r) > abs(best[0]) or best[1] is None:
				best = (r, s, lag_ms)
	r, s, lag = best
	print(f"best normalised cross-correlation {r:+.3f} at time scale {s:.4f} (candidate slower than MAME by this factor), lag {lag:+.2f} ms")

main()
