Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$atom = Get-Content -Raw (Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgProfileNavigationBar.ets')
$page = Get-Content -Raw (Join-Path $root 'entry/src/main/ets/ui/pages/profile/TgProfilePage.ets')
$tokens = Get-Content -Raw (Join-Path $root 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets')
$spec = Get-Content -Raw (Join-Path $root 'entry/src/main/ets/ui/tg_ui/spec/TgProfileNavigationBar.md')

$checks = @(
  @{ Name = 'profile page uses the isolated atom'; Source = $page; Text = 'TgProfileNavigationBar({' },
  @{ Name = 'native material path'; Source = $atom; Text = '.systemMaterial(new uiMaterial.ImmersiveMaterial({' },
  @{ Name = 'API23 adaptive blur fallback'; Source = $atom; Text = '.backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())' },
  @{ Name = '44vp response region'; Source = $atom; Text = 'PROFILE_NAV_RESPONSE_SIZE' },
  @{ Name = 'iOS 16pt side inset token'; Source = $tokens; Text = 'PROFILE_NAV_SIDE_INSET: number = 16' },
  @{ Name = 'no full width plate contract'; Source = $spec; Text = 'there is no full-width background plate' },
  @{ Name = 'profile search keeps existing route'; Source = $page; Text = 'this.openChatSearch();' }
)

foreach ($check in $checks) {
  if (-not $check.Source.Contains($check.Text)) {
    throw "FAIL: $($check.Name)"
  }
}

Write-Host 'PASS: profile navigation glass atom contracts are present'
