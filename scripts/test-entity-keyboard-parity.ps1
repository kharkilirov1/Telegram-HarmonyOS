$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$modeBar = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgEntityKeyboardModeBar.ets'
$stickerPanel = Get-Content (Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgComposerStickerPanel.ets') -Raw
$emojiPanel = Get-Content (Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgComposerEmojiPanel.ets') -Raw
$chatPage = Get-Content (Join-Path $root 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets') -Raw
$commands = Get-Content (Join-Path $root 'entry/src/main/ets/core/model/AppCommand.ets') -Raw
$serializer = Get-Content (Join-Path $root 'entry/src/main/ets/infra/td/serialization/CommandSerializer.ets') -Raw
$useCase = Get-Content (Join-Path $root 'entry/src/main/ets/domain/usecases/stickerPanel.ets') -Raw

if (-not (Test-Path $modeBar)) {
  throw 'Missing production TgEntityKeyboardModeBar atom'
}

$modeBarSource = Get-Content $modeBar -Raw
foreach ($required in @('gifs', 'stickers', 'emoji', 'onModePress')) {
  if ($modeBarSource -notmatch [regex]::Escape($required)) {
    throw "Mode bar is missing $required"
  }
}

if ($stickerPanel -notmatch 'TgEntityKeyboardModeBar' -or
    $emojiPanel -notmatch 'TgEntityKeyboardModeBar') {
  throw 'Both production panels must share the entity-keyboard mode bar'
}

if ($chatPage -notmatch 'handleComposerGifPress' -or
    $chatPage -notmatch 'handleComposerStickerModePress') {
  throw 'Chat page does not own real GIF/Stickers mode switching'
}

if ($commands -notmatch "type:\s*string\s*=\s*'getFavoriteStickers'" -or
    $serializer -notmatch "result\.method\s*=\s*'getFavoriteStickers'" -or
    $useCase -notmatch 'loadFavoriteStickers') {
  throw 'Favorites are not wired through the typed TDLib path'
}

if ($commands -notmatch "type:\s*string\s*=\s*'getPremiumStickers'" -or
    $serializer -notmatch "result\.method\s*=\s*'getPremiumStickers'" -or
    $serializer -notmatch "setNumber\('limit'" -or
    $useCase -notmatch 'loadPremiumStickers') {
  throw 'Premium stickers are not wired through the typed TDLib path'
}

foreach ($required in @('premiumItems', 'favoriteItems', 'buildGroupedStickerHome')) {
  if ($stickerPanel -notmatch [regex]::Escape($required)) {
    throw "Sticker panel grouped home is missing $required"
  }
}

if ($chatPage -notmatch 'premiumStickerItems' -or
    $chatPage -notmatch 'favoriteStickerItems' -or
    $chatPage -notmatch 'loadPremiumStickerHomeIfNeeded') {
  throw 'Chat page does not load Premium/Favorites grouped sticker content'
}

if ($useCase -notmatch 'requestStickerFileDownload' -or
    $useCase -notmatch 'createDownloadFileCommand\(fileId, priority, false\)' -or
    $useCase -notmatch "getTopLevelNumber\('id'\)" -or
    $chatPage -notmatch 'refreshGroupedStickerHomePreviews' -or
    $chatPage -notmatch 'files\.transfers') {
  throw 'Grouped sticker previews must use bounded update-driven downloads'
}

if ($chatPage -match "new StickerSetTabVO\('gifs'") {
  throw 'GIF must not remain inside the sticker-pack strip'
}

Write-Host 'Entity keyboard production parity contract: PASS' -ForegroundColor Green
