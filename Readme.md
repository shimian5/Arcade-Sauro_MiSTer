# Tecfri arcade core for MiSTer (Sauro, Sea Wolf, Tricky Doc)

Work in progress; **nothing here is playable or hardware-accepted yet.**

See [AGENTS.md](AGENTS.md) for project rules and [docs/SPEC_AND_PLAN.md](docs/SPEC_AND_PLAN.md)
for the MAME-derived hardware spec and plan. Hardware evidence is limited to MAME 0.257
(no schematics found), so all behavior is provisional.

Imported components (pinned, licenses retained):
- `rtl/tv80` (submodule, hutch31/tv80 @ 66a131c): Z80 core, used via `rtl/cpu_z80.v`
  (adapted from the Victory core; build with `TV80_REFRESH` for external refresh).
- `rtl/sound/imports/jtopl` (jotego/jtopl @ 7ac0c81, GPL-3.0): YM3812.
- `rtl/sound/imports/Speech256` (trcwm/Speech256 @ 4c311cf, LGPL-3.0): SP0256.
- `rtl/pause.sv`: JimmyStones Pause_MiSTer (GPL-3.0), as used in Victory.

Tests: `wsl -d archlinux -- make -C /mnt/c/MiSTerDev/Arcade-Tecfri_MiSTer/sim test`
Build: `tools/build.ps1` (full Quartus flow, unsandboxed PowerShell).
