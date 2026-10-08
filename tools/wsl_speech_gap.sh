cd /mnt/c/MiSTerDev/Arcade-Tecfri_MiSTer/sim
S=../rtl/sound/imports/Speech256/verilog/controller
verilator --binary --timing -O3 --top-module tb_speech -Wno-fatal --Mdir $HOME/sp/obj tb_speech.sv ../rtl/tecfri_speech.sv ../rtl/sound/speech256_ce/*.v $S/ctrlrom.v $S/xlat.v > $HOME/sp/build.log 2>&1 || tail $HOME/sp/build.log
cd $HOME/sp && ./obj/Vtb_speech +SEQ=3 +OUT=sp3 | grep ^speech; cat sp3.log
