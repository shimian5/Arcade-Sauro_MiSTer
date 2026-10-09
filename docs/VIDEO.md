# Video block (milestone 4)

`rtl/video/sauro_video.sv` renders the visible 240x224 area for Sauro, Sea Wolf and Tricky Doc.
Colour PROM lookup and the DAC curve (14/31/67/143 per bit, from MAME 0.288) are inside it.

## What is evidence and what is design
- **Behavior** (tile layout, attribute bits, sprite format, scroll, palette indexing, draw order)
  comes from MAME's `sauro.cpp` and is checked pixel-exactly against MAME frames (below).
- **Structure** is this core's own: per-pixel tile fetch, per-line sprite scan into a
  double-buffered line buffer. The original PCB's sprite engine and timing are unknown.
- **Geometry** is the provisional 316 x 284 at 5 MHz (docs/PIXEL_TIMING.md).

## Verification (Verilator, sim/tb_video.sv, `tools/run_video_tests.ps1`)
RTL output vs MAME's rendered frame, full RGB, every one of 53,760 visible pixels:
**42 dumped frames (6 attract + 8 scripted-gameplay per game, sauro/seawolft/trckydoc): 0 pixels
differ.** A negative control (scroll off by one) fails as expected (1220 pixels). Sprite engine:
0 line overruns, peak 2506 of 5056 clk per line in the tested frames (80 MHz, 16 clk per pixel).
The attract/gameplay captures use MAME 0.288 with the 0.257 ROM sets.

## Not verified / limitations
- Flip screen (cocktail): not implemented, the input is not even connected yet.
- Palette-bank bits (Sauro latch Q5/Q6) were 0 in every captured frame, so that path is untested.
- Tricky Doc sprite attribute bit 3: implemented as flip-y (MAME 0.288); MAME 0.257 treated it as
  y += 6. Owner observation on the core accepts flip-y (see below); no real-board evidence.
- The sprite engine budget is untested for frames with many sprites per line; excess sprites are dropped.
- Graphics ROMs and PROMs are abstract 1-clk-latency memories here; the real core must supply
  them from SDRAM/BRAM (a memory-architecture decision still to be made and measured).
- No sync/DE/hblank output stage and no Direct Video/scandoubler timing work yet.
- Video RAM is read live by the renderer; the real board's arbitration with CPU accesses is unknown.

## Tricky Doc sprite attribute bit 3 (resolved by owner observation, 2026-10-07)
The owner ran RBF 60c2c1c3 on hardware and reported the stage-2 elevator cable correct and the stage-3 balls
touching the ground, i.e. the flip-y reading (MAME 0.288) as implemented. This rests on the owner's
observation of the core, not on a real board or footage, and is adopted as the working truth.

Evidence that led to the check:
Only five sprite codes use the bit in 300 attract captures: 462/463, 477/478 (the stage-3 bouncing red
balls, confirmed by the owner) and 479 (off-screen in the captured frames). `tools/td_variants.py` renders a
dump under both readings with identical palettes. `docs/reference/images/trckydoc_bit3_A-flipy_vs_B-up6.png`
(left: flip-y, as implemented; right: no flip and 6 pixels higher) shows the balls resting on the walkway at
the bottom of their bounce under flip-y, and hovering about 6 pixels above it under the older rule. Which is the
real board's behaviour is not established; an observation on hardware of the ball at the floor and of the stage-2
elevator cable (it should be one continuous line, no 6-pixel step) would decide it.
