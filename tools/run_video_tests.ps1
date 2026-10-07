# Compare the RTL video block with every MAME frame dump in simulation/frames.
# Prerequisites: sim/mame/dump_frame.lua dumps, `make -C sim video-build` (WSL archlinux).
param(
	[string]$RomPath = '\\fairlanenas\data\Games\ROMS\MAME\MAME 0.257 ROMs (split)',
	[string[]]$Sets = @('sauro', 'seawolft', 'trckydoc'),
	[string]$Prefix = ''   # e.g. 'play_' for the scripted-input dumps
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$wslRoot = '/mnt/' + $root.Substring(0, 1).ToLower() + ($root.Substring(2) -replace '\\', '/')
$fail = 0
foreach ($set in $Sets) {
	foreach ($dump in Get-ChildItem (Join-Path $root "simulation\frames\${Prefix}${set}_*.bin") | Sort-Object Name) {
		$name = $dump.BaseName
		$vec = Join-Path $root "simulation\vec\$name"
		python -I (Join-Path $root 'tools\prep_video_vectors.py') $RomPath $set $dump.FullName $vec | Out-Null
		$args = (Get-Content (Join-Path $vec 'plusargs.txt')) -split ' '
		wsl -d archlinux -- "$wslRoot/simulation/video/Vtb_video" "+DIR=$wslRoot/simulation/vec/$name" "+OUT=$wslRoot/simulation/vec/$name/rtl.hex" @args | Out-Null
		$result = python -I (Join-Path $root 'tools\compare_frame.py') (Join-Path $vec 'expected.hex') (Join-Path $vec 'rtl.hex') (Join-Path $vec 'cmp') | Select-Object -First 1
		"{0,-18} {1}" -f $name, $result
		if ($result -notlike 'PASS*') { $fail++ }
	}
}
if ($fail) { throw "$fail frame(s) differ" }
