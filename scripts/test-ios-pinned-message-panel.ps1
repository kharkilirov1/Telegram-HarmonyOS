$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$atomPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgPinnedMessagePanel.ets'
$demoPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/demos/TgPinnedMessagePanelDemo.ets'
$specPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/spec/TgPinnedMessagePanel.md'
$tokensPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets'
$pagePath = Join-Path $root 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets'
$useCasePath = Join-Path $root 'entry/src/main/ets/domain/usecases/loadPinnedMessage.ets'
$commandPath = Join-Path $root 'entry/src/main/ets/core/model/AppCommand.ets'
$serializerPath = Join-Path $root 'entry/src/main/ets/infra/td/serialization/CommandSerializer.ets'

foreach ($path in @($atomPath, $demoPath, $specPath, $pagePath, $useCasePath, $commandPath, $serializerPath)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing pinned-message artifact: $path"
  }
}

$atom = Get-Content -LiteralPath $atomPath -Raw
$demo = Get-Content -LiteralPath $demoPath -Raw
$spec = Get-Content -LiteralPath $specPath -Raw
$tokens = Get-Content -LiteralPath $tokensPath -Raw

$requiredAtomPatterns = @(
  "import { uiMaterial } from '@kit.ArkUI';",
  "import { Available, deviceInfo } from '@kit.BasicServicesKit';",
  'export struct TgPinnedMessagePanel',
  '@Param totalCount: number',
  '@Param index: number',
  '@Param hasThumbnail: boolean',
  '@Param thumbnailSrc: Resource | string',
  'buildNativeSurface',
  'buildFallbackSurface',
  'new uiMaterial.ImmersiveMaterial',
  'buildNavigationStripe',
  '.responseRegion(',
  'onListPress',
  'onClosePress'
)
foreach ($pattern in $requiredAtomPatterns) {
  if (-not $atom.Contains($pattern)) {
    throw "TgPinnedMessagePanel is missing: $pattern"
  }
}

if ($atom.Contains('TgTopChromeBackground')) {
  throw 'Pinned-message panel must remain an isolated glass capsule.'
}

$requiredTokens = @(
  'PINNED_PANEL_HEIGHT',
  'PINNED_PANEL_SIDE_INSET',
  'PINNED_PANEL_RADIUS',
  'PINNED_PANEL_STRIPE_WIDTH',
  'PINNED_PANEL_THUMB_SIZE',
  'PINNED_PANEL_TITLE_SIZE',
  'PINNED_PANEL_PREVIEW_SIZE'
)
foreach ($pattern in $requiredTokens) {
  if (-not $tokens.Contains($pattern)) {
    throw "TgUiTokens is missing: $pattern"
  }
}

foreach ($fragment in @('PINNED_PANEL_HEIGHT: number = 48;', 'PINNED_PANEL_RADIUS: number = 12;',
    'PINNED_PANEL_THUMB_SIZE: number = 34;', 'PINNED_PANEL_TITLE_SIZE: number = 14;',
    'PINNED_PANEL_PREVIEW_SIZE: number = 14;', 'PINNED_PANEL_ACTION_SIZE: number = 38;')) {
  if (-not $tokens.Contains($fragment)) {
    throw "Compact pinned-panel geometry is missing: $fragment"
  }
}

$demoCount = ([regex]::Matches($demo, 'TgPinnedMessagePanel\(')).Count
if ($demoCount -lt 6) {
  throw "Pinned-message demo needs at least 6 representative states; found $demoCount."
}
if (-not $demo.Contains('TgChatBackground')) {
  throw 'Pinned-message demo must prove the isolated capsule over chat wallpaper.'
}

foreach ($pattern in @('ChatPinnedMessageTitlePanelNode.swift', '50.0', '15.0', '36.0', '2.0')) {
  if (-not $spec.Contains($pattern)) {
    throw "Pinned-message passport is missing iOS evidence: $pattern"
  }
}

$page = Get-Content -LiteralPath $pagePath -Raw -Encoding UTF8
foreach ($pattern in @('TgPinnedMessagePanel({', 'loadPinnedMessageInfo(chatId)',
    '.contentStartOffset(this.chatContentStartOffset())', 'this.jumpToMessageId(this.pinnedMessageId)',
    'this.pinnedMessageDismissedId = this.pinnedMessageId',
    'timelineEntryContainsMessageId(entry, messageId)',
    'scrollToIndex(i, false, ScrollAlign.CENTER)')) {
  if (-not $page.Contains($pattern)) {
    throw "Live pinned-message integration is missing: $pattern"
  }
}

$useCase = Get-Content -LiteralPath $useCasePath -Raw -Encoding UTF8
foreach ($pattern in @('export class PinnedMessageInfo', 'parsePinnedMessageInfo',
    'createGetChatPinnedMessageCommand(chatId)', 'createMessageDtoFromTd(response)')) {
  if (-not $useCase.Contains($pattern)) {
    throw "Pinned-message use case is missing: $pattern"
  }
}

$command = Get-Content -LiteralPath $commandPath -Raw -Encoding UTF8
$serializer = Get-Content -LiteralPath $serializerPath -Raw -Encoding UTF8
foreach ($pattern in @('GetChatPinnedMessageCommand', 'createGetChatPinnedMessageCommand')) {
  if (-not $command.Contains($pattern)) {
    throw "Pinned-message command contract is missing: $pattern"
  }
}
foreach ($pattern in @("COMMAND_SERIALIZATION_HANDLERS.set('getChatPinnedMessage'", "result.method = 'getChatPinnedMessage'")) {
  if (-not $serializer.Contains($pattern)) {
    throw "Pinned-message serializer contract is missing: $pattern"
  }
}

Write-Output 'iOS pinned-message panel source contract: PASS'
