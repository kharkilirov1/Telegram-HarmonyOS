Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$atomPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgChannelShareButton.ets'
$routerPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/molecules/TgMessageRouter.ets'
$pagePath = Join-Path $root 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets'
$controllerPath = Join-Path $root 'entry/src/main/ets/ui/pages/chat/ChatMessageActionsController.ets'
$tokensPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets'
$demoPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/demos/TgChannelShareButtonDemo.ets'
$passportPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/spec/TgChannelShareButton.md'

foreach ($path in @($atomPath, $routerPath, $pagePath, $controllerPath, $tokensPath, $demoPath, $passportPath)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Channel share button contract file is missing: $path"
  }
}

$atom = Get-Content -LiteralPath $atomPath -Raw
$router = Get-Content -LiteralPath $routerPath -Raw
$page = Get-Content -LiteralPath $pagePath -Raw
$controller = Get-Content -LiteralPath $controllerPath -Raw
$tokens = Get-Content -LiteralPath $tokensPath -Raw
$demo = Get-Content -LiteralPath $demoPath -Raw
$passport = Get-Content -LiteralPath $passportPath -Raw

foreach ($fragment in @(
    'CHANNEL_SHARE_BUTTON_SIZE: number = 30',
    'CHANNEL_SHARE_BUTTON_RESPONSE_SIZE: number = 40',
    'CHANNEL_SHARE_BUTTON_GAP: number = 8',
    'CHANNEL_SHARE_BUTTON_BOTTOM_INSET: number = 1')) {
  if (-not $tokens.Contains($fragment)) {
    throw "Channel share token missing: $fragment"
  }
}

foreach ($fragment in @(
    'export struct TgChannelShareButton',
    'new uiMaterial.ImmersiveMaterial',
    'TgUiTokens.ICON_RES_FORWARD',
    '.responseRegion({',
    '.accessibilityText(this.accessibilityLabel)',
    'this.onPress();')) {
  if (-not $atom.Contains($fragment)) {
    throw "Channel share atom contract missing: $fragment"
  }
}

foreach ($fragment in @(
    "import { TgChannelShareButton } from '../atoms/TgChannelShareButton';",
    '@Event onChannelSharePress: () => void',
    'private shouldShowChannelShareButton(): boolean',
    'return this.isBroadcastChannel && !this.isOutgoing;',
    'private buildChannelShareButton()')) {
  if (-not $router.Contains($fragment)) {
    throw "Router channel share contract missing: $fragment"
  }
}

$shareBuilderCallCount = ([regex]::Matches($router, 'this\.buildChannelShareButton\(\)')).Count
if ($shareBuilderCallCount -lt 7) {
  throw "Router must cover every message family with the channel share button; found $shareBuilderCallCount builder calls."
}

if ($router -notmatch '(?s)TgMediaBubbleShellV2\(\{.*?\}\)\s*\.width\(this\.visualMediaBubbleWidth\(\)\)') {
  throw 'Broadcast media must expose its intrinsic bubble edge so the adjacent share button is not clipped.'
}

foreach ($fragment in @(
    'openForwardTargetPickerForEntry(entry: ChatTimelineEntryVO, host: ChatMessageActionsHost)',
    'this.openForwardTargetPicker([entry.message.messageId], author, preview, host);')) {
  if (-not $controller.Contains($fragment)) {
    throw "Message action controller direct-forward contract missing: $fragment"
  }
}

foreach ($fragment in @(
    'onChannelSharePress: (): void => {',
    'this.messageActionsCtrl.openForwardTargetPickerForEntry(entry, this);')) {
  if (-not $page.Contains($fragment)) {
    throw "Chat page channel share callback missing: $fragment"
  }
}

if (-not $demo.Contains('TgChannelShareButton({')) {
  throw 'Channel share demo does not render the atom.'
}

foreach ($fragment in @(
    'ChatMessageShareButton.swift',
    '30×30pt',
    '`bubble.maxX + 8pt`',
    '`forwardMessages`')) {
  if (-not $passport.Contains($fragment)) {
    throw "Channel share passport evidence missing: $fragment"
  }
}

Write-Host 'Channel share button source contract passed.' -ForegroundColor Green
