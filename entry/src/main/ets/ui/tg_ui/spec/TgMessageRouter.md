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
| `text` | TgMessageBubbleBase | Default fallback |
| `photo` | TgPhotoBubble | With optional caption |
| `video` | TgVideoBubble | Thumbnail + play overlay + duration |
| `document` | TgDocumentRow | File icon + name + size |
| `voice` | TgVoiceBubble | Waveform + play/pause + duration |
| `sticker` | TgStickerView | No bubble background |
| `animation` | TgVideoBubble | Treated as video (GIF preview) |
| `videoNote` | TgVideoBubble | Routed as square video placeholder until dedicated round atom |
| `audio` | TgDocumentRow | Treated as document (audio atom not yet available) |
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

### Photo
- `photoPath: string`
- `photoWidth: number`
- `photoHeight: number`
- `caption: string`

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

## Acceptance checklist

- [ ] All 5 media atoms render when given correct contentType
- [ ] Unknown/unsupported types fall back to text bubble
- [ ] `animation` routes to TgVideoBubble
- [ ] `audio` routes to TgDocumentRow
- [ ] `caption` is passed to photo and video bubbles
- [ ] Sticker renders without bubble background
- [ ] No new tokens required (delegates to existing atoms)
