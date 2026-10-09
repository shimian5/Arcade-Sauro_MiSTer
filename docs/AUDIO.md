# Audio (milestone 6): status and evidence

## Structure (rtl/sound/sauro_audio.sv, rtl/sound/sauro_speech.sv)
YM3812 = jtopl2 (4 MHz Sauro family, 2.5 MHz Tricky Doc); Sauro family also has a Z80 sound CPU (4 MHz) with
its ROM/RAM/command latch, INT = YM3812 IRQ (inferred from the firmware, MAME fakes 480 Hz), NMI = SP0256 LRQ.
Pause freezes the sound CPU and chips and mutes. The speech block is currently Speech256 (see below).

## Sound CPU in simulation (Verilator, original ROMs)
First 1.7 s of machine time after reset: 29,523 YM3812 writes and 845 sound-command reads; 845 reads in 1.7 s is a
497 Hz interrupt rate, as predicted for YM timer 2 (7 x 288 us = 2.016 ms) and different from MAME's 480 Hz timer.

## SP0256 candidates, measured against MAME's SP0256 (BSD, sp0256.cpp, docs/reference/mame)
Sauro writes only allophone numbers 00-3B (checked over a 150 s gameplay trace), so every candidate only has to
play the AL2 allophone set. MAME was driven with the same sequences through its real chip (sim/mame/speech_inject.lua,
NMI-paced like the firmware, captured while the YM3812 is silent). Durations per allophone, derived from the write
times (tools/speech_timing.py):

| candidate | agreement with MAME per allophone (ratio candidate / MAME) |
|---|---|
| Speech256 (trcwm, own parameter ROM, not microcode) | 0.06 to 2.6; e.g. 0x07 10 ms vs 46 ms, 0x04 10 ms vs 169 ms |
| ivoice.vhd (Intv_MiSTer, runs the real AL2 ROM, ModelSim) | 0.98 to 1.96; most 1.0-1.3, 0x28 about 1.9; several exactly 170 ms like MAME |

Neither reproduces MAME's timing. ivoice.vhd is much closer and uses the genuine ROM, but is not exact, and I have
not established which side of the remaining difference is wrong. ivoice.vhd is vendored (rtl/sound/imports/intv_ivoice,
GPL position per owner) for evaluation; the clock-enabled Speech256 copy is in rtl/sound/speech256_ce.

## Music and full-core audio vs MAME (Sauro, 9 s of machine time from reset, unmodified ROMs)
`tools/audio_compare.py` on the core's mixed output vs a MAME capture of the same period (MAME is silent until
about 5 s, then the attract music starts): the core is also silent until 5.0 s and the music starts in the same
window. Over the six music windows the RMS level ratio core/MAME is 0.83 to 0.99 (median 0.90, core slightly quieter)
and the log-spectrum correlation is 0.67 to 0.80. 140,720 YM3812 writes, 4,458 sound-command reads (about 497 Hz).
This shows the right music at about the right level; it is not a sample-accurate match, because jtopl and MAME's
ymfm differ and the audio CPU interrupt is the YM3812 timer (about 496 Hz) rather than MAME's 480 Hz timer, which
also makes the tempo about 3 % faster than MAME's. No speech occurs in this window (no coin inserted).
Listening copies: simulation/audio/rtl_sauro_boot_9s.wav and mame_sauro_boot_8s.wav.

## Listening test and upstream check (2026-10-07)
- Owner listened to MAME, ivoice.vhd and Speech256 renditions of three real Sauro phrases (simulation/audio/listen) and
  found Speech256 the most like the voice, with no board recording to judge accuracy. MAME is not treated as authoritative.
- Total phrase length (seconds, first to last audible sample): A: MAME 0.97, Speech256 0.91, ivoice at least 1.55
  (cut at the window); B: 0.40, 0.38, at least 0.65; C: 0.97, 0.90, 1.02. Speech256 matches MAME's phrase length to about
  6 % even though individual allophone lengths differ (see the table above); ivoice runs longer.
- Intv_MiSTer issues (MiSTer-devel/Intv_MiSTer): none reports wrong voice timing or pitch. Related: #20 (voice too quiet; the
  maintainer replied 2026-09-28 "fixed *4 voice amplitude", which probably explains the clipping seen in the vendored
  2026-10-01 ivoice.vhd output), #7 (no in-game voice, fixed 2021), #28 (B-17 Bomber voice drops out, open, no cause),
  #24 (Space Shuttle prototype missing voice, possibly a bad dump). Absence of an accuracy report is not evidence of accuracy.
- Decision: keep Speech256 for now, speech accuracy is UNVERIFIED pending a recording of a real Sauro board.
- When phrases play (MAME with scripted input): phrase B (1B 07 2D 20 00) right after the game starts; phrases A and C recur
  during play every few seconds. What each says has not been identified.

## ivoice.vhd read-through (static, against MAME's sp0256.cpp model; nothing here is confirmed by a hardware recording)
1. `repeat` is decremented in the per-output-sample branch of the state machine (ivoice.vhd lines 1065-1068). MAME decrements its
   repeat count once per pitch period (lpc12_update, rpt-- at each impulse, and per noise period). Not resolved whether ivoice
   compensates elsewhere; the measured allophone-length differences (0.98-1.96x) are consistent with a model difference like this.
2. Pitch/amplitude interpolation (registers IP, IA) is added in sGENE2/sGENE4 on every sample; MAME adds r[14], r[15] only at the start
   of each pitch period (do_int).
3. Impulse spacing: ivoice reloads its counter with PR-1 and fires at zero, so the period is PR samples; MAME's counter gives PR+1.
4. Output scaling: ivoice latches sat(samp/4)*256, MAME uses limit(samp >> 4) << 8. ivoice is 4x louder than MAME (the
   maintainer's 2026-09-28 "x4 voice amplitude" change), which is why it clips; both quantise to 8 bits.
5. The sound latch happens at divcpt = 320 inside the sample period, so the design needs divi >= about 321 phi ticks per sample. At
   Sauro's rate this is met by running phi at 4.59 MHz with divi = 358 (same 12.82 kHz sample rate).

## SP0256 versions
- Sauro's chip is an SP0256-AL2 (board photo); MAME's ROM dump sp0256-al2.bin (CRC b504ac15) is also used, undumped, for seawolft.
- No source found documents any difference between "SP0256-AL2" and "SP0256A-AL2" ROM contents; the Wikipedia article says versions
  differ in the voice data in the mask ROM (AL2 = allophone set, -012 = Intellivoice phrases). A chip-version difference therefore
  cannot explain differences between candidate implementations: all of them are meant to play the same AL2 data.
- Clock is the variable that matters for pace and pitch: the SP0256 is usually driven at 3.12 MHz (10 kHz sample rate, Amstrad SSA-1) but
  some boards use 4 MHz (dk'tronics). MAME has Sauro at 4 MHz (12.82 kHz), which makes speech about 28 % faster and higher than at 3.12 MHz.
- Inference to check on hardware: the second crystal on the Sauro board is marked 8.xxx and sits near the audio section; 8 MHz / 2 = 4 MHz
  would feed the sound CPU, YM3812 and SP0256 (MAME's 20 MHz / 5 gives the same 4 MHz). Tricky Doc has only the 20 MHz crystal, matching
  MAME's 2.5 MHz (20 / 8) YM3812 there. Numerically nothing changes in this core.

## Outcome of the delegated ivoice/SP0256 timing analysis (2026-10-07)
Corrections to the "ivoice.vhd read-through" above, from the agent's analysis (primary documentation: Zbiciak/Palazzolo SP0256 Instruction Set,
CPCWiki SP0256 pages, the Radio Shack AL2 datasheet) and my own checks:
- ivoice's repeat counter DOES count pitch periods (it only decrements when the pulse counter reaches zero), so finding 1 above was wrong, and the
  pulse spacing PR (finding 3) agrees with the documentation (MAME's PR+1 is the odd one). Interpolation per sample (finding 2) is a real bug but
  AL2 never uses interpolation.
- The real ivoice bugs are: swapped SETMODE repeat MSBs, a full extra excitation period after every control instruction, and PAUSE running at stale
  pitch. With those fixed, ivoice matches the documentation-based model to 0.2 percent on 18 allophones (my ModelSim re-run of the clean patched file
  reproduces the agent's numbers for 1B, 07 and 2D exactly: 69.8, 42.5, 63.8 ms). Files: rtl/sound/ivoice_fixed/.
- MAME is off in two places relative to the documentation: impulse spacing per+1 (docs: PR) and `CLOCK_DIVIDER = 7*6*8 = 336` (I confirmed this in
  sp0256.cpp line 34), which makes a 4 MHz chip run at 11.9 kHz instead of the documented 3.12 MHz/312 = 10 kHz ratio (12.82 kHz at 4 MHz). MAME's
  speech therefore runs about 8 percent slow. The 312 divider rests on indirect evidence (the datasheet's pause lengths and the CPCWiki derivation).
- Consequence for Speech256: its whole-phrase lengths were within 6 percent of MAME only because it runs at 12.82 kHz while MAME runs slow; its
  individual allophone lengths disagree with the documented timing (e.g. 04: 10 ms vs 155 ms, 38: 243 ms vs 106 ms).
- Open: what time control instructions really take on silicon (no source; zero is assumed), and any comparison of audio content.
