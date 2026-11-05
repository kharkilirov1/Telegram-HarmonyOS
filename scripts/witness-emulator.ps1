<#
.SYNOPSIS
  Boot an API 26 emulator, launch the app and capture one witness frame plus a fault check.

.DESCRIPTION
  Automates the loop used for device witnesses: start the headless emulator, wait for hdc, optionally
  reinstall the entry HAP, force-stop and launch, verify the process is fresh (STIME after force-stop),
  take a screenshot through `uitest screenCap` and count fault logs.

  `snapshot_display` is intentionally not used: on the headless emulator it returns frames with an
  unpainted grey region (see LESSONS 273), while `uitest screenCap` renders the real UI.

.PARAMETER HvdName
  Emulator instance name, for example "Mate 90 Pro".

.PARAMETER HapPath
  Optional entry HAP to install before launching.

.PARAMETER OutputDirectory
  Directory for the screenshot and layout dump; defaults to .witness in the repo root.

.PARAMETER SkipStart
  Do not start the emulator (assume a target is already connected).
#>
param(
  [string]$HvdName = 'Mate 90 Pro',
  [string]$HapPath = '',
  [string]$OutputDirectory = '',
  [switch]$SkipStart
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$emulator = 'C:\Program Files\Huawei\DevEco Studio\tools\emulator\Emulator.exe'
$serial = '127.0.0.1:5555'
$bundle = 'com.telegram.harmonyos'
if ($OutputDirectory.Length -eq 0) { $OutputDirectory = Join-Path $repo '.witness' }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

function Invoke-Hdc {
  param([string[]]$Arguments)
  & $hdc -t $serial @Arguments 2>&1
}

if (-not $SkipStart) {
  $targets = & $hdc list targets 2>&1 | Out-String
  if ($targets -notmatch [regex]::Escape($serial)) {
    Write-Host "Starting emulator '$HvdName'..."
    Start-Process -FilePath $emulator -ArgumentList @('-start', $HvdName, '-noWindow') | Out-Null
  }
}

$deadline = (Get-Date).AddSeconds(240)
while ((Get-Date) -lt $deadline) {
  $targets = & $hdc list targets 2>&1 | Out-String
  if ($targets -match [regex]::Escape($serial)) { break }
  Start-Sleep -Seconds 5
}
& $hdc tconn $serial 2>&1 | Out-Null
$apiVersion = (Invoke-Hdc -Arguments @('shell', 'param get const.ohos.apiversion') | Out-String).Trim()
Write-Host "API version: $apiVersion"

if ($HapPath.Length -gt 0) {
  Write-Host "Installing $HapPath ..."
  & $hdc -t $serial install -r $HapPath 2>&1 | Select-Object -Last 3
}

Invoke-Hdc -Arguments @('shell', "aa force-stop $bundle") | Out-Null
$start = Invoke-Hdc -Arguments @('shell', "aa start -a EntryAbility -b $bundle")
$start | Select-Object -First 3 | ForEach-Object { Write-Host $_ }
Start-Sleep -Seconds 8

$processLine = (Invoke-Hdc -Arguments @('shell', "ps -ef | grep $bundle | grep -v grep | head -3") | Out-String).Trim()
$deviceDate = (Invoke-Hdc -Arguments @('shell', 'date') | Out-String).Trim()
Write-Host "Process: $processLine"
Write-Host "Device date: $deviceDate"

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$remoteShot = "/data/local/tmp/witness-$stamp.jpeg"
$remoteLayout = "/data/local/tmp/witness-$stamp.json"
Invoke-Hdc -Arguments @('shell', "uitest screenCap -p $remoteShot") | Out-Null
Invoke-Hdc -Arguments @('shell', "uitest dumpLayout -p $remoteLayout") | Out-Null
$localShot = Join-Path $OutputDirectory "witness-$stamp.jpeg"
$localLayout = Join-Path $OutputDirectory "witness-$stamp.json"
& $hdc -t $serial file recv $remoteShot $localShot 2>&1 | Select-Object -Last 1
& $hdc -t $serial file recv $remoteLayout $localLayout 2>&1 | Select-Object -Last 1

$faults = (Invoke-Hdc -Arguments @('shell', 'ls /data/log/faultlog/faultlogger 2>/dev/null | wc -l') | Out-String).Trim()
Write-Host "Fault logs: $faults"
Write-Host "Screenshot: $localShot"
Write-Host "Layout: $localLayout"
