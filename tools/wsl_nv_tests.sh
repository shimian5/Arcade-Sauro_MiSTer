#!/bin/bash
# NVRAM end-to-end scenarios through the whole core (Sauro): cold start, restore of a valid image, restore of an
# edited (invalid) image, and a save (upload). Each run is about 2 s of machine time; results go to simulation/core/nv_*.
# Run after tools/make_core_vectors.py has produced simulation/core/sauro_image.hex and simulation/nv_images/*.hex.
set -e
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # repository root, independent of the folder name
W=$HOME/sauro_sim
mkdir -p "$W/obj"
cd "$R/sim"
J=../rtl/sound/imports/jtopl/hdl
JT="$J/jtopl2.v $(ls $J/jtopl_*.v) $J/jtopl.v"
S=../rtl/sound/imports/Speech256/verilog/controller
verilator --binary --timing -O3 -CFLAGS "-O3 -march=native" -j 8 --top-module tb_core -Wno-fatal \
	+define+TV80_REFRESH --Mdir "$W/obj" tb_core.sv ../rtl/sauro_core.sv ../rtl/sauro_rom.sv ../rtl/sauro_nvram.sv \
	../rtl/sauro_main.sv ../rtl/video/sauro_timing.sv ../rtl/video/sauro_video.sv ../rtl/sound/sauro_audio.sv \
	../rtl/sound/sauro_speech.sv ../rtl/cpu_z80.v \
	../rtl/tv80/rtl/core/tv80_core.v ../rtl/tv80/rtl/core/tv80_alu.v \
	../rtl/tv80/rtl/core/tv80_mcode.v ../rtl/tv80/rtl/core/tv80_reg.v \
	$JT ../rtl/sound/speech256_ce/*.v $S/ctrlrom.v $S/xlat.v > "$W/build.log" 2>&1 \
	|| { tail -20 "$W/build.log"; exit 1; }
cp "$R/simulation/core/sauro_image.hex" "$W/image.hex"
cd "$W"
run() {  # name, args...
	local name=$1; shift
	rm -f nv_out_*.hex nv_out_audio.log
	./obj/Vtb_core +IMAGE=image.hex +OUT=nv_out "$@" > "nv_$name.log" 2>&1
	cp "nv_$name.log" "$R/simulation/core/nv_$name.log"
	[ -e nv_out_20_ram.hex ] && cp nv_out_20_ram.hex "$R/simulation/core/nv_${name}_ram.hex"
	[ -e nv_out_nvsave.hex ] && cp nv_out_nvsave.hex "$R/simulation/core/nv_${name}_nvsave.hex"
	echo "== $name"; grep -E "hi-score|NVRAM|frame at|PAUSE" "nv_$name.log" | head -6
}
run cold        +F0=20
run restoreM    +F0=20 +NVIMAGE=$R/simulation/nv_images/M.hex
run restoreEdit +F0=20 +NVIMAGE=$R/simulation/nv_images/M_edited.hex
run save        +F0=36 +NVSAVE=30
echo ALL-DONE
