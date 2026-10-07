#!/bin/bash
# Build and run sim/tb_core.sv natively inside WSL (own filesystem, -O3) and copy the frame
# dumps back. Long runs on /mnt/c have been unreliable on this machine.
# Usage: tools/wsl_core_sim.sh <set> [+Fn=<ack count> ...] [+TRICKY]   (run from any directory)
set -e
R=/mnt/c/MiSTerDev/Arcade-Tecfri_MiSTer
W=$HOME/tecfri_sim
SET=$1; shift
mkdir -p "$W/obj"
cd "$R/sim"
verilator --binary --timing -O3 -CFLAGS "-O3 -march=native" -j 8 --top-module tb_core -Wno-fatal \
	+define+TV80_REFRESH --Mdir "$W/obj" tb_core.sv ../rtl/tecfri_core.sv ../rtl/tecfri_rom.sv \
	../rtl/tecfri_main.sv ../rtl/tecfri_timing.sv ../rtl/tecfri_video.sv ../rtl/cpu_z80.v \
	../rtl/tv80/rtl/core/tv80_core.v ../rtl/tv80/rtl/core/tv80_alu.v \
	../rtl/tv80/rtl/core/tv80_mcode.v ../rtl/tv80/rtl/core/tv80_reg.v > "$W/build.log" 2>&1
cp "$R/simulation/core/${SET}_image.hex" "$W/image.hex"
cd "$W"
rm -f out_*.hex
time ./obj/Vtb_core +IMAGE=image.hex +OUT=out "$@" > run.log 2>&1; grep -v "^- " run.log | tail -12
for f in out_*.hex; do cp "$f" "$R/simulation/core/${SET}_rtl_${f#out_}"; done
