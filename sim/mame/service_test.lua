-- Set the DSW1 Service switch (bit 0) before the game starts and take a snapshot after SECS seconds (env SECS, default 6).
local m = manager.machine
local secs = tonumber(os.getenv("SECS") or "6")
local on = os.getenv("SERVICE") ~= "0"
local f = m.ioport.ports[":DSW1"]:field(0x01)
f.user_value = on and 1 or 0
local done = false
service_notifier = emu.add_machine_frame_notifier(function()
	if not done and emu.time() >= secs then
		done = true
		local scr = m.screens[":screen"]
		local w, h = scr.width, scr.height
		local fo = io.open(os.getenv("PIXOUT") or "service_frame.bin", "wb")
		fo:write(string.pack("<II", w, h)); fo:write(scr:pixels()); fo:close()
		local mem = m.devices[":maincpu"].spaces["program"]
		print(string.format("t=%.2f service=%d  E31A(~DSW1)=%02x  E316(mode?)=%02x  E318=%02x  E0CA=%02x", emu.time(), f.user_value, mem:read_u8(0xe31a), mem:read_u8(0xe316), mem:read_u8(0xe318), mem:read_u8(0xe0ca)))
		m:exit()
	end
end)
