# Build and acceptance record

Readiness claims name the exact artifact they apply to. Add a row for every bitstream that is tested.

## RBF 60c2c1c32ee5194645e6802417e8aa68  (Arcade-Tecfri.rbf, 3,459,140 bytes)
- Source revision: `949a57959aeb78e4f981c990d69c2eba3a16c60e` (clean tree). An earlier build from the tree one
  commit before that, which still carried an unconnected `.dim_video()` named port, produced a bit-identical RBF.
- Tool: Quartus Prime 17.0.2 Build 602 Lite, `quartus_sh --flow compile Arcade-Tecfri` via `tools/build.ps1`,
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

## RBF aeb5f0d20531530bfcc839f1376c8a29  (releases/Tecfri_20261007.rbf, 3,600,856 bytes): first build with sound
- Source revision: `0eba59a` (tracked tree clean; untracked WIP files rtl/tecfri_nvram.sv, sim/tb_nvram.sv are not in files.qip).
- Tool: Quartus Prime 17.0.2 Build 602 Lite, `quartus_sh --flow compile Arcade-Tecfri` via `tools/build.ps1`, built 2026-10-07 18:08.
- Contents: video and CPU as in RBF 60c2c1c3, plus the YM3812 (jtopl2), the Sauro-family sound CPU, and Speech256 (clock-enabled copy)
  for the SP0256 voice. Mix levels calibrated against MAME captures (provisional). No NVRAM saving, no CRT controls yet.
- Fit: 11,156 / 41,910 ALMs (27 %); block memory 3,507,966 bits (62 %), 452 / 553 RAM blocks (82 %); 35 DSP blocks (framework 33 plus
  2 multipliers inside jtopl); 3 PLLs.
- Timing (final models): setup slack positive on every clock: 80 MHz system clock 0.706 ns, HDMI PLL clock 0.436 ns (framework),
  others above 3.8 ns; hold slack positive, worst 0.246 ns. One critical warning, the framework's "mode" port width message.
- Simulation evidence for this source: 9 s of machine time from reset on `sauro`: music starts at 5.0 s as in MAME, level ratio 0.83-0.99;
  speech not run through the full core yet (it is exercised standalone, docs/AUDIO.md). NOT yet tested on hardware.

## RBF 0e426e13ead0557180a14c14fb6fa6ce (output_files/Arcade-Tecfri.rbf, NVRAM build): NOT FOR RELEASE, timing not clean
- Source revision `f16aa4c` (clean tree). Quartus 17.0.2 full flow, 2026-10-07 18:34. 11,281 ALMs (27 %), 454 RAM blocks (82 %), 35 DSP.
- **Setup slack is negative on the framework's HDMI clock: -0.119 ns, TNS -1.204 ns**, all endpoints inside `ascal` (o_hcpt -> o_vcpt counters,
  148.5 MHz; Fmax 145.96 MHz). Not our logic, but the slack moved +0.70 -> +0.44 -> -0.12 ns across our last three builds, so our design perturbs
  its placement. Hold is positive (0.212 ns). This RBF has NOT been tested on hardware and should not be shipped.
- Pending remedy: fitter seed sweep (tools/seed_sweep.ps1 -Seeds 2,3,4 in scratch copies, started, result in simulation/seed_sweep.log); adopt a
  seed with positive slack in Arcade-Tecfri.qsf, then rebuild officially and re-record. `tools/report_hdmi_paths.tcl` lists the failing paths.
- The last hardware-tested RBF remains aeb5f0d2 (sound, no NVRAM).

## RBF 1d3eed9e1e8af5941859322233d457b8 (releases/Tecfri_20261007b_diag.rbf, 3,601,736 bytes): diagnostic build
- Source revision `9452dfb` (clean tree), Quartus 17.0.2 full flow, fitter seed 2, 2026-10-07 20:28.
- Adds battery RAM save/restore (rtl/tecfri_nvram.sv, MRA `<nvram index="4">`), and two diagnostic OSD switches for the silent Sauro/Sea Wolf
  sound report: "Speech (Sauro)" On/Off (drops the voice from the mix) and "Sound test tone" (440 Hz square through the output path).
- Fit: 11,292 / 41,910 ALMs (27 %); 454 / 553 RAM blocks (82 %); 35 DSP blocks. Timing: no negative slack; worst setup +0.749 ns (HDMI scaler
  clock), worst hold +0.248 ns. The earlier default-seed NVRAM build (0e426e13) missed by -0.119 ns on the framework's ascal paths.
- Owner report on RBF aeb5f0d2: Tricky Doc has sound; Sauro and Sea Wolf make no sound at all. Cause not yet found; simulation with zero-initialised
  state plays them correctly. NOT yet tested on hardware: this build.

## RBF 6c3827f33052d4d94c35b136e05b6ef6 (releases/Tecfri_20261008_debugtone.rbf, 3,617,128 bytes): debug-tone diagnostic build
- Source revision `f17e0f9` (clean tree), Quartus 17.0.2 full flow, fitter seed 2, 2026-10-08 09:03.
- Adds the OSD "Debug tone" selector: a tone plays once the chosen event has happened since reset (ROM loaded, sound CPU running past 0100,
  YM3812 written, YM3812 IRQ low, command latch read, main CPU sent a sound command, YM3812 output audible). In simulation (Sauro, zero-initialised
  state, 2 s) flags 1-5 are set; "cmd sent" needs a coin and "YM audible" the music at about 5 s.
- Fit: 11,338 / 41,910 ALMs (27 %), 454 / 553 RAM blocks (82 %), 35 DSP. Timing: no negative slack; worst setup +0.244 ns (framework HDMI clock), worst hold +0.253 ns.
- Owner result on the previous diagnostic build (1d3eed9e): the 440 Hz test tone is audible, and Sauro stays silent with speech on or off, so the output path
  and the speech block are not the cause; Tricky Doc (YM3812 driven by the main CPU) has sound. Not yet tested on hardware: this build.

## RBF b9aee70af83314fd81088d338fd1b6bf (releases/Tecfri_20261008b_debugtone2.rbf, 3,624,388 bytes): debug-tone build 2
- Source revision `d7c67ae` (clean tree), Quartus 17.0.2 full flow, fitter seed 2, 2026-10-08 09:27. Fit 11,355 ALMs (27 %), 454 RAM blocks (82 %), 35 DSP.
  Timing: no negative slack; worst setup +0.679 ns (framework HDMI clock), worst hold +0.249 ns.
- Owner result on build 6c3827f3 (Sauro, silent): debug tones for ROM loaded, CPU running, YM written, Cmd read were audible; YM IRQ and YM audible were not.
  Only the interrupt routine at 0039 reads address E000 and RST 38 (opcode FF) also enters it, so "Cmd read" does not prove a real interrupt.
- This build adds debug-tone entries: Main loop (0278 reached), INT vector (0038), NMI vector (0066), Wild fetch (opcode fetch at 8000+), YM timer2 start.
  Simulation expectation for Sauro at 2 s: main loop, INT vector and timer-2 start set; NMI vector and wild fetch not set. Not yet tested on hardware.

## RBF 3a8a5f65d4da8701ef0b2fd829834eda (releases/Tecfri_20261008c_ntfix.rbf, 3,613,376 bytes): sound-CPU NMI hold-off
- Source revision `90b08bb` (clean tree), Quartus 17.0.2 full flow, fitter seed 2, 2026-10-08 09:59. 11,355 ALMs (27 %), 454 RAM blocks (82 %), 35 DSP. No negative slack in the STA summary (worst listed setup +0.716 ns, hold +0.252 ns).
- Change: the speech-LRQ NMI to the Sauro audio CPU is held off for the first 1 ms of audio CPU time after reset.
- Evidence: with randomised power-up state (Verilator +rand+reset, seeds 2, 4, 5 of 1-6) the previous source ran away (NMI before LD SP, wild fetch, no YM IRQ or timer 2), matching the hardware report for b9aee70a. With the change, seeds 1-6 all reach the main loop and timer-2 start with no wild fetch.
- The real SP0256 LRQ timing after reset is unmeasured; the 1 ms is an assumption. Not yet tested on hardware.

## RBF 8898b849650dd64f35f07878e98b902a (releases/Tecfri_20261008d_speechbusy.rbf, 3,644,292 bytes): speech LRQ busy time
- Source revision `9470ce1` (clean tree), Quartus 17.0.2 full flow, fitter seed 2, 2026-10-08 15:16. 11,358 ALMs (27 %), 454 RAM blocks (82 %), 35 DSP. No negative slack in the STA summary (smallest listed slack +0.206 ns).
- Change: LRQ to the Sauro audio CPU stays high for at least 3 ms after each ALD write (on top of the 1 ms NMI hold-off of 90b08bb).
- Owner report on 3a8a5f65: Sauro has sound; after game over a steady loud static; no voices heard (voices are triggered by Start 1P, not by attract mode).
- Simulation (scripted MAME-identical play, core RTL): before the change the first game-over allophone (28) was followed by no further writes and the speech output sat at full scale for about 5 s; after it the phrase 28 28 14 00 29 04 38 20 00 is written with MAME's timing and the static is gone.
  Still present in simulation: a full-scale burst of about 80 ms on that first noise allophone. The synthesiser alone, replayed with the same writes, does not show it; cause not yet found.
- The 3 ms figure comes from MAME's write spacing; real SP0256 timing is unmeasured. Not yet tested on hardware.
