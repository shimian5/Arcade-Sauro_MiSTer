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
CORE_SRC := tb_core.sv ../rtl/tecfri_core.sv ../rtl/tecfri_rom.sv ../rtl/tecfri_main.sv ../rtl/tecfri_timing.sv \
	../rtl/tecfri_video.sv ../rtl/cpu_z80.v $(TV80_SRC)
core-build:
	mkdir -p $(OUT)/core
	$(VERILATOR) --binary --timing --top-module tb_core -Wno-fatal +define+TV80_REFRESH \
		--Mdir $(OUT)/core $(CORE_SRC) > $(OUT)/core/build.log 2>&1
