-- Log main-CPU writes to battery RAM (E000-E7FF) during boot, to see how the game treats a restored NVRAM image.
-- Env: OUT (log file). Logs every write to the hi-score bytes (E057-E059) and a summary per 256-byte page.
local m = manager.machine
local main = m.devices[":maincpu"]
local prog = main.spaces["program"]
local out = io.open(os.getenv("OUT") or "nv_probe.txt", "w")
local pages = {}
nv_probe_tap = prog:install_write_tap(0xe000, 0xe7ff, "nvw", function(off, data, mask)
	local pg = (off >> 8) & 7
	pages[pg] = (pages[pg] or 0) + 1
	if off >= 0xe057 and off <= 0xe059 then
		out:write(string.format("%.4f pc=%04x write %04x=%02x\n", emu.time(), main.state["PC"].value, off, data & 0xff))
	end
end)
nv_probe_stop = emu.add_machine_stop_notifier(function()
	for pg = 0, 7 do out:write(string.format("page E%d00: %d writes\n", pg, pages[pg] or 0)) end
	out:close()
end)
