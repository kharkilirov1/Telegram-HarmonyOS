Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$mainTabs = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/MainTabsPage.ets') -Raw
$contactsPage = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/contacts/ContactsPage.ets') -Raw
$contactRow = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgContactRow.ets') -Raw
$tokens = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets') -Raw

$contracts = @(
  @{ Name = 'compact native title'; Source = $mainTabs; Text = 'mainTitleSize: TitleSize.TITLE_S' },
  @{ Name = 'opaque contacts title clearance'; Source = $mainTabs; Text = 'backgroundStyle: { backgroundColor: TgUiTokens.COLOR_BG_PRIMARY }' },
  @{ Name = 'native search'; Source = $contactsPage; Text = 'Search({ value: this.searchText' },
  @{ Name = 'real contact filtering'; Source = $contactsPage; Text = 'contact.sortKey.includes(query)' },
  @{ Name = 'emoji-safe initials'; Source = $contactsPage; Text = 'firstAlphabeticLetter(user.firstName)' },
  @{ Name = 'locale-aware ordering'; Source = $contactsPage; Text = 'a.sortKey.localeCompare(b.sortKey, locale)' },
  @{ Name = 'resource locale source'; Source = $contactsPage; Text = 'resourceManager.getConfigurationSync().locale' },
  @{ Name = 'locale tag normalization'; Source = $contactsPage; Text = "configuredLocale.replace('_', '-')" },
  @{ Name = 'Russian script ordering'; Source = $contactsPage; Text = "locale.toLowerCase().startsWith('ru')" },
  @{ Name = 'sticky section groups'; Source = $contactsPage; Text = 'ListItemGroup({ header: this.buildSectionHeader(section.title) })' },
  @{ Name = 'native alphabet indexer'; Source = $contactsPage; Text = 'AlphabetIndexer({ arrayValue: this.alphabet' },
  @{ Name = 'indexer pending selection'; Source = $contactsPage; Text = 'this.pendingSectionIndex = index' },
  @{ Name = 'programmatic scroll completion'; Source = $contactsPage; Text = '.onScrollStop(() => {' },
  @{ Name = 'indexer scroll contract'; Source = $contactsPage; Text = 'this.listScroller.scrollToIndex(index + 1, true, ScrollAlign.START)' },
  @{ Name = 'title-safe list viewport'; Source = $contactsPage; Text = '.padding({ top: this.topBarTotalHeight })' },
  @{ Name = 'custom contact atom'; Source = $contactsPage; Text = 'TgContactRow({' },
  @{ Name = 'single-line contact name'; Source = $contactRow; Text = '.textOverflow({ overflow: TextOverflow.Ellipsis })' },
  @{ Name = 'indexer lane token'; Source = $tokens; Text = 'CONTACT_ROW_INDEXER_END_PADDING: number = 32;' }
)

foreach ($contract in $contracts) {
  if (-not $contract.Source.Contains($contract.Text)) {
    throw "Missing contacts-surface contract: $($contract.Name)"
  }
}

Write-Output 'PASS: contacts surface hierarchy and behavior contracts are present'
