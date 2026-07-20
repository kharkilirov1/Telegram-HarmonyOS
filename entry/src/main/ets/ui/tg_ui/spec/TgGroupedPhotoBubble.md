# TgGroupedPhotoBubble — component passport

## Purpose

Render one Telegram grouped-photo message for a `media_album_id` cluster. The atom owns calculated
media geometry and per-cell interaction only; timeline grouping, TDLib transfer state and gallery
navigation remain page/controller responsibilities.

## References

### Shipped visual truth

- Current Telegram iOS runtime captures supplied by the user remain the visual acceptance source.

### Telegram iOS source

- `C:\Refs\Telegram\Telegram-iOS-current\submodules\MosaicLayout\Sources\ChatMessageBubbleMosaicLayout.swift`
  - aspect classification, special 2/3/4 compositions, generic 5–10 row optimizer and edge flags.
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\Chat\ChatMessageBubbleItemNode\Sources\ChatMessageBubbleItemNode.swift`
  - grouped-media integration and outer bubble composition.
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\Chat\ChatMessageItemCommon\Sources\ChatMessageItemCommon.swift`
  - compact/regular media bubble radii and size limits.
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\Chat\ChatMessageMediaBubbleContentNode\Sources\ChatMessageMediaBubbleContentNode.swift`
  - grouped-media content wiring and media-resource actions.
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\Chat\ChatMessageInteractiveMediaNode\Sources\ChatMessageInteractiveMediaNode.swift`
  - cell-local resource status, progress, cancel/retry and gallery transition snapshots.

### Telegram Android fallback

- `C:\Refs\Telegram\telegram-android\TMessagesProj\src\main\java\org\telegram\ui\Cells\GroupMedia.java`
  - grouped-media sizing and edge-position corroboration.

### HarmonyOS platform

- ArkUI custom-layout documentation confirms calculated child measurement/placement via
  `onMeasureSize`/`onPlaceChildren`; this atom keeps the algorithm pure and renders its frames in a
  positioned `Stack`, avoiding state mutation during layout.
- ArkUI touch events bubble by default; transfer controls stay sibling hit targets rather than a
  child of the media surface click target.

## Inputs

- Visual: `photoPaths`, `photoMinithumbs`, `photoWidths`, `photoHeights`.
- Transfer: `photoFileIds`, `photoHasLocal`, `photoDownloading`,
  `photoDownloadFailed`, `photoDownloadProgress`.
- Lane: `isOutgoing`, `containerWidth`, `maxWidthRatio`, `noBubbleWrap`.
- Events: `onPhotoTap(albumIndex)`, `onDownloadToggle(albumIndex)`.

All per-cell arrays are index-aligned with `ChatMessageRowVO.sourceMessageIds`. A non-empty
`photoPaths[index]` can be a thumbnail fallback and does not imply `photoHasLocal[index]`.

## State matrix

1. 2, 3 and 4 items with mixed portrait/square/landscape ratios.
2. Generic 5–10 item albums; all Telegram album members remain visible.
3. Local full media.
4. Thumbnail/minithumb-only remote media with download control.
5. Determinate/indeterminate download with cell-local cancel control.
6. Failed transfer with cell-local retry control.
7. Narrow message lane and missing/invalid source dimensions.
8. Defensive malformed `>10` input: render the Telegram maximum ten and show `+N` on the last cell.

## Layout contract

1. `TgPhotoAlbumLayout` is a pure deterministic geometry function.
2. The active width comes from `TgUiTokens.resolveBubbleMaxWidth` and
   `resolvePhotoAlbumMaxWidth`; spacing/radius/max height come from album tokens.
3. iOS special compositions are used for 2/3/4 when their aspect classes permit it.
4. 5–10 items use the iOS-style row partition optimizer; geometry is driven by aspect ratios, not
   only by count.
5. Edge flags map only exterior corners to `PHOTO_ALBUM_RADIUS`; internal edges remain square and
   separated by the iOS `1.0 pt` seam. On HarmonyOS, `PHOTO_ALBUM_GAP` must resolve to the same
   `1 vp` logical gap; a `2 vp` seam is not parity.
6. The outer container clips the whole mosaic so rounding is stable during image replacement.
7. The iOS compact baseline uses `300 x 380 pt` maximum media bounds, `15 pt` outer radius and
   `7 pt` merged radius; regular width uses `440 x 440 pt`, `16 pt` outer, `8 pt` merged and `5 pt`
   content-merged radii. Tokens may scale by device class, but the relationships remain intact.
8. Layout classification follows iOS: wide aspect `> 1.2`, narrow `< 0.8`, square otherwise;
   generic optimization is used for aspect `> 2.0` or group count `>= 5`.

## Interaction contract

- A surface tap opens the gallery only when that exact photo has a local full resource.
- A remote or paused photo tap requests only that cell's exact `fileId` and stays in chat; the
  gallery must not open from a thumbnail/minithumb while the full photo is unavailable.
- A fetching photo tap/control cancels only that cell. A failed or paused cell returns to the same
  retryable idle affordance and a retry must not alter sibling progress.
- Page wiring resolves `sourceMessageIds[index]` and passes it to the existing
  `handleMediaGalleryOpen`, which computes the exact gallery index.
- Gallery and shared-element identity use the real album member message ID plus semantic media
  identity, never the visual child index alone. Each cell publishes its own transition endpoint;
  only the active cell hides/reappears while the rest of the mosaic stays in place. Missing member
  IDs use the same deterministic `primary_album_index` fallback on both source and gallery sides.
- Every cell owns an independent transfer subscription/state. Progress, cancel, failure and retry
  may update only the matching `(fileId, album member)`.

## Tokens

- `PHOTO_ALBUM_RADIUS`, `PHOTO_ALBUM_GAP`.
- `PHOTO_ALBUM_MAX_WIDTH[_REGULAR]`, `PHOTO_ALBUM_MAX_HEIGHT[_REGULAR]`.
- Existing media progress/cancel/download tokens from `TgPhotoBubble`.

## Demo

`entry/src/main/ets/ui/tg_ui/demos/TgGroupedPhotoBubbleDemo.ets` covers mixed 2/3/4/5/10 layouts,
determinate per-cell progress, failure/retry and a narrow lane.

## Acceptance

- [x] One collapsed album row renders one grouped unit.
- [x] Layout responds to actual dimensions.
- [x] Every item is visible for valid 2–10 Telegram albums.
- [x] Per-cell local/downloading/failed/progress state reaches the atom.
- [x] Tap resolves the exact album member index/message ID.
- [x] Pure layout tests cover 2–10, mixed ratios, invalid dimensions and narrow width.
- [x] API23 light runtime: one six-member row opened `42 / 51`, `45 / 51`, `47 / 51` from indices
  `0 / 3 / 5`.
- [x] Fresh API23 runtime: request/active progress remained isolated to one cell while a sibling
  remote cell kept its idle download affordance (`final-acceptance-v2/11-transfer-120.jpeg`).
- [ ] Fresh runtime: cancel/retry remains isolated to one cell on sufficiently slow uncached media.
- [x] iOS parity: a remote/paused photo requests download without opening the gallery; only a local
  full photo opens.
- [x] Visual parity: runtime cell bounds resolve internal album seams to `1 vp` on HarmonyOS.
- [x] Fresh runtime motion: only the tapped cell expands and returns to its own frame
  (`final-acceptance-v2/17-open-mid.jpeg`, `19-close-mid.jpeg`).
