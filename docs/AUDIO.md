# Audio (milestone 6): status and evidence

## Structure (rtl/tecfri_audio.sv, rtl/tecfri_speech.sv)
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
