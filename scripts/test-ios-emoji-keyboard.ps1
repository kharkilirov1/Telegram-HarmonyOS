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

$command = Read-ProjectFile 'entry/src/main/ets/core/model/AppCommand.ets'
$serializer = Read-ProjectFile 'entry/src/main/ets/infra/td/serialization/CommandSerializer.ets'
$sendMessage = Read-ProjectFile 'entry/src/main/ets/domain/usecases/sendMessage.ets'
$stickerUseCase = Read-ProjectFile 'entry/src/main/ets/domain/usecases/stickerPanel.ets'
$panel = Read-ProjectFile 'entry/src/main/ets/ui/tg_ui/atoms/TgComposerEmojiPanel.ets'
$unicodeCatalog = Read-ProjectFile 'entry/src/main/ets/ui/tg_ui/data/TgUnicodeEmojiCatalog.ets'
$page = Read-ProjectFile 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets'

Assert-Contains $command 'GetInstalledCustomEmojiSetsCommand' `
  'Missing typed TDLib command for installed custom-emoji packs'
Assert-Contains $command 'GetTrendingCustomEmojiSetsCommand' `
  'Missing typed TDLib command for Telegram featured custom-emoji packs'
Assert-Contains $serializer 'stickerTypeCustomEmoji' `
  'Installed custom-emoji packs are not serialized as stickerTypeCustomEmoji'
Assert-Contains $serializer 'getTrendingStickerSets' `
  'Featured custom-emoji packs are not loaded through TDLib getTrendingStickerSets'
Assert-Contains $serializer 'textEntityTypeCustomEmoji' `
  'Outgoing custom emoji are not serialized as TDLib textEntityTypeCustomEmoji'
Assert-Contains $sendMessage 'customEmojiEntities' `
  'SendMessageUseCase does not carry custom-emoji entities'
Assert-Contains $stickerUseCase 'customEmojiId' `
  'Sticker parser drops stickerFullTypeCustomEmoji.custom_emoji_id'
Assert-Contains $stickerUseCase 'loadInstalledCustomEmojiSets' `
  'StickerPanelUseCase does not load real Telegram custom-emoji packs'
Assert-Contains $stickerUseCase 'loadTrendingCustomEmojiSets' `
  'StickerPanelUseCase does not load real Telegram featured custom-emoji packs'

Assert-Contains $panel 'export class CustomEmojiCellVO' `
  'Emoji panel has no typed real custom-emoji cell model'
Assert-Contains $panel 'export class CustomEmojiPackTabVO' `
  'Emoji panel has no typed custom-emoji pack tabs'
Assert-Contains $panel 'private buildPackStrip' `
  'Emoji panel is missing the iOS-style horizontal pack strip'
Assert-Contains $panel 'Grid\(\)' `
  'Emoji panel is missing a scrollable ArkUI grid'
Assert-Contains $panel 'TgEntityKeyboardModeBar' `
  'Emoji panel lost the shared GIF/Stickers/Emoji bottom mode bar'
Assert-Contains $panel 'LazyForEach\(this\.unicodeDataSource' `
  'Full Unicode catalog must render lazily instead of eagerly creating every emoji cell'

Assert-Contains $unicodeCatalog 'new UnicodeEmojiCategory\(' `
  'Unicode emoji catalog has no typed category data'
Assert-Contains $unicodeCatalog '"people"' `
  'Unicode emoji catalog is missing the People & Body category'
Assert-Contains $unicodeCatalog '"flags"' `
  'Unicode emoji catalog is missing the Flags category'
$categoryCount = [regex]::Matches($unicodeCatalog, 'new UnicodeEmojiCategory\(').Count
if ($categoryCount -ne 9) {
  throw "Unicode emoji catalog must expose the nine CLDR keyboard groups; got $categoryCount"
}
$countMatch = [regex]::Match($unicodeCatalog, 'UNICODE_EMOJI_COUNT:\s*number\s*=\s*(\d+)')
if (-not $countMatch.Success -or [int]$countMatch.Groups[1].Value -lt 1500) {
  throw 'Unicode emoji catalog is still a short sample instead of the complete base RGI set'
}

Assert-Contains $page 'loadCustomEmojiPanelIfNeeded' `
  'Production chat path does not load custom-emoji packs'
Assert-Contains $page 'loadTrendingCustomEmojiSets' `
  'Production chat path does not expose Telegram featured custom emoji when no packs are installed'
Assert-Contains $page 'handleCustomEmojiSelected' `
  'Production chat path does not insert selected Telegram custom emoji'
Assert-Contains $page 'customEmojiItems:\s*this\.customEmojiPanelItems' `
  'Production page does not pass real custom-emoji cells into the emoji panel'
Assert-Contains $page 'customEmojiTabs:\s*this\.customEmojiPackTabs' `
  'Production page does not pass real custom-emoji pack tabs into the emoji panel'

Write-Host 'PASS: iOS-like Telegram emoji keyboard contract is wired end-to-end'
