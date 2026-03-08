Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$phase0Files = @(
  'entry/src/main/ets/ui/pages/MainTabsPage.ets',
  'entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets',
  'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgChatRow.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgTopBar.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgTabBar.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgSearchBar.ets'
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

$chatRowFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgChatRow.ets'
$chatListPageFile = Join-Path $root 'entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets'
$mainTabsFile = Join-Path $root 'entry/src/main/ets/ui/pages/MainTabsPage.ets'
$chatScreenFile = Join-Path $root 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets'

if (-not (Select-String -Path $chatRowFile -Pattern '@Reusable')) {
  Write-Error 'TgChatRow must be marked with @Reusable.'
  exit 1
}

if (-not (Select-String -Path $chatListPageFile -Pattern '\.reuseId\(')) {
  Write-Error 'ChatListPage must apply reuseId() for TgChatRow in LazyForEach.'
  exit 1
}

if (-not (Select-String -Path $mainTabsFile -Pattern 'TgTabBar\(')) {
  Write-Error 'MainTabsPage must compose TgTabBar.'
  exit 1
}

if (-not (Select-String -Path $chatListPageFile -Pattern 'TgTopBar\(')) {
  Write-Error 'ChatListPage must compose TgTopBar.'
  exit 1
}

if (-not (Select-String -Path $chatListPageFile -Pattern 'TgSearchBar\(')) {
  Write-Error 'ChatListPage must compose TgSearchBar.'
  exit 1
}

if (-not (Select-String -Path $chatScreenFile -Pattern 'TgChatTopBar\(')) {
  Write-Error 'TgChatScreenPage must compose TgChatTopBar.'
  exit 1
}

if (-not (Select-String -Path $chatScreenFile -Pattern 'TgMessageRouter\(')) {
  Write-Error 'TgChatScreenPage must compose TgMessageRouter.'
  exit 1
}

Write-Host 'tg_ui shell smoke checks passed.'
