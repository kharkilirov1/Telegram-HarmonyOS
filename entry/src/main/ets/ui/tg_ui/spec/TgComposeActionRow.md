# TgComposeActionRow

## References

- `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Sources\ComposeControllerNode.swift:44-54`
  defines exactly `New Group -> New Contact -> New Channel`; current source exposes no Secret Chat row.
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\ContactListUI\Sources\ContactListActionItem.swift:209-253,289-336`
  defines the 50pt lane, 65pt icon/title baseline, accent text and inset separator.

## Inputs

- localized title;
- tintable icon resource;
- separator visibility;
- press event. The atom owns no navigation or TDLib state.

## State matrix

- normal / pressed through the native light click effect;
- last row with no separator;
- light/dark colors through `TgUiTokens` resources.

## Layout contract

- 50vp content lane;
- 65vp leading icon lane;
- 24vp accent icon and 17fp accent title;
- 0.5vp separator beginning at 65vp;
- one-line title with end ellipsis.

## Acceptance

- The order is owned by `TgComposePage`: Group, Contact, Channel.
- Search hides the actions; empty-query Compose always keeps them reachable.
- Every visible row must point to a functional route; no clickable placeholder is allowed.
