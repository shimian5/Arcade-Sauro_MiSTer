# Run from an unsandboxed PowerShell session; always use the full project flow.
param(
	[string]$QuartusSh = 'C:\MiSTerDev\intelFPGA_lite\17.0\quartus\bin64\quartus_sh.exe'
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $QuartusSh)) {
	throw "Quartus executable not found: $QuartusSh"
}
$buildRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $buildRoot
try {
	& $QuartusSh --flow compile Arcade-Tecfri 2>&1 | Tee-Object -FilePath build.log
	if ($LASTEXITCODE -ne 0) {
		throw "Quartus full flow failed with exit code $LASTEXITCODE. See build.log."
	}
	Write-Output (Join-Path $buildRoot 'output_files\Arcade-Tecfri.rbf')
} finally {
	Pop-Location
}
