-- Drive MAME's SP0256 with a chosen allophone sequence while the rest of Sauro is quiet (the YM3812 is silent
-- for the first ~5 s), so a -wavwrite capture is speech only.
-- Env: SEQ (comma separated hex, e.g. "1b,07,2d,20,00"), START (seconds, default 2.0), OUT (log file).
-- Each byte is written from the audio CPU's NMI entry (address 0066), as the firmware's own handler does, so the
-- handshake follows the chip's LRQ. The first byte is written at START.
local m = manager.machine
local acpu = m.devices[":audiocpu"]
local space = acpu.spaces["program"]
local seq = {}
for h in (os.getenv("SEQ") or "1b,07,2d,20,00"):gmatch("%x+") do seq[#seq + 1] = tonumber(h, 16) end
local start = tonumber(os.getenv("START") or "2.0")
local out = io.open(os.getenv("OUT") or "speech_inject.txt", "w")
local idx, started = 0, false
local function push(why)
	if idx < #seq then
		idx = idx + 1
		space:write_u8(0xa000, seq[idx])
		out:write(string.format("%.6f write %02x (%s)\n", emu.time(), seq[idx], why))
		out:flush()
	end
end
speech_inject_nmi = space:install_read_tap(0x0066, 0x0066, "nmi", function(o, d, mk)
	if started and acpu.state["PC"].value == 0x0066 then push("nmi") end
end)
speech_inject_frame = emu.add_machine_frame_notifier(function()
	if not started and emu.time() >= start then
		started = true
		push("start")
	end
end)
