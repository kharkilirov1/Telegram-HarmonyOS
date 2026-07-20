Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$mainTabs = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/MainTabsPage.ets') -Raw
$settingsPage = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/settings/SettingsPage.ets') -Raw
$tokens = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets') -Raw
$baseStrings = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/resources/base/element/string.json') -Raw
$ruStrings = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/resources/ru_RU/element/string.json') -Raw

$contracts = @(
  @{ Name = 'compact native title'; Source = $mainTabs; Text = 'mainTitleSize: TitleSize.TITLE_S' },
  @{ Name = 'native title safe area'; Source = $mainTabs; Text = 'enableComponentSafeArea: true' },
  @{ Name = 'stable full settings title'; Source = $mainTabs; Text = '.titleMode(HdsNavigationTitleMode.FULL)' },
  @{ Name = 'live recent-calls route'; Source = $mainTabs; Text = 'this.controller.changeIndex(1)' },
  @{ Name = 'recent-calls event'; Source = $settingsPage; Text = '@Event onOpenCalls' },
  @{ Name = 'emoji-safe profile initials'; Source = $settingsPage; Text = 'firstAlphabeticLetter(user.firstName)' },
  @{ Name = 'devices shortcut'; Source = $settingsPage; Text = "app.string.settings_devices" },
  @{ Name = 'chat-folders shortcut'; Source = $settingsPage; Text = "app.string.settings_chat_folders" },
  @{ Name = 'power-saving row'; Source = $settingsPage; Text = "app.string.settings_power_saving" },
  @{ Name = 'Telegram tips row'; Source = $settingsPage; Text = "app.string.settings_tips" },
  @{ Name = 'localized language label'; Source = $settingsPage; Text = "app.string.language_current" },
  @{ Name = 'title-safe scroll viewport'; Source = $settingsPage; Text = '.padding({ top: this.topBarTotalHeight })' },
  @{ Name = 'device icon token'; Source = $tokens; Text = 'ICON_RES_DEVICE' },
  @{ Name = 'folder icon token'; Source = $tokens; Text = 'ICON_RES_FOLDER' },
  @{ Name = 'power icon token'; Source = $tokens; Text = 'ICON_RES_POWER_SAVING' },
  @{ Name = 'base language value'; Source = $baseStrings; Text = '"name": "language_current"' },
  @{ Name = 'Russian language value'; Source = $ruStrings; Text = '"value": "Русский"' },
  @{ Name = 'floating tab clearance'; Source = $settingsPage; Text = 'Row().width(''100%'').height(this.contentBottomInset)' }
)

foreach ($contract in $contracts) {
  if (-not $contract.Source.Contains($contract.Text)) {
    throw "Missing settings-surface contract: $($contract.Name)"
  }
}

Write-Output 'PASS: settings surface hierarchy and routing contracts are present'
