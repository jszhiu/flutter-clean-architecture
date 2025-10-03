param(
  [Parameter(ValueFromRemainingArguments=$true)]
  [string[]]$args
)

$ErrorActionPreference = 'Stop'

# Wrapper to run the generator from anywhere, against the current directory.
# Usage: flutter-clean.ps1 [--state bloc|riverpod|provider|getx] [--name "App Name"]

$repoRoot = (Split-Path $PSScriptRoot -Parent)
$setup = Join-Path $repoRoot 'scripts\setup-windows.ps1'

if (!(Test-Path $setup)) { throw "Cannot find setup script at $setup" }

if (-not $args -or $args.Count -eq 0) {
  $args = @('--auto','--profile','minimal')
}

& powershell -ExecutionPolicy Bypass -File $setup @args
