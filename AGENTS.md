# Tecfri (Sauro, Sea Wolf, Tricky Doc) development instructions

Milestones are distinct and reported separately: **playable**, **diagnostically
correct**, **timing-clean**, **hardware-accepted**.

Paths: ROMs `\\fairlanenas\data\Games\ROMS\MAME\MAME 0.257 ROMs (split)`;
MAME `C:\MiSTerDev\mame\mame.exe`; reference core `C:\MiSTerDev\Arcade-Victory_MiSTer`.
Quartus 17.0.2 (`C:\MiSTerDev\intelFPGA_lite\17.0`). No schematics exist; MAME
(`docs/reference/mame`, mame0257) is the model, so mark MAME-only facts provisional.

1. Keep `sys/` unchanged upstream. Use standard `emu` and `hps_io` interfaces.
   Game clocks, video conversion, controls and persistence live outside `sys/`.
2. Build from documented hardware evidence (schematics, manuals, datasheets,
   verified dumps). Pin reference revisions, record provenance. Use MAME as a
   comparison and document uncertainty.
3. Model timing as well as results: bus decoding and mirrors, memory ownership,
   WAIT, interrupt capture/acknowledge, register side effects, clock phases.
4. Never bypass failures. Validate startup with unmodified ROMs and observe
   diagnostics explicitly; no service shortcuts or patched ROMs.
5. Separate machine timing from display adaptation. Output geometry must not
   change CPU, graphics or audio speed. Document buffering and latency.
6. Pixel cadence is a requirement: uniform repetition for Direct Video/DV1,
   RGB/sync/DE alignment, complete active pixels, supported scandoubler/effects.
7. Clock crossings use synchronizers, handshakes or async FIFOs. Keep timing
   exceptions narrow and justified; no broad false paths.
8. Pause, reset and CRT controls work throughout development. Pause preserves
   coherent state while video continues; verify resume, OSD pause, dimming, reset.
9. Implement persistence completely (upload/download, cold start, ordering,
   save/reload, interrupted transfers, bounds, reset) before advertising it in
   the MRA.
10. Every build milestone uses the full flow from an unsandboxed PowerShell:
    `quartus_sh --flow compile <project>`. Keep the PLL instance named `pll`.
11. After builds inspect setup/hold, clocks, unconstrained paths, RAM, DSP,
    logic and PLL usage. Fix accidental resource expansion at its source.
12. Validate at several levels with Verilator in WSL2 `archlinux`:
    `wsl -d archlinux -- make -C /mnt/c/MiSTerDev/Arcade-Tecfri_MiSTer/sim test`.
    Derive expectations independently of the RTL where practical. Simulation,
    synthesis and hardware acceptance are separate evidence.
13. Package ROMs accurately: chip CRCs, assembled MD5, offsets, setname, core
    id, dot-free MAME version, button names matching joystick bits 4+. No ROM
    payloads in the repo. Follow the MiSTer MRA reference.
14. Preserve upstream code and attribution (pinned submodules/vendored copies,
    licenses, notices). Follow MiSTer developer principles: tabs, aligned
    declarations, descriptive names, `_n` for active-low, comments on interfaces
    and non-obvious timing.
15. Tie every readiness claim to the exact artifact tested: RBF hash, source
    revision, tool version, reports, test results. State which checks were rerun
    after a change. Keep limitations explicit.
