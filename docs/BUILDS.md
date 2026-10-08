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
