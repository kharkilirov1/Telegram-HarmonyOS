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

Dark surface colors are runtime-calibrated from the supplied current iPhone reference through qualified semantic resources (`incoming #1E2E3D`, `outgoing #406D97`), not hardcoded in this atom.

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
- `editedText: string` (localized label derived from TDLib `edit_date`; empty for unedited messages)
- `sendStatus: TgMessageSendStatus`

### Visual
- `containerWidth: number`
- `maxWidthRatio: number`
- `groupingFlags: string`

## Contract
1. Width/height ownership lives in `TextBubbleLayout`, computed before render.
2. Bubble width must shrink-wrap to text/reply/meta content, bounded by Telegram max-width tokens.
   Compact portrait lanes use the iOS `0.85` maximum fill so a short final line may widen enough to keep time/status inline instead of forcing an avoidable meta row.
3. Hard line breaks in message text must stay visible.
4. Failed outgoing messages must reserve meta width exactly like sent/read states.
5. Quote blocks must contribute to bubble height/width in the layout pass.
6. `metaInline=false` means a dedicated trailing meta row; `metaInline=true` means overlay in the bottom-right lane.
7. Bubble grouping flags use `none | top | middle | bottom` (`both` is accepted only as legacy alias for `middle`): `top` shrinks the lower tail-side corner, `middle` shrinks both tail-side corners, and `bottom` shrinks the upper tail-side corner.
8. The same composed localized `editedText + timeText` string must be used for both meta measurement and rendering; never infer edit state from message text.

## Current composition
- bubble shell: `TgTextBubbleV3`
- text body: `TgTextBodyV3`
- engine facade: `TgTextLayout`
- layout math: `computeTextBubbleLayout()`

## Internal helper ownership: `TgTextBodyV3`
`TgTextBodyV3` is treated as an internal renderer owned by `TgTextBubbleV3`, not as a standalone public atom.

Reference grounding:
- iOS `ChatMessageTextBubbleContentNode.swift` owns message text entity rendering and quote-range handling inside the text bubble.
- iOS `ChatMessageReplyInfoNode.swift` handles quote-specific reply layout separately from ordinary reply snippets (`isQuote`, expanded/collapsed text lines, thumbnail cutout).
- HarmonyOS maps this to a parent-owned `TextBubbleLayout` plus a narrow body renderer with explicit width and tokenized colors.

Parent-owned helper contract:
1. `contentWidth` comes from `TextBubbleLayout` / `computeTextBubbleLayout()`; the helper must not auto-measure text or reserve meta width.
2. Quote segmentation is driven by `quoteOffsets`, `quoteLengths`, and `quoteCollapsedFlags`; invalid ranges are clamped/ignored, overlapping ranges merge, and quote blocks use tokenized bar/background/padding.
3. Rich text rendering is driven by `TextEntity[]`: bold, italic, underline, strikethrough, code/pre/preCode, and link-like entity groups are visualized by spans; unsupported entity types remain safe plain text until promoted.
4. Incoming/outgoing text, link, code, quote bar, and quote background colors come from `TgUiTokens`.
5. `metaInline` and meta reserve remain parent responsibilities in `TgTextBubbleV3`; the helper must not reintroduce the old transparent reserve-span/meta injection hack.
6. A standalone `TgTextBodyV3Demo` is not required while the helper stays non-public, but `TgTextBubbleV3Demo` must cover the helper contract. Current parent demo covers plain, multiline, outgoing failed meta, reply, visible quote, narrow URL, rich-entity, and collapsed-quote states.

## Acceptance
- [ ] multiline `\n` text survives layout and render
- [ ] quote blocks affect total bubble height
- [x] rich entity spans are represented in the parent demo
- [x] collapsed quote segments are represented in the parent demo
- [ ] failed status does not clip meta
- [ ] sender + reply + text + meta stay stable in narrow width
- [ ] live router path remains build-safe

## Demo
- `entry/src/main/ets/ui/tg_ui/demos/TgTextBubbleV3Demo.ets`
