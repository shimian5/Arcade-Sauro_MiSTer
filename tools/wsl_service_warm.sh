#!/bin/bash
# Warm service restart: run with DSW1 = 66, at 3 s switch Service on and reset for 100 ms (+SVC_AT), dump frame + RAM at the
# 150th interrupt (the game's start-up self-test takes about 1.7 s after the restart) and print the firmware mode bytes.
# Needs ~/sauro_sim/obj from wsl_core_sim.sh.
cd $HOME/sauro_sim || exit 1
./obj/Vtb_core +IMAGE=image.hex +OUT=warm +F0=150 +MS=${1:-6300} +DSW1=66 +SVC_AT=3000 > warm.log 2>&1
python3 - <<'PY'
r=[int(x,16) for x in open('warm_150_ram.hex').read().split()]
for name,a in (('E31A (~DSW1)',0x31a),('E316 (mode)',0x316),('E318',0x318),('E0CA',0x0ca)): print(name, '%02x'%r[a])
PY
