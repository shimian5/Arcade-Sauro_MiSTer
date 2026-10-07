# What can and cannot determine the pixel timing

Provisional geometry (leading hypothesis, adopted 2026-10-07): 5 MHz pixel enable,
**316 x 284** total, 240 x 224 visible, 15.823 kHz line rate, 55.714 Hz
(refresh quoted as PCB-verified in MAME: 55.72 Hz).

Evidence for 316 x 284 (all circumstantial, none measured on a Sauro/Tricky Doc board):
1. MAME `holeland.cpp` (Tecfri): Crazy Rally `set_raw(20 MHz/4, 332, 0, 256, 256, 16, 240)`
   and Hole Land the same 332 at double rate: 5 MHz pixel clock, 332-clock line,
   76 blanking clocks. Checked in the source; those values carry no "verified on PCB" note.
2. Keeping 76 blanking clocks with 240 active pixels gives H = 316.
3. 5 MHz / (316 x 284) = 55.714 Hz, 0.01 % from 55.72 Hz. A 55.72 Hz reading with H = 316
   predicts 283.97 lines.

Caveats: 240 is MAME's chosen visible area for Sauro, not a known hardware width. The
family-consistent alternative is **H = 332** (256 active, as Crazy Rally) with V about 270.3:
332 x 270 = 55.78 Hz (0.11 % off), 332 x 271 = 55.57 Hz. Alternatives rejected on fit:
320 x 280 = 55.80 Hz. The quoted 55.72 Hz is a two-digit reading, so none of these is excluded
by it alone.

## What the Z80 code shows (from MAME traces and disassembly)
- No port exposes a raster or vblank status bit. Inputs are DSW1/DSW2/P1/P2 only. Firmware
  sees video timing only through the frame interrupt. Pixel clock, line count and sync
  widths are therefore **not** observable from software.
- After the vblank interrupt the ISR finishes its video-related writes quickly:
  `A0` at +13 us, `A1` at +38 us, `C0` at +50 us (sauro, MAME trace). The IRQ must arrive
  before active scan reaches the scrolled area, or the scroll update would tear. That bounds
  the IRQ to the end of active video or vblank, with margin under about one line (64 us).
  It does not fix vblank length.
- Frame period: the 55.72 Hz PCB measurement is the only hard figure. Any (H x V x pixel
  period) must reproduce it: at 5 MHz, 320 x 280.4 lines (an integer 280 gives 55.80 Hz,
  281 gives 55.60 Hz; the PCB counter chain presumably yields the true count).

## What would settle it
1. Video or photo evidence from a real board showing the sync frequency or a scoped line.
2. Tracing the 74LS163/393 counter chain on a board photo (needs a sharp top and bottom
   shot) and the PAL equations.
3. Sprite-timing artifacts in recorded real-board footage compared to our output.

Until then pixel timing is an assumption, shown in OSD/docs as unmeasured. The core's
CPU, sound and game logic do not depend on the exact blanking.
