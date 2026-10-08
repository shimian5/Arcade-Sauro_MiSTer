VERILATOR ?= verilator
OUT       ?= ../simulation

TV80_SRC := $(wildcard ../rtl/tv80/rtl/core/tv80_core.v ../rtl/tv80/rtl/core/tv80_alu.v ../rtl/tv80/rtl/core/tv80_mcode.v ../rtl/tv80/rtl/core/tv80_reg.v)

.PHONY: test cpu-smoke main-build
test: cpu-smoke

cpu-smoke:
	mkdir -p $(OUT)/cpu_smoke
	$(VERILATOR) --binary --timing --top-module tb_cpu_smoke -Wno-fatal +define+TV80_REFRESH \
		--Mdir $(OUT)/cpu_smoke tb_cpu_smoke.sv ../rtl/cpu_z80.v $(TV80_SRC) > $(OUT)/cpu_smoke/build.log 2>&1
	$(OUT)/cpu_smoke/Vtb_cpu_smoke

# Main-CPU subsystem executing original ROMs (needs `python tools/prepare_roms.py <romdir>` first).
MAIN_SRC := tb_main.sv ../rtl/tecfri_main.sv ../rtl/tecfri_timing.sv ../rtl/cpu_z80.v $(TV80_SRC)
main-build:
	mkdir -p $(OUT)/main
	$(VERILATOR) --binary --timing --top-module tb_main -Wno-fatal +define+TV80_REFRESH 		--Mdir $(OUT)/main $(MAIN_SRC) > $(OUT)/main/build.log 2>&1

# Video block vs MAME frame vectors (see tools/prep_video_vectors.py).
VIDEO_SRC := tb_video.sv ../rtl/tecfri_video.sv ../rtl/tecfri_timing.sv
video-build:
	mkdir -p $(OUT)/video
	$(VERILATOR) --binary --timing --top-module tb_video -Wno-fatal 		--Mdir $(OUT)/video $(VIDEO_SRC) > $(OUT)/video/build.log 2>&1

# Whole machine core: ROM download, reset, original-ROM execution, video (tools/make_core_vectors.py).
JTOPL := ../rtl/sound/imports/jtopl/hdl
AUDIO_SRC := $(JTOPL)/jtopl2.v $(filter-out $(JTOPL)/jtopll% $(JTOPL)/jt2413.v $(JTOPL)/jtopl2.v,$(wildcard $(JTOPL)/*.v)) \
	$(wildcard ../rtl/sound/speech256_ce/*.v) ../rtl/sound/imports/Speech256/verilog/controller/ctrlrom.v ../rtl/sound/imports/Speech256/verilog/controller/xlat.v
CORE_SRC := tb_core.sv ../rtl/tecfri_core.sv ../rtl/tecfri_rom.sv ../rtl/tecfri_main.sv ../rtl/tecfri_timing.sv \
	../rtl/tecfri_video.sv ../rtl/tecfri_audio.sv ../rtl/tecfri_speech.sv ../rtl/cpu_z80.v $(TV80_SRC) $(AUDIO_SRC)
core-build:
	mkdir -p $(OUT)/core
	$(VERILATOR) --binary --timing --top-module tb_core -Wno-fatal +define+TV80_REFRESH \
		--Mdir $(OUT)/core $(CORE_SRC) > $(OUT)/core/build.log 2>&1

# Clock-enabled Speech256 copy vs the pristine import (see rtl/sound/speech256_ce/ADAPTATION.md).
SP256 := ../rtl/sound/imports/Speech256/verilog
SP256_ORIG := $(SP256)/speech256_top/speech256_top.v $(SP256)/controller/controller.v $(SP256)/controller/ctrlrom.v \
	$(SP256)/controller/xlat.v $(SP256)/filter/filter.v $(SP256)/source/source.v $(SP256)/spmul/spmul.v $(SP256)/pwmdac/pwmdac.v
SP256_CE := $(wildcard ../rtl/sound/speech256_ce/*.v)
speech-equiv:
	mkdir -p $(OUT)/speech_equiv
	$(VERILATOR) --binary --timing --top-module tb_speech_equiv -Wno-fatal --Mdir $(OUT)/speech_equiv \
		tb_speech_equiv.sv $(SP256_ORIG) $(SP256_CE) > $(OUT)/speech_equiv/build.log 2>&1
	$(OUT)/speech_equiv/Vtb_speech_equiv
