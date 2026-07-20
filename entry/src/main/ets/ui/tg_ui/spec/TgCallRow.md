# TgCallRow Component Passport

## 1) Scope
- Atom: `TgCallRow`
- Target layer: `atoms`
- Status: `done`

## 2) iOS source mapping
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\CallListUI\Sources\CallListCallItem.swift`
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\CallListUI\Sources\CallListControllerNode.swift`
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\PeerInfoUI\Sources\ItemListCallListItem.swift`

## 3) Props / inputs
- `name: string`
- `initials: string`
- `avatarPath: string`
- `callType: TgCallType` (`Incoming`, `Outgoing`, `Missed`)
- `dateText: string`
- `labelText: string` (optional override for localized/precise subtitle)
- `isVideo: boolean`
- `showSeparator: boolean`
- `avatarBgColor: ResourceColor`

## 4) State matrix
- incoming / outgoing / missed
- audio call / video call
- avatar image / initials fallback
- long name ellipsis
- separator on / off

## 5) Layout rules
- Left cluster: avatar + name/status stack.
- Right cluster: relative/localized date + iOS-style info icon.
- Missed call paints title and type icon with destructive color.
- Subtitle line combines direction/video state and stays single-line.
- Separator inset starts after the avatar block.

## 6) Token mapping
- `CALL_ROW_*`
- `ICON_RES_CALL_INCOMING`
- `ICON_RES_CALL_OUTGOING`
- `ICON_RES_INFO`
- `COLOR_TEXT_TITLE`
- `COLOR_TEXT_PREVIEW`
- `COLOR_SEPARATOR`
- `CALL_ROW_MISSED_COLOR`

## 7) Acceptance checklist
- [x] incoming/outgoing/missed states rendered
- [x] missed call hierarchy emphasized
- [x] long names ellipsize correctly
- [x] right-side date/action cluster stays aligned
- [x] geometry and colors are tokenized
- [x] older dates use localized short months and append a year only outside the current year
