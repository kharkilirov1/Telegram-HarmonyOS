param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot)
)
. (Join-Path $PSScriptRoot "chat-screen-source.ps1")

$ErrorActionPreference = 'Stop'

function Read-ProjectFile([string]$RelativePath) {
  return Get-ChatContractContent -LiteralPath (Join-Path $Root $RelativePath) -Raw -Encoding UTF8
}

function Assert-Contains([string]$Text, [string]$Pattern, [string]$Message) {
  if ($Text -notmatch $Pattern) {
    throw $Message
  }
}

$commands = Read-ProjectFile 'entry/src/main/ets/core/model/AppCommand.ets'
$serializer = Read-ProjectFile 'entry/src/main/ets/infra/td/serialization/CommandSerializer.ets'
$useCase = Read-ProjectFile 'entry/src/main/ets/domain/usecases/stickerPanel.ets'
$panel = Read-ProjectFile 'entry/src/main/ets/ui/tg_ui/atoms/TgComposerStickerPanel.ets'
$page = Read-ProjectFile 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets'
$searchController = Read-ProjectFile 'entry/src/main/ets/ui/pages/chat/ChatStickerSearchController.ets'

Assert-Contains $commands 'class SearchRegularStickersCommand' `
  'Missing typed SearchRegularStickersCommand'
Assert-Contains $commands 'createSearchRegularStickersCommand' `
  'Missing regular sticker search command factory'
Assert-Contains $serializer "COMMAND_SERIALIZATION_HANDLERS\.set\('searchRegularStickers'" `
  'Regular sticker search serializer is not registered'
Assert-Contains $serializer 'stickerTypeRegular' `
  'Regular sticker search does not serialize stickerTypeRegular'
Assert-Contains $useCase 'async searchRegularStickers\(' `
  'StickerPanelUseCase does not expose regular sticker search'
Assert-Contains $panel '@Event onSearchQueryChange' `
  'Sticker panel does not emit search query changes'
Assert-Contains $panel 'searchItems: StickerCellVO\[\]' `
  'Sticker panel does not accept external search results'
Assert-Contains $panel 'TextInput\(' `
  'Sticker panel has no iOS-style search field'
Assert-Contains $searchController 'STICKER_SEARCH_DEBOUNCE_MS' `
  'Sticker search controller does not debounce requests'
Assert-Contains $searchController 'searchRegularStickers' `
  'Sticker search controller is not wired to typed regular sticker search'
Assert-Contains $searchController 'isCurrent\(' `
  'Sticker search controller does not fence stale results'
Assert-Contains $page 'this\.stickerSearchCtrl\.handleSearchQueryChange\(' `
  'Chat page does not dispatch sticker queries to the controller'
Assert-Contains $page 'this\.stickerSearchCtrl\.reset\(' `
  'Chat page does not reset sticker search on panel teardown'

Write-Output 'PASS: regular Telegram sticker search is wired end-to-end'
