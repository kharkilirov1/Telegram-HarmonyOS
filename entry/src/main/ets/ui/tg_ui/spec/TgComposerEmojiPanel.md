# TgComposerEmojiPanel passport

## Reference

- Runtime visual truth: user-provided Telegram iOS entity-keyboard screenshots from 2026-07-10.
- Unicode keyboard data: Unicode `emoji-test.txt` 17.0 in CLDR order. The generated
  `TgUnicodeEmojiCatalog.ets` keeps every fully-qualified neutral/base sequence in
  the nine keyboard groups and records the source SHA-256; skin-tone modifiers are
  contextual variants rather than duplicated grid cells.
- iOS hierarchy: `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\ChatEntityKeyboardInputNode\Sources\ChatEntityKeyboardInputNode.swift:184-195`.
  `EmojiPagerContentComponent.emojiInputData` enables Unicode and custom emoji together and carries search state.
- iOS insertion model: the same component inserts custom emoji into the attributed
  input at the active selection with `ChatTextInputAttributes.customEmoji`; it does
  not append blindly to the end of the draft.
- iOS search flow: `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\ChatEntityKeyboardInputNode\Sources\StickerPaneSearchContentNode.swift:621-645`.
  Queries longer than one character resolve localized emoji keywords, add an English fallback for non-English locales, then search stickers with the resulting emoticons and original query.
- TDLib contract: `tdlib/td/generate/scheme/td_api.tl:5575-5581`, `:13083`, `:13095`, `:13158`.
  Installed and featured packs are `stickerTypeCustomEmoji`; featured results use
  `trendingStickerSets`, and selected items are sent as
  `textEntityTypeCustomEmoji(custom_emoji_id:int64)`.

## Inputs

- Unicode recent/category emoji.
- Real installed plus featured custom-emoji pack tabs and their downloaded static previews.
- Active pack id, loading state, server Unicode/custom search results, localized Search/GIF/Stickers/Emoji labels.
- Glass policy and bottom safe-area inset.

## State matrix

- Unicode pack: recent plus the nine CLDR keyboard groups (Smileys, People,
  Animals, Food, Travel, Activities, Objects, Symbols, Flags), 1914 base emoji,
  eight-column grid.
- Custom pack loading / empty / populated.
- Installed packs first, then deduplicated featured packs from `getTrendingStickerSets`.
- Pack strip with Unicode synthetic tab plus real TDLib packs; the strip is omitted
  when Unicode is the only available tab.
- Category rail / search field with idle, loading, empty, and mixed-result states.
- Bottom peer modes: GIF / Stickers / Emoji.

## Layout contract

- Full-width keyboard-slot panel; never an overlay over the composer or timeline.
- Conditional top horizontal pack strip, rounded category/search rail, section title, scrollable
  eight-column grid, and shared bottom mode bar.
- The large Unicode catalog uses `LazyForEach` + `IDataSource`; changing category
  reloads the data source instead of eagerly creating hundreds of offscreen cells.
- Animated TGS/WebM cells use static thumbnails in the grid to avoid multiplying
  live animation players.
- During search, matching Unicode and real custom emoji share one eight-column grid.

## Interaction contract

- Unicode tap emits a plain emoji.
- Custom tap emits fallback Unicode plus the exact string int64 custom emoji id.
- Pack tap loads the exact real `stickerSet`; featured packs are previews and are not
  falsely marked installed.
- Production send and draft paths serialize the id as `textEntityTypeCustomEmoji`.
- Search starts at two trimmed characters and is page-owned: 250 ms debounce,
  current locale plus `en-US` fallback, monotonically increasing request id, and
  query/panel/lifecycle checks before results or downloaded previews are applied.
- The data path is typed TDLib `searchEmojis` followed by
  `searchStickers(stickerTypeCustomEmoji)`; no local glyph substring fallback is used.
- The page tracks the current `TextArea` selection and inserts Unicode/custom emoji
  at that range. Manual edits reconcile custom-emoji spans in UTF-16 coordinates:
  untouched spans are retained/shifted and a span intersected by the edit is dropped.
- Draft normalization and restore preserve the exact custom-emoji ids through the
  TDLib DTO/state pipeline. The plain `TextArea` still renders fallback glyphs;
  animated inline custom-emoji media requires a separate `RichEditor` migration.

## Verification

- Focused contract: `scripts/test-ios-emoji-keyboard.ps1`.
- Generated-catalog suite: `TgUnicodeEmojiCatalog.test.ets` (nine-group order,
  1914-count invariant, People/Flags completeness and no skin-tone duplicates).
- API23 runtime: Recent, localized `Люди и жесты`, localized `Флаги`, and lazy
  Flags scrolling are captured under `.codex/ui-audit/2026-07-15/emoji-catalog/`.

## Token mapping

- Panel and mode-bar geometry: `COMPOSER_KEYBOARD_PANEL_*`, `ENTITY_KEYBOARD_MODE_*`.
- Pack strip: `COMPOSER_EMOJI_PACK_*`.
- Search/category rail: `COMPOSER_EMOJI_NAV_*`, `COMPOSER_EMOJI_PILL_*`.
- Grid: `COMPOSER_EMOJI_CELL_*`, `COMPOSER_CUSTOM_EMOJI_IMAGE_SIZE`.
