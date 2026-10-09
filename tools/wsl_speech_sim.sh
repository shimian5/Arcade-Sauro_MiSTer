#!/bin/bash
# Build and run sim/tb_speech.sv inside WSL; results are copied to simulation/speech_<n>.{raw,log}.
set -e
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # repository root, independent of the folder name
W=$HOME/sp
mkdir -p "$W"
cd "$R/sim"
S=../rtl/sound/imports/Speech256/verilog/controller
verilator --binary --timing -O3 --top-module tb_speech -Wno-fatal --Mdir "$W/obj" tb_speech.sv \
	../rtl/sound/sauro_speech.sv ../rtl/sound/speech256_ce/*.v $S/ctrlrom.v $S/xlat.v > "$W/build.log" 2>&1 \
	|| { tail -15 "$W/build.log"; exit 1; }
cd "$W"
for q in 0 1 2; do
	./obj/Vtb_speech +SEQ=$q +OUT=sp$q | grep "^speech"
	cp sp$q.raw "$R/simulation/speech_$q.raw"
	cp sp$q.log "$R/simulation/speech_$q.log"
done
