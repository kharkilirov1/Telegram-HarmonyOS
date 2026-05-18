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

function Invoke-HvigorStep {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Command,
    [Parameter(Mandatory = $true)]
    [string]$StepName,
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  Write-Host "Running hvigor step: $StepName"
  & $Command @Arguments
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    throw "hvigor step '$StepName' failed with exit code $exitCode."
  }
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

Invoke-HvigorStep -Command $hvigorCmd -StepName 'clean' -Arguments @('clean', '--no-daemon')
Invoke-HvigorStep -Command $hvigorCmd -StepName 'assembleHap' -Arguments @(
  'assembleHap',
  '--mode',
  'module',
  '-p',
  'product=default',
  '-p',
  'buildMode=debug',
  '--no-daemon'
)

Write-Host 'Smoke build completed successfully.'
