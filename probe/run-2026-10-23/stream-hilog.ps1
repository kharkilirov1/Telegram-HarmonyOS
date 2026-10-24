param(
  [string]$OutFile = 'C:\Users\Kharki\Desktop\Telegram-HarmonyOS\probe\run-2026-10-23\hilog-stream.txt'
)

$ErrorActionPreference = 'Continue'
$hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'

while ($true) {
  $t = (& $hdc list targets 2>&1) -join ' '
  $hasTarget = (($t -replace '\[Empty\]', '').Trim().Length -gt 0)
  if (-not $hasTarget) {
    Start-Sleep -Seconds 3
    continue
  }
  try {
    & $hdc shell hilog 2>$null | Tee-Object -FilePath $OutFile -Append
  } catch {
  }
  Start-Sleep -Seconds 3
}
