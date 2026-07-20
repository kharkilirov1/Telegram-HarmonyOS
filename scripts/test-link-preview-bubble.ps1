$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

$paths = @{
  dto = Join-Path $root 'entry/src/main/ets/core/model/dto/MessageDto.ets'
  state = Join-Path $root 'entry/src/main/ets/core/model/AppState.ets'
  reducer = Join-Path $root 'entry/src/main/ets/core/reducers/messagesReducer.ets'
  files = Join-Path $root 'entry/src/main/ets/core/reducers/filesReducer.ets'
  download = Join-Path $root 'entry/src/main/ets/domain/usecases/downloadMessageMedia.ets'
  timeline = Join-Path $root 'entry/src/main/ets/ui/pages/chat/ChatTimelineVO.ets'
  dataSource = Join-Path $root 'entry/src/main/ets/ui/pages/chat/ChatTimelineDataSource.ets'
  page = Join-Path $root 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets'
  router = Join-Path $root 'entry/src/main/ets/ui/tg_ui/molecules/TgMessageRouter.ets'
  bubble = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgTextBubbleV3.ets'
  preview = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgLinkPreviewBubble.ets'
  tokens = Join-Path $root 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets'
  layout = Join-Path $root 'entry/src/main/ets/ui/tg_ui/layout/TgBubbleLayout.ets'
  layoutTypes = Join-Path $root 'entry/src/main/ets/ui/tg_ui/layout/TgBubbleLayoutTypes.ets'
  spec = Join-Path $root 'entry/src/main/ets/ui/tg_ui/spec/TgLinkPreviewBubble.md'
  demo = Join-Path $root 'entry/src/main/ets/ui/tg_ui/demos/TgLinkPreviewBubbleDemo.ets'
}

foreach ($name in $paths.Keys) {
  if (-not (Test-Path -LiteralPath $paths[$name])) {
    throw "Link-preview contract file is missing: $($paths[$name])"
  }
}

$source = @{}
foreach ($name in $paths.Keys) {
  $source[$name] = Get-Content -LiteralPath $paths[$name] -Raw
}

foreach ($pattern in @(
  "tdGetObject(contentObj, 'link_preview')",
  "tdGetObject(contentObj, 'web_page')",
  'linkPreviewSiteName',
  'linkPreviewDescription',
  'linkPreviewPhotoThumbFileId',
  'linkPreviewShowLargeMedia',
  'linkPreviewShowMediaAboveDescription',
  'linkPreviewShowAboveText'
)) {
  if (-not $source.dto.Contains($pattern)) {
    throw "MessageDto link-preview parser is missing: $pattern"
  }
}

foreach ($fragment in @('LINK_PREVIEW_SMALL_MEDIA_SIZE: number = 54;',
    'LINK_PREVIEW_SMALL_MEDIA_RADIUS: number = 4;',
    'LINK_PREVIEW_MAX_SITE_LINES: number = 2;',
    'LINK_PREVIEW_MAX_TITLE_LINES: number = 5;',
    'LINK_PREVIEW_MAX_DESCRIPTION_LINES: number = 12;')) {
  if (-not $source.tokens.Contains($fragment)) {
    throw "Link-preview tokens drifted from the iOS source hierarchy: $fragment"
  }
}

foreach ($name in @('state', 'reducer', 'timeline', 'page', 'router', 'bubble')) {
  if (-not $source[$name].Contains('linkPreviewSiteName')) {
    throw "$name does not carry link-preview data to the rendered bubble"
  }
}

if (-not $source.dataSource.Contains('prev.linkPreviewPhotoPath === next.linkPreviewPhotoPath')) {
  throw 'ChatTimelineDataSource must invalidate a recycled row when the preview poster resolves.'
}

foreach ($pattern in @('minimumContentWidth', 'forceSeparateMeta')) {
  if (-not $source.layout.Contains($pattern) -or -not $source.layoutTypes.Contains($pattern) -or
      -not $source.router.Contains($pattern)) {
    throw "Text layout does not protect link-preview width/meta placement: $pattern"
  }
}

foreach ($pattern in @('linkPreviewPhotoFileId', 'linkPreviewPhotoThumbFileId',
    'linkPreviewPhotoUniqueId', 'linkPreviewPhotoThumbUniqueId')) {
  if (-not $source.files.Contains($pattern)) {
    throw "Files reducer does not preserve/resolve link-preview media: $pattern"
  }
}

if (-not $source.download.Contains('content.linkPreviewPhotoThumbFileId')) {
  throw 'Background media policy must enqueue the link-preview thumbnail, not the full preview photo.'
}

foreach ($pattern in @(
  'export struct TgLinkPreviewBubble',
  'ImageFit.Cover',
  'TextOverflow.Ellipsis',
  'LINK_PREVIEW_MAX_DESCRIPTION_LINES',
  'LINK_PREVIEW_SMALL_MEDIA_SIZE',
  'LINK_PREVIEW_LARGE_MEDIA_ASPECT_RATIO'
)) {
  if (-not $source.preview.Contains($pattern) -and -not $source.tokens.Contains($pattern)) {
    throw "TgLinkPreviewBubble contract is missing: $pattern"
  }
}

if (-not $source.bubble.Contains('TgLinkPreviewBubble({')) {
  throw 'TgTextBubbleV3 must compose the link-preview atom inside the text bubble.'
}

foreach ($pattern in @(
  'ChatMessageWebpageBubbleContentNode.swift',
  'ChatMessageAttachedContentNode.swift',
  'link_preview',
  'ImageFit.Cover',
  'TextOverflow.Ellipsis'
)) {
  if (-not $source.spec.Contains($pattern)) {
    throw "Link-preview passport is missing reference/API evidence: $pattern"
  }
}

foreach ($pattern in @('small trailing media', 'large media', 'text-only', 'outgoing')) {
  if (-not $source.demo.Contains($pattern)) {
    throw "Link-preview demo is missing representative state: $pattern"
  }
}

Write-Output 'Telegram link-preview bubble source contract: PASS'
