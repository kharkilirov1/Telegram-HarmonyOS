# TgComposerEmojiPanel

## Goal
First safe slice of Telegram composer emoji/sticker input mode:
- render a compact recent-emoji panel above the composer;
- insert selected emoji through a parent-owned callback;
- expose a dedicated sticker callback without pretending sticker packs are implemented.

## iOS References
- `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelComponent.swift`
  - `InputMode.text / emoji / stickers`
  - parent-owned `openStickers`, `sendEmoji`, and `updateInputMode...` callbacks
- `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift`
  - composer node owns input-mode plumbing and custom emoji rendering around the text input
- `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/AccessoryItemIconButton.swift`
  - emoji/sticker/keyboard icon state is an input-mode action, not a text-send action

## Props / Inputs
- `title: string`
- `stickersTitle: string`
- `emojis: string[]`
- `glassMode: string`
- callbacks:
  - `onEmojiSelected(emoji)`
  - `onStickerPress()`

## State Matrix
- default recent emoji grid
- narrow-width recent emoji grid
- sticker action pressed
- emoji insertion into parent composer draft

## Layout Rules
1. The panel is a composer-owned glass capsule rendered immediately above `TgComposerInput`.
2. The panel does not own draft state; selecting an emoji only emits `onEmojiSelected`.
3. Sticker press is explicit and parent-owned; until real sticker packs exist it must fail visibly at integration level.
4. The panel is included in the chat page composer-height measurement so the message list bottom offset grows with it.
5. Repeated geometry belongs in `TgUiTokens`.

## Token Mapping
- `COMPOSER_EMOJI_PANEL_RADIUS`
- `COMPOSER_EMOJI_PANEL_PADDING`
- `COMPOSER_EMOJI_PANEL_TOP_GAP`
- `COMPOSER_EMOJI_PANEL_ROW_GAP`
- `COMPOSER_EMOJI_PANEL_HEADER_HEIGHT`
- `COMPOSER_EMOJI_CELL_SIZE`
- `COMPOSER_EMOJI_CELL_RADIUS`
- `COMPOSER_EMOJI_CELL_GAP`
- `COMPOSER_EMOJI_COLUMNS`
- `COMPOSER_EMOJI_TEXT_SIZE`
- `COMPOSER_EMOJI_HEADER_SIZE`
- `COMPOSER_EMOJI_PILL_HEIGHT`
- `COMPOSER_EMOJI_PILL_RADIUS`
- `COMPOSER_EMOJI_PILL_PADDING_H`

## Acceptance Checklist
- [ ] Emoji button toggles the panel in live chat
- [ ] Emoji selection appends to the current composer draft
- [ ] Send button becomes active after emoji insertion
- [ ] Sticker pill uses a dedicated callback and does not route through send
- [ ] Composer overlay/list bottom offset includes panel height
- [ ] No manual media/sticker backend behavior is claimed

## Demo
- `entry/src/main/ets/ui/tg_ui/demos/TgComposerEmojiPanelDemo.ets`

## Known Risks
- This is not a full emoji/sticker picker: no categories, search, skin tones, animated/custom emoji, or sticker pack data.
- Current insertion appends to the end of the draft because the composer does not yet expose a caret-aware text controller.
