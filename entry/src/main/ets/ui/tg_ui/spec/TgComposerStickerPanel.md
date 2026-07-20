# TgComposerStickerPanel passport

## Reference

- Runtime visual truth: user-provided Telegram iOS entity-keyboard screenshots from 2026-07-10.
- iOS hierarchy: `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\ChatEntityKeyboardInputNode\Sources\ChatEntityKeyboardInputNode.swift:208`, `:1306-1314`.
  Sticker packs are content groups; GIF, Stickers, and Emoji are peer keyboard modes.
- iOS search content: `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\ChatEntityKeyboardInputNode\Sources\StickerPaneSearchContentNode.swift:621-645` and `PaneSearchContainerNode.swift`.
- iOS GIF search: `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\ChatEntityKeyboardInputNode\Sources\GifPaneSearchContentNode.swift` and `_internal_searchGifs` in `submodules/TelegramCore/Sources/TelegramEngine/Stickers/SearchStickers.swift:1862-1885`.
- TDLib contract: `tdlib/td/generate/scheme/td_api.tl:13074`.
  Production search uses `searchStickers(stickerTypeRegular)` with query, locale codes, offset, and limit.
- iOS grouped home hierarchy: `CloudSavedStickers`, `CloudRecentStickers`, and `CloudAllPremiumStickers` in `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\EntityKeyboard\Sources\EmojiPagerContentSignals.swift` and `EmojiPagerContentComponent.swift`.
- TDLib grouped-home contract: `tdlib/td/generate/scheme/td_api.tl:13079-13080`; Premium uses bounded `getPremiumStickers(limit)`, while Favorites use `getFavoriteStickers`.
- TDLib GIF contract: `getOption("animation_search_bot_username")` -> `searchPublicChat` -> `getInlineQueryResults`; selection is sent with `sendInlineQueryResultMessage` rather than a fabricated animation input.

## Inputs

- Real recent/favorite/Premium/installed-pack sticker cells and pack tabs.
- Saved GIF cells and external inline-bot GIF search pages for the peer GIF mode.
- Active pack, loading state, localized Search/GIF/Stickers/Emoji labels.
- External sticker/GIF search results, pagination state, and search loading state.
- Glass policy and bottom safe-area inset.

## State matrix

- Recent populated / empty / loading.
- Favorites populated and omitted when empty.
- Recent home with Premium and Favorites groups; either group is independently omitted when empty.
- Installed pack populated.
- Search idle / one-character / loading / empty / populated.
- Saved GIF populated / empty.
- GIF search first page / next page / exhausted / stale request.

## Layout contract

- Full-width keyboard-slot panel below the composer; never overlays the timeline.
- Sticker mode order follows iOS: pack strip, rounded search rail, grouped Premium/Favorites home for Recent, shared bottom mode bar.
- Search and explicit pack tabs retain the section title plus four-column grid; grouped home never replaces search results.
- GIF mode follows the same panel hierarchy without the sticker-pack strip: rounded search rail, section title, two-column cover grid, shared bottom mode bar.
- Animated TGS/WebM cells use static thumbnails in the grid to avoid multiplying live animation players.

## Interaction contract

- Pack tap exits search and loads real pack data.
- Search starts from two trimmed characters, uses current locale plus `en-US` fallback, and is debounced by 250 ms.
- GIF search starts from non-empty trimmed text, resolves Telegram's configured animation-search bot (fallback `gif`), debounces by 250 ms, and loads `next_offset` pages from the grid edge.
- Request id, query, active mode, panel visibility, and page lifecycle are rechecked before results or preview downloads are applied.
- Grouped home requests only its visible `8 + 4` thumbnail ids through non-blocking `downloadFile`; `updateFile` completion is resolved from `FilesState.transfers`. Nested TDLib file ids use `getTopLevelNumber('id')`, not the generic nested-key matcher.
- Sticker tap sends `inputMessageSticker`; saved GIF tap sends `inputMessageAnimation`; inline GIF tap carries exact string `inline_query_id` and `result_id` into `sendInlineQueryResultMessage`.
- No local substring filtering and no fake GIF results.

## Token mapping

- Panel geometry: `COMPOSER_STICKER_PANEL_*`, `COMPOSER_KEYBOARD_PANEL_*`.
- Pack/search navigation: `COMPOSER_STICKER_TAB_*`, `COMPOSER_EMOJI_NAV_*`, `COMPOSER_EMOJI_PILL_*`.
- Grid: `COMPOSER_STICKER_CELL_*`, `COMPOSER_GIF_*`, `COMPOSER_EMOJI_CELL_RADIUS`.
- Grouped home: `COMPOSER_STICKER_GROUP_*`, `COMPOSER_STICKER_PREMIUM_*`, `COMPOSER_STICKER_FAVORITE_*`.
- Bottom modes: `ENTITY_KEYBOARD_MODE_*`.

## Demo

- `entry/src/main/ets/ui/tg_ui/demos/TgComposerStickerPanelDemo.ets` covers grouped Premium/Favorites home, favorites, installed pack, loading, empty, and saved GIF states; search rail is interactive.

## Runtime witness

- API23 clean-cold-boot evidence: `.codex/ui-audit/2026-07-13/gif-search/coldboot-final/`.
- One Search tap focused `tg_sticker_panel_search_input`; query `cat` returned 50 real inline results and rendered TDLib Base64 minithumbnail previews in the two-column grid.
- The runtime-tested process stayed alive after a 35-second settle with no new Telegram AppFreeze or RenderService freeze fault. No GIF result was selected or sent.
