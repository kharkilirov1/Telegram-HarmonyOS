# iOS Composer Panels Design

## Scope

Bring the existing HarmonyOS chat composer auxiliary surfaces in line with the
provided current Telegram iOS runtime captures. This slice changes only the
composer panel presentation and attachment entry surface; message sending and
TDLib domain behavior remain unchanged.

## Accepted behavior

- Telegram owns one custom GIF/Stickers/Emoji panel rendered below the composer.
- The custom panel and the system IME never coexist: touching the text field
  closes the Telegram panel before ArkUI focuses the `TextArea` and opens IME.
- While the Telegram panel is visible, the trailing emoji glyph becomes a
  keyboard glyph; tapping it closes the custom panel and focuses the composer.
- The custom panel continues to displace the timeline through the existing
  measured composer/panel bottom padding contract.
- The paperclip opens a native ArkUI `bindSheet` with `SheetSize.LARGE`.
- The sheet contains a compact header, a three-column grid backed by real recent
  `PhotoAsset` URIs, and a bottom category rail.
- The first functional slice supports Gallery, Camera and File. Location, Poll
  and Contact remain visible but disabled until their business flows exist; no
  fake success or unrelated Wallet feature is introduced.

## Boundaries

- `TgAttachmentSheet` owns sheet-only rendering and emits typed UI events.
- `TgComposerInput` owns sheet presentation and composer glyph/state wiring.
- `TgChatScreenPage` owns reactive recent-media state and mutual exclusion of
  Telegram panel/IME state.
- `ChatComposerController` owns permission, PhotoAccessHelper access and existing
  picker dispatch.

## Verification

- Contract test first: `scripts/test-ios-native-liquid-composer.ps1`.
- Shell UI contract: `scripts/smoke-ui-phase0.ps1`.
- Compile: `scripts/smoke-build.ps1`.
- Runtime: install the entry HAP on API23, verify a fresh process, then capture
  custom-panel -> IME replacement and attachment-sheet recent grid.
