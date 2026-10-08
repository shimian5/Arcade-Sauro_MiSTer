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

## Coefficient-load interlock (added after the equivalence check)

The filter shares its 12-entry coefficient ring between its own per-sample rotation and the controller's coefficient
load, with no interlock. The controller started an allophone's coefficient burst as soon as the previous one ended, so
when the first allophone after an idle period was written at certain points of the 256-clock sample frame, the burst
landed while the filter was mid-computation and old and new coefficients interleaved: an unstable set that rang at
full scale for tens of milliseconds (a loud crack at the start of speech). In `sim/tb_speech_game.sv`, 13 of 32 write
phases reproduced it with this copy; the pristine design has the same structure and the same hazard.

Change: `TCE_CONTROLLER` takes the filter's idle output (`filter_idle_in`) and, with `SAFE_COEF_LOAD = 1` (default),
starts the burst of a coefficient-loading allophone only in the first 40 enabled clocks of the filter's idle window
(the burst takes 12 and the window is about 86). `SAFE_COEF_LOAD = 0` restores the original behaviour;
`sim/tb_speech_equiv.sv` uses it and still reports 0 mismatches against the pristine design. With the interlock all 32
phases give a peak of 52. Allophone starts are delayed by at most one sample frame (about 78 microseconds).

