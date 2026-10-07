VERILATOR ?= verilator
OUT       ?= ../simulation

TV80_SRC := $(wildcard ../rtl/tv80/rtl/core/tv80_core.v ../rtl/tv80/rtl/core/tv80_alu.v ../rtl/tv80/rtl/core/tv80_mcode.v ../rtl/tv80/rtl/core/tv80_reg.v)

.PHONY: test cpu-smoke
test: cpu-smoke

cpu-smoke:
	mkdir -p $(OUT)/cpu_smoke
	$(VERILATOR) --binary --timing --top-module tb_cpu_smoke -Wno-fatal +define+TV80_REFRESH \
		--Mdir $(OUT)/cpu_smoke tb_cpu_smoke.sv ../rtl/cpu_z80.v $(TV80_SRC) > $(OUT)/cpu_smoke/build.log 2>&1
	$(OUT)/cpu_smoke/Vtb_cpu_smoke
