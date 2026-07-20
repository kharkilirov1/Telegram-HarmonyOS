Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$demo = Join-Path $root 'entry/src/main/ets/ui/tg_ui/demos/TgHdsActionBarComposerDemo.ets'
$passport = Join-Path $root 'entry/src/main/ets/ui/tg_ui/spec/HdsActionBarComposerCapability.md'

if (-not (Test-Path -LiteralPath $demo)) {
  throw "HdsActionBar composer demo not found: $demo"
}
if (-not (Test-Path -LiteralPath $passport)) {
  throw "HdsActionBar composer passport not found: $passport"
}

$content = Get-Content -LiteralPath $demo -Raw -Encoding UTF8
$required = @(
  "HdsActionBar({",
  "primaryButtonBuilder:",
  "primaryButtonBuilderWidth: LengthMetrics.vp(",
  "startButtons:",
  "endButtons:",
  "new ActionBarStyle({",
  "TextArea({",
  "MODE_REPLY",
  "MODE_EDIT",
  "MODE_FORWARD",
  "MODE_ATTACHMENT",
  "MODE_SLOW",
  "MODE_RECORDING",
  "showAuxPanel"
)

foreach ($fragment in $required) {
  if (-not $content.Contains($fragment)) {
    throw "HdsActionBar composer demo contract missing: $fragment"
  }
}

$protectedFiles = @(
  'entry/src/main/ets/ui/pages/MainTabsPage.ets',
  'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets',
  'entry/src/main/ets/ui/tg_ui/atoms/TgComposerInput.ets',
  'entry/src/main/ets/ui/pages/chat/ChatComposerController.ets',
  'entry/src/main/ets/ui/pages/login/LoginRouterPage.ets'
)

foreach ($relativePath in $protectedFiles) {
  $path = Join-Path $root $relativePath
  $protectedContent = Get-Content -LiteralPath $path -Raw -Encoding UTF8
  if ($protectedContent.Contains('TgHdsActionBarComposerDemo')) {
    throw "Demo-only isolation violated by: $relativePath"
  }
}

if ((Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets') -Raw -Encoding UTF8).Contains('HdsActionBar')) {
  throw 'Live chat page must not contain HdsActionBar during the demo-only capability phase.'
}

Write-Host 'HdsActionBar composer demo source contract passed.'
