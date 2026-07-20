Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$atomPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgForwardPickerNavigationBar.ets'
$pagePath = Join-Path $root 'entry/src/main/ets/ui/pages/forward/TgForwardTargetPickerPage.ets'
$tokensPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets'
$specPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/spec/TgForwardPickerNavigationBar.md'
$demoPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/demos/TgForwardPickerNavigationBarDemo.ets'
$ruStringsPath = Join-Path $root 'entry/src/main/resources/ru_RU/element/string.json'

$requiredPaths = @($atomPath, $pagePath, $tokensPath, $specPath, $demoPath, $ruStringsPath)
foreach ($path in $requiredPaths) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "FAIL: required file is missing: $path"
  }
}

$atom = Get-Content -Raw $atomPath
$page = Get-Content -Raw $pagePath
$tokens = Get-Content -Raw $tokensPath
$spec = Get-Content -Raw $specPath
$ruStrings = Get-Content -Raw $ruStringsPath

$checks = @(
  @{ Name = 'picker page uses the dedicated navigation atom'; Source = $page; Text = 'TgForwardPickerNavigationBar({' },
  @{ Name = 'legacy full-width TgTopBar is removed from picker'; Source = $page; Absent = 'TgTopBar({' },
  @{ Name = 'native API26 material path'; Source = $atom; Text = '.systemMaterial(new uiMaterial.ImmersiveMaterial({' },
  @{ Name = 'API23 adaptive blur fallback'; Source = $atom; Text = '.backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())' },
  @{ Name = 'status-bar safe area is measured'; Source = $atom; Text = 'getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)' },
  @{ Name = 'compact 38vp navigation control'; Source = $tokens; Text = 'FORWARD_PICKER_NAV_CONTROL_SIZE: number = TgUiTokens.CHAT_TOP_BAR_CONTROL_SIZE' },
  @{ Name = '44vp response region remains safe'; Source = $tokens; Text = 'FORWARD_PICKER_NAV_RESPONSE_SIZE: number = TgUiTokens.CHAT_TOP_BAR_RESPONSE_SIZE' },
  @{ Name = 'Search keeps native ArkUI component'; Source = $page; Text = 'Search({' },
  @{ Name = 'real Telegram chat rows remain the content'; Source = $page; Text = 'TgChatRow({' },
  @{ Name = 'existing typed forward result is preserved'; Source = $page; Text = 'this.pageStack.pop(new ForwardTargetPickerResult(item.chatId, item.title));' },
  @{ Name = 'Russian forward title is localized'; Source = $ruStrings; Text = '"name": "action_forward"' },
  @{ Name = 'no full-width navigation plate contract'; Source = $spec; Text = 'no full-width background plate' }
)

foreach ($check in $checks) {
  if ($check.ContainsKey('Text') -and -not $check.Source.Contains($check.Text)) {
    throw "FAIL: $($check.Name)"
  }
  if ($check.ContainsKey('Absent') -and $check.Source.Contains($check.Absent)) {
    throw "FAIL: $($check.Name)"
  }
}

Get-Content -Raw $ruStringsPath | ConvertFrom-Json | Out-Null
Write-Host 'PASS: forward picker polish contracts are present'
