#!/bin/bash
# Run sim/tb_nvram.sv against rtl/sauro_nvram.sv, and against a mutant with the restore bounds check removed
# (the mutant must FAIL, proving the bounds test is effective).
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # repository root, independent of the folder name
W=$HOME/nv
mkdir -p $W
cd $R/sim
sed 's/ && addr < 27.d2048) mem/) mem/' ../rtl/sauro_nvram.sv > $W/mutant_nobounds.sv
for v in real mutant; do
	if [ $v = real ]; then F=../rtl/sauro_nvram.sv; else F=$W/mutant_nobounds.sv; fi
	verilator --binary --timing -Wno-fatal --top-module tb_nvram --Mdir $W/obj_$v tb_nvram.sv $F > $W/b_$v.log 2>&1 || { tail -5 $W/b_$v.log; exit 1; }
	echo "== $v"
	$W/obj_$v/Vtb_nvram | grep -v "^- " | head -6
done
