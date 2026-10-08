#!/bin/bash
# Build and run sim/tb_core.sv natively inside WSL (own filesystem, -O3) and copy the results back.
# Long runs on /mnt/c have been unreliable on this machine.
# Usage: tools/wsl_core_sim.sh <set> [+Fn=<ack count> ...] [+TRICKY] [+WAV] [+PAUSE_AT=n +PAUSE_FRAMES=m]
# Results land in simulation/core/<set>_rtl_*: frame dumps (_<n>.hex, _<n>_ram.hex), audio (.raw, _audio.log).
set -e
R=/mnt/c/MiSTerDev/Arcade-Tecfri_MiSTer
W=$HOME/tecfri_sim
SET=$1; shift
mkdir -p "$W/obj"
cd "$R/sim"
J=../rtl/sound/imports/jtopl/hdl
JT="$J/jtopl2.v $(ls $J/jtopl_*.v) $J/jtopl.v"
S=../rtl/sound/imports/Speech256/verilog/controller
verilator --binary --timing -O3 -CFLAGS "-O3 -march=native" -j 8 --top-module tb_core -Wno-fatal \
	+define+TV80_REFRESH --Mdir "$W/obj" tb_core.sv ../rtl/tecfri_core.sv ../rtl/tecfri_rom.sv ../rtl/tecfri_nvram.sv \
	../rtl/tecfri_main.sv ../rtl/tecfri_timing.sv ../rtl/tecfri_video.sv ../rtl/tecfri_audio.sv \
	../rtl/tecfri_speech.sv ../rtl/cpu_z80.v \
	../rtl/tv80/rtl/core/tv80_core.v ../rtl/tv80/rtl/core/tv80_alu.v \
	../rtl/tv80/rtl/core/tv80_mcode.v ../rtl/tv80/rtl/core/tv80_reg.v \
	$JT ../rtl/sound/speech256_ce/*.v $S/ctrlrom.v $S/xlat.v > "$W/build.log" 2>&1 \
	|| { tail -20 "$W/build.log"; exit 1; }
cp "$R/simulation/core/${SET}_image.hex" "$W/image.hex"
cd "$W"
rm -f out_*.hex out.raw out_audio.log
time stdbuf -oL ./obj/Vtb_core +IMAGE=image.hex +OUT=out "$@" 2>&1 | tee run.log | grep --line-buffered -v "^- "
for f in out_*.hex; do [ -e "$f" ] && cp "$f" "$R/simulation/core/${SET}_rtl_${f#out_}"; done
[ -e out.raw ] && cp out.raw "$R/simulation/core/${SET}_rtl.raw"
[ -e out_audio.log ] && cp out_audio.log "$R/simulation/core/${SET}_rtl_audio.log"
true
