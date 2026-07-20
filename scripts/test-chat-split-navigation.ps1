Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$mainTabs = Join-Path $root 'entry/src/main/ets/ui/pages/MainTabsPage.ets'
$chatList = Join-Path $root 'entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets'
$geometry = Join-Path $root 'entry/src/main/ets/ui/utils/ChatSplitGeometry.ets'
$placeholder = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgChatSplitPlaceholder.ets'
$tokens = Join-Path $root 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets'
$module = Join-Path $root 'entry/src/main/module.json5'
$passport = Join-Path $root 'entry/src/main/ets/ui/tg_ui/spec/TgChatSplitShell.md'

foreach ($path in @($mainTabs, $chatList, $geometry, $placeholder, $tokens, $module, $passport)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Chat split-view contract file is missing: $path"
  }
}

$contracts = @(
  @{ Path = $geometry; Pattern = 'export function resolveChatSplitGeometry'; Label = 'pure responsive-width resolver' },
  @{ Path = $geometry; Pattern = 'export function resolveChatHostTopInset'; Label = 'pure host-origin top-inset resolver' },
  @{ Path = $tokens; Pattern = 'CHAT_SPLIT_NAV_MIN_WIDTH: number = 320;'; Label = 'Telegram iOS 320pt master minimum' },
  @{ Path = $tokens; Pattern = 'CHAT_SPLIT_MIN_CONTENT_WIDTH: number = 360;'; Label = 'viable native detail minimum' },
  @{ Path = $mainTabs; Pattern = 'Navigation(this.chatDetailNavStack) {'; Label = 'root adaptive master-detail host' },
  @{ Path = $mainTabs; Pattern = 'HdsTabs({ index: this.selectedIndex, controller: this.controller }) {'; Label = 'native HDS tabs inside the master column' },
  @{ Path = $mainTabs; Pattern = 'Navigation(this.chatListNavStack) {'; Label = 'independent master-side chat-list stack' },
  @{ Path = $mainTabs; Pattern = 'chatDetailStack: this.chatDetailNavStack'; Label = 'explicit chat-detail routing seam' },
  @{ Path = $mainTabs; Pattern = '.mode(NavigationMode.Auto)'; Label = 'native adaptive root mode' },
  @{ Path = $mainTabs; Pattern = '.navBarWidthRange(['; Label = 'bounded native master width' },
  @{ Path = $mainTabs; Pattern = '.minContentWidth(TgUiTokens.CHAT_SPLIT_MIN_CONTENT_WIDTH)'; Label = 'detail-width protection' },
  @{ Path = $mainTabs; Pattern = '.onNavigationModeChange((mode: NavigationMode)'; Label = 'split-mode observation' },
  @{ Path = $placeholder; Pattern = 'TgChatBackground()'; Label = 'iOS wallpaper placeholder' },
  @{ Path = $placeholder; Pattern = "`$r('app.string.chat_split_start_messaging')"; Label = 'localized start-messaging capsule' },
  @{ Path = $chatList; Pattern = '@Param chatDetailStack: NavPathStack'; Label = 'typed outer detail stack input' },
  @{ Path = $chatList; Pattern = 'const navStack = this.chatDetailStack;'; Label = 'chat opens in outer detail stack' },
  @{ Path = $chatList; Pattern = 'let lastPortraitChatTopInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;'; Label = 'durable portrait safe-area cache' },
  @{ Path = $chatList; Pattern = 'this.chatTopInset = resolveChatHostTopInset('; Label = 'orientation-aware safe-area resolver' },
  @{ Path = $chatList; Pattern = 'this.computeSafeInsets(size);'; Label = 'window-size callback supplies fresh rotation geometry' },
  @{ Path = $chatList; Pattern = 'this.restoreChatListStartAfterInsetChange(previousTopInset, nextTopInset);'; Label = 'top-position compensation after inset changes' },
  @{ Path = $chatList; Pattern = 'this.chatListScroller.scrollToIndex(0, false, ScrollAlign.START);'; Label = 'first-row re-alignment when list is at start' },
  @{ Path = $chatList; Pattern = 'private chatListTopInset(): number {'; Label = 'explicit inner top-inset contract' },
  @{ Path = $chatList; Pattern = 'return TgUiTokens.CHAT_LIST_NAV_TOTAL_HEIGHT + this.chatListTopInset();'; Label = 'custom chrome height follows measured host origin' },
  @{ Path = $passport; Pattern = 'NavigationControllerMode.automaticMasterDetail'; Label = 'current iOS source provenance' },
  @{ Path = $passport; Pattern = 'NavigationMode.Auto'; Label = 'HarmonyOS native mapping' },
  @{ Path = $module; Pattern = '"orientation": "auto_rotation"'; Label = 'rotation-enabled responsive witness' }
)

foreach ($contract in $contracts) {
  if (-not (Select-String -LiteralPath $contract.Path -SimpleMatch $contract.Pattern -Quiet)) {
    throw "Missing $($contract.Label): $($contract.Pattern)"
  }
}

$mainTabsSource = Get-Content -LiteralPath $mainTabs -Raw
$rootNavigationIndex = $mainTabsSource.IndexOf('Navigation(this.chatDetailNavStack) {')
$nativeTabsIndex = $mainTabsSource.IndexOf('HdsTabs({ index: this.selectedIndex, controller: this.controller }) {')
if ($rootNavigationIndex -lt 0 -or $nativeTabsIndex -lt 0 -or $rootNavigationIndex -gt $nativeTabsIndex) {
  throw 'HdsTabs must be nested inside the adaptive root Navigation so the island remains in the master column.'
}

if ($mainTabsSource.Contains('Navigation(this.chatNavStack) {')) {
  throw 'Legacy chat-only root Navigation stack must not remain after master-detail extraction.'
}

$chatListSource = Get-Content -LiteralPath $chatList -Raw
if ($chatListSource.Contains('.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])')) {
  throw 'ChatListPage must not bypass the outer native Navigation top safe area.'
}

if ($chatListSource.Contains('@Param hostTopInset: number')) {
  throw 'ChatListPage must derive top chrome from its live window/host geometry, not a parent snapshot.'
}

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
  throw 'node is required for ChatSplitGeometry host tests.'
}

$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$tempDir = Join-Path $tempRoot ("telegram-chat-split-geometry-{0}" -f [System.Guid]::NewGuid().ToString('N'))
$resolvedTempDir = [System.IO.Path]::GetFullPath($tempDir)
if (-not $resolvedTempDir.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
  $resolvedTempDir -eq $tempRoot) {
  throw "Unsafe temporary test directory: $resolvedTempDir"
}

New-Item -ItemType Directory -Path $resolvedTempDir | Out-Null
try {
  Copy-Item -LiteralPath $geometry -Destination (Join-Path $resolvedTempDir 'ChatSplitGeometry.ts')
  @'
import assert from 'node:assert/strict';
import { resolveChatHostTopInset, resolveChatSplitGeometry } from './ChatSplitGeometry.ts';

assert.deepEqual(resolveChatSplitGeometry(600, 320), { navBarWidth: 320, maxNavBarWidth: 320 });
assert.deepEqual(resolveChatSplitGeometry(800, 320), { navBarWidth: 320, maxNavBarWidth: 400 });
assert.deepEqual(resolveChatSplitGeometry(1200, 320), { navBarWidth: 400, maxNavBarWidth: 600 });
assert.deepEqual(resolveChatSplitGeometry(2000, 320), { navBarWidth: 666, maxNavBarWidth: 1000 });
assert.deepEqual(resolveChatSplitGeometry(Number.NaN, 320), { navBarWidth: 320, maxNavBarWidth: 320 });
assert.equal(resolveChatHostTopInset(39, 1308, 2880, 39), 39);
assert.equal(resolveChatHostTopInset(0, 2880, 1308, 39), 0);
assert.equal(resolveChatHostTopInset(0, 1308, 2880, 39), 39);
assert.equal(resolveChatHostTopInset(24, 2880, 1308, 39), 24);
assert.equal(resolveChatHostTopInset(Number.NaN, 1308, 2880, 39), 39);
'@ | Set-Content -LiteralPath (Join-Path $resolvedTempDir 'ChatSplitGeometry.test.mjs') -Encoding utf8

  & $node.Source --experimental-strip-types (Join-Path $resolvedTempDir 'ChatSplitGeometry.test.mjs')
  if ($LASTEXITCODE -ne 0) {
    throw "ChatSplitGeometry host tests failed with exit code $LASTEXITCODE."
  }
} finally {
  if (Test-Path -LiteralPath $resolvedTempDir) {
    $cleanupPath = [System.IO.Path]::GetFullPath($resolvedTempDir)
    if ($cleanupPath.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
      $cleanupPath -ne $tempRoot) {
      Remove-Item -LiteralPath $cleanupPath -Recurse -Force
    }
  }
}

Write-Output 'Adaptive chat master-detail source and geometry contract: PASS'
