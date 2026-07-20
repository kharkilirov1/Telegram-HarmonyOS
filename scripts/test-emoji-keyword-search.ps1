param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Read-ProjectFile([string]$RelativePath) {
  $path = Join-Path $Root $RelativePath
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing file: $RelativePath"
  }
  return Get-Content -LiteralPath $path -Raw
}

function Assert-Contains([string]$Content, [string]$Pattern, [string]$Message) {
  if ($Content -notmatch $Pattern) {
    throw $Message
  }
}

function Assert-NotContains([string]$Content, [string]$Pattern, [string]$Message) {
  if ($Content -match $Pattern) {
    throw $Message
  }
}

$command = Read-ProjectFile 'entry/src/main/ets/core/model/AppCommand.ets'
$serializer = Read-ProjectFile 'entry/src/main/ets/infra/td/serialization/CommandSerializer.ets'
$useCase = Read-ProjectFile 'entry/src/main/ets/domain/usecases/stickerPanel.ets'
$panel = Read-ProjectFile 'entry/src/main/ets/ui/tg_ui/atoms/TgComposerEmojiPanel.ets'
$page = Read-ProjectFile 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets'

Assert-Contains $command 'SearchEmojisCommand' 'Missing typed searchEmojis command'
Assert-Contains $command 'SearchCustomEmojiStickersCommand' `
  'Missing typed searchStickers command for custom emoji'
Assert-Contains $serializer "result\.method = 'searchEmojis'" `
  'searchEmojis serializer is not wired'
Assert-Contains $serializer "result\.method = 'searchStickers'" `
  'searchStickers serializer is not wired'
Assert-Contains $serializer 'stickerTypeCustomEmoji' `
  'Custom emoji search does not select stickerTypeCustomEmoji'
Assert-Contains $serializer '_input_language_codes_json' `
  'Emoji search does not preserve input language codes'
Assert-Contains $useCase 'searchEmojiKeyboard' `
  'StickerPanelUseCase has no combined Unicode/custom emoji search'

Assert-Contains $panel 'searchUnicodeResults' `
  'Emoji panel does not consume server Unicode results'
Assert-Contains $panel 'searchCustomEmojiItems' `
  'Emoji panel does not consume server custom-emoji results'
Assert-Contains $panel 'onSearchQueryChange' `
  'Emoji panel does not emit search query changes'
Assert-NotContains $panel 'fallbackEmoji\.indexOf\(this\.searchQuery\)' `
  'Emoji panel still performs the old local glyph-only search'

Assert-Contains $page 'EMOJI_SEARCH_DEBOUNCE_MS' `
  'Production page is missing the iOS-style search debounce'
Assert-Contains $page 'handleEmojiSearchQueryChange' `
  'Production page does not own emoji search lifecycle'
Assert-Contains $page 'searchEmojiKeyboard' `
  'Production page does not call the real TDLib emoji search path'
Assert-Contains $page 'searchUnicodeResults:\s*this\.emojiSearchUnicodeResults' `
  'Production panel is not wired to server Unicode results'
Assert-Contains $page 'searchCustomEmojiItems:\s*this\.emojiSearchCustomItems' `
  'Production panel is not wired to server custom-emoji results'

Write-Host 'PASS: TDLib emoji keyword search contract is wired end-to-end'
