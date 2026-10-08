"""Compare the RTL audio capture (tb_core +WAV raw PCM) with a MAME wav of the same machine time.

Not a bit-exact check: the two use different YM3812 and SP0256 implementations and different audio-CPU interrupt
timing (MAME 480 Hz timer vs the YM3812 timer), so waveforms drift apart. It reports, per window:
RMS level of each, and the correlation of the two log-magnitude spectra (does it sound the same, not does it
match sample for sample). Optional gain ratio over the loud windows to calibrate the mix level.

Usage: python -I tools/audio_compare.py <rtl.raw> <mame.wav> [window_seconds=0.5] [rtl_rate=47994]
"""
import sys, wave
import numpy as np

def load_raw(path):
	return np.frombuffer(open(path, "rb").read(), dtype="<i2").astype(np.float64)

def load_wav(path):
	w = wave.open(path)
	return np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64), w.getframerate()

def main():
	rtl = load_raw(sys.argv[1])
	mame, mrate = load_wav(sys.argv[2])
	win = float(sys.argv[3]) if len(sys.argv) > 3 else 0.5
	rrate = int(sys.argv[4]) if len(sys.argv) > 4 else 47994
	# resample the RTL stream to MAME's rate by linear interpolation (rates differ by 0.01 %)
	t = np.arange(int(len(rtl) * mrate / rrate)) * rrate / mrate
	rtl = np.interp(t, np.arange(len(rtl)), rtl)
	n = min(len(rtl), len(mame))
	size = int(win * mrate)
	ratios = []
	print(f"{'t(s)':>6} {'rtl rms':>9} {'mame rms':>9} {'ratio':>6} {'spectral corr':>14}")
	for i in range(0, n - size + 1, size):
		a, b = rtl[i:i + size], mame[i:i + size]
		ra, rb = np.sqrt(np.mean(a * a)), np.sqrt(np.mean(b * b))
		corr = float("nan")
		if ra > 1 and rb > 1:
			fa = np.log10(np.abs(np.fft.rfft(a * np.hanning(size))) + 1)
			fb = np.log10(np.abs(np.fft.rfft(b * np.hanning(size))) + 1)
			corr = float(np.corrcoef(fa, fb)[0, 1])
			ratios.append(ra / rb)
		print(f"{i / mrate:6.2f} {ra:9.1f} {rb:9.1f} {ra / rb if rb > 1 else float('nan'):6.2f} {corr:14.3f}")
	if ratios:
		print(f"median level ratio rtl/mame over {len(ratios)} active windows: {np.median(ratios):.3f}")

main()
