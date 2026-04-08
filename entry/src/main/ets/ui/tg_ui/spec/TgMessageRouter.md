# TgMessageRouter — Component Passport

> Phase: C.1-6
> Type: molecule (routing, no visual output of its own)
> Status: DONE

## Purpose

Routes a message to the correct bubble atom based on `contentType`.
Drop-in replacement for direct `TgMessageBubbleBase` usage in chat timeline.

## Routing table

| contentType | Atom | Notes |
|-------------|------|-------|
| `text` | TgTextBubbleV3 | Engine-driven text-family live path |
| `photo` | TgMediaBubbleShellV2 | Visual media shell (sender/reply/media/caption/meta) |
| `photoAlbum` | TgMediaBubbleShellV2 | Visual media shell for grouped photos |
| `video` | TgMediaBubbleShellV2 | Visual media shell + existing video atom |
| `document` | TgDocumentRow | File icon + name + size |
| `voice` | TgVoiceBubble | Waveform + play/pause + duration |
| `sticker` | TgStickerView | No bubble background |
| `animation` | TgMediaBubbleShellV2 | Visual media shell + GIF atom |
| `videoNote` | TgInstantVideoBubble | Dedicated round instant-video path |
| `audio` | TgAudioBubble | Music/file-audio path with seek/progress |
| all others | TgMessageBubbleBase | Text fallback with `[Type]` label |

## Props

### Routing
- `contentType: string` — MessageContentType value

### Common (passed to all atoms)
- `isOutgoing: boolean`
- `containerWidth: number`

### Text
- `text: string` — message text or fallback label
- `isEmojiOnly: boolean`
- `forceBreakAll: boolean`
- text-family composition now routes through `TgTextBubbleV3` in the live text branch
- visual media family composition now routes through `TgMediaBubbleShellV2` for `photo` / `photoAlbum` / `video` / `animation`

### Photo / album
- `photoPath: string`
- `photoWidth: number`
- `photoHeight: number`
- `caption: string`
- `albumPhotoPaths: string[]`
- `albumPhotoWidths: number[]`
- `albumPhotoHeights: number[]`

### Video / Animation
- `videoThumbPath: string`
- `videoPath: string`
- `videoDuration: number`
- `videoWidth: number`
- `videoHeight: number`

### Document / Audio
- `fileName: string`
- `fileSize: number`
- `mimeType: string`

### Voice
- `voiceDuration: number`
- `voiceWaveform: string`
- `isVoiceListened: boolean`

### Sticker
- `stickerPath: string`
- `stickerWidth: number`
- `stickerHeight: number`
- `isAnimatedSticker: boolean`
- `isVideoSticker: boolean`

### Reply snippet
- `showReplySnippet: boolean`
- `replyAuthor: string`
- `replyPreview: string`
- `replyIsOutgoing: boolean`
- `replyIsQuote: boolean`
- `replyHasThumbnail: boolean`
- `replyThumbnailSrc: Resource | string`

## Acceptance checklist

- [ ] Visual media family shares one shell contract for sender/reply/caption/meta
- [ ] Unknown/unsupported types fall back to text bubble
- [ ] `videoNote` stays on the dedicated round atom path
- [ ] `audio` routes to TgAudioBubble
- [ ] caption/no-caption rules are owned by the media shell instead of the router
- [ ] Reply snippets preserve media-aware preview labels and thumbnails when available
- [ ] Sticker renders without bubble background
- [ ] Router remains orchestration-only for text + visual-media families
- [ ] Shrink-wrapped bubble variants keep time/status anchored via explicit trailing alignment, not generic `width('100%')` footer rows


## 2026-04-05 updates
- Live `text` path now routes through `TgTextBubbleV3` with precomputed engine layout and explicit quote ranges (`quoteOffsets` / `quoteLengths` / `quoteCollapsedFlags`).
- Non-text shrink-wrapped bubble variants (`sticker`, `contact`, `location`, `poll`, `document`) should right-anchor their footer meta via `alignSelf(ItemAlign.End)` instead of ambiguous `width('100%')` footer rows.
- Image-like special cases keep overlay meta tied to the surface itself:
  - `sticker` uses bottom-right overlay meta on the sticker surface
  - `location` without venue text uses bottom-right overlay meta on the map surface
