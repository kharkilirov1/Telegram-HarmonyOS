# TgMessageBubbleBase (Phase C / Step 1)

## Goal
Provide Telegram-like bubble geometry for incoming/outgoing messages on HarmonyOS.
UI-only scope for this step: background, radius, paddings, max-width, alignment.

## iOS References
- `submodules/TelegramUI/Components/Chat/ChatMessageTextBubbleContentNode/Sources/ChatMessageTextBubbleContentNode.swift`
  - text insets/top-bottom adjustments and constrained text width
  - bubble content layout entry (`asyncLayoutContent`)
- `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Sources/ChatMessageItemCommon.swift`
  - `ChatMessageItemLayoutConstants`:
    - `bubble.maximumWidthFill` (`freeMaximumFillFactor` 0.85 compact / 0.65 regular)
    - `text.bubbleInsets` baseline
- `submodules/TelegramUI/Components/Chat/ChatMessageItemView/Sources/ChatMessageItemView.swift`
  - dynamic text inset recalibration from bubble corner radius (`chatMessageItemLayoutConstants`)
- `submodules/TelegramPresentationData/Sources/ChatPresentationData.swift`
  - message base font / emoji font setup baseline

## Props
- `text: string`
- `isOutgoing: boolean`
- `isEmojiOnly: boolean`
- `kind: TgMessageTextKind` (`plain | link | mention | hashtag` style-only)
- `containerWidth: number` (for width contract in demo/integration)
- `forceBreakAll: boolean` (torture mode for long unbroken tokens)
- `maxWidthRatio: number`
- `editedText: string` (localized UI state projected from TDLib `message.edit_date` / `updateMessageEdited.edit_date`)

## State Coverage
- incoming / outgoing
- short / long multi-line
- emoji-only (1, 3)
- newline paragraphs
- long URL / long unbroken token
- narrow / wide width regimes

## Tokens (must use)
- Layout:
  - `BUBBLE_MAX_WIDTH_RATIO`
    - compact portrait: `0.85` (`freeMaximumFillFactor`)
    - regular/master-detail: `0.65`
  - `BUBBLE_PADDING_H`
  - `BUBBLE_PADDING_V`
  - `BUBBLE_RADIUS_INCOMING`
  - `BUBBLE_RADIUS_OUTGOING`
- Colors:
  - `COLOR_MSG_BUBBLE_INCOMING_BG`
  - `COLOR_MSG_BUBBLE_OUTGOING_BG`
  - `MSG_TEXT_INCOMING`
  - `MSG_TEXT_OUTGOING`
  - `MSG_LINK_INCOMING`
  - `MSG_LINK_OUTGOING`
- Typography (from Step 0):
  - `MSG_TEXT_SIZE`
  - `MSG_TEXT_WEIGHT`
  - `MSG_TEXT_LINE_HEIGHT`
  - `MSG_EMOJI_ONLY_SIZE`
  - `MSG_EMOJI_ONLY_LINE_HEIGHT`
  - `TEXT_MAX_LINES`

## Layout Rules (contract)
1) Bubble width must be constrained by `containerWidth * maxWidthRatio`.
2) Incoming bubble aligned start, outgoing bubble aligned end.
3) All paddings/radii are tokenized.
4) Text rendering respects Step 0 rules:
   - default `WordBreak.BREAK_WORD`
   - torture fallback: `WordBreak.BREAK_ALL`
   - no clipping/overflow outside bubble bounds.
5) Emoji-only mode changes font and line height only (no special hardcoded geometry).
6) Edited-state text participates in the same date/status width pass as the time and send-status icon, so narrow lanes may place the complete meta on a dedicated trailing row without clipping.

## Acceptance Checklist
- [ ] Incoming/outgoing alignment is stable
- [ ] Bubble max width respected in narrow/wide containers
- [ ] No overflow in long URL / unbroken string torture cases
- [ ] Emoji-only baseline/padding visually stable (no vertical jump)
- [ ] Tokens only (no magic visual constants in atom)

## Dark runtime color calibration

- The supplied current Telegram iOS runtime screenshot is the visual truth for the dark theme.
- Dominant solid surfaces measured from that reference are approximately `#1E2E3D` incoming and `#406D97` outgoing.
- HarmonyOS maps those values only through the qualified `dark/element/color.json` resources `chat_bubble_incoming` and `chat_bubble_outgoing`; bubble atoms and the router continue consuming semantic tokens.
- Light resources remain independent and unchanged.

## Demo Requirements (`TgMessageBubbleDemo.ets`)
Must show 10+ cases:
1) incoming short
2) outgoing short
3) incoming long paragraph
4) outgoing long paragraph
5) incoming URL torture (native wrap mode)
6) incoming URL torture (zero-width helper in demo)
7) incoming newline paragraph
8) outgoing emoji-only (1)
9) outgoing emoji-only (3)
10) narrow container mode
11) wide container mode
12) side-by-side same text different widths

## Notes / Risks
- ArkUI may render very long unbroken tokens differently across devices/fonts.
- Demo includes helper insertion (`\u200B`) for geometry stress-test only; not production parsing logic.
