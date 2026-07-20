# TgContactsSurface integration passport

## Reference
- iOS contacts controller/search: `C:\Refs\Telegram\Telegram-iOS-current\submodules\ContactListUI\Sources\ContactsController.swift`.
- iOS indexed sections: `C:\Refs\Telegram\Telegram-iOS-current\submodules\ContactListUI\Sources\ContactListNode.swift`.
- Platform implementation: native ArkUI `Search`, `ListItemGroup`, sticky headers and `AlphabetIndexer`.

## Data and state
- Source remains real `AppState.users` filtered by `isContact`, excluding self/deleted accounts.
- Empty query shows locale-aware letter groups and an index of the groups that really exist.
- Search filters the already-hydrated contact set without a fake server result and hides the alphabet rail.

## Layout
- HDS owns root title/safe-area material; custom Telegram rows own content semantics.
- Search is the first list item so it scrolls with content rather than overlapping the title.
- Sticky 24vp section headers and the native indexer use the same group model.

## Acceptance
- [x] Search filters the live account contact list on API23.
- [x] Sticky Cyrillic/Latin sections and index selection scroll to the intended group.
- [x] Search/first header/first row do not overlap the HDS title.
- [x] Bottom rows stay clear of the native tab island.
