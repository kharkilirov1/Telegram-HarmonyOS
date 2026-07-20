Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$layout = Join-Path $root 'entry/src/main/ets/ui/tg_ui/layout/TgPhotoAlbumLayout.ets'
$tokens = Join-Path $root 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets'
$policy = Join-Path $root 'entry/src/main/ets/ui/tg_ui/utils/TgMediaGalleryPolicy.ets'
$identity = Join-Path $root 'entry/src/main/ets/ui/tg_ui/utils/TgMediaGeometryTransition.ets'
$bubble = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgGroupedPhotoBubble.ets'
$shell = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgMediaBubbleShellV2.ets'
$router = Join-Path $root 'entry/src/main/ets/ui/tg_ui/molecules/TgMessageRouter.ets'
$timeline = Join-Path $root 'entry/src/main/ets/ui/pages/chat/ChatTimelineVO.ets'
$page = Join-Path $root 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets'
$unitTest = Join-Path $root 'entry/src/ohosTest/ets/test/TgPhotoAlbumLayout.test.ets'
$testRegistry = Join-Path $root 'entry/src/ohosTest/ets/test/List.test.ets'
$passport = Join-Path $root 'entry/src/main/ets/ui/tg_ui/spec/TgGroupedPhotoBubble.md'

foreach ($path in @($layout, $tokens, $policy, $identity, $bubble, $shell, $router, $timeline, $page, $unitTest, $testRegistry, $passport)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Grouped-photo album contract file is missing: $path"
  }
}

$contracts = @(
  @{ Path = $layout; Pattern = 'export function computeTgPhotoAlbumLayout'; Label = 'pure album layout API' },
  @{ Path = $layout; Pattern = 'TELEGRAM_ALBUM_MAX_ITEMS = 10'; Label = 'Telegram album limit' },
  @{ Path = $tokens; Pattern = 'PHOTO_ALBUM_GAP: number = 1;'; Label = 'iOS one-point mosaic seam' },
  @{ Path = $policy; Pattern = 'export function resolvePhotoAlbumTapMode'; Label = 'local-before-open photo tap policy' },
  @{ Path = $identity; Pattern = 'export function albumMediaSourceId'; Label = 'stable per-member transition identity' },
  @{ Path = $bubble; Pattern = 'ForEach(this.albumLayout().frames'; Label = 'calculated frame rendering' },
  @{ Path = $bubble; Pattern = '@Param photoMessageIds: string[]'; Label = 'per-cell source-message identity' },
  @{ Path = $bubble; Pattern = '@Param hiddenPhotoMessageId: string'; Label = 'per-cell transition hiding' },
  @{ Path = $bubble; Pattern = '.geometryTransition(mediaGeometryTransitionId(this.cellMessageId(frame.index)))'; Label = 'per-cell shared-element endpoint' },
  @{ Path = $bubble; Pattern = '@Param photoFileIds: number[]'; Label = 'per-cell file identity' },
  @{ Path = $bubble; Pattern = '@Param photoDownloadProgress: number[]'; Label = 'per-cell progress' },
  @{ Path = $bubble; Pattern = '@Event onPhotoTap: (albumIndex: number)'; Label = 'exact tapped index event' },
  @{ Path = $bubble; Pattern = "if (mode === 'download')"; Label = 'remote member downloads before gallery open' },
  @{ Path = $bubble; Pattern = 'this.onPhotoTap(index);'; Label = 'surface tap routing' },
  @{ Path = $shell; Pattern = '@Event onMediaDownloadCancel: (fileId: number)'; Label = 'live shell cancel routing' },
  @{ Path = $shell; Pattern = 'photoMessageIds: this.albumPhotoMessageIds'; Label = 'member identities reach the atom' },
  @{ Path = $shell; Pattern = "if (this.mediaKind === 'photoAlbum')"; Label = 'album bypasses the outer shared-element host' },
  @{ Path = $shell; Pattern = 'this.handleAlbumDownloadToggle(albumIndex);'; Label = 'cell-local shell transfer action' },
  @{ Path = $router; Pattern = '@Param albumPhotoDownloadFailed: boolean[]'; Label = 'failure state bridge' },
  @{ Path = $router; Pattern = '@Param albumPhotoMessageIds: string[]'; Label = 'member identity bridge' },
  @{ Path = $router; Pattern = 'albumPhotoFileIds: this.albumPhotoFileIds'; Label = 'router to live shell file bridge' },
  @{ Path = $router; Pattern = 'hiddenMediaMessageId: this.hiddenMediaMessageId'; Label = 'active member hiding bridge' },
  @{ Path = $page; Pattern = 'private effectiveAlbumPhotoDownloading'; Label = 'controller pending-state projection' },
  @{ Path = $page; Pattern = 'private effectiveAlbumPhotoDownloadFailed'; Label = 'controller failure-state projection' },
  @{ Path = $page; Pattern = 'albumMediaSourceId('; Label = 'exact source-message gallery target' },
  @{ Path = $page; Pattern = 'albumPhotoMessageIds: entry.message.sourceMessageIds'; Label = 'page to router member identities' },
  @{ Path = $page; Pattern = 'albumItem.messageId = albumMediaSourceId('; Label = 'stable member gallery identity' },
  @{ Path = $timeline; Pattern = 'let albumStateStamp = 0;'; Label = 'album render-key state fingerprint' },
  @{ Path = $unitTest; Pattern = 'for (let count = 2; count <= 10; count++)'; Label = '2-10 layout coverage' },
  @{ Path = $testRegistry; Pattern = "import tgPhotoAlbumLayoutTest from './TgPhotoAlbumLayout.test';"; Label = 'layout test registration' },
  @{ Path = $testRegistry; Pattern = 'tgPhotoAlbumLayoutTest();'; Label = 'layout test execution' },
  @{ Path = $passport; Pattern = 'onPhotoTap(albumIndex)'; Label = 'typed passport interaction contract' }
)

foreach ($contract in $contracts) {
  if (-not (Select-String -LiteralPath $contract.Path -SimpleMatch $contract.Pattern -Quiet)) {
    throw "Missing $($contract.Label): $($contract.Pattern)"
  }
}

if (Select-String -LiteralPath $bubble -SimpleMatch 'Math.min(4, this.photoPaths.length)' -Quiet) {
  throw 'Grouped-photo bubble must not clip valid Telegram albums to four cells.'
}

if (Select-String -LiteralPath $page -SimpleMatch 'onAlbumPhotoTap: (photoPath: string, caption: string)' -Quiet) {
  throw 'Album tap must not discard the cell index and reopen the primary item.'
}

Write-Output 'Grouped-photo album layout, transfer and exact-tap contract: PASS'
