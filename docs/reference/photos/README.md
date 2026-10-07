# Board photo: Tecfri 60922/1

`tecfri-60922-1-board.webp` was supplied by the project owner (original source
not recorded; the owner also pointed to https://jammarcade.net/tricky-doc-repair-log/
as a small source of board information). Which game's board this is has not been
established: one Z80 (Zilog Z0840006PSC, date code 8709) is visible and the EPROM
labels are Tecfri-stamped.

Observations (read from the photo, unverified chip-level detail):
- One crystal, marked 20.000 MHz. No second crystal is visible. The 8 MHz crystal
  listed in MAME for the Sauro *bootleg* is therefore not evidence for the original.
- Video timing is built from discrete counters: several 74LS163 (4-bit sync
  counters), 74LS393, 74LS107/74LS74 dividers, 74LS169 up/down counters, with
  74LS157 muxes and 74LS273/373 latches. There is no custom video chip.
- PAL16R6A, several PAL16R4A and a PAL16L8A are present (decode/state logic). Their
  fuse maps are not dumped, so decode and timing derived from them stay unknown.
- Work RAM TMM2016BP-10 (2 KB), a battery holder (NVRAM), two 8-position DIP banks.
