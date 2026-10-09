#!/bin/bash
# Run the core with the Sauro DIP bank 1 Service switch off (66) and on (67) and dump frame + RAM at the 300th interrupt.
# Needs ~/sauro_sim/obj from wsl_core_sim.sh. Result: ~/sauro_sim/svc{0,1}_300.hex and _300_ram.hex
cd $HOME/sauro_sim || exit 1
./obj/Vtb_core +IMAGE=image.hex +OUT=svc0 +F0=300 +MS=7000 +DSW1=66 > svc0.log 2>&1 &
./obj/Vtb_core +IMAGE=image.hex +OUT=svc1 +F0=300 +MS=7000 +DSW1=67 > svc1.log 2>&1 &
wait
ls -la svc*_300*.hex
