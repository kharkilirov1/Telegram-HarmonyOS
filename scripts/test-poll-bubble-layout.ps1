Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$atomPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgPollBubble.ets'
$routerPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/molecules/TgMessageRouter.ets'
$tokensPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets'
$demoPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/demos/TgPollBubbleDemo.ets'
$passportPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/spec/TgPollBubble.md'
$baseStringsPath = Join-Path $root 'entry/src/main/resources/base/element/string.json'
$ruStringsPath = Join-Path $root 'entry/src/main/resources/ru_RU/element/string.json'
$zhStringsPath = Join-Path $root 'entry/src/main/resources/zh_CN/element/string.json'

foreach ($path in @($atomPath, $routerPath, $tokensPath, $demoPath, $passportPath,
    $baseStringsPath, $ruStringsPath, $zhStringsPath)) {
  if (-not (Test-Path $path)) {
    throw "Poll layout contract file is missing: $path"
  }
}

$atom = Get-Content $atomPath -Raw
$router = Get-Content $routerPath -Raw
$tokens = Get-Content $tokensPath -Raw
$demo = Get-Content $demoPath -Raw
$passport = Get-Content $passportPath -Raw

$requiredTokenFragments = @(
  'POLL_BUBBLE_PREFERRED_MIN_WIDTH: number = 280',
  'POLL_OPTION_TEXT_INSET: number = 50',
  'POLL_OPTION_SIDE_INSET: number = 12',
  'resolvePollBubbleMinWidth(availableWidth: number)'
)
foreach ($fragment in $requiredTokenFragments) {
  if (-not $tokens.Contains($fragment)) {
    throw "Poll token contract missing: $fragment"
  }
}

$requiredAtomFragments = @(
  '@Param availableWidth: number = TgUiTokens.POLL_BUBBLE_PREFERRED_MIN_WIDTH',
  'minWidth: TgUiTokens.resolvePollBubbleMinWidth(this.availableWidth)',
  'maxWidth: this.availableWidth',
  '.padding({ left: TgUiTokens.POLL_OPTION_SIDE_INSET',
  '.padding({ left: TgUiTokens.POLL_OPTION_TEXT_INSET'
)
foreach ($fragment in $requiredAtomFragments) {
  if (-not $atom.Contains($fragment)) {
    throw "Poll atom contract missing: $fragment"
  }
}
if ($atom.Contains('.constraintSize({ minWidth: 240 })')) {
  throw 'Poll atom still has an unbounded 240vp minimum width.'
}
foreach ($fragment in @("localized(`$r('app.string.anonymous_poll').id", "localized(`$r('app.string.few_votes').id",
    '.alignItems(HorizontalAlign.Start)')) {
  if (-not $atom.Contains($fragment)) {
    throw "Poll localization/alignment contract missing: $fragment"
  }
}

foreach ($path in @($baseStringsPath, $ruStringsPath, $zhStringsPath)) {
  $names = @((Get-Content $path -Raw | ConvertFrom-Json).string.name)
  foreach ($name in @('anonymous_quiz', 'few_votes', 'many_votes')) {
    if ($names -notcontains $name) {
      throw "Poll localization resource '$name' is missing from $path"
    }
  }
}

if (-not $router.Contains('availableWidth: this.pollContentWidth()')) {
  throw 'Router does not pass the bounded poll content width.'
}
if (-not $router.Contains('private pollContentWidth(): number')) {
  throw 'Router poll content width helper is missing.'
}
$pollBlock = [regex]::Match($router, "else if \(this\.contentType === 'poll'\)(?<body>[\s\S]*?)else if \(this\.isVisualMedia\(\)\)").Groups['body'].Value
if ($pollBlock -match '\.borderRadius\(TgUiTokens\.BUBBLE_RADIUS_INCOMING\)\s*\.padding\(') {
  throw 'Router still adds a second all-around padding layer around the poll atom.'
}
if (-not $demo.Contains("'10 narrow incoming width clamp'")) {
  throw 'Poll demo does not cover the narrow-width regression.'
}
if (-not $passport.Contains('min(280vp, available content width)')) {
  throw 'Poll passport does not record the iOS bounded minimum-width rule.'
}

Write-Host 'Poll bubble bounded-layout source contract passed.' -ForegroundColor Green
