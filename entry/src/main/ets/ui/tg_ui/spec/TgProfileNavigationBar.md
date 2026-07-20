# TgProfileNavigationBar

## References

- Telegram iOS navigation container:
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\PeerInfo\PeerInfoScreen\Sources\PeerInfoHeaderNavigationButtonContainerNode.swift`
  - `buttonHeight = 44.0`, `sideInset = 16.0`, independent left/right `GlassContextExtractableContainer` surfaces.
- Telegram iOS navigation button states and accessibility:
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\PeerInfo\PeerInfoScreen\Sources\PeerInfoHeaderNavigationButton.swift`
  - icon-only Back and Search states, each exposed as an accessibility button.
- HarmonyOS grounding: ArkUI `systemMaterial` owns material background/border/shadow attributes; do not combine those visual attributes on the native-material path. API23 fallback uses adaptive `backgroundBlurStyle`.

## Inputs

- `topInset`: current safe status-bar inset.
- `showSearch`: whether the profile context exposes chat search.
- `glassMode`: shared realtime/fallback glass policy.
- localized Back/Search accessibility labels.
- Back and Search events only; the atom owns no navigation or profile data.

## State matrix

| Runtime | Surface |
| --- | --- |
| API26 + realtime glass | native interactive `ImmersiveMaterial(THIN)` |
| API23-25 | adaptive ultra-thin blur + tint + 0.5vp edge |
| fallback mode | opaque fallback tint + edge, no realtime blur |

## Layout contract

- Left and right controls are independent capsules; there is no full-width background plate.
- Profile side inset is the iOS 16pt value.
- Accepted compact visual geometry is 38vp with a centered 44vp response region.
- Icon size is 20vp; radius is half the visual control size.
- Top and bottom gaps are tokens so safe-area placement stays identical in page and demo.

## Acceptance

- [x] API23 runtime shows visibly separated glass Back/Search capsules.
- [x] Back returns to the originating chat.
- [x] Search returns to the same chat with focused search input and system IME.
- [x] No opaque full-width top plate appears.
