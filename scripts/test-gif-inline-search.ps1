param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

function Read-ProjectFile([string]$RelativePath) {
  return Get-Content -LiteralPath (Join-Path $Root $RelativePath) -Raw -Encoding UTF8
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

Assert-Contains $commands 'class GetOptionCommand' 'Missing typed getOption command'
Assert-Contains $commands 'class SearchPublicChatCommand' 'Missing typed searchPublicChat command'
Assert-Contains $commands 'class GetInlineQueryResultsCommand' 'Missing typed getInlineQueryResults command'
Assert-Contains $commands 'class SendInlineQueryResultCommand' 'Missing typed sendInlineQueryResultMessage command'
Assert-Contains $serializer "result\.method = 'getOption'" 'getOption serializer is not wired'
Assert-Contains $serializer "result\.method = 'searchPublicChat'" 'searchPublicChat serializer is not wired'
Assert-Contains $serializer "result\.method = 'getInlineQueryResults'" 'getInlineQueryResults serializer is not wired'
Assert-Contains $serializer "result\.method = 'sendInlineQueryResultMessage'" `
  'sendInlineQueryResultMessage serializer is not wired'
Assert-Contains $serializer "_user_location_json.*'null'" 'Inline query must pass null user_location'
Assert-Contains $useCase 'class GifSearchPage' 'Missing typed GIF search page result'
Assert-Contains $useCase 'async searchGifs\(' 'StickerPanelUseCase does not search inline GIFs'
Assert-Contains $useCase "animation_search_bot_username" 'GIF bot username option is not used'
Assert-Contains $useCase 'inlineQueryResultAnimation' 'Inline GIF results are not parsed as animations'
Assert-Contains $panel '@Event onGifSearchQueryChange' 'GIF mode does not emit search queries'
Assert-Contains $panel '@Event onSearchLoadMore' 'GIF search has no pagination event'
Assert-Contains $page 'GIF_SEARCH_DEBOUNCE_MS' 'Chat page does not debounce GIF search'
Assert-Contains $page 'handleGifSearchQueryChange' 'Chat page does not own GIF search lifecycle'
Assert-Contains $page 'loadMoreGifSearch' 'Chat page does not request next GIF search page'
Assert-Contains $page 'inlineQueryId' 'Inline query id is not carried to send'
Assert-Contains $page 'inlineResultId' 'Inline result id is not carried to send'

Write-Output 'PASS: Telegram inline-bot GIF search/send contract is wired end-to-end'
