Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$phase0Files = @(
  'entry/src/main/ets/ui/pages/MainTabsPage.ets',
  'entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets',
  'entry/src/main/ets/ui/pages/chatlist/ChatListItem.ets',
  'entry/src/main/ets/ui/pages/chatlist/ChatItemVO.ets',
  'entry/src/main/ets/ui/components/common/AppTopBar.ets',
  'entry/src/main/ets/ui/components/common/AppTabBarItem.ets',
  'entry/src/main/ets/ui/components/common/AppListRow.ets'
) | ForEach-Object { Join-Path $root $_ }

$hexPattern = '#[0-9A-Fa-f]{3,8}'
$hexViolations = @()

foreach ($file in $phase0Files) {
  if (-not (Test-Path $file)) {
    throw "Required file not found: $file"
  }

  $matches = Select-String -Path $file -Pattern $hexPattern
  foreach ($match in $matches) {
    $hexViolations += "{0}:{1} -> {2}" -f $file, $match.LineNumber, $match.Line.Trim()
  }
}

if ($hexViolations.Count -gt 0) {
  $details = $hexViolations -join "`n"
  Write-Error ("Hardcoded color hex detected in Phase 0 shell/chatlist files:`n{0}" -f $details)
  exit 1
}

$chatListItemFile = Join-Path $root 'entry/src/main/ets/ui/pages/chatlist/ChatListItem.ets'
$chatListPageFile = Join-Path $root 'entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets'

if (-not (Select-String -Path $chatListItemFile -Pattern '@Reusable')) {
  Write-Error 'ChatListItem must be marked with @Reusable.'
  exit 1
}

if (-not (Select-String -Path $chatListPageFile -Pattern '\.reuseId\(')) {
  Write-Error 'ChatListPage must apply reuseId() for ChatListItem in LazyForEach.'
  exit 1
}

Write-Host 'Phase 0 UI smoke checks passed.'
