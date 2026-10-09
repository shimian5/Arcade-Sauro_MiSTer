#!/bin/bash
# Build sim/tb_audio.sv (Sauro sound board only) and run one scenario per argument set in parallel.
# Usage: tools/wsl_audio_only.sh "<name> <plusargs...>" ...   e.g. "c9b +CMD=9b +CMD_AT=1500 +MS=4000"
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # repository root, independent of the folder name
W=$HOME/sauro_audio
mkdir -p $W/obj; cd $R/sim
J=../rtl/sound/imports/jtopl/hdl
JT="$J/jtopl2.v $(ls $J/jtopl_*.v) $J/jtopl.v"
S=../rtl/sound/imports/Speech256/verilog/controller
verilator --binary --timing -O3 --top-module tb_audio -Wno-fatal +define+TV80_REFRESH --Mdir $W/obj tb_audio.sv \
	../rtl/sound/sauro_audio.sv ../rtl/sound/sauro_speech.sv ../rtl/sauro_rom.sv ../rtl/cpu_z80.v \
	../rtl/tv80/rtl/core/tv80_core.v ../rtl/tv80/rtl/core/tv80_alu.v ../rtl/tv80/rtl/core/tv80_mcode.v ../rtl/tv80/rtl/core/tv80_reg.v \
	$JT ../rtl/sound/speech256_ce/*.v $S/ctrlrom.v $S/xlat.v > $W/build.log 2>&1 || { tail -20 $W/build.log; exit 1; }
cp $R/simulation/core/sauro_image.hex $W/image.hex
cd $W
for a in "$@"; do
	set -- $a; n=$1; shift
	( ./obj/Vtb_audio +IMAGE=image.hex +OUT=$n "$@" | grep audio-only | sed "s/^/$n: /" ) &
done
wait
