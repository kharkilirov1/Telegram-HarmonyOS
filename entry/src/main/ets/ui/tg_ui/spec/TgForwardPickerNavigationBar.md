# TgForwardPickerNavigationBar

## References

- Telegram iOS forward entry point:
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Sources\ChatControllerForwardMessages.swift`
  - constructs `PeerSelectionController` with `multipleSelection` and forwarded message ids.
- Telegram iOS modal/navigation hierarchy:
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\PeerSelectionController\Sources\PeerSelectionController.swift`
  - modal navigation, `Conversation_ForwardTitle`, native Back item and `NavigationBarSearchContentNode`.
- Telegram iOS content hierarchy:
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\PeerSelectionController\Sources\PeerSelectionControllerNode.swift`
  - forwarding targets remain a `ChatListNode`, not a fabricated recent-peer grid.
- HarmonyOS grounding: ArkUI `Search` remains the native search control. API26 uses `systemMaterial(ImmersiveMaterial)`; API23-25 retain the shared adaptive `backgroundBlurStyle` fallback.

## Inputs

- Localized modal title.
- Optional top safe-area override. Production measures `TYPE_SYSTEM` from the current window; demos pass `0` explicitly.
- Shared glass mode.
- Localized Back accessibility label.
- Back event only; the atom owns no navigation stack or forwarding state.

## State matrix

| Runtime | Navigation surfaces |
| --- | --- |
| API26 + realtime glass | native interactive `ImmersiveMaterial(THIN)` Back plus noninteractive `REGULAR` title |
| API23-25 | adaptive ultra-thin blur, tint and 0.5vp edge |
| fallback mode | opaque fallback tint and edge, no realtime blur |

## Layout contract

- Back and title are independent capsules; there is no full-width background plate.
- Production chrome starts below the measured system status-bar inset.
- Back uses the accepted chat geometry: 38vp visual, 19vp radius, 20vp icon and centered 44vp response region.
- The title is screen-centered independently of the left control, 40vp high, with a 128vp floor and 220vp ceiling.
- The native ArkUI Search remains below the navigation row and the existing `TgChatRow` list begins immediately after its compact 50vp lane.
- The atom contains no target selection, filtering, TDLib or send behavior.

## Acceptance

- [x] Russian runtime title is `Переслать`.
- [x] API23 shows separate Back/title glass capsules without an opaque top plate.
- [x] Search and target rows preserve their real behavior.
- [x] Back returns to the source chat without choosing a target or sending anything.
