# TgComposerInput (Phase C / Step 5)

## Goal
Build Telegram-like bottom composer panel:
- attach button
- rounded input field with placeholder/text
- emoji button
- mic/send action button
- optional reply snippet block on top

UI-only scope for this step. No message send logic, no keyboard controller integration, no media picker actions.

## iOS References
- `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift`
  - text input panel visual composition and spacing
  - min/max input height behavior and action buttons
- `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelComponent.swift`
  - panel composition integration contract
- `submodules/TelegramUI/Components/Chat/ChatInputPanelNode/Sources/ChatInputPanelNode.swift`
  - base panel lifecycle/structure
- `submodules/TelegramUI/Components/Chat/ChatMessageReplyInfoNode/Sources/ChatMessageReplyInfoNode.swift`
  - reply snippet header style used above composer input

## Props / Inputs
- `text: string`
- `placeholder: string`
- `isFocused: boolean` (visual state only in this step)
- `isDisabled: boolean`
- `showAttachButton: boolean`
- `showEmojiButton: boolean`
- `canSend: boolean` (switch mic/send icon)
- `showReplySnippet: boolean`
- `replyAuthor: string`
- `replyPreview: string`
- `replyIsOutgoing: boolean`
- `replyIsQuote: boolean`
- `replyHasThumbnail: boolean`
- `containerWidth: number`

## State Matrix (demo)
- empty idle (mic)
- empty focused
- short text (send)
- long text (send)
- multiline text
- with reply snippet
- no attach button
- no emoji button
- disabled
- narrow/wide container

## Layout Rules
1) Panel has top separator and tokenized container paddings.
2) Main row composition:
   - optional attach button
   - rounded input capsule with text/placeholder + optional emoji button
   - action button (mic or send)
3) Input capsule keeps min/max height token limits for stability.
4) Reply snippet is optional and rendered above main input row with tokenized gap.
5) All colors/sizes/weights/radii are tokenized.

## Token Mapping
- Colors:
  - `COMPOSER_BG`
  - `COMPOSER_TOP_SEPARATOR`
  - `COMPOSER_INPUT_BG`
  - `COMPOSER_TEXT`
  - `COMPOSER_PLACEHOLDER`
  - `COMPOSER_ACTION_ACTIVE`
  - `COMPOSER_ACTION_INACTIVE`
- Geometry:
  - `COMPOSER_MIN_HEIGHT`
  - `COMPOSER_MAX_HEIGHT`
  - `COMPOSER_SIDE_INSET`
  - `COMPOSER_VERTICAL_INSET`
  - `COMPOSER_ROW_GAP`
  - `COMPOSER_INPUT_RADIUS`
  - `COMPOSER_INPUT_PADDING_H/V`
  - `COMPOSER_BUTTON_SIZE`
  - `COMPOSER_ICON_SIZE`
  - `COMPOSER_REPLY_GAP`
- Typography:
  - `COMPOSER_TEXT_SIZE/WEIGHT/LINE_HEIGHT`
  - `COMPOSER_MAX_LINES`
- Icons:
  - `ICON_RES_ATTACH`
  - `ICON_RES_SEND`
  - `ICON_RES_MIC`
  - `ICON_RES_EMOJI`

## Acceptance Checklist
- [ ] Mic/send state switch is stable and centered
- [ ] Input capsule keeps stable geometry on empty/long/multiline text
- [ ] Placeholder/text typography stays telegram-like and tokenized
- [ ] Reply snippet integration does not break panel alignment
- [ ] Narrow/wide container behavior is stable
- [ ] Tokens-only implementation (no magic visual numbers)

## Demo Requirements (`TgComposerInputDemo.ets`)
At least 10 states:
1) empty idle
2) empty focused
3) short text send
4) long text send
5) multiline text
6) with reply snippet
7) no attach
8) no emoji
9) disabled
10) narrow/wide container

## Known Risks
- Real keyboard avoid mode and caret behavior are integration concerns (screen-level).
- Final icon/background alpha may be tuned after binding to live chat page wallpaper.
