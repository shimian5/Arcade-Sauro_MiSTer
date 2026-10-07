# Evidence log: MAME traces and Z80 disassembly

Tool: MAME 0.288 (`C:\MiSTerDev\mame`) running the 0.257 ROM sets (all three
sets verify good). Driver text is from 0.257; behaviors below were observed with
`sim/mame/trace_io.lua` (`tools/run_mame_trace.ps1`) and `unidasm` on the
unmodified ROMs. Traces: `simulation/trace_<set>.txt` (not committed).
Everything here is MAME-model evidence plus firmware inference, **not** PCB measurement.

## F1. Main CPU boot (sauro, seawolft; same code layout)
- Z80 IM1, reset-time writes: `OUT C0,C2,C4,CE = 0`, then `E0` (watchdog), `A0/A1` scroll = 0.
- ROM/RAM self-test kicks the watchdog (`OUT E0`) with an incrementing value for about 1.6 s of
  machine time; gameplay/attract IRQs only start after IFF1 is set at about frame 90.
- Per frame ISR (entry ~`0053`): `OUT C9=01` (latch Q4 high), writes `A0`, `A1`
  (bg/fg scroll), `C0` (flip latch bit), then `OUT C8=00` (Q4 low) at `009F`.
- **IRQ model (corrected 2026-10-07):** MAME's LS259 clears on reset, so Q4=0 and the
  interrupt is enabled from reset. VBLANK start sets a level-held INT only while Q4=0.
  A latch write that leaves Q4 low (enabled) **clears** the pending INT; Q4=1 only masks
  new interrupts. The firmware ISR therefore does `OUT C9=01` (mask) ... `OUT C8=00`
  (unmask and clear) at its end. An earlier draft of this file had the clear on Q4 high.
  Exact flip-flop polarity remains provisional (no schematic).
- Seawolft main boot trace identical in structure to sauro.

## F2. Tricky Doc
- Latch writes `F839,F83A,F83B,F838,F83F=0` at reset; YM3812 programming through
  `F820/F821`; Z80 IM1.

## F3. Audio CPU interrupt source (resolves spec risk #2)
- MAME drives audio INT from a fake 480 Hz timer (`irq0_line_hold`, marked `?`).
- Audio ROM disassembly: IM1 vector `0038` begins `push af; ld a,(E000); bit 7,a` and,
  when no command is pending, goes to `00E9`, which **writes YM3812 register 04 = 80h**
  (IRQ/flag reset) every interrupt. Boot sets timer2 (`reg 03 = F9`) then `reg 04 = 42`.
- Inference: the real INT source is the **YM3812 IRQ output** (timer 2, 7 ticks of
  1152 clk at 4 MHz = 2.016 ms, about 496 Hz), not a 480 Hz divider. MAME's 480 Hz is an
  approximation. The command latch is **polled**, not interrupt-driven. Model: YM IRQ
  to audio INT, cleared by reg 04 bit 7. Needs hardware confirmation of the IRQ wiring.

## F4. Speech
- `0066` NMI handler `jp 0185`: stores next byte to `A000` (SP0256 ALD) while a
  buffer pointer (`82BD`) is below its end (`82BF/82C0`); SP0256 LRQ drives audio NMI.

## F5. Still unknown (needs measurement or more tracing)
- Pixel clock, H/V totals, sync widths, vblank position. MAME's 256x256 geometry is
  a placeholder; 55.72 Hz is the only PCB-verified figure.
- Watchdog timeout, sprite engine timing, Q3 of the Sauro latch, `user1` PROM role.

## F6. Milestone 3 result (main-CPU subsystem, Verilator, original ROMs)
`rtl/tecfri_main.sv` + `rtl/tecfri_timing.sv` (provisional 320x280) execute the unmodified
`sauro`, `seawolft` and `trckydoc` program ROMs through the self-test to the first ISRs.
`tools/compare_trace.py` finds the first 40 write events (I/O `80-FF` or program `F820-F83F`,
watchdog values excluded) identical to the MAME trace for all three sets. This shows
bus decode, latch, IRQ and input defaults agree with MAME for that window only. It says
nothing about video, sound, wait states or pixel timing. First ISR in RTL occurs at
1.6324 s machine time (MAME 1.6324 s); with different frame periods the near-equality
is not independent evidence of timing.

## F7. Video rules verified against MAME frames (milestone 4a, Python reference model)
`tools/video_ref.py` implements MAME's tile, sprite, scroll and palette-index rules independently
of the RTL and checks six dumped frames per game (`sim/mame/dump_frame.lua`) for `sauro`, `seawolft`
and `trckydoc`: **0 inconsistent colour samples out of 161,280 in all 18 frames** (every drawn
pixel's PROM nibble maps to one MAME colour value per channel). This validates, for attract-mode
content with scroll, two layers and sprites: 8x8 4bpp tile layout (high nibble first), column-major
32x32 maps, attribute bits, sprite quarter-ROM row interleave and pair-swapped x, transparency,
draw order (bg, fg, sprites), palette bank bits, and x scroll semantics (source x = x + scroll).
- fg scroll uses the permutation `{2,1,4,3,6,5,0,7}` on the low 3 bits (confirmed: the game's
  intended scroll increments by 1 per frame through that map).
- **MAME palette DAC (0.288):** channel level = 14*b0 + 31*b1 + 67*b2 + 143*b3 (b0 = LSB of the
  PROM nibble), full scale 255. 0.257's driver text did not reveal this; it came from the dumps.
  Real board resistor values are unknown.
- **0.257 vs 0.288 differences:** Tricky Doc sprite attribute bit 3 is `y += 6` in 0.257 and
  `flipy` in 0.288. The traces and dumps use the 0.288 binary. The attract frames cannot tell the
  two apart (both give identical output), so this is **unresolved**; gameplay frames with bit-3
  sprites (elevator cable, bouncing balls per the 0.257 comment) are needed.
- Capture pitfall found and fixed: MAME's frame notifier fires after vblank, when the interrupt
  routine has already written the next scroll values; state must be snapshotted at interrupt entry.
- Not yet verified: flip_screen (cocktail), gameplay frames (coin/start needed), palette bank bits
  with the bank latch set.

## F8. RTL video block (milestone 4b)
42 MAME frames (attract and scripted gameplay, all three games) reproduce pixel-exactly through
`rtl/tecfri_video.sv` in Verilator; see docs/VIDEO.md for scope and limits. Scripted gameplay needs
`PLAY=1` in `sim/mame/dump_frame.lua` (coin at frame 400, start at 450, pseudo-random controls).
Tricky Doc's later captures are largely the continue/attract screens (credits 00).
