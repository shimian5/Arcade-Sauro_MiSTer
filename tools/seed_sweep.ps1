# Try several Quartus fitter seeds in parallel in scratch copies of the project (the real project is not touched), then
# print the worst setup/hold slack of each. Used when the framework's HDMI scaler paths (ascal) land at a negative slack.
# Usage: tools\seed_sweep.ps1 -Seeds 2,3,4     Run from an unsandboxed PowerShell session.
param([int[]]$Seeds = @(2, 3, 4), [string]$QuartusBin = 'C:\MiSTerDev\intelFPGA_lite\17.0\quartus\bin64')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$procs = @()
foreach ($seed in $Seeds) {
	$dir = Join-Path $env:TEMP "sauro_seed_$seed"
	if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
	robocopy $root $dir /E /XD .git db incremental_db output_files simulation releases docs greybox_tmp hc_output | Out-Null
	Add-Content -Path (Join-Path $dir 'Arcade-Sauro.qsf') -Value "`r`nset_global_assignment -name SEED $seed"
	$procs += Start-Process -FilePath (Join-Path $QuartusBin 'quartus_sh.exe') -ArgumentList '--flow', 'compile', 'Arcade-Sauro' `
		-WorkingDirectory $dir -RedirectStandardOutput (Join-Path $dir 'build.out') -RedirectStandardError (Join-Path $dir 'build.err') -PassThru -WindowStyle Hidden
}
$procs | Wait-Process
foreach ($seed in $Seeds) {
	$sum = Join-Path $env:TEMP "sauro_seed_$seed\output_files\Arcade-Sauro.sta.summary"
	if (-not (Test-Path $sum)) { "seed ${seed}: no timing summary (build failed)"; continue }
	$text = (Get-Content $sum -Raw) -replace "`r", ''
	$rows = [regex]::Matches($text, "Type  : (Setup|Hold) '([^']+)'\s+Slack : (-?[\d.]+)") | ForEach-Object { [pscustomobject]@{ Kind = $_.Groups[1].Value; Clock = $_.Groups[2].Value; Slack = [double]$_.Groups[3].Value } }
	$ws = ($rows | Where-Object Kind -eq 'Setup' | Sort-Object Slack | Select-Object -First 1)
	$wh = ($rows | Where-Object Kind -eq 'Hold' | Sort-Object Slack | Select-Object -First 1)
	$sys = ($rows | Where-Object { $_.Kind -eq 'Setup' -and $_.Clock -like 'emu|pll*' } | Select-Object -First 1)
	"seed ${seed}: worst setup {0:N3} ns ({1}); worst hold {2:N3} ns; 80 MHz clock setup {3:N3} ns" -f $ws.Slack, ($ws.Clock -replace '\|.*', ''), $wh.Slack, $sys.Slack
}
