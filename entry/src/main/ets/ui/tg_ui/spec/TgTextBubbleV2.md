# TgTextBubbleV2

## Goal
Parallel rebuild path for the **text message surface** only:
- sender line
- reply snippet slot
- text body
- inline meta
- grouped bubble corners

This atom intentionally excludes:
- avatar lane
- media routing
- chat-screen business state

## iOS References
- `submodules/TelegramUI/Components/Chat/ChatMessageTextBubbleContentNode/Sources/ChatMessageTextBubbleContentNode.swift`
  - constrained text width
  - text insets
  - status/date coexistence in text bubbles
- `submodules/TelegramUI/Components/Chat/ChatMessageBubbleItemNode/Sources/ChatMessageBubbleItemNode.swift`
  - text-content placement inside bubble item
  - reply-panel placement above text content
- `submodules/TelegramUI/Components/Chat/ChatMessageReplyInfoNode/Sources/ChatMessageReplyInfoNode.swift`
  - reply block geometry / thumbnail / quote mode

## Inputs
- `text: string`
- `isOutgoing: boolean`
- `isEmojiOnly: boolean`
- `forceBreakAll: boolean`
- `quoteOffsets: number[]`
- `quoteLengths: number[]`
- `quoteCollapsedFlags: boolean[]`
- `containerWidth: number`
- `maxWidthRatio: number`
- `groupingFlags: string`

### Sender
- `showSenderName: boolean`
- `senderName: string`
- `senderColorHex: string`

### Reply
- `showReplySnippet: boolean`
- `replyAuthor: string`
- `replyPreview: string`
- `replyIsOutgoing: boolean`
- `replyIsQuote: boolean`
- `replyHasThumbnail: boolean`
- `replyThumbnailSrc: Resource | string`

### Meta
- `timeText: string`
- `sendStatus: TgMessageSendStatus`

## Layout Contract
1. Outer bubble width is constrained by `containerWidth * maxWidthRatio`.
2. Bubble alignment is start/end by `isOutgoing`.
3. Sender line, reply snippet, and text body live inside one shared bubble surface.
4. Inline meta is overlaid bottom-right using the transparent trailing reserve pattern.
5. Bubble radius changes with `groupingFlags`.
6. Avatar lane remains outside this atom and stays router/integration-owned.

## Composition
- plain-text rendering stays delegated to `TgMessageBubbleBase` in `noBubbleWrap` mode
- quote-aware body rendering is delegated to `TgMessageTextBodyV2`
- reply rendering is delegated to `TgReplySnippet`
- meta rendering is delegated to `TgMessageMeta`

## Acceptance Checklist
- [ ] incoming/outgoing text bubbles feel coherent without router-specific layout hacks
- [ ] sender + reply + text + meta stack remains stable in narrow width
- [ ] grouped-corner states render predictably
- [ ] emoji-only and long-token cases do not break bubble bounds
- [ ] atom stays presentation-only and V2-param driven

## Demo
- `entry/src/main/ets/ui/tg_ui/demos/TgTextBubbleV2Demo.ets`
