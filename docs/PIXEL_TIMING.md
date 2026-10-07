# What can and cannot determine the pixel timing

Provisional geometry: 5 MHz pixel enable, 320 x 280 total, 240 x 224 visible,
15.625 kHz, 55.80 Hz (PCB-verified refresh per MAME: 55.72 Hz).

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
