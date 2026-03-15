# TgComposerInput (Phase C / Step 5)

## Goal
Build Telegram-like bottom composer panel:
- attach button
- unified rounded glass capsule with placeholder/text
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
- `submodules/ChatPresentationInterfaceState/Sources/ChatTextInputPanelState.swift`
  - accessory/input mode state (`keyboard` / `emoji`)
- `submodules/TelegramUI/Components/Chat/ChatMessageReplyInfoNode/Sources/ChatMessageReplyInfoNode.swift`
  - reply snippet header style used above composer input

## Props / Inputs
- `text: string`
- `placeholder: string`
- `isDisabled: boolean`
- `showAttachButton: boolean`
- `showEmojiButton: boolean`
- `showReplySnippet: boolean`
- `replyAuthor: string`
- `replyPreview: string`
- `replyIsOutgoing: boolean`
- `replyIsQuote: boolean`
- `replyHasThumbnail: boolean`
- `containerWidth: number`
- `bottomInset: number`
- callbacks:
  - `onTextChange(text)`
  - `onSendPress(text)`

## State Matrix (demo)
- empty idle (interactive)
- short text (send)
- long text (send)
- multiline text
- with reply snippet
- no attach button
- no emoji button
- disabled
- narrow container
- wide container

## Layout Rules
1) Main row is a **single unified glass capsule**:
   - optional attach button
   - inline `TextArea`
   - optional emoji button
   - action button (mic or send)
2) The input field uses ArkUI `TextContentStyle.INLINE` so stock text-box chrome does not fight the custom capsule shell.
3) The send-style Enter key uses `onSubmit(..., SubmitEvent)` + `keepEditableState()` so the keyboard can stay visible after submit.
4) Reply snippet is optional and rendered above the main input row with a tokenized gap.
5) All colors/sizes/weights/radii are tokenized in `TgUiTokens`.

## Token Mapping
- Colors:
  - `COMPOSER_CAPSULE_BG`
  - `COMPOSER_CAPSULE_FALLBACK_BG`
  - `COMPOSER_CAPSULE_BORDER`
  - `COMPOSER_TEXT`
  - `COMPOSER_PLACEHOLDER`
  - `COMPOSER_ACTION_ACTIVE`
  - `COMPOSER_ACTION_INACTIVE`
- Geometry:
  - `COMPOSER_BUTTON_SIZE`
  - `COMPOSER_ICON_SIZE`
  - `COMPOSER_MIN_CAPSULE_HEIGHT`
  - `COMPOSER_CAPSULE_RADIUS`
  - `COMPOSER_SIDE_INSET`
  - `COMPOSER_VERTICAL_INSET`
  - `COMPOSER_REPLY_GAP`
  - `COMPOSER_TEXT_PADDING_TOP/BOTTOM/LEFT/RIGHT`
  - `COMPOSER_ATTACH_LEFT_INSET`
  - `COMPOSER_BORDER_WIDTH`
- Typography:
  - `COMPOSER_TEXT_SIZE/WEIGHT`
  - `COMPOSER_MAX_LINES`
- Icons:
  - `ICON_RES_ATTACH`
  - `ICON_RES_SEND`
  - `ICON_RES_MIC`
  - `ICON_RES_EMOJI`

## Acceptance Checklist
- [ ] Mic/send state switch is stable and centered
- [ ] Input capsule keeps stable geometry on empty/long/multiline text
- [ ] Emoji lane is optional and does not collapse the send button hit target
- [ ] Placeholder/text typography stays telegram-like and tokenized
- [ ] Reply snippet integration does not break panel alignment
- [ ] Narrow/wide container behavior is stable
- [ ] Tokens-only implementation (no magic visual numbers)

## Demo Requirements (`TgComposerInputDemo.ets`)
At least 10 states:
1) empty idle (interactive)
2) short text send
3) long text send
4) multiline text
5) with reply snippet
6) no attach
7) no emoji
8) disabled
9) narrow container
10) wide container

## HarmonyOS grounding
- `TextArea.style(TextContentStyle.INLINE)` — inline input style for custom shells
- `TextArea.enterKeyType(EnterKeyType.Send)`
- `TextArea.onSubmit((enterKey, event) => event.keepEditableState())` — keep keyboard visible after send-style submit

## Known Risks
- Real keyboard avoid mode and caret behavior are integration concerns (screen-level).
- Final icon/background alpha may be tuned after binding to live chat page wallpaper.
