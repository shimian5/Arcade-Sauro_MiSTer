"""Compare the RTL write log with a MAME trace_io.lua trace (sequence, not time).

Watchdog writes (io 00e0) are dropped from both sides: the value is a running
counter in the ROM test and is not behavior under test here.
Usage: python -I tools/compare_trace.py <mame_trace.txt> <rtl_log.txt> [count]
"""
import re, sys

def mame_events(path):
	pat = re.compile(r" M pc=[0-9a-f]+ (io|program) w ([0-9a-f]{4})=([0-9a-f]{2})")
	for line in open(path):
		m = pat.search(line)
		if m and not (m.group(1) == "io" and m.group(2) == "00e0"):
			yield f"{m.group(1)} w {m.group(2)}={m.group(3)}"

def rtl_events(path):
	for line in open(path):
		line = line.strip()
		if line and not line.startswith("io w 00e0="):
			yield line

def main():
	mame = list(mame_events(sys.argv[1]))
	rtl = list(rtl_events(sys.argv[2]))
	count = int(sys.argv[3]) if len(sys.argv) > 3 else 40
	n = min(count, len(mame), len(rtl))
	for i in range(n):
		if mame[i] != rtl[i]:
			print(f"MISMATCH at event {i}: MAME '{mame[i]}' RTL '{rtl[i]}'")
			sys.exit(1)
	if n < count:
		print(f"FAIL: only {n} comparable events (MAME {len(mame)}, RTL {len(rtl)}), wanted {count}")
		sys.exit(1)
	print(f"PASS: first {n} write events identical")

main()
