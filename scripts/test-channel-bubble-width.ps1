Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$tokensPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets'
$routerPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/molecules/TgMessageRouter.ets'
$pagePath = Join-Path $root 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets'
$demoPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/demos/TgMessageRouterDemo.ets'
$passportPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/spec/TgMessageRouter.md'

foreach ($path in @($tokensPath, $routerPath, $pagePath, $demoPath, $passportPath)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Channel bubble width contract file is missing: $path"
  }
}

$tokens = Get-Content -LiteralPath $tokensPath -Raw
$router = Get-Content -LiteralPath $routerPath -Raw
$page = Get-Content -LiteralPath $pagePath -Raw
$demo = Get-Content -LiteralPath $demoPath -Raw
$passport = Get-Content -LiteralPath $passportPath -Raw

foreach ($fragment in @(
    'CHANNEL_BUBBLE_SHARE_ACTION_INSET: number = 45',
    'CHANNEL_BUBBLE_EDGE_INSET: number = 3',
    'resolveChannelBubbleMaxWidth(containerWidth: number, reserveShareAction: boolean)')) {
  if (-not $tokens.Contains($fragment)) {
    throw "Channel bubble token contract missing: $fragment"
  }
}

foreach ($fragment in @(
    '@Param isBroadcastChannel: boolean = false',
    'TgUiTokens.resolveChannelBubbleMaxWidth(effectiveContainer, !this.isOutgoing)')) {
  if (-not $router.Contains($fragment)) {
    throw "TgMessageRouter channel width contract missing: $fragment"
  }
}

foreach ($fragment in @(
    '@Local private activeChatIsChannel: boolean = false',
    "this.activeChatIsChannel = chat?.type === 'channel';",
    'isBroadcastChannel: this.activeChatIsChannel')) {
  if (-not $page.Contains($fragment)) {
    throw "TgChatScreenPage channel width integration missing: $fragment"
  }
}

if (-not $demo.Contains("this.buildSection('broadcast channel: full-width text lane')") -or
    -not $demo.Contains('isBroadcastChannel: true')) {
  throw 'TgMessageRouterDemo does not cover the broadcast-channel width state.'
}

foreach ($fragment in @(
    'ChatMessageBubbleItemNode.swift',
    '`allowFullWidth`',
    '45pt share-action lane',
    '`isBroadcastChannel`')) {
  if (-not $passport.Contains($fragment)) {
    throw "TgMessageRouter passport is missing channel-width evidence: $fragment"
  }
}

Write-Host 'Broadcast-channel bubble width source contract passed.' -ForegroundColor Green
