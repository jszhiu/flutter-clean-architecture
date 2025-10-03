$ErrorActionPreference = 'Stop'

function Write-Step($msg) { Write-Host "[INSTALL] $msg" -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

$repo = Split-Path -Parent $PSScriptRoot
$bin = Join-Path $repo 'bin'

if (!(Test-Path $bin)) { throw "bin folder not found at $bin" }

Write-Step "Adding $bin to user PATH"
$current = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($current -notlike "*${bin}*") {
  $new = if ($current) { "$current;$bin" } else { $bin }
  [Environment]::SetEnvironmentVariable('Path', $new, 'User')
  Write-Ok "User PATH updated. Restart terminal to take effect."
} else {
  Write-Ok "Path already contains $bin"
}

Write-Step 'Verifying flutter-clean'
& where.exe flutter-clean.ps1 2>$null | Out-Null
Write-Ok 'Install complete. Use: flutter-clean.ps1 --state bloc|riverpod|provider|getx --name "My App"'

