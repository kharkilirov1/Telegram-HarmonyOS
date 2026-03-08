Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-HvigorCommand {
  $candidates = @(
    'hvigorw',
    'hvigorw.bat',
    'hvigor'
  )

  $defaultInstallCandidates = @(
    (Join-Path ${env:ProgramFiles} 'Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat'),
    (Join-Path ${env:ProgramFiles} 'Huawei\DevEco Studio\tools\hvigor\bin\hvigorw'),
    (Join-Path ${env:ProgramFiles} 'Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js')
  )

  foreach ($candidate in $candidates) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) {
      return $cmd.Source
    }
  }

  foreach ($candidate in $defaultInstallCandidates) {
    if ($candidate -and (Test-Path $candidate)) {
      return $candidate
    }
  }

  return $null
}

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$hvigorCmd = Resolve-HvigorCommand
if (-not $hvigorCmd) {
  throw @"
hvigor command was not found.
Install/configure DevEco command-line environment so that `hvigorw` (or `hvigor`) is available in PATH.
"@
}

Write-Host "Using hvigor command: $hvigorCmd"

& $hvigorCmd clean --no-daemon
& $hvigorCmd assembleHap --mode module -p product=default -p buildMode=debug --no-daemon

Write-Host 'Smoke build completed successfully.'
