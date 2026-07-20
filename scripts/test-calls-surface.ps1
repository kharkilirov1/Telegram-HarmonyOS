Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$mainTabs = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/MainTabsPage.ets') -Raw
$callsPage = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/calls/CallsPage.ets') -Raw
$callRow = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgCallRow.ets') -Raw
$tokens = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets') -Raw

$contracts = @(
  @{ Name = 'native calls filter'; Source = $mainTabs; Text = 'CapsuleSegmentButtonV2({' },
  @{ Name = 'HDS bottom builder'; Source = $mainTabs; Text = 'bottomBuilder:' },
  @{ Name = 'compact HDS calls title'; Source = $mainTabs; Text = 'mainTitleSize: TitleSize.TITLE_S' },
  @{ Name = 'localized calls title'; Source = $mainTabs; Text = "mainTitle: `$r('app.string.calls_title')" },
  @{ Name = 'typed missed query'; Source = $callsPage; Text = 'params.onlyMissed = this.onlyMissed;' },
  @{ Name = 'stale filter guard'; Source = $callsPage; Text = 'queryGeneration !== this.callsQueryGeneration' },
  @{ Name = 'short month date'; Source = $callsPage; Text = "callDate.getDate().toString() + ' ' + monthShort" },
  @{ Name = 'different-year date'; Source = $callsPage; Text = 'callDate.getFullYear() !== now.getFullYear()' },
  @{ Name = 'compact incoming label'; Source = $callsPage; Text = "calls_incoming_label').id" },
  @{ Name = 'compact outgoing label'; Source = $callsPage; Text = "calls_outgoing_label').id" },
  @{ Name = 'filter-to-list gap'; Source = $callsPage; Text = 'TgUiTokens.CALLS_FILTER_LIST_GAP' },
  @{ Name = 'info action icon'; Source = $callRow; Text = 'src: TgUiTokens.ICON_RES_INFO' },
  @{ Name = 'single-line call status'; Source = $callRow; Text = '.textOverflow({ overflow: TextOverflow.Ellipsis })' },
  @{ Name = 'filter geometry token'; Source = $tokens; Text = 'CALLS_FILTER_BAR_HEIGHT: number = 48;' }
)

foreach ($contract in $contracts) {
  if (-not $contract.Source.Contains($contract.Text)) {
    throw "Missing calls-surface contract: $($contract.Name)"
  }
}

Write-Output 'PASS: calls surface hierarchy and behavior contracts are present'
