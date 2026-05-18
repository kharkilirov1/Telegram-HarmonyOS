# TgMessageTextBodyV2

- Status: `archived` — implementation/demo removed; active text/quote rendering path is `TgTextBodyV3` / `TgTextBubbleV3`.
## Goal
Render **visible blockquote segments inside text-message bubbles** without reopening the whole router or pretending that all text entities are already supported.

This atom is a narrow first step:
- keeps ordinary text rendering simple
- introduces explicit quote-block surfaces
- stays presentation-only

## iOS References
- `submodules/TelegramUI/Components/Chat/ChatMessageTextBubbleContentNode/Sources/ChatMessageTextBubbleContentNode.swift`
  - blockquote-aware text layout in chat bubbles
- `submodules/TextFormat/Sources/StringWithAppliedEntities.swift`
  - `.BlockQuote(isCollapsed)` entity mapping
- `submodules/Display/Source/TextNode.swift`
  - rendered quote background/bar treatment

## Harmony Grounding
- ArkUI `Text` can contain `Span` children and is the standard text-display primitive
- for this narrow pass we use `Text` + regular layout containers rather than a full StyledString pipeline

## Inputs
- `text: string`
- `isOutgoing: boolean`
- `forceBreakAll: boolean`
- `quoteAccentHex: string`
- `metaReserveText: string`
- `quoteOffsets: number[]`
- `quoteLengths: number[]`
- `quoteCollapsedFlags: boolean[]`

## Layout Contract
1. Plain text segments render with normal message text tokens.
2. Quote segments render as distinct blocks with:
   - left accent bar
   - tinted background
   - compact inner paddings closer to Telegram iOS text-node treatment
3. When `quoteAccentHex` is provided, the quote bar/tint should derive from that accent instead of a single hardcoded blue fallback.
4. When `metaReserveText` is provided, the final plain/quote segment should reserve inline space for time/status so the parent bubble can keep Telegram-style bottom-right meta overlay.
5. This atom does **not** own the outer bubble shell or avatar lane.
6. This pass is for **message-body quotes in text messages**; caption/entity parity is still separate work.

## Acceptance Checklist
- [ ] quote blocks are visually visible in live text bubbles
- [ ] ordinary text messages still render through the stable path
- [ ] long quoted text wraps without exploding bubble width
- [ ] atom remains presentation-only

## Demo
- Historical demo removed; use `entry/src/main/ets/ui/tg_ui/demos/TgTextBubbleV3Demo.ets` for active quote/text coverage.
