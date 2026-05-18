# TgMediaBubbleShellV2

## Goal
Parallel rebuild path for the **visual media family shell**:
- sender line
- reply snippet slot
- visual media slot
- caption/meta rules
- grouped bubble corners

This atom intentionally excludes:
- avatar lane
- instant video (`videoNote`)
- audio / voice / document rows
- chat-screen business state

## iOS References
- `submodules/TelegramUI/Components/Chat/ChatMessageMediaBubbleContentNode/Sources/ChatMessageMediaBubbleContentNode.swift`
  - media content sizing
  - visual media content mode and playback/download behavior
- `submodules/TelegramUI/Components/Chat/ChatMessageBubbleItemNode/Sources/ChatMessageBubbleItemNode.swift`
  - sender/reply/media stacking inside the bubble item
  - caption with inline date/status vs no-caption overlay date/status
- `submodules/TelegramUI/Components/Chat/ChatMessageReplyInfoNode/Sources/ChatMessageReplyInfoNode.swift`
  - reply block geometry / thumbnail / quote mode

## Inputs
- `mediaKind: string` — `photo | photoAlbum | video | animation`
- `messageId: string`
- `isOutgoing: boolean`
- `containerWidth: number`
- `groupingFlags: string`
- `caption: string`

### Photo / Album
- `photoPath`
- `photoFileId`
- `hasLocalPhoto`
- `isPhotoDownloading`
- `photoDownloadProgress`
- `photoWidth`
- `photoHeight`
- `albumPhotoPaths`
- `albumPhotoWidths`
- `albumPhotoHeights`

### Video / Animation
- `videoThumbPath`
- `videoPath`
- `videoFileId`
- `isShortVideo`
- `isVideoDownloading`
- `videoDownloadProgress`
- `videoDuration`
- `videoWidth`
- `videoHeight`

### Sender
- `showSenderName`
- `senderName`
- `senderColorHex`

### Reply
- `showReplySnippet`
- `replyAuthor`
- `replyPreview`
- `replyIsOutgoing`
- `replyIsQuote`
- `replyHasThumbnail`
- `replyThumbnailSrc`

### Meta
- `timeText`
- `sendStatus`

### Events
- `onMediaDownloadRequest(fileId)`
- `onPhotoTap()`
- `onAlbumPhotoTap(photoPath, caption)`
- `onMediaGalleryOpen(messageId)`

## Composition
- `TgPhotoBubble`
- `TgGroupedPhotoBubble`
- `TgVideoBubble`
- `TgAnimationBubble`
- `TgReplySnippet`
- `TgMessageMeta`

## Layout Contract
1. Sender + reply + visual media + optional caption live inside one shared bubble surface.
2. No caption => meta overlays on media in the lower-right corner.
3. Caption present => caption uses transparent trailing reserve and inline meta.
4. Outer shell, not the router, owns visual media bubble background and grouped corners.
5. Avatar lane remains router/integration-owned and stays outside this atom.
6. `videoNote` remains a separate message form and must not be forced into this shell.
7. `groupingFlags` follows the live text-bubble contract: `top` = connected below, `middle`/legacy `both` = connected above and below, `bottom` = connected above. Only the tail-side corners shrink to `BUBBLE_RADIUS_GROUPED`.

## Acceptance Checklist
- [ ] photo / album / video / animation share one caption/meta rule set
- [ ] no-caption visual media uses overlay meta
- [ ] caption visual media uses inline meta reserve
- [ ] sender/reply/media stack stays stable without router-specific padding hacks
- [ ] grouped visual-media corners match text-bubble grouping semantics
- [ ] atom stays presentation-only and V2-param driven

## Demo
- `entry/src/main/ets/ui/tg_ui/demos/TgMediaBubbleShellV2Demo.ets`


## 2026-03-23 narrow update
- Visual-media captions now support explicit quote ranges via `captionQuoteOffsets` / `captionQuoteLengths` / `captionQuoteCollapsedFlags`.
- When a caption contains blockquote entities, the shell routes the caption through `TgMessageTextBodyV2` instead of the plain `Text + invisible meta reserve` path.
