# Speech256 with a clock enable

Derived from `../imports/Speech256` (trcwm/Speech256 @ 4c311cf, GPL-3.0; see `../imports/Speech256/LICENSE`),
which is kept pristine. The original design clocks every register from one free-running `clk` (256 clocks per
10 kHz output sample). This core runs everything from one 80 MHz clock, so the copies here add a clock enable.

Changes, and only these:
- modules renamed with a `TCE_` prefix (`TCE_SPEECH256_TOP`, `TCE_CONTROLLER`, `TCE_FILTER`, `TCE_SOURCE`,
  `TCE_SPMUL`, `TCE_PWMDAC`) so the original and adapted versions can be simulated together;
- new input `ce`, passed down the hierarchy;
- the clocked process of each module updates only when `ce` is high (`else begin` became `else if (ce) begin`);
- in the controller, `rom_en` is `ce` instead of 1;
- `CTRLROM` and `XLAT` are unchanged and taken from `../imports/Speech256`.

`sim/tb_speech_equiv.sv` checks that, with `ce` held high or gated, the adapted design produces exactly the
same samples as the original.
