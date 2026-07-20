$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$topBarPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets'
$pagePath = Join-Path $root 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets'
$tokensPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets'
$motionPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/utils/TgChatTopBarMotionPolicy.ets'
$specPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/spec/TgChatTopBar.md'
$demoPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/demos/TgChatTopBarDemo.ets'

$topBar = Get-Content -LiteralPath $topBarPath -Raw
$page = Get-Content -LiteralPath $pagePath -Raw
$tokens = Get-Content -LiteralPath $tokensPath -Raw
$spec = Get-Content -LiteralPath $specPath -Raw
$demo = Get-Content -LiteralPath $demoPath -Raw

$requiredTopBarPatterns = @(
  "import { uiMaterial } from '@kit.ArkUI';",
  "import { Available, deviceInfo } from '@kit.BasicServicesKit';",
  'export enum TgChatTopBarTrailingAction',
  '@Param trailingAction: TgChatTopBarTrailingAction',
  'buildNativeBackCapsule',
  'buildFallbackBackCapsule',
  'buildNativeTitleCapsule',
  'buildFallbackTitleCapsule',
  'buildNativeSearchActionCapsule',
  'buildFallbackSearchActionCapsule',
  'buildNativeAvatarCapsule',
  'buildFallbackAvatarCapsule',
  'new uiMaterial.ImmersiveMaterial',
  '.systemMaterial(',
  'chatTopBarContentTransition()'
)

foreach ($pattern in $requiredTopBarPatterns) {
  if (-not $topBar.Contains($pattern)) {
    throw "TgChatTopBar is missing the iOS glass contract: $pattern"
  }
}

$titleContentStart = $topBar.IndexOf('private buildTitleContent()')
$titleContentEnd = $topBar.IndexOf('private buildNativeTitleCapsule()', $titleContentStart)
if ($titleContentStart -lt 0 -or $titleContentEnd -lt 0) {
  throw 'Unable to inspect the title-content builder.'
}
$titleContentBuilder = $topBar.Substring($titleContentStart, $titleContentEnd - $titleContentStart)
if ($titleContentBuilder.Contains(".width('100%')")) {
  throw 'The center title content must wrap its intrinsic width; width(100%) forces the island to maximum width.'
}

$wrapContentCount = ([regex]::Matches($topBar, '\.width\(LayoutPolicy\.wrapContent\)')).Count
if ($wrapContentCount -lt 2) {
  throw 'Both native and fallback title capsules must explicitly use LayoutPolicy.wrapContent.'
}

if ($topBar.Contains('R1.5:')) {
  throw 'TgChatTopBar still contains the rejected flat-control implementation.'
}

if ($topBar.Contains('TgTopChromeBackground')) {
  throw 'Chat top bar must not paint a full-width panel behind the independent glass capsules.'
}

if (-not $demo.Contains('TgChatBackground')) {
  throw 'TgChatTopBarDemo must render over chat wallpaper so accidental full-width panels stay visible.'
}

if ($topBar.Contains("Image(`$r('app.media.ic_search'))")) {
  throw 'Search must be rendered inside the trailing glass capsule, not as a naked image.'
}

$requiredPagePatterns = @(
  'TgChatTopBarTrailingAction',
  'chatTopBarTrailingAction',
  'trailingAction: this.chatTopBarTrailingAction'
)
foreach ($pattern in $requiredPagePatterns) {
  if (-not $page.Contains($pattern)) {
    throw "TgChatScreenPage is missing the trailing-action state contract: $pattern"
  }
}

$requiredTokenPatterns = @(
  'CHAT_TOP_BAR_CONTROL_SIZE',
  'CHAT_TOP_BAR_CONTROL_RADIUS',
  'CHAT_TOP_BAR_TITLE_HEIGHT',
  'CHAT_TOP_BAR_RESPONSE_SIZE',
  'CHAT_TOP_BAR_MOTION_MS'
)
foreach ($pattern in $requiredTokenPatterns) {
  if (-not $tokens.Contains($pattern)) {
    throw "TgUiTokens is missing the top-bar token: $pattern"
  }
}

foreach ($fragment in @('CHAT_TOP_BAR_CONTROL_SIZE: number = 38;',
    'CHAT_TOP_BAR_TITLE_HEIGHT: number = 40;', 'CHAT_TOP_BAR_AVATAR_INNER: number = 32;',
    'CHAT_TOP_BAR_TITLE_MIN_WIDTH: number = 144;', 'CHAT_TOP_BAR_TITLE_SIZE: number = 16;',
    'CHAT_TOP_BAR_SUBTITLE_SIZE: number = 12;',
    "CHAT_TOP_BAR_SCROLL_CAPSULE_BG: Resource = `$r('app.color.chat_top_bar_scroll_capsule_bg');")) {
  if (-not $tokens.Contains($fragment)) {
    throw "Compact chat top-bar geometry is missing: $fragment"
  }
}

if (-not (Test-Path -LiteralPath $motionPath)) {
  throw 'TgChatTopBarMotionPolicy.ets is missing.'
}
$motion = Get-Content -LiteralPath $motionPath -Raw
if (-not $motion.Contains('TransitionEffect.asymmetric') -or
    -not $motion.Contains('TransitionEffect.OPACITY') -or
    -not $motion.Contains('TransitionEffect.scale')) {
  throw 'Top-bar motion must use an asymmetric opacity/scale transition.'
}

$requiredSpecPatterns = @(
  'ChatTitleView.swift',
  'GlassBackgroundView',
  '44.0',
  '12.0',
  'API 26',
  'API 23'
)
foreach ($pattern in $requiredSpecPatterns) {
  if (-not $spec.Contains($pattern)) {
    throw "TgChatTopBar passport is missing reference evidence: $pattern"
  }
}

Write-Output 'iOS chat top-bar source contract: PASS'
