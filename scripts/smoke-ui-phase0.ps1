Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$phase0Files = @(
  'entry/src/main/ets/ui/pages/MainTabsPage.ets',
  'entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets',
  'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgChatRow.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgChatMeta.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgTopBar.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets'
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
$chatMetaFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgChatMeta.ets'
$chatListPageFile = Join-Path $root 'entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets'
$chatListNavFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets'
$mainTabsFile = Join-Path $root 'entry/src/main/ets/ui/pages/MainTabsPage.ets'
$chatScreenFile = Join-Path $root 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets'

if (-not (Select-String -Path $chatRowFile -Pattern '@ComponentV2')) {
  Write-Error 'TgChatRow must be marked with @ComponentV2.'
  exit 1
}

if (Select-String -Path $chatMetaFile -Pattern '(^|[^A-Za-z0-9_])Badge\(') {
  Write-Error 'TgChatMeta must use the project-owned chat-list unread capsule, not the stock ArkUI Badge halo.'
  exit 1
}

if (Select-String -Path $chatMetaFile -Pattern 'UNREAD_BADGE_MAX_VISIBLE_COUNT|99\+') {
  Write-Error 'TgChatMeta unread counts must use compact K/M formatting instead of 99+ clamping.'
  exit 1
}

if (-not (Select-String -Path $chatListPageFile -Pattern '\.reuseId\(')) {
  Write-Error 'ChatListPage must apply reuseId() for TgChatRow in LazyForEach.'
  exit 1
}

if (-not (Select-String -Path $mainTabsFile -Pattern 'HdsTabs\(')) {
  Write-Error 'MainTabsPage must compose HdsTabs for the API23 shell.'
  exit 1
}

if (-not (Select-String -Path $mainTabsFile -Pattern 'barBackgroundBlurStyle\(')) {
  Write-Error 'MainTabsPage must keep the flat full-width tab bar blurred (iOS pattern).'
  exit 1
}

if (-not (Select-String -Path $mainTabsFile -Pattern 'chatScreenVisible')) {
  Write-Error 'MainTabsPage must react to chatScreenVisible so the root tab bar can be hidden on chat detail screens.'
  exit 1
}

if (-not (Select-String -Path $mainTabsFile -Pattern 'barHeight\(')) {
  Write-Error 'MainTabsPage must collapse the HDS root tab bar height while a chat detail screen is visible.'
  exit 1
}

if (-not (Select-String -Path $mainTabsFile -Pattern '@kit\.UIDesignKit')) {
  Write-Error 'MainTabsPage must source HDS shell components from @kit.UIDesignKit.'
  exit 1
}

if (-not (Select-String -Path $chatListPageFile -Pattern 'TgChatListNavigationBar\(')) {
  Write-Error 'ChatListPage must compose TgChatListNavigationBar.'
  exit 1
}

if (-not (Select-String -Path $chatListNavFile -Pattern 'Search\(')) {
  Write-Error 'TgChatListNavigationBar must compose a Search component.'
  exit 1
}

if (-not (Select-String -Path $chatScreenFile -Pattern 'TgChatTopBar\(')) {
  Write-Error 'TgChatScreenPage must compose TgChatTopBar.'
  exit 1
}

if (-not (Select-String -Path $chatScreenFile -Pattern 'TgComposerInput\(')) {
  Write-Error 'TgChatScreenPage must compose TgComposerInput.'
  exit 1
}

if (-not (Select-String -Path $chatScreenFile -Pattern 'TgMessageRouter\(')) {
  Write-Error 'TgChatScreenPage must compose TgMessageRouter.'
  exit 1
}

Write-Host 'tg_ui shell smoke checks passed.'
