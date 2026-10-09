# Tecfri core: hardware spec (MAME-derived) and plan

Status: **draft for review, no RTL written.** Every fact below comes from MAME
0.257 `src/mame/tecfri/sauro.cpp` unless stated. No schematics are available, so
all of it is *provisional* (rule 2) until confirmed by traces or physical
measurement.

## 1. Provenance

Local copies (gitignored) in `docs/reference/mame/`, fetched from
`https://raw.githubusercontent.com/mamedev/mame/mame0257/src/`:
`mame/tecfri/sauro.cpp`, `devices/sound/{sp0256,ymopl}.*`,
`devices/machine/{74259,gen_latch,watchdog,nvram}.cpp`, `devices/cpu/z80/z80.cpp`.
The driver is a single file (video included); there is no `sauro_v.cpp`.

## 2. Games in scope (non-clones, per request)

| MAME set | Title | Board variant | ROM zip found |
|---|---|---|---|
| `sauro` | Sauro (set 1) | Sauro board | yes |
| `trckydoc` | Tricky Doc (set 1) | Tricky Doc board | yes |
| `seawolft` | Sea Wolf (Tecfri), a **clone of sauro** | Sauro board | yes |

Note: `seawolf.zip` on the NAS is the unrelated Midway game. The Tecfri one is
`seawolft`. It shares audio CPU, SP0256, fg/bg tile and several ROMs with
`sauro`; it differs in main CPU, `bgtiles` second half and the sprites. Its PROMs and
SP0256 ROM were not dumped from that PCB (MAME reuses Sauro's), which is an
open uncertainty. Later: `sauroa/b/c/p/rr`, `trckydoca` (DIP differences only).

## 3. Two board variants

| | Sauro / Sea Wolf | Tricky Doc |
|---|---|---|
| CPUs | Z80 main 5 MHz (20/4) + Z80 audio 4 MHz (20/5) | **one** Z80 5 MHz, no audio CPU |
| FM | YM3812 @ 4 MHz | YM3812 @ 2.5 MHz (20/8) |
| Speech | SP0256-AL2 @ 4 MHz, its `LRQ` drives audio NMI | none |
| Layers | bg + fg 32x32 tiles, sprites (1024 codes) | bg only, sprites (512 codes) |
| I/O | Z80 I/O ports (`IN`/`OUT`) | memory mapped at `F800-F83F` |
| Main ROM | 64 KB at 0000-DFFF visible (banks 0000-7FFF / 8000-FFFF files) | same |
| Colour | 3 x 82S137 1Kx4 PROMs, 1024 entries RGB444 | 3 x 256-byte PROMs (same layout, only 0x100 loaded) |

Common: 20 MHz XTAL, 55.72 Hz refresh (verified on PCB per MAME), visible area
240x224 (cols 8-247, rows 16-239), vblank ~5 ms, 2 KB battery-backed RAM at
`E000-E7FF` (MAME NVRAM default fill = all 1s), watchdog, LS259 addressable
latch, 8-bit DIP banks DSW1/DSW2, inputs P1/P2 (active high).

## 4. Main CPU map

Sauro (`main_prg_map` / `main_io_map`):

```
0000-DFFF ROM        E000-E7FF RAM (NVRAM)   E800-EBFF sprite RAM
F000-F3FF bg tile    F400-F7FF bg attr       F800-FBFF fg tile   FC00-FFFF fg attr
IN  00 DSW1  20 DSW2  40 P1  60 P2
OUT 80 sound command (stored | 0x80)   A0 bg scrollx   A1 fg scrollx (see 5)
    C0-CF LS259 (A0 = data, A1-A3 = address)   E0 watchdog reset
```

Tricky Doc (`prg_map`): same 0000-F7FF, sprite RAM mirrored at EC00-EFFF, plus
`F800 DSW1, F808 DSW2, F810 P1, F818 P2, F820-F821 YM3812, F828 read=watchdog
reset, F830 bg scrollx, F838-F83F LS259 (D0 = data, A0-A2 = address)`.

LS259 outputs: Q4 = IRQ enable/reset (**both** boards). Sauro: Q0 flip, Q1/Q2
coin counters, Q3 unknown ("sound IRQ trigger?"), Q5/Q6 palette bank bits
(+0x10/+0x20 to colour). Tricky Doc: Q1 flip, Q2/Q3 coin counters.

## 5. Timing-sensitive behaviours to model (rule 3)

- **Main IRQ:** level-held, asserted at VBLANK start *if enabled*; cleared only by
  latch Q4 going low->enabled (`irq_enable = !Q4`; enabling also clears the line). Z80
  IM1 presumably; the vector must be checked in a trace.
- **Sound command latch:** write ORs bit 7; read returns and clears it. Audio
  CPU reads `E000`; `E000-E006` and `E00E-E00F` writes are ignored.
- **Audio IRQ:** MAME fakes it with an 8x60 = 480 Hz periodic interrupt
  (`// ?`). **Unverified; no real source known.** Candidate hardware origin is
  unknown. This is the largest modelling risk for Sauro.
- **SP0256:** `A000` write = address-load (ALD); `LRQ` low->NMI on the audio CPU.
  MAME delays LRQ by 50 clocks after ALD. Speech256 must be checked for this.
- **Watchdog:** MAME default timeout to be read from `watchdog.cpp`; port or
  read-strobe resets it. Real reset behavior needs a measured value.
- **fg scroll quirk:** low 3 bits are permuted via `{2,1,4,3,6,5,0,7}` (flipped
  `{0,7,2,1,4,3,6,5}`), high 5 bits pass through.
- **Sprites:** MAME draws instantly from RAM; real scan/priority/line-buffer
  timing, "sprite lag" and the 0xF8 sy hide value are unknown. Sprite attr bits differ
  between boards (Sauro: bit3 = x-extend, bit2 flipx, code 10 bits;
  Tricky Doc: bit1 = x-extend, bit3 = y+6, code 9 bits, x-2).
- **Unknown PROM:** `user1` 512-byte PROM (CRC 5261bc11) appears in
  `trckydoc*` and `saurobl` but is unused by MAME. Probably address decode or
  timing; it must be understood or at least shipped in the MRA.

## 6. Open questions / risks

1. Pixel clock and total H/V counts are not in MAME (256x256 placeholder).
   Need: derive from 55.72 Hz and the 20 MHz crystal (candidates 5 or 6.667 MHz
   pixel clock), then confirm with a recorded MAME video trace.
2. The audio-CPU 480 Hz IRQ source (above).
3. T80 location (see section 8) and the "external refresh" requirement. Z80
   refresh is only needed if DRAM exists; none is identified in MAME. Please confirm why it is wanted.
4. SP0256: Speech256 repo license, its SDRAM/ROM interface, and whether the AL2
   ROM (`b504ac15`, 2 KB internal) is accepted via the MRA.
5. NVRAM: this is true battery RAM, so I plan the standard `hps_io` NVRAM
   save/load of 2 KB (filled 0xFF when absent) instead of `hiscore.v`. Tell me if
   you prefer hiscore.
6. Hardware PROM for `seawolft` not dumped; Sauro's assumed.

## 7. Architecture (proposed)

- `sys/` untouched; top-level `Tecfri.sv` with `emu`, `hps_io`.
- Clocks: PLL (instance `pll`) 40/80 MHz-class system clock with clock enables
  for 5 MHz, 4 MHz, YM3812 4/2.5 MHz, SP0256 4 MHz; video pixel enable from a
  separate counter. Machine speed is independent of video output.
- Modules: `sauro_board` (per-variant map select via game index), `video`
  (tile fetch, sprite engine, palette PROM), `ym3812` (jtopl), `sp0256` (vendored
  Speech256), `pause.sv` (from Victory, with state-hold), `nvram`, MRA builder.
- ROMs in SDRAM: main 64 KB, audio 32 KB, tiles/sprites 192-ish KB, PROMs, AL2.

## 8. Dependencies

- T80: **`Arcade-SegaVCO_MiSTer` doesn't exist** under `C:\MiSTerDev`. T80 copies
  are in `Arcade-DonkeyKong_MiSTer/rtl/T80`; Victory uses tv80. Need your pick.
- jtopl and Speech256: clone, pin commits, vendor under `rtl/`, keep licenses.
- Pause: Victory `rtl/pause.sv` (also Exidy2 `pause.v`).

## 9. Milestones (reported separately, rule: playable != accepted)

1. Repo rename, `AGENTS.md`, build scripts, Verilator harness. 2. MAME
reference-trace tooling (Lua) for each of the 3 games. 3. CPU + RAM + inputs
boots original ROMs, self-test observed. 4. Video vs MAME frames. 5. Sound.
6. Pause/reset. 7. NVRAM. 8. MRA + RBF packaging. 9. Full Quartus flow + timing
review. 10. Hardware acceptance (needs your testing).

## 10. Controls (from MAME)

P1: B1, B2, coin1, coin2, joystick L/R/U/D (bits 0-7). P2 byte: B1, B2
(cocktail), START1, START2, joystick. DSW1: service, demo sounds, cabinet, free
play, difficulty, continue, freeze. DSW2: coin A/B, lives. `trckydoca` changes
coin B only. Standard rotation, no rotate option needed.
