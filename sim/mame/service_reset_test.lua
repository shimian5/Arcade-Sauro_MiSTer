-- Boot Sauro normally, flip the DSW1 Service switch on at T_FLIP seconds, restart the machine (MODE = soft | hard) and report
-- the firmware's mode variable (E316: 04 = attract, 01 = test mode) and the DSW1 copy (E31A) before and after.
-- MAME re-runs the autoboot script after every machine reset, so the state lives in a global table and a second run only
-- re-attaches the notifier.
local m = manager.machine
if not svc_state then svc_state = { flipped = false, reported = false, frames_after = 0 } end
local t_flip = tonumber(os.getenv("T_FLIP") or "8")
local frames_wait = tonumber(os.getenv("FRAMES_AFTER") or "900")
local mode   = os.getenv("MODE") or "soft"
local f = m.ioport.ports[":DSW1"]:field(0x01)
if not svc_state.flipped then f.user_value = 0 end
local mem = m.devices[":maincpu"].spaces["program"]
local function show(tag)
	print(string.format("%s t=%.2f  E31A=%02x  E316=%02x  E318=%02x  E0CA=%02x", tag, emu.time(), mem:read_u8(0xe31a), mem:read_u8(0xe316), mem:read_u8(0xe318), mem:read_u8(0xe0ca)))
end
sreset_notifier = emu.add_machine_frame_notifier(function()
	local s = svc_state
	if not s.flipped and emu.time() >= t_flip then
		s.flipped = true
		show("before")
		f.user_value = 1
		if mode == "hard" then m:hard_reset() else m:soft_reset() end
	elseif s.flipped and not s.reported then
		s.frames_after = s.frames_after + 1
		if s.frames_after >= frames_wait then
			s.reported = true
			show(mode .. " after")
			m:exit()
		end
	end
end)
