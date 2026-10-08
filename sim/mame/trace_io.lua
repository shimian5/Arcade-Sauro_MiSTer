-- Log CPU register/IO activity of a Tecfri set in MAME for spec verification.
-- Usage: mame <set> -autoboot_script trace_io.lua -video none -sound none
--        -nothrottle -seconds_to_run N   (env TRACE_OUT = output file)
local m = manager.machine
local out = io.open(os.getenv("TRACE_OUT") or "trace_io.txt", "w")
local main = m.devices[":maincpu"]
local audio = m.devices[":audiocpu"]
local frame = 0
local function log(cpu, what, ...)
	out:write(string.format("%.6f f%d %s pc=%04x %s\n", emu.time(), frame, cpu, cpu == "M" and main.state["PC"].value or audio.state["PC"].value, string.format(what, ...)))
end
tecfri_taps = {}   -- global: MAME unregisters taps and notifiers that Lua garbage-collects
local function tapw(cpu, dev, space, s, e, name)
	tecfri_taps[#tecfri_taps+1] = dev.spaces[space]:install_write_tap(s, e, name, function(off, data, mask)
		log(cpu, "%s w %04x=%02x", space, off, data & 0xff)
	end)
end
if not m.system.name:find("trckydoc") then   -- trckydoc is memory mapped; others use Z80 I/O ports
	tapw("M", main, "io", 0x80, 0xff, "mio")
else
	tapw("M", main, "program", 0xf820, 0xf83f, "mio")  -- YM3812, scroll, latch
end

-- Input port reads (first 4 per address) so DIP/input defaults can be taken from MAME.
local rd_count = {}
local function tapr(cpu, dev, space, s, e, name)
	tecfri_taps[#tecfri_taps+1] = dev.spaces[space]:install_read_tap(s, e, name, function(off, data, mask)
		rd_count[off] = (rd_count[off] or 0) + 1
		if rd_count[off] <= 4 then log(cpu, "%s r %04x -> %02x", space, off, data & 0xff) end
	end)
end
if not m.system.name:find("trckydoc") then tapr("M", main, "io", 0x00, 0x7f, "mior") else tapr("M", main, "program", 0xf800, 0xf81f, "mior") end
if audio then
	tapw("A", audio, "program", 0xa000, 0xa000, "aspeech")
	tapw("A", audio, "program", 0xc000, 0xc001, "aym")
	tecfri_taps[#tecfri_taps+1] = audio.spaces["program"]:install_read_tap(0xe000, 0xe000, "acmd", function(off, data, mask)
		log("A", "cmd read -> %02x", data & 0xff)
	end)
end

-- Optional scripted input (env PLAY=1): coin at frame 400, start 1 at 450, then a deterministic
-- pseudo-random pattern of joystick and button presses (same as dump_frame.lua).
local play = os.getenv("PLAY") == "1"
local function field(port, mask) return m.ioport.ports[port]:field(mask) end
local rng, held = 12345, 0
local function drive_input()
	if not play then return end
	field(":P1", 0x04):set_value((frame >= 400 and frame < 410) and 1 or 0)
	field(":P2", 0x04):set_value((frame >= 450 and frame < 460) and 1 or 0)
	if frame >= 520 and frame % 20 == 0 then
		rng = (rng * 1103515245 + 12345) & 0x7fffffff
		held = (rng >> 8) & 0xff
	end
	if frame >= 520 then
		for bit, mask in pairs({ [0] = 0x01, [1] = 0x02, [4] = 0x10, [5] = 0x20, [6] = 0x40, [7] = 0x80 }) do
			field(":P1", mask):set_value(((held >> bit) & 1) == 1 and 1 or 0)
		end
	end
end
tecfri_frame_notifier = emu.add_machine_frame_notifier(function()
	frame = frame + 1
	drive_input()
	if frame % 60 == 1 then
		local s = string.format("frame %d t=%.6f main IM=%s I=%02x IFF1=%s", frame, emu.time(), tostring(main.state["IM"] and main.state["IM"].value), main.state["I"].value, tostring(main.state["IFF1"] and main.state["IFF1"].value))
		if audio then s = s .. string.format(" | audio IM=%s IFF1=%s", tostring(audio.state["IM"].value), tostring(audio.state["IFF1"].value)) end
		out:write(s .. "\n")
	end
	out:flush()
end)
tecfri_stop_notifier = emu.add_machine_stop_notifier(function() out:close() end)
