# TgArchivedChatsRow passport

## Reference
- Visual/runtime truth: current Telegram iOS archive group row supplied by the user's account.
- Hierarchy/state source: `C:\Refs\Telegram\Telegram-iOS-current\submodules\ChatListUI\Sources\Node\ChatListNodeEntries.swift` (`GroupReferenceEntry`, lines 917–935) and `Node\ChatListItem.swift` (`GroupReferenceData`, archived title/icon/subtitle rendering).
- Behavior fallback: `C:\Refs\Telegram\telegram-android\TMessagesProj\src\main\java\org\telegram\ui\Cells\DialogCell.java` (`currentDialogFolderId`, archived peer-name summary).

## Inputs
- `title`: localized archive title.
- `preview`: ordered compact titles of the first archived chats.
- `chatCount`: real archive size; fallback text only when `preview` is empty.
- `unreadCount`: number of unread archived dialogs (never the message sum).
- `showSeparator`: list integration separator policy.
- `surfaceColor` / `separatorColor`: parent-owned ChatList palette, with generic atom defaults.

## State matrix
- Archive absent: atom is not mounted.
- Archive with preview: archive icon + title + comma-separated peer names.
- Archive without preview: localized title + numeric chat-count fallback.
- Unread archive: compact inactive/neutral unread capsule on the trailing edge. Telegram iOS marks `GroupReferenceData` unread state as muted (`unreadCount = (..., true, ...)`) even when the archived chats themselves contain unmuted messages.

## Layout contract
- Same row height, side insets, title/preview baseline and separator inset as `TgChatRow`.
- Circular archive glyph occupies the normal avatar slot.
- Title and preview ellipsize to one line; trailing unread capsule never shifts the avatar/title axis.
- The text column explicitly aligns to `HorizontalAlign.Start`; direct Text children must not inherit the Column's centered cross-axis default.

## Token mapping
- Geometry/typography: shared iOS-density `CHAT_ROW_HEIGHT = 72`, `CHAT_ROW_*`, `AVATAR_SIZE_DEFAULT = 60`.
- Colors: `COLOR_BG_PRIMARY`, `CHAT_LIST_PINNED_SURFACE_BG`, `CHAT_LIST_SEPARATOR`, `COLOR_TEXT_TITLE`, `COLOR_TEXT_PREVIEW`, `COLOR_ICON_PRIMARY`, `COLOR_UNREAD_BG_MUTED`, `COLOR_UNREAD_TEXT`.
- Icon: `ICON_RES_ARCHIVE`.

## Runtime ownership
- The atom is visual only. `ChatsState.archivedChatIds` and `Chat.archiveOrder` are the source of truth.
- Main-list visibility and navigation are owned by `ChatListPage`; archive content is owned by `TgArchivedChatsPage`.
- Main-list swipe archives through TDLib `addChatToList(chatListArchive)`.
- Archive rows expose Pin/Unpin for `chatListArchive` and Unarchive through
  `addChatToList(chatListMain)`, matching Telegram iOS reveal options.
- Both reveal actions use the iOS icon-over-label hierarchy and remove default
  `Button` content padding so translated labels stay readable.
