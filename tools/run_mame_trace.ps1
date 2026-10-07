# Run a Tecfri set in MAME headless with sim/mame/trace_io.lua and write the log
# to simulation/trace_<set>.txt. ROMs come from the NAS 0.257 split set.
param(
	[Parameter(Mandatory)][ValidateSet('sauro','trckydoc','seawolft')][string]$Set,
	[int]$Seconds = 8,
	[string]$RomPath = '\fairlanenas\data\Games\ROMS\MAME\MAME 0.257 ROMs (split)'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$nv = Join-Path $root 'simulation\nv'
New-Item -ItemType Directory -Force $nv | Out-Null
$env:TRACE_OUT = Join-Path $root "simulation\trace_$Set.txt"
Push-Location C:\MiSTerDev\mame
try {
	& .\mame.exe $Set -rompath $RomPath -nvram_directory $nv -autoboot_script (Join-Path $root 'sim\mame\trace_io.lua') -video none -sound none -nothrottle -seconds_to_run $Seconds
} finally { Pop-Location }
