Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$chatPage = Join-Path $root 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets'
$router = Join-Path $root 'entry/src/main/ets/ui/tg_ui/molecules/TgMessageRouter.ets'
$mediaShell = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgMediaBubbleShellV2.ets'
$groupedPhoto = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgGroupedPhotoBubble.ets'
$gallery = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgMediaGalleryPage.ets'
$tokens = Join-Path $root 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets'
$galleryState = Join-Path $root 'entry/src/main/ets/ui/pages/chat/MediaGalleryState.ets'
$galleryPolicy = Join-Path $root 'entry/src/main/ets/ui/tg_ui/utils/TgMediaGalleryPolicy.ets'
$itemModel = Join-Path $root 'entry/src/main/ets/models/MediaGalleryItem.ets'
$identity = Join-Path $root 'entry/src/main/ets/ui/tg_ui/utils/TgMediaGeometryTransition.ets'
$passport = Join-Path $root 'entry/src/main/ets/ui/tg_ui/spec/TgMediaGalleryPage.md'

foreach ($path in @($chatPage, $router, $mediaShell, $groupedPhoto, $gallery, $tokens, $galleryState, $galleryPolicy, $itemModel, $identity, $passport)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Media geometry-transition contract file is missing: $path"
  }
}

$contracts = @(
  @{ Path = $identity; Pattern = 'export function mediaGeometryTransitionId'; Label = 'stable shared-element identity' },
  @{ Path = $identity; Pattern = 'export function albumMediaSourceId'; Label = 'stable album-member identity' },
  @{ Path = $itemModel; Pattern = 'sourceMessageId: string'; Label = 'gallery source-message identity' },
  @{ Path = $router; Pattern = '@Param hiddenMediaMessageId: string'; Label = 'temporary source-media hiding contract' },
  @{ Path = $router; Pattern = 'hideMediaForTransition: this.hiddenMediaMessageId === this.messageId'; Label = 'media-only source hiding integration' },
  @{ Path = $mediaShell; Pattern = '.geometryTransition(mediaGeometryTransitionId(this.messageId))'; Label = 'media-surface source geometry transition' },
  @{ Path = $mediaShell; Pattern = "if (this.mediaKind === 'photoAlbum')"; Label = 'album outer-host bypass' },
  @{ Path = $mediaShell; Pattern = 'private buildTransitionedMediaNode()'; Label = 'media-surface transition ownership' },
  @{ Path = $groupedPhoto; Pattern = '.geometryTransition(mediaGeometryTransitionId(this.cellMessageId(frame.index)))'; Label = 'album cell source geometry transition' },
  @{ Path = $groupedPhoto; Pattern = 'hiddenPhotoMessageId'; Label = 'exact album-cell source hiding' },
  @{ Path = $gallery; Pattern = '.geometryTransition(mediaGeometryTransitionId(item.sourceMessageId))'; Label = 'fullscreen destination geometry transition' },
  @{ Path = $gallery; Pattern = "@Monitor('mediaItems', 'initialIndex', 'downloadStateVersion')"; Label = 'async transfer-state refresh contract' },
  @{ Path = $tokens; Pattern = 'MEDIA_GALLERY_DOWNLOAD_BUTTON_SIZE: number = 50;'; Label = 'iOS radial control size' },
  @{ Path = $galleryState; Pattern = "sourceMessageId: string = '0';"; Label = 'refreshed active source identity' },
  @{ Path = $galleryPolicy; Pattern = 'export function resolveGalleryTransferActive'; Label = 'failure releases optimistic gallery transfer' },
  @{ Path = $chatPage; Pattern = 'private animateMediaGalleryState'; Label = 'parent-owned native transition state change' },
  @{ Path = $chatPage; Pattern = 'this.gallerySourceMessageId = result.sourceMessageId'; Label = 'current-item hidden source refresh' },
  @{ Path = $chatPage; Pattern = 'hiddenMediaMessageId: this.gallerySourceMessageId'; Label = 'active source hiding integration' },
  @{ Path = $passport; Pattern = 'setupTemporaryHiddenMedia'; Label = 'iOS hidden-media provenance' },
  @{ Path = $passport; Pattern = 'geometryTransition'; Label = 'HarmonyOS shared-element provenance' }
)

foreach ($contract in $contracts) {
  if (-not (Select-String -LiteralPath $contract.Path -SimpleMatch $contract.Pattern -Quiet)) {
    throw "Missing $($contract.Label): $($contract.Pattern)"
  }
}

if (Select-String -LiteralPath $chatPage -SimpleMatch 'this.showMediaGallery = true;' -Quiet) {
  throw 'Gallery open must mutate visibility only inside animateMediaGalleryState().'
}

if (Select-String -LiteralPath $router -SimpleMatch '.geometryTransition(mediaGeometryTransitionId(this.messageId))' -Quiet) {
  throw 'The shared-element host must be the media surface, not the full captioned bubble shell.'
}

Write-Output 'Media bubble to fullscreen geometry-transition source contract: PASS'
