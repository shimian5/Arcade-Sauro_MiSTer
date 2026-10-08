# Battery RAM (NVRAM) persistence

Work RAM E000-E7FF (2 KB) is battery backed on the board; MAME's NVRAM default is all ones. `rtl/tecfri_nvram.sv` holds it and
implements MiSTer's standard save/restore stream (ioctl index 4, MRA `<nvram index="4" size="2048"/>`); the interface follows the one
used by the Victory core. `sys/` is unchanged.

## How the game uses it (measured in MAME, sim/mame/nv_probe.lua)
- At boot the game validates the RAM contents. A valid image (MAME's own saved file) is kept: the game does not rewrite the default
  hi-score. An edited image (3 bytes of the hi-score changed) or garbage is rejected and re-initialised (3 default hi-score writes
  from pc=0299 at 1.632 s). So persistence matters, but only complete images that the game itself produced are accepted.
- The hi-score lives at E057-E059 (BCD, little endian: 063820 = 20 38 06). The stack also lives in this RAM, so it changes constantly.

## Behaviour of the module
- Cold start: all ones. Restore: index-4 download, bounds checked, ordered, accepted while the machine is paused or in reset; the machine is held
  in reset for any download so the game boots with the restored RAM. Save: index-4 upload through a synchronous read port (hps_io primes
  address 0). The CPUs and sound freeze during a transfer; video keeps running.
- Autosave: held off until the game's first interrupt (never during the ROM self-test), then requested one second after the last write or
  within 30 s of the first if writes continue (the stack keeps this RAM busy, so in practice the 30 s limit applies). Only a complete,
  ordered 2048-byte transfer clears pending changes; an interrupted one leaves them pending. User reset clears nothing.

## Verification (Verilator, unmodified ROMs, compared with MAME started with the same image)
- Unit test `sim/tb_nvram.sv` (`tools/wsl_nvram_test.sh`): cold default, save, restore, interrupted transfers, bounds (a mutant without the bound
  check fails), wrong index, CPU writes during a transfer, autosave timing and the arm hold. 
- Whole core (`tools/wsl_nv_tests.sh`), Sauro, to the 20th interrupt: cold start: 3 hi-score writes, as MAME; restore of MAME's saved image:
  0 hi-score writes, as MAME; restore of the edited image: 3 hi-score writes, as MAME. Work RAM after boot equals MAME's in every case except
  3-4 bytes at the top of the stack (E7F6-E7FE), which depend on the instruction phase of the interrupt. An upload at the 30th interrupt
  equals MAME's RAM at the matching frame except the same 3 stack bytes, and the CPU made 0 bus writes during the transfer.

## Not verified
- On real MiSTer: that the OSD "Save settings" / autosave / restore cycle works with these MRAs (older MRAs lack the tag), and that the
  30 s autosave pause is not noticeable in play. Tricky Doc and Sea Wolf share the RAM map but were not run through the restore tests.
