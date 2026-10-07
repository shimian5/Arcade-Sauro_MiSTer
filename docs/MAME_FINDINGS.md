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
- **IRQ model:** MAME's LS259 clears on reset, so Q4=0 and the IRQ is enabled from
  reset. VBLANK start asserts INT (level); Q4=1 clears and masks it; Q4=0 re-enables.
  Firmware pulses Q4 high then low in every ISR, consistent with a flip-flop that is
  cleared by Q4 and set by vblank. Exact flip-flop polarity: provisional.
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
