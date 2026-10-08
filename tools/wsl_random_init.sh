#!/bin/bash
# Run the already-built tb_core with randomised power-up state (Verilator +rand+reset) for several seeds, in parallel,
# to find logic that only works when every register starts at zero. Needs ~/tecfri_sim/obj from wsl_core_sim.sh / wsl_nv_tests.sh.
cd $HOME/tecfri_sim || exit 1
for s in "$@"; do
	./obj/Vtb_core +IMAGE=image.hex +OUT=rnd$s +F0=20 +MS=2600 +verilator+rand+reset+2 +verilator+seed+$s > rnd$s.log 2>&1 &
done
wait
for s in "$@"; do echo "== seed $s"; grep -E "^audio:|hi-score|done after|TIMEOUT" rnd$s.log | cut -c1-200; done
