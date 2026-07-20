# TgChatSearch

## References

- Shipped Telegram iOS runtime remains the visual authority when a fresh search capture is available.
- Current iOS source behavior and paging:
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Sources\ChatControllerUpdateSearch.swift`
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Sources\ChatTagSearchInputPanelNode.swift`
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\PeerInfo\PeerInfoScreen\Sources\PeerInfoData.swift`
- Exact TDLib cursor contract:
  - `tdlib\td\generate\scheme\td_api.tl`: `foundChatMessages.next_from_message_id`
  - `searchChatMessages(... from_message_id ... limit <= 100)`
- HarmonyOS grounding: ArkUI `LoadingProgress` is the native visible loading indicator and stops animating when hidden.

## Inputs

- Search query.
- Loaded result ids, total result count and exact `next_from_message_id` cursor.
- Current 1-based result position.
- Initial/page-loading and failure states.

## State matrix

| State | Status capsule | Older control |
| --- | --- | --- |
| Empty query | hidden | disabled |
| Debounce/request pending | spinner + `Searching...` | disabled |
| Results loaded | `position / total` | enabled while `position < total` |
| Next page pending | spinner + retained `position / total` | remains semantically available |
| Empty completed result | `No results found` | disabled |
| Initial request failure | `Search failed` | disabled |

## Layout and behavior

- The bottom search controls are independent 40vp glass capsules over the chat wallpaper; no full-width opaque plate.
- Each arrow keeps a 40vp interaction region and a 22vp glyph.
- Search is debounced by 200ms. Changing the query invalidates even an older request with the same final text.
- Opening search requests focus through ArkUI `FocusController`; `TextInput` focus opens the system IME. Chats whose top bar keeps the iOS avatar/info action expose Search from the profile header and return to the same chat in search mode.
- TDLib pages are appended with id deduplication. Near the end of the loaded page, the exact TDLib cursor is prefetched; pressing Older at the boundary loads and advances into the next page.
- A jump keeps the existing scroll-to-latest control available after leaving search mode.
- Bubble hits use the accent wash. Standalone sticker rows additionally receive a high-contrast rounded outline.

## Acceptance

- [x] A query with more than 100 matches navigates past result 100 (`iphone`: `102 / 2997`, second page `200/2997`).
- [ ] `Searching...` is visible before an empty result can be shown.
- [ ] Page loading retains the current counter and shows a compact spinner.
- [ ] Standalone sticker jump flash is visible on dark wallpaper.
- [ ] Search close and scroll-to-latest return to the normal chat surface without stale state.
- [x] A group/channel avatar -> profile -> Search returns to the same chat with the search field and system IME focused.
