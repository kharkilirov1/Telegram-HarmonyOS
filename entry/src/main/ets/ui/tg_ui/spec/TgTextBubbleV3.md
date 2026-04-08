# TgTextBubbleV3

## Goal
Engine-driven text bubble for the live router path:
- pre-computed shrink-wrap width
- explicit inline-vs-row meta placement
- sender / reply / quote composition
- no transparent reserve-span hack in the bubble shell

## References
- iOS:
  - `submodules/TelegramUI/Components/Chat/ChatMessageTextBubbleContentNode/Sources/ChatMessageTextBubbleContentNode.swift`
  - `submodules/TelegramUI/Components/Chat/ChatMessageReplyInfoNode/Sources/ChatMessageReplyInfoNode.swift`
- HarmonyOS:
  - ArkUI `textOverflow` / `maxLines`
  - ArkUI `MeasureUtils.measureText` / `measureTextSize`

## Inputs
### Layout
- `layout: TextBubbleLayout | null`

### Content
- `text: string`
- `isOutgoing: boolean`
- `isEmojiOnly: boolean`
- `forceBreakAll: boolean`

### Sender
- `showSenderName: boolean`
- `senderName: string`
- `senderColorHex: string`

### Reply
- `showReplySnippet: boolean`
- `replyAuthor: string`
- `replyAuthorColorHex: string`
- `replyPreview: string`
- `replyIsOutgoing: boolean`
- `replyIsQuote: boolean`
- `replyHasThumbnail: boolean`
- `replyThumbnailSrc: Resource | string`

### Quote
- `quoteOffsets: number[]`
- `quoteLengths: number[]`
- `quoteCollapsedFlags: boolean[]`
- `quoteAccentHex: string`

### Meta
- `timeText: string`
- `sendStatus: TgMessageSendStatus`

### Visual
- `containerWidth: number`
- `maxWidthRatio: number`
- `groupingFlags: string`

## Contract
1. Width/height ownership lives in `TextBubbleLayout`, computed before render.
2. Bubble width must shrink-wrap to text/reply/meta content, bounded by Telegram max-width tokens.
3. Hard line breaks in message text must stay visible.
4. Failed outgoing messages must reserve meta width exactly like sent/read states.
5. Quote blocks must contribute to bubble height/width in the layout pass.
6. `metaInline=false` means a dedicated trailing meta row; `metaInline=true` means overlay in the bottom-right lane.

## Current composition
- bubble shell: `TgTextBubbleV3`
- text body: `TgTextBodyV3`
- engine facade: `TgTextLayout`
- layout math: `computeTextBubbleLayout()`

## Acceptance
- [ ] multiline `\n` text survives layout and render
- [ ] quote blocks affect total bubble height
- [ ] failed status does not clip meta
- [ ] sender + reply + text + meta stay stable in narrow width
- [ ] live router path remains build-safe

## Demo
- `entry/src/main/ets/ui/tg_ui/demos/TgTextBubbleV3Demo.ets`
