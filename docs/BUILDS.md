# Build and acceptance record

Readiness claims name the exact artifact they apply to. Add a row for every bitstream that is tested.

## RBF 60c2c1c32ee5194645e6802417e8aa68  (Arcade-Sauro.rbf, 3,459,140 bytes)
- Source revision: `949a57959aeb78e4f981c990d69c2eba3a16c60e` (clean tree). An earlier build from the tree one
  commit before that, which still carried an unconnected `.dim_video()` named port, produced a bit-identical RBF.
- Tool: Quartus Prime 17.0.2 Build 602 Lite, `quartus_sh --flow compile Arcade-Sauro` via `tools/build.ps1`,
  device 5CSEBA6U23I7. Built 2026-10-07.
- Fit: 9,364 / 41,910 ALMs (22 %); block memory 3,189,953 / 5,662,720 bits (56 %), 408 / 553 RAM blocks (74 %);
  33 DSP blocks, all in the framework (none in this design); 3 PLLs.
- Timing (final models): setup slack positive on every clock, worst on the 80 MHz system clock 1.481 ns,
  HDMI PLL clock 0.697 ns; hold slack positive on every clock, worst 0.249 ns. Unconstrained paths: framework
  ports only (4 inputs, 50 outputs). Warnings in our hierarchy: width-truncation notices from the imported TV80.
- Simulation checks run against this source (Verilator 5.052, unmodified ROMs, ROM download through ioctl):
  sauro, seawolft, trckydoc frames at interrupt 5, 10, 20 match MAME frames 4, 9, 19 pixel for pixel;
  sauro pause test (0 bus writes, 0 interrupt acknowledges, 269,232 pixel clocks over 3 frames, resumed).
  Video block vs 42 MAME frame dumps: 0 differing pixels.
- Hardware (physical, owner, 2026-10-07), HDMI at 1920x1080, DIRECT_VIDEO=2, 8BitDo controller:
  all three games (`_Sauro`, `_Sea Wolf (Tecfri)`, `_Tricky Doc` MRAs) load and play; no loss of sync.
  The owner reported a few visual oddities, then confirmed each also appears in MAME and treats them as normal:
  junk at the left edge of Sauro, a span of missing pixels along the Sauro horizon, and the unusual top/bottom
  spacing of the Tricky Doc game-over screen. No defect has been identified in this build. Colours looked correct
  on the Sauro sky and Tricky Doc screens photographed.
- The MiSTer log shows the ROM download arrived as laid out (0x59400 bytes for index 0, 1 byte for index 1) and
  reports the core's output as 240x224, 15.8 kHz, 55.7 Hz, 5.00 MHz pixel, 80.00 MHz video clock. That measures
  THIS core's output, not the original board, so it is not evidence for the unmeasured original timing.
- Not yet checked on hardware: VGA/15 kHz RGB output, scandoubler/effects, pause button, DIP menu changes.
  No sound in this build.

## RBF aeb5f0d20531530bfcc839f1376c8a29  (releases/dev/Tecfri_20261007.rbf, 3,600,856 bytes): first build with sound
- Source revision: `0eba59a` (tracked tree clean; untracked WIP files rtl/sauro_nvram.sv, sim/tb_nvram.sv are not in files.qip).
- Tool: Quartus Prime 17.0.2 Build 602 Lite, `quartus_sh --flow compile Arcade-Sauro` via `tools/build.ps1`, built 2026-10-07 18:08.
- Contents: video and CPU as in RBF 60c2c1c3, plus the YM3812 (jtopl2), the Sauro-family sound CPU, and Speech256 (clock-enabled copy)
  for the SP0256 voice. Mix levels calibrated against MAME captures (provisional). No NVRAM saving, no CRT controls yet.
- Fit: 11,156 / 41,910 ALMs (27 %); block memory 3,507,966 bits (62 %), 452 / 553 RAM blocks (82 %); 35 DSP blocks (framework 33 plus
  2 multipliers inside jtopl); 3 PLLs.
- Timing (final models): setup slack positive on every clock: 80 MHz system clock 0.706 ns, HDMI PLL clock 0.436 ns (framework),
  others above 3.8 ns; hold slack positive, worst 0.246 ns. One critical warning, the framework's "mode" port width message.
- Simulation evidence for this source: 9 s of machine time from reset on `sauro`: music starts at 5.0 s as in MAME, level ratio 0.83-0.99;
  speech not run through the full core yet (it is exercised standalone, docs/AUDIO.md). NOT yet tested on hardware.

## RBF 0e426e13ead0557180a14c14fb6fa6ce (output_files/Arcade-Sauro.rbf, NVRAM build): NOT FOR RELEASE, timing not clean
- Source revision `f16aa4c` (clean tree). Quartus 17.0.2 full flow, 2026-10-07 18:34. 11,281 ALMs (27 %), 454 RAM blocks (82 %), 35 DSP.
- **Setup slack is negative on the framework's HDMI clock: -0.119 ns, TNS -1.204 ns**, all endpoints inside `ascal` (o_hcpt -> o_vcpt counters,
  148.5 MHz; Fmax 145.96 MHz). Not our logic, but the slack moved +0.70 -> +0.44 -> -0.12 ns across our last three builds, so our design perturbs
  its placement. Hold is positive (0.212 ns). This RBF has NOT been tested on hardware and should not be shipped.
- Pending remedy: fitter seed sweep (tools/seed_sweep.ps1 -Seeds 2,3,4 in scratch copies, started, result in simulation/seed_sweep.log); adopt a
  seed with positive slack in Arcade-Sauro.qsf, then rebuild officially and re-record. `tools/report_hdmi_paths.tcl` lists the failing paths.
- The last hardware-tested RBF remains aeb5f0d2 (sound, no NVRAM).

## RBF 1d3eed9e1e8af5941859322233d457b8 (releases/dev/Tecfri_20261007b_diag.rbf, 3,601,736 bytes): diagnostic build
- Source revision `9452dfb` (clean tree), Quartus 17.0.2 full flow, fitter seed 2, 2026-10-07 20:28.
- Adds battery RAM save/restore (rtl/sauro_nvram.sv, MRA `<nvram index="4">`), and two diagnostic OSD switches for the silent Sauro/Sea Wolf
  sound report: "Speech (Sauro)" On/Off (drops the voice from the mix) and "Sound test tone" (440 Hz square through the output path).
- Fit: 11,292 / 41,910 ALMs (27 %); 454 / 553 RAM blocks (82 %); 35 DSP blocks. Timing: no negative slack; worst setup +0.749 ns (HDMI scaler
  clock), worst hold +0.248 ns. The earlier default-seed NVRAM build (0e426e13) missed by -0.119 ns on the framework's ascal paths.
- Owner report on RBF aeb5f0d2: Tricky Doc has sound; Sauro and Sea Wolf make no sound at all. Cause not yet found; simulation with zero-initialised
  state plays them correctly. NOT yet tested on hardware: this build.

## RBF 6c3827f33052d4d94c35b136e05b6ef6 (releases/dev/Tecfri_20261008_debugtone.rbf, 3,617,128 bytes): debug-tone diagnostic build
- Source revision `f17e0f9` (clean tree), Quartus 17.0.2 full flow, fitter seed 2, 2026-10-08 09:03.
- Adds the OSD "Debug tone" selector: a tone plays once the chosen event has happened since reset (ROM loaded, sound CPU running past 0100,
  YM3812 written, YM3812 IRQ low, command latch read, main CPU sent a sound command, YM3812 output audible). In simulation (Sauro, zero-initialised
  state, 2 s) flags 1-5 are set; "cmd sent" needs a coin and "YM audible" the music at about 5 s.
- Fit: 11,338 / 41,910 ALMs (27 %), 454 / 553 RAM blocks (82 %), 35 DSP. Timing: no negative slack; worst setup +0.244 ns (framework HDMI clock), worst hold +0.253 ns.
- Owner result on the previous diagnostic build (1d3eed9e): the 440 Hz test tone is audible, and Sauro stays silent with speech on or off, so the output path
  and the speech block are not the cause; Tricky Doc (YM3812 driven by the main CPU) has sound. Not yet tested on hardware: this build.

## RBF b9aee70af83314fd81088d338fd1b6bf (releases/dev/Tecfri_20261008b_debugtone2.rbf, 3,624,388 bytes): debug-tone build 2
- Source revision `d7c67ae` (clean tree), Quartus 17.0.2 full flow, fitter seed 2, 2026-10-08 09:27. Fit 11,355 ALMs (27 %), 454 RAM blocks (82 %), 35 DSP.
  Timing: no negative slack; worst setup +0.679 ns (framework HDMI clock), worst hold +0.249 ns.
- Owner result on build 6c3827f3 (Sauro, silent): debug tones for ROM loaded, CPU running, YM written, Cmd read were audible; YM IRQ and YM audible were not.
  Only the interrupt routine at 0039 reads address E000 and RST 38 (opcode FF) also enters it, so "Cmd read" does not prove a real interrupt.
- This build adds debug-tone entries: Main loop (0278 reached), INT vector (0038), NMI vector (0066), Wild fetch (opcode fetch at 8000+), YM timer2 start.
  Simulation expectation for Sauro at 2 s: main loop, INT vector and timer-2 start set; NMI vector and wild fetch not set. Not yet tested on hardware.

## RBF 3a8a5f65d4da8701ef0b2fd829834eda (releases/dev/Tecfri_20261008c_ntfix.rbf, 3,613,376 bytes): sound-CPU NMI hold-off
- Source revision `90b08bb` (clean tree), Quartus 17.0.2 full flow, fitter seed 2, 2026-10-08 09:59. 11,355 ALMs (27 %), 454 RAM blocks (82 %), 35 DSP. No negative slack in the STA summary (worst listed setup +0.716 ns, hold +0.252 ns).
- Change: the speech-LRQ NMI to the Sauro audio CPU is held off for the first 1 ms of audio CPU time after reset.
- Evidence: with randomised power-up state (Verilator +rand+reset, seeds 2, 4, 5 of 1-6) the previous source ran away (NMI before LD SP, wild fetch, no YM IRQ or timer 2), matching the hardware report for b9aee70a. With the change, seeds 1-6 all reach the main loop and timer-2 start with no wild fetch.
- The real SP0256 LRQ timing after reset is unmeasured; the 1 ms is an assumption. Not yet tested on hardware.

## RBF 8898b849650dd64f35f07878e98b902a (releases/dev/Tecfri_20261008d_speechbusy.rbf, 3,644,292 bytes): speech LRQ busy time
- Source revision `9470ce1` (clean tree), Quartus 17.0.2 full flow, fitter seed 2, 2026-10-08 15:16. 11,358 ALMs (27 %), 454 RAM blocks (82 %), 35 DSP. No negative slack in the STA summary (smallest listed slack +0.206 ns).
- Change: LRQ to the Sauro audio CPU stays high for at least 3 ms after each ALD write (on top of the 1 ms NMI hold-off of 90b08bb).
- Owner report on 3a8a5f65: Sauro has sound; after game over a steady loud static; no voices heard (voices are triggered by Start 1P, not by attract mode).
- Simulation (scripted MAME-identical play, core RTL): before the change the first game-over allophone (28) was followed by no further writes and the speech output sat at full scale for about 5 s; after it the phrase 28 28 14 00 29 04 38 20 00 is written with MAME's timing and the static is gone.
  Still present in simulation: a full-scale burst of about 80 ms on that first noise allophone. The synthesiser alone, replayed with the same writes, does not show it; cause not yet found.
- The 3 ms figure comes from MAME's write spacing; real SP0256 timing is unmeasured. Not yet tested on hardware.

## RBF 262bae55212489ae27c41983c55fbd68 (releases/dev/Tecfri_20261008e_speechfix_crt.rbf, 3,626,120 bytes): speech coefficient interlock + CRT Adjust
- Source revision `370eacd` (clean tree), Quartus 17.0.2 full flow, fitter seed 2, 2026-10-08 16:38. 11,541 ALMs (28 %), 454 RAM blocks (82 %), 35 DSP. No negative slack in the STA summary (smallest listed slack +0.192 ns).
- Owner report on 8898b849: a very loud static crack before each speech clip (also in attract mode); speech present but "doesn't sound right".
- Cause found in simulation (standalone speech block, 32 write phases within the 256-clock sample frame): the Speech256 controller starts an allophone's coefficient burst while the filter may be mid-computation (shared coefficient ring, no interlock), giving a scrambled coefficient set that rings at full scale. 13 of 32 phases reached peak 32767 before the change; all 32 give peak 52 after it. `sim/tb_speech_equiv.sv` (interlock disabled by parameter) still reports 0 mismatches against the pristine Speech256.
- Change: TCE_CONTROLLER starts the burst only in the first 40 enabled clocks of the filter's idle window (rtl/sound/speech256_ce, ADAPTATION.md). Also in this build: 3 ms LRQ busy time (9470ce1) and the new core-side CRT Adjust (OSD: CRT Adjust Off/On, CRT H-Position, CRT V-Shift) adapted from Victory; off by default.
- Not tested: full-core replay of the fix (not rerun after the interlock), hardware, CRT Adjust (raster 316x284 at the pixel-enable level, HSync column 252, HDMI behaviour while On are all unverified).

## RBF 4ba8ba9acc81fa67b2861a98260c0685 (releases/dev/Tecfri_20261008f_crtmenu.rbf, 3,599,976 bytes): CRT Adjust menu mask fix
- Source revision `5ebe565` (clean tree; later commits only add photos and docs), Quartus 17.0.2 full flow, fitter seed 2, 2026-10-08 17:28. 11,535 ALMs (28 %), 454 RAM blocks (82 %), 35 DSP. No negative slack in the STA summary (smallest listed slack +0.242 ns).
- Change vs 262bae55: the hps_io status_menumask bits were swapped, which disabled "CRT Adjust" while it was Off (it could never be switched on) and hid/showed H-Position/V-Shift at the wrong time. Now bit 0 hides the sliders unless Adjust is On, bit 1 disables Adjust only in scandoubler modes (same polarity as Victory). No other RTL change.
- Owner report on 262bae55: CRT Adjust greyed out (this fix). Analog (Direct Video) picture dark on a CRT, also on earlier builds, while HDMI looks fine.
- Darkness analysis (not a code change): the two screens in question use palette levels 2 and 3 of 15 (R,G,B = (0,0,31) and (45,45,0), measured from MAME screenshots; the core outputs the same values); PROMs span the full range; text reaches 247-249. Palette weights are MAME's generic RGB_444_PROMS (14/31/67/143), unverified for this board; photo evidence of the real resistor ladder is being collected (docs/reference/photos).
- Not tested on hardware: CRT Adjust behaviour (raster 316x284, HSync column 252, HDMI while On), the speech interlock (see 262bae55).

## RBF e60fd52bf2de9d910f3439b451b07bb9 (releases/Arcade-Sauro_20261008.rbf, 3,615,968 bytes): first beta, project renamed to Arcade-Sauro
- Source revision `29de8b6` (the build ran from this exact tree, committed unchanged afterwards), Quartus 17.0.2 full flow (`quartus_sh --flow compile Arcade-Sauro`), fitter seed 2, 2026-10-08 20:34. 11,534 ALMs (28 %), 454 RAM blocks (82 %), 35 DSP. No negative slack in the STA summary (smallest listed slack +0.242 ns).
- Change vs 4ba8ba9a (source `5ebe565`): no logic change intended. The project, files and module names are Arcade-Sauro / sauro_*; the OSD core name is now "Sauro" (this also names the config and save files on the SD card); RTL grouped into rtl/video and rtl/sound. The resource figures match the previous build (11,535 ALMs, 454 RAM blocks, 35 DSP) but the two RBFs were not compared function by function.
- MRAs (releases/): Sauro.mra (setname sauro), Sea Wolf (Tecfri).mra (seawolft, parent sauro), Tricky Doc.mra (trckydoc); `<rbf>Sauro</rbf>`, mameversion 0257, nvram index 4 size 2048. Image MD5s: sauro 45a595e50de092150ce351e97e2d975d, seawolft b254125ca8f64a5f6ba5eac1ae195d3d, trckydoc 924ad85f45089ea8528f15d9230b5e22 (generated by tools/make_mra.py from the 0.257 split sets on the NAS; no ROM data in the repository).
- Simulation after the rename: Speech256 equivalence test passed (0 mismatches), NVRAM unit test passed (the bounds-check mutant fails as designed), main/video/core testbenches build without errors, CPU smoke test passed. The frame-comparison and gameplay runs were not repeated.
- Not tested on hardware: this build; the speech crack fix and CRT Adjust (see 262bae55/4ba8ba9a); NVRAM save/restore. Known limitations: raster 316x284 inferred, not measured; speech voice accuracy unverified (Speech256 allophone model); palette uses MAME's generic resistor weights (real ladder not yet read); cocktail flip not implemented; Tricky Doc and Sea Wolf not run through the NVRAM restore tests.

## RBF a652e139cc012f4e95842e9b44254b9e (releases/Arcade-Sauro_20261011.rbf, 3,629,240 bytes): Service switch restarts the machine, T[0] Reset entry
- Source revision `b983fa5` (clean tree), Quartus 17.0.2 full flow (`quartus_sh --flow compile Arcade-Sauro`), fitter seed 2, 2026-10-11 16:07. 11,550 ALMs (28 %), 454 RAM blocks (82 %), 35 DSP. No negative slack in the STA summary (smallest listed slack +0.177 ns). Another project's compile was running on the same machine; it does not affect the result.
- Changes vs e60fd52b (`29de8b6`): (1) a change of DSW1 bit 0 (Service) holds the core in reset for 100 ms, inline in Arcade-Sauro.sv; (2) `T[0],Reset;` added to CONF_STR beside `R[0],Reset and close OSD;`.
- Evidence for the Service behaviour: the firmware reads DSW1 once (main ROM `IN A,(0)` at 034E, stored inverted at E31A; the bit-0 test is in the init path). With the switch on before boot, MAME (0.288, set sauro) and the core simulation both stay in the test mode (E316 = 01, E31A = 98) and the core's frame at the 290th interrupt matches MAME's service frame pixel for pixel (0 of 53,760 differ): a grid with RED / GREEN / BLUE / GREY colour bars. With the switch off both reach attract mode (E316 = 04, E31A = 99). Scripts: sim/mame/service_test.lua, tools/wsl_service_test.sh, `+DSW1=<hex>` in sim/tb_core.sv.
- The reset-on-change logic itself has no unit test (the separate module and its test were removed at the owner's request); it is verified only by this build's timing/resource report. Not tested on hardware: this build; whether the MiSTer re-sends DIP bytes when a switch is changed in the OSD (if it only sends them at MRA load, the game restarts anyway).
- MRAs regenerated with mratimestamp 20261011; ROM image MD5s unchanged (sauro 45a595e5..., seawolft b254125c..., trckydoc 924ad85f...). The 20261008 beta RBF moved to releases/dev/.
- Still outstanding from earlier builds: NVRAM save on hardware (the test MRAs had no nvram tag; the beta MRAs do), speech crack fix and CRT Adjust on hardware, palette ladder photos.

## MRA correction 2026-10-11 (no RBF change; RBF a652e139 / Arcade-Sauro_20261011.rbf is unchanged)
- Bug found after hardware feedback ("Service does nothing"): the MRAs numbered `<dip bits="...">` from 1 and carried a `base="1"` attribute. Main_MiSTer (support/arcade/mra_loader.cpp, local checkout, commit d3e55f5) ignores `base` and reads `bits` as 0-based bit numbers, so every DIP entry toggled the bit above its own: "Service" toggled DSW1 bit 1 (Demo Sounds), "Demo Sounds" toggled Cabinet, and so on, and the OSD showed the shifted defaults. Corrected to 0-based (Service 0, Demo Sounds 1, Cabinet 2, Free Play 3, Difficulty 4-5, Allow Continue 6, Freeze 7, Coin A 8-9, Coin B 10-11, Lives 12-13, from MAME's INPUT_PORTS), `base`, `page_id` and `page_name` removed. tools/make_mra.py updated; ROM image MD5s unchanged.
- Consequences for earlier hardware tests: any DIP-dependent observation made with the earlier MRAs was made with shifted switches. MiSTer stores the DIP word per MRA name in config/dips/<mra name>.dip and loads it over the MRA defaults, so stale files from the shifted mapping must be deleted before testing with the corrected MRAs.
- The Service restart (a652e139) is consistent with this: flipping the old "Service" entry changed DSW1 bit 1, not bit 0, so no restart-into-test-mode could occur; the brief reset seen was the DIP block transfer (index 254 download) holding the core in reset. Core-level warm restart into test mode is verified in simulation (E316 = 01, E31A = 98). Corrected MRAs not yet tested on hardware.
