-- Log Sauro sound-chain events during scripted play (coin, start, random joystick): audio CPU command-latch reads that
-- return a non-zero command, SP0256 allophone writes (A000), and YM3812 writes per second. Env: OUT (log file).
-- Input script is the same as dump_frame.lua PLAY=1.
local m = manager.machine
local acpu = m.devices[":audiocpu"]
local aspace = acpu.spaces["program"]
local main = m.devices[":maincpu"]
local out = io.open(os.getenv("OUT") or "sound_events.txt", "w")
local function field(port, mask) return m.ioport.ports[port]:field(mask) end
local frame, rng, held = 0, 12345, 0
local ymw, lastsec = 0, 0
sev_cmd = aspace:install_read_tap(0xe000, 0xe000, "cmd", function(o, d, mk)
	if d ~= 0 and acpu.state["PC"].value ~= nil then out:write(string.format("%.3f cmd %02x frame %d\n", emu.time(), d, frame)) end
end)
sev_sp = aspace:install_write_tap(0xa000, 0xa000, "sp", function(o, d, mk)
	out:write(string.format("%.3f speech %02x\n", emu.time(), d & 0xff))
end)
sev_ym = aspace:install_write_tap(0xc000, 0xc001, "ym", function(o, d, mk) ymw = ymw + 1 end)
sev_frame = emu.add_machine_frame_notifier(function()
	frame = frame + 1
	local coin, start = field(":P1", 0x04), field(":P2", 0x04)
	coin:set_value((frame >= 400 and frame < 410) and 1 or 0)
	start:set_value((frame >= 450 and frame < 460) and 1 or 0)
	if frame >= 520 and frame % 20 == 0 then
		rng = (rng * 1103515245 + 12345) & 0x7fffffff
		held = (rng >> 8) & 0xff
	end
	if frame >= 520 then
		for bit, mask in pairs({ [0] = 0x01, [1] = 0x02, [4] = 0x10, [5] = 0x20, [6] = 0x40, [7] = 0x80 }) do
			field(":P1", mask):set_value(((held >> bit) & 1) == 1 and 1 or 0)
		end
	end
	local sec = math.floor(emu.time())
	if sec ~= lastsec then out:write(string.format("%d s: ym writes %d, frame %d\n", sec, ymw, frame)); ymw = 0; lastsec = sec; out:flush() end
end)
