# Board photos

## tricky-doc-60922-1-board.webp (saved)
Tecfri 60922/1, **Tricky Doc** (identified by the project owner). Supplied by the
owner; original source not recorded. The owner also pointed to
https://jammarcade.net/tricky-doc-repair-log/ (no raster information).
- One Z80 (Zilog Z0840006PSC, date code 8709), one crystal marked 20.000 MHz.
- Discrete video timing: several 74LS163, 74LS393, 74LS107, 74LS74, 74LS169; no custom video chip.
- PAL16R6A, PAL16R4A (several) and PAL16L8A (fuse maps not dumped).
- TMM2016BP-10 work RAM, battery holder, two 8-position DIP banks, 3 PROM-sized sockets.

## Sauro board (NOT yet saved as a file)
The owner posted a photo of the **Sauro** board (dual Z80, two crystals) in chat. The
image exists only inline in the conversation, so no file could be written; the owner
needs to place it here (e.g. `sauro-board.jpg`). Read from the inline image:
- Two Z80s: Z8400B PS "Z80B" (date 8651, main) and Z8400A PS "Z80A" (date 8643, audio).
- Two crystals: one marked 20.000 MHz (centre); a second small crystal at the lower
  left near the audio section whose marking is **not legible** in the downscaled image.
- GI SP0256-AL2 (Taiwan) in a socket, 74LS393/163/169/174/273/157 etc., PAL16L8A, PAL16R4A,
  PAL16R6A, Toshiba TC5516APL and MCM2016 RAMs, Am2149-35 1Kx4 SRAMs (probably video RAM),
  a black enclosure/heat-sink over the audio amplifier, two DIP banks, battery position.
- The second crystal is the main open item: its frequency and which circuit it clocks
  (speech, YM3812, or video) are unknown until the marking is read.

## sauro-rom-battery-area.png (saved)
Close-up of the Sauro board supplied by the project owner (2026-10-08): two EPROMs (one ST 27C256 type) at silkscreen
positions about 10 and 9, the battery holder with an adhesive pad, 74ALS244-type buffers along the top, and two small
resistor-and-diode pairs left of the upper EPROM. This crop does NOT show the colour PROMs (82S137 x3) or the resistor
network feeding the video output, so it gives no palette evidence. Still wanted: the area around the three colour PROMs and
the resistors / transistors between them and the JAMMA video pins (to read the real DAC weights and any output gain).
