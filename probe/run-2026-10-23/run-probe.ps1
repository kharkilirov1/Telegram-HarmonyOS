param(
  [string]$Bundle = 'com.telegram.harmonyos.nativevalidation20261023',
  [string]$Hap = 'C:\Users\Kharki\Desktop\Telegram-HarmonyOS\entry\build\default\outputs\default\entry-default-unsigned.hap',
  [string]$OutDir = 'C:\Users\Kharki\Desktop\Telegram-HarmonyOS\probe\run-2026-10-23'
)

$ErrorActionPreference = 'Continue'
$hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$log = Join-Path $OutDir 'runner.log'
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
function Say([string]$m) {
  $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m
  Add-Content -Path $log -Value $line
  Write-Host $line
}
function Run-Hdc([string[]]$cmd) { & $hdc @cmd 2>&1 }

Say 'runner start'

$target = $null
for ($i = 0; $i -lt 150; $i++) {
  $t = (Run-Hdc @('list','targets')) -join ' '
  if (($t -replace '\[Empty\]','').Trim().Length -gt 0) { $target = $t.Trim(); break }
  if ($i % 10 -eq 0) { Say "waiting for target ($($i*4)s)" }
  Start-Sleep -Seconds 4
}
if (-not $target) { Say 'FAIL: no target'; exit 2 }
Say "target: $target"

$booted = $false
for ($j = 0; $j -lt 60; $j++) {
  $b = (Run-Hdc @('shell','param get bootevent.boot.completed')) -join ' '
  if ($b -match 'true') { $booted = $true; Say "boot complete after $($j*4)s"; break }
  Start-Sleep -Seconds 4
}
if (-not $booted) { Say 'FAIL: boot did not complete'; exit 3 }

Say 'wakeup'
[void](Run-Hdc @('shell','power-shell wakeup'))
Start-Sleep -Seconds 1
Say 'swipe unlock'
[void](Run-Hdc @('shell','uitest uiInput swipe 654 2300 654 700 300'))
Start-Sleep -Seconds 1
[void](Run-Hdc @('shell','uinput -T -m 654 2300 654 700 300'))
Start-Sleep -Seconds 1
$focus = (Run-Hdc @('shell','dumpsys window windows | grep -E "mCurrentFocus"')) -join ' | '
Say "focus: $focus"

$pkgs = (Run-Hdc @('shell','bm dump -a')) -join ' '
if ($pkgs -notmatch [regex]::Escape($Bundle)) {
  Say 'installing HAP'
  $inst = (Run-Hdc @('install','-r',$Hap)) -join ' '
  Say "install: $inst"
} else {
  Say 'probe package already installed'
}

[void](Run-Hdc @('shell','hilog -r'))
Say 'starting ability'
$startOut = (Run-Hdc @('shell',"aa start -a EntryAbility -b $Bundle")) -join ' '
Say "start: $startOut"
if ($startOut -match 'error') {
  Say 'retry unlock+start'
  [void](Run-Hdc @('shell','power-shell wakeup'))
  [void](Run-Hdc @('shell','uitest uiInput swipe 654 2300 654 700 300'))
  Start-Sleep -Seconds 1
  $startOut = (Run-Hdc @('shell',"aa start -a EntryAbility -b $Bundle")) -join ' '
  Say "start2: $startOut"
}

Start-Sleep -Seconds 6
$psOut = (Run-Hdc @('shell',"ps -ef | grep $Bundle")) -join ' | '
Say "ps: $psOut"

Start-Sleep -Seconds 120
$dump = Run-Hdc @('shell','hilog -x')
$dump | Set-Content -Path (Join-Path $OutDir 'hilog-raw.txt') -Encoding utf8
$probe = $dump | Select-String -Pattern 'Probe' | ForEach-Object { $_.Line }
$probe | Set-Content -Path (Join-Path $OutDir 'probe-lines.txt') -Encoding utf8
Say ("probe lines: " + ($probe | Measure-Object).Count)
Say 'runner done'
