"""Wrap tb_core's raw 16-bit little-endian mono PCM in a WAV header (about 48 kHz).
Usage: python -I tools/raw2wav.py <in.raw> <out.wav> [rate]   (rate default 47994 = 80 MHz / 1667)
"""
import sys, wave
raw = open(sys.argv[1], "rb").read()
rate = int(sys.argv[3]) if len(sys.argv) > 3 else 80_000_000 // 1667
with wave.open(sys.argv[2], "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate); w.writeframes(raw)
print(f"{sys.argv[2]}: {len(raw) // 2} samples, {len(raw) / 2 / rate:.2f} s at {rate} Hz")
