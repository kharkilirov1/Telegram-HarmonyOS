Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$controller = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/chat/ChatSearchController.ets') -Raw
$useCase = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/domain/usecases/searchChatMessages.ets') -Raw
$page = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets') -Raw
$tokens = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets') -Raw
$topBar = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets') -Raw
$profile = Get-Content -LiteralPath (Join-Path $root 'entry/src/main/ets/ui/pages/profile/TgProfilePage.ets') -Raw

$contracts = @(
  @{ Name = 'TDLib next cursor parsed'; Source = $useCase; Text = "getInt64String('next_from_message_id')" },
  @{ Name = 'result exposes exact cursor'; Source = $useCase; Text = "nextFromMessageId: MessageId = '0'" },
  @{ Name = 'controller requests cursor page'; Source = $controller; Text = 'useCase.execute(chatId, query, cursor)' },
  @{ Name = 'pagination deduplicates ids'; Source = $controller; Text = 'new Set<string>(this.resultIds)' },
  @{ Name = 'older boundary loads then navigates'; Source = $controller; Text = 'this.loadMore(host, true)' },
  @{ Name = 'near-boundary prefetch'; Source = $controller; Text = 'SEARCH_PREFETCH_REMAINING' },
  @{ Name = 'same-query stale request guard'; Source = $controller; Text = 'requestId === this.requestId' },
  @{ Name = 'loading state callback'; Source = $controller; Text = 'onSearchLoadingChanged' },
  @{ Name = 'reliable system chevrons'; Source = $page; Text = "sys.symbol.chevron_up" },
  @{ Name = 'glass search controls'; Source = $page; Text = 'SEARCH_NAV_CAPSULE_HEIGHT' },
  @{ Name = 'searching state before empty'; Source = $page; Text = 'app.string.search_searching' },
  @{ Name = 'pagination keeps total navigation active'; Source = $page; Text = 'this.searchResultPos < this.searchResultTotal' },
  @{ Name = 'sticker hit gets outline'; Source = $page; Text = 'useSearchFlashOutline' },
  @{ Name = 'strong standalone outline token'; Source = $tokens; Text = 'SEARCH_HIT_OUTLINE' },
  @{ Name = 'search field has focus id'; Source = $topBar; Text = 'TG_CHAT_SEARCH_INPUT_ID' },
  @{ Name = 'search open requests system focus'; Source = $page; Text = 'getFocusController().requestFocus' },
  @{ Name = 'group profile exposes message search'; Source = $profile; Text = 'PendingChatSearchSignal.set' }
)

foreach ($contract in $contracts) {
  if (-not $contract.Source.Contains($contract.Text)) {
    throw "Missing chat-search polish contract: $($contract.Name)"
  }
}

Write-Output 'PASS: in-chat search pagination, state and flash contracts are present'
