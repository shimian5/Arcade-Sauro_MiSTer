cd "$(dirname "${BASH_SOURCE[0]}")/../sim"
S=../rtl/sound/imports/Speech256/verilog/controller
verilator --binary --timing -O3 --top-module tb_speech -Wno-fatal --Mdir $HOME/sp/obj tb_speech.sv ../rtl/sound/sauro_speech.sv ../rtl/sound/speech256_ce/*.v $S/ctrlrom.v $S/xlat.v > $HOME/sp/build.log 2>&1 || tail $HOME/sp/build.log
cd $HOME/sp && ./obj/Vtb_speech +SEQ=3 +OUT=sp3 | grep ^speech; cat sp3.log
