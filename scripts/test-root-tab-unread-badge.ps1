Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$mainTabs = Join-Path $root 'entry/src/main/ets/ui/pages/MainTabsPage.ets'
$atom = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgRootTabUnreadBadge.ets'
$formatter = Join-Path $root 'entry/src/main/ets/ui/tg_ui/utils/TgCompactCount.ets'
$passport = Join-Path $root 'entry/src/main/ets/ui/tg_ui/spec/TgRootTabUnreadBadge.md'
$demo = Join-Path $root 'entry/src/main/ets/ui/tg_ui/demos/TgRootTabUnreadBadgeDemo.ets'
$appEvent = Join-Path $root 'entry/src/main/ets/core/model/AppEvent.ets'
$appState = Join-Path $root 'entry/src/main/ets/core/model/AppState.ets'
$normalizer = Join-Path $root 'entry/src/main/ets/core/events/normalizers/ChatNormalizer.ets'
$reducer = Join-Path $root 'entry/src/main/ets/core/reducers/chatsReducer.ets'
$selector = Join-Path $root 'entry/src/main/ets/domain/selectors/chatSelectors.ets'

foreach ($path in @($mainTabs, $atom, $formatter, $passport, $demo, $appEvent, $appState, $normalizer, $reducer, $selector)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Root-tab unread badge contract file is missing: $path"
  }
}

$contracts = @(
  @{ Path = $mainTabs; Pattern = 'HdsTabs({'; Label = 'native HdsTabs host' },
  @{ Path = $mainTabs; Pattern = 'bleedIconStyle(() => {'; Label = 'native HDS custom-item hook' },
  @{ Path = $mainTabs; Pattern = 'TgRootTabUnreadBadge({'; Label = 'dedicated badge atom integration' },
  @{ Path = $formatter; Pattern = 'export function formatTelegramCompactCount'; Label = 'shared compact count formatter' },
  @{ Path = $formatter; Pattern = 'UNREAD_BADGE_COMPACT_MILLION'; Label = 'compact million formatting' },
  @{ Path = $appEvent; Pattern = 'ChatListUnreadMessageCountChangedEvent'; Label = 'aggregate unread domain event' },
  @{ Path = $appState; Pattern = 'mainUnreadMessageCount'; Label = 'aggregate unread state' },
  @{ Path = $normalizer; Pattern = "handlers.set('updateUnreadMessageCount'"; Label = 'TDLib unread handler registration' },
  @{ Path = $reducer; Pattern = "case 'chatListUnreadMessageCountChanged'"; Label = 'aggregate unread reducer case' },
  @{ Path = $selector; Pattern = 'state.chats.mainUnreadMessageCount'; Label = 'aggregate-first selector' },
  @{ Path = $passport; Pattern = 'ChatListController.swift'; Label = 'iOS source provenance' },
  @{ Path = $passport; Pattern = 'updateUnreadMessageCount'; Label = 'TDLib source provenance' }
)

foreach ($contract in $contracts) {
  if (-not (Select-String -LiteralPath $contract.Path -SimpleMatch $contract.Pattern -Quiet)) {
    throw "Missing $($contract.Label): $($contract.Pattern)"
  }
}

if (Select-String -LiteralPath $mainTabs -SimpleMatch "return count > 999 ? '999+'" -Quiet) {
  throw 'Root Chats badge must use Telegram compact K/M formatting instead of 999+ clamping.'
}

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
  throw 'node is required for TgCompactCount host tests.'
}

$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$tempDir = Join-Path $tempRoot ("telegram-root-tab-badge-{0}" -f [System.Guid]::NewGuid().ToString('N'))
$resolvedTempDir = [System.IO.Path]::GetFullPath($tempDir)
if (-not $resolvedTempDir.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
  $resolvedTempDir -eq $tempRoot) {
  throw "Unsafe temporary test directory: $resolvedTempDir"
}

New-Item -ItemType Directory -Path $resolvedTempDir | Out-Null
try {
  $formatterModule = Join-Path $resolvedTempDir 'TgCompactCount.ts'
  $tokenModule = Join-Path $resolvedTempDir 'TgUiTokens.ts'
  $testModule = Join-Path $resolvedTempDir 'TgCompactCount.test.mjs'

  $formatterText = (Get-Content -LiteralPath $formatter -Raw).Replace(
    "from '../tokens/TgUiTokens';",
    "from './TgUiTokens.ts';"
  )
  Set-Content -LiteralPath $formatterModule -Value $formatterText -Encoding utf8

  @'
export class TgUiTokens {
  static readonly UNREAD_BADGE_COMPACT_THOUSAND: number = 1000;
  static readonly UNREAD_BADGE_COMPACT_MILLION: number = 1000000;
  static readonly UNREAD_BADGE_COMPACT_DECIMAL_DIVISOR: number = 10;
  static readonly UNREAD_BADGE_COMPACT_THOUSAND_SUFFIX: string = 'K';
  static readonly UNREAD_BADGE_COMPACT_MILLION_SUFFIX: string = 'M';
}
'@ | Set-Content -LiteralPath $tokenModule -Encoding utf8

  @'
import assert from 'node:assert/strict';
import { formatTelegramCompactCount } from './TgCompactCount.ts';

assert.equal(formatTelegramCompactCount(-4), '0');
assert.equal(formatTelegramCompactCount(999), '999');
assert.equal(formatTelegramCompactCount(1000), '1K');
assert.equal(formatTelegramCompactCount(2500), '2.5K');
assert.equal(formatTelegramCompactCount(999999), '999.9K');
assert.equal(formatTelegramCompactCount(1250000), '1.2M');
assert.equal(formatTelegramCompactCount(2500, ','), '2,5K');
'@ | Set-Content -LiteralPath $testModule -Encoding utf8

  & $node.Source --experimental-strip-types $testModule
  if ($LASTEXITCODE -ne 0) {
    throw "TgCompactCount host tests failed with exit code $LASTEXITCODE."
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

Write-Output 'Root native Chats-tab unread badge source contract: PASS'
