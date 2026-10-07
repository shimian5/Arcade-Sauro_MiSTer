# Integration (milestone 5): machine core and MiSTer top level

## Structure
- `Arcade-Tecfri.sv`: `emu` top level. Unmodified `sys/`; standard `hps_io`, `pll` (instance named `pll`),
  `arcade_video`, and the Pause_MiSTer `pause` module. DIP bytes arrive via ioctl index 254.
- `rtl/tecfri_core.sv`: everything else, so Verilator can drive the ROM download and run from reset.
- ROM storage is all M10K (`rtl/tecfri_rom.sv`), written by the download, one clk read latency. No SDRAM.
- Download layout (index 0) and the one-byte board select (index 1): see the header of `tecfri_core.sv`;
  `tools/rom_layout.py` is the single source for images and MRA files (CRC and size are checked when built).

## Clocks
80 MHz system clock from the 50 MHz reference. 1/16 gives the 5 MHz CPU and pixel enable; 1/20 (4 MHz)
and 1/32 (2.5 MHz) are reserved for the audio side. CLK_VIDEO is the system clock with a uniform
1-in-16 CE_PIXEL. MAME's clock plan is used; the second crystal on the Sauro board ("8...") is unexplained.

## Inputs
MiSTer joystick bits 0-3 are right, left, down, up; bits 4 up are the J1 buttons: Button 1, Button 2,
Start 1P, Start 2P, Coin, Pause (`jn` defaults A, B, Start, Select, R, L, identical to the MRA `buttons`
default). P1 byte = B1 B2 COIN1 COIN2 LEFT RIGHT UP DOWN; P2 byte = B1 B2 START1 START2 LEFT RIGHT UP DOWN.

## Verification (Verilator, unmodified ROMs, ROM download through the ioctl interface)
- `sauro`: the real ROM/RAM self-test passes and the screen reads "ROM 1 ... OK, ROM 2 ... OK, RAM ... OK"
  (viewed in the RTL frame), then attract starts. Frames at interrupt acknowledge 5, 10 and 20 match
  MAME frames 4, 9 and 19 pixel for pixel (0 of 53,760 pixels). MAME's tap does not count the first
  interrupt entry, hence the offset of one. Video RAMs are identical to MAME's at that moment; 4 bytes of
  work RAM (stack contents) differ because they depend on the instruction phase of the interrupt.
- Pause: for a 3-frame pause the CPU made 0 bus writes and 0 interrupt acknowledges, video timing kept
  running (269,232 pixel clocks = 3 x 316 x 284, 3 vsync pulses) and the machine resumed (6 interrupts later).
- Cold start state: work RAM initialises to all ones (MAME NVRAM default); no saving yet.

## Not done / limitations
- No sound, NVRAM saving, flip screen (cocktail), CRT geometry controls or Direct Video checking.
- `seawolft` and `trckydoc` have not been run end to end through the core (only `sauro`); their video was
  verified from MAME state dumps.
- Sync placement (hsync 252-275, vsync lines 236-238 of 316 x 284) is a guess; geometry is provisional.
- No hardware has run this design.
