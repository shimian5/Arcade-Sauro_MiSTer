# ivoice.vhd with timing fixes (candidate SP0256, NOT in the build)

Derived from `../imports/intv_ivoice/ivoice.vhd` (MiSTer-devel/Intv_MiSTer @ 808bbcb, see that folder's PROVENANCE.txt). The pristine import
is untouched. These patches come from a delegated agent's analysis (2026-10-07) and were re-simulated by the main session in ModelSim:

1. SETMODE read the two repeat MSBs in the wrong order (`inst(7:6)`); the field is LSB first (`inst(6) & inst(7)`). This made allophone 0x28
   about 1.9x long and some others short.
2. Control instructions (SETPAGE/SETMODE/JMP/JSR/RTS, including the halting RTS) each emitted a full extra excitation period; now they go
   straight back to the sequencer and take no output time.
3. PAUSE only cleared the amplitude, so it ran at the previous allophone's pitch; now it runs as 64-sample noise-style periods.
4. Pitch/amplitude interpolation was applied every sample; now once per pitch (or 64-sample) period. The AL2 ROM never uses interpolation, so
   this has no effect on Sauro and is untested.

`ivoice_fixed.vhd` is the patched file; `ivoice_fixed_scaled.vhd` also changes the output scaling from `sat(samp/4)*256` to `sat(samp/16)*256`
(MAME's `limit(samp >> 4) << 8`), undoing the maintainer's x4 boost that made the original clip. `ivoice_fix.diff` is the agent's diff against
the vendored file (it also contains one stray blank-line hunk). `tools/sp_model.py` is the agent's Python port of MAME's micro()/lpc12 sample
counts used as a reference; it reproduces MAME's durations to 0.1 ms and the original ivoice's, and its "doc" variant (documentation timing at
12.82 kHz) agrees with the patched ivoice to 0.2 percent. Evidence is timing only; audio content has not been compared sample for sample.
