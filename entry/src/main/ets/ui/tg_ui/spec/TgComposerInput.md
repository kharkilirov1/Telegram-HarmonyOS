# TgComposerInput (Phase C / Step 5)

## Goal
Build Telegram-like bottom composer panel:
- attach button
- rounded glass text capsule with placeholder/text
- emoji button
- mic/send action button
- optional reply snippet block on top

UI-only scope for this atom. Message send, keyboard controller integration, media picker, emoji panel, and voice recording remain parent-owned; the atom only exposes dedicated action callbacks for those controls. A selected attachment can be previewed as a pending accessory snippet, but the actual send-media serialization remains parent/runtime-owned.

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
- `requestedCaretPosition: number`
- `caretRequestRevision: number`
- `isDisabled: boolean`
- `showAttachButton: boolean`
- `sendEnabled: boolean`, `voiceEnabled: boolean` — отдельные read-only gates; blocked text/attachment intent сохраняет Send icon и никогда не запускает microphone.
- `accessRetryVisible: boolean`, `accessRetryLabel: string`, `onAccessRetryPress` — native Button above the still-working composer when a failed supergroup FullInfo load leaves some per-kind rights unknown. Default hidden; does not clear draft or replace text/media controls. Parent owns bounded retry; actual callback rechecks visibility and disabled state. This is an explicit HarmonyOS recovery affordance, not a claimed pixel-identical iOS control. Host callback path is covered by `scripts/test-supergroup-boosts.cjs`; device layout/focus/contrast acceptance remains open.
  - Demo: `TgComposerInputDemo` case 19, simulated retry without network; hides Retry, retains the draft and enables photo capability. iOS source grounding for accessory/input separation: `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift:2849–2860`; the new native recovery button is not copied from iOS.
- `attachmentPhotoEnabled`, `attachmentVideoEnabled`, `attachmentCategoryEnabled` — category/recent availability; parent supplies reactive @Local snapshot, callbacks revalidate fresh store rights.
- `showEmojiButton: boolean`
- `showReplySnippet: boolean`
- `replyAuthor: string`
- `replyPreview: string`
- `replyIsOutgoing: boolean`
- `replyIsQuote: boolean`
- `replyHasThumbnail: boolean`
- `showEditSnippet: boolean`
- `editPreview: string`
- `showForwardSnippet: boolean`
- `forwardTitle: string`
- `forwardPreview: string`
- `showAttachmentSnippet: boolean`
- `attachmentKind: string` (`photo` / `video` / `document`)
- `attachmentTitle: string`
- `attachmentPreview: string`
- `containerWidth: number`
- `bottomInset: number`
  - callbacks:
  - `onTextChange(text)`
  - `onTextSelectionChange(start, end)`
  - `onSendPress(text)`
  - `onAttachPress()`
  - `onEmojiPress()`
  - `onVoicePress()`
  - `onReplyCancelPress()`
  - `onEditCancelPress()`
  - `onForwardCancelPress()`
  - `onAttachmentCancelPress()`

## Permission contract (2026-09-06)
Media-only basic group retains composer; a caption uses the pending media permission, not text permission. For a forbidden text intent both submit and voice gesture are inert. Recent/category controls expose their disabled state; scalar props do not replace runtime dispatch guards. Host/native compile witness: `docs/reviews/2026-09-06-reliability-wave9.md`; current device/visual acceptance remains open.

## Slow mode contract (2026-10-02)
`slowmodeSeconds` is a presentation value from the account-scoped TDLib FullInfo receipt aged with device uptime. The trailing action displays `m:ss` for empty and populated drafts; `slowmodeLabel` also labels the empty placeholder and accessibility text. Active countdown blocks ordinary Send, attachment opening and recording start. Text, reply and selected attachments remain editable; their cancel controls remain available. `showEditSnippet` bypasses the countdown for existing-message edits.

`voiceRecordingState: 'preview'` retains a stopped unsent recording when countdown blocks dispatch. It uses the existing Send/Delete controls and `voicePreviewLabel`; Send displays the timer while blocked. Expiry enables explicit Send without sending automatically. Account, chat, operation and permission guards remain controller-owned; timer ticks never change input revision, selection, reply, entities or attachment order.

Timed expiry follows authoritative TDLib snapshots, with administrator/creator and qualifying boost exemptions. Scheduled-send and the distinct iOS pending-message slow-mode state are outside this timed countdown slice.

## State Matrix (demo)
- empty idle (interactive)
- short text (send)
- long text (send)
- multiline text
- with reply snippet
- with edit snippet
- with forward snippet
- with selected attachment snippet
- no attach button
- no emoji button
- disabled
- narrow container
- wide container

## Layout Rules
1) Main row follows the iOS composer split:
   - optional attach circle
   - central text capsule with inline accessory panel, text field, and emoji lane
   - one trailing action circle that morphs from mic to send when the draft becomes sendable
2) The input field uses ArkUI `TextContentStyle.DEFAULT`: on the current API23 runtime
   `INLINE` paints an opaque focused block and blue frame over the custom glass shell.
3) The send-style Enter key uses `onSubmit(..., SubmitEvent)` + `keepEditableState()` so the keyboard can stay visible after submit.
4) Reply/edit/forward snippets are optional accessory panels rendered inside the central text capsule above the input row, not as separate external glass strips.
5) Forward and selected-attachment snippets use the same embedded accessory-panel pattern as reply/edit, and the send action must stay enabled even when the text field is empty.
6) Attach, emoji, and idle mic are explicit parent-owned actions. The atom must not silently route an idle mic tap through `onSendPress`.
7) A selected attachment preview is only a UI/accessory state. Sending a picked URI requires a separate parent/runtime media-send path and must not be faked by this atom.
8) All colors/sizes/weights/radii are tokenized in `TgUiTokens`.
9) Selection is parent-owned. `onTextSelectionChange` reports the active range, while
   `requestedCaretPosition` + `caretRequestRevision` restore the caret after a
   panel-originated insertion or the panel-to-system-IME handoff.

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
  - `COMPOSER_REPLY_CLOSE_SIZE`
  - `COMPOSER_REPLY_CLOSE_GAP`
  - `COMPOSER_ACCESSORY_MIN_HEIGHT`
  - `COMPOSER_ACCESSORY_TEXT_GAP`
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
- `ICON_RES_FORWARD`
- `ICON_RES_PHOTO`
- `ICON_RES_VIDEO`
- `ICON_RES_DOCUMENT`

## Acceptance Checklist
- [ ] Mic/send state switch is stable and centered
- [ ] One external action capsule changes from mic to send without changing row alignment
- [ ] Input capsule keeps stable geometry on empty/long/multiline text
- [ ] Emoji lane is optional and does not collapse the send button hit target
- [ ] Placeholder/text typography stays telegram-like and tokenized
- [ ] Reply snippet integration does not break panel alignment
- [ ] Reply/edit/forward accessory panels share the text capsule background instead of creating a second external capsule
- [ ] Forward snippet keeps send action available without typed text
- [ ] Selected attachment preview keeps send action available without typed text
- [ ] Selected attachment close action exits through `onAttachmentCancelPress`
- [ ] Attach, emoji, and idle mic taps leave the atom through dedicated callbacks
- [ ] Reply snippet cancel action stays inside the atom contract
- [ ] Narrow/wide container behavior is stable
- [ ] Tokens-only implementation (no magic visual numbers)

## Demo Requirements (`TgComposerInputDemo.ets`)
At least 10 states:
1) empty idle (interactive)
2) short text send
3) long text send
4) multiline text
5) with reply snippet
6) with edit snippet
7) with forward snippet
8) with selected attachment snippet
9) no attach
10) no emoji
11) disabled
12) narrow container
13) wide container

## HarmonyOS grounding
- `TextArea.style(TextContentStyle.DEFAULT)` — accepted runtime path for the current glass shell
- `TextArea.enterKeyType(EnterKeyType.Send)`
- `TextArea.onSubmit((enterKey, event) => event.keepEditableState())` — keep keyboard visible after send-style submit
- `TextArea.onTextSelectionChange((start, end) => ...)` — keep parent selection state current
- `TextAreaController.caretPosition(offset)` — restore caret after custom-panel insertion

## Known Risks
- Inline animated custom emoji cannot be rendered by plain `TextArea`; use `RichEditor`
  only as a separate migration with a fallback/rollback path.
- Final icon/background alpha may be tuned after binding to live chat page wallpaper.
