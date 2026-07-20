# TgComposePage component passport

## References

- Current public iOS hierarchy: `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Sources\ComposeController.swift` and `ComposeControllerNode.swift`.
- Contact list/row geometry: `C:\Refs\Telegram\Telegram-iOS-current\submodules\ContactListUI\Sources\ContactListNode.swift` and `C:\Refs\Telegram\Telegram-iOS-current\submodules\ContactsPeerItem\Sources\ContactsPeerItem.swift`.
- Current visual caveat: this thread does not yet contain a shipped iPhone screenshot of the New Message screen, so source-derived geometry is not pixel-parity proof.

## Inputs and result

- Data source: live `AppState.users.users` entries marked `isContact`.
- Excludes the current account and deleted/empty users.
- Selection result: exact `chatId` returned by TDLib `createPrivateChat(user_id, false)` plus the selected display name.
- Cancellation result: typed zero `chatId`, so the caller always clears its duplicate-navigation guard.

## State matrix

- loading / contacts / no contacts / no search results;
- empty query / filtered local query / hydrated cloud and public-user results;
- opening one selected contact / TDLib error;
- opening Group / Contact / Channel creation route;
- back cancellation / successful chat hand-off.

## Layout contract

- Reuse `TgForwardPickerNavigationBar` for the floating title/back capsules.
- Native ArkUI `Search`, 36vp height with 16vp side inset.
- Compose contact row: 50vp, 40vp avatar, 17fp name, 13fp status, 65vp text/separator inset.
- Section header: 29vp; Cyrillic-first ordering for Russian locale.
- Root HDS tab bar remains hidden while Compose is visible.

## Fidelity boundary

- Current iOS non-search order is New Group → New Contact → New Channel → contacts; there is no Secret Chat row.
- All three action rows now open functional typed routes; clickable no-op parity remains rejected.
- Global user search is live through `searchContacts`, `searchChatsOnServer` and `searchPublicChats`, with private-user filtering, dedupe, hydration limits and stale-query cancellation.
- This is a bounded functional creation slice, not full iOS parity: group global member search/avatar/TTL, OS Contacts permission and country/phone resolution, and channel visibility/username/subscriber steps remain separate work.
- A shipped-runtime iPhone Compose screenshot is still required before any pixel-parity claim.

## Acceptance

- Compose never renders `TgChatRow` or group/channel dialogs.
- Search matches display name, username and phone.
- A contact tap opens that exact private chat once; rapid duplicate taps are ignored.
- Group / Contact / Channel action results are returned through typed `NavPathStack` callbacks; a committed TDLib result is never recreated merely because hydration or navigation hand-off fails.
- Back, reopen and return-to-ChatList restore the native HDS shell.
- Focused tests, smoke, clean build and emulator runtime witness are fresh after final edits.
