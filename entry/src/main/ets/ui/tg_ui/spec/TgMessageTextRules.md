# TgMessageTextRules (Phase C / Step 0)

## Goal
Define **Telegram-like text rendering contract** for message bubbles on HarmonyOS (ArkUI ArkTS API 22).
This spec is the **source of truth** for typography, wrapping, and max bubble width.
No business logic; UI-only.

## iOS References (fill after mapping)
- iOS file(s):
  - `submodules/TelegramUI/Components/Chat/ChatMessageTextBubbleContentNode/Sources/ChatMessageTextBubbleContentNode.swift`
  - `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Sources/ChatMessageItemCommon.swift`
  - `submodules/TelegramPresentationData/Sources/ChatPresentationData.swift`
- Key classes/components:
  - `ChatMessageTextBubbleContentNode`
  - `InteractiveTextNode` (layout arguments used by text content node)
  - `ChatMessageItemLayoutConstants` (bubble/text insets + width fill factors)
  - `ChatPresentationData` (message font/emoji baseline)

## Scope
✅ Included
- Plain text rendering inside message bubble
- Typography tokens (size/weight/lineHeight)
- Wrapping rules (soft wrap, long words)
- Inline styling rules (links/mentions/hashtags — style only)
- Emoji-only sizing rules (basic)
- Newline handling (`\n`)
- Max bubble width constraint

❌ Excluded (later)
- Rich entities parsing/rendering (actual clickable spans)
- Media messages
- Reply/forward headers
- Message selection/copy
- Markdown parsing

## Inputs
- text: string
- kind: "plain" | "link" | "mention" | "hashtag" (demo uses manual styling)
- isOutgoing: boolean (affects colors only)
- isEmojiOnly: boolean (demo uses heuristic or explicit flag)

## Tokens (must exist / be used)
### Typography
- MSG_TEXT_SIZE
- MSG_TEXT_WEIGHT
- MSG_TEXT_LINE_HEIGHT
- MSG_TEXT_LETTER_SPACING (optional)
- MSG_EMOJI_ONLY_SIZE (1–3 emoji)
- MSG_META_SIZE (reserved for later)

### Colors
- MSG_TEXT_INCOMING
- MSG_TEXT_OUTGOING
- MSG_LINK_INCOMING
- MSG_LINK_OUTGOING

### Layout
- BUBBLE_MAX_WIDTH_RATIO (0.80 in current token baseline)
- BUBBLE_PADDING_H
- BUBBLE_PADDING_V
- TEXT_MAX_LINES (optional; current baseline = unlimited)

## Layout Rules (contract)
1) Bubble content width = min(screenWidth * BUBBLE_MAX_WIDTH_RATIO, intrinsicTextWidth + padding)
2) Text wraps by words (soft wrap). No clipping.
3) Long unbroken tokens (very long URL/word):
   - Must wrap (or break) without overflowing bubble bounds.
   - Preferred: `WordBreak.BREAK_WORD`, fallback `WordBreak.BREAK_ALL` in torture cases.
4) Newlines `\n`:
   - Preserved as hard line breaks.
5) Emoji-only:
   - 1–3 emoji: use MSG_EMOJI_ONLY_SIZE, centered baseline within bubble padding.
   - Mixed emoji+text uses normal MSG_TEXT_*.
6) Outgoing vs incoming:
   - Only affects text/link colors in this step.

## Acceptance Checklist (must pass)
- [ ] Visual: lineHeight matches “Telegram feel” (not cramped, not too airy)
- [ ] Long text wraps correctly to multiple lines
- [ ] Very long word/URL does not overflow bubble width
- [ ] Newline handling produces expected multi-line layout
- [ ] Emoji-only 1–3 renders larger and doesn’t look vertically misaligned
- [ ] All sizes/colors come from tokens (no magic numbers)

## Demo Requirements (TgMessageTextRulesDemo.ets)
Must render a matrix of cases:
1) Incoming: short 1-line
2) Incoming: long 4–6 lines (paragraph)
3) Outgoing: long 4–6 lines
4) Incoming: long URL / long unbroken word (wrap torture)
5) Incoming: text with `\n\n` (multiple paragraphs)
6) Outgoing: emoji-only (1 emoji)
7) Outgoing: emoji-only (3 emoji)
8) Incoming: “link style” (manually styled substring)
9) Narrow layout (simulate small width container)
10) Wide layout (simulate tablet/large width container)

Include a “side-by-side” block: same text rendered with different width constraints.

## Notes / Known Risks
- ArkUI Text wrapping behavior for long unbroken strings may require `wordBreak` tuning (`BREAK_WORD` vs `BREAK_ALL`).
- If measured lineHeight differs across devices/fonts, adjust `MSG_TEXT_LINE_HEIGHT` token first.
- Context7 refs used for ArkUI text behavior:
  - `ts-basic-components-text-V13` (`wordBreak`, `maxLines`, `textOverflow`)
  - `ts-universal-styled-string-V13` (line-height controls)
