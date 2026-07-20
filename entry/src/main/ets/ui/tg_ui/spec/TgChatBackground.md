# TgChatBackground passport

## References
- Runtime visual truth: `docs/ai/UI_RUNTIME_BASELINE_2026-07-10.md`
- Ownership/design contract: `docs/ai/HYBRID_NATIVE_CUSTOM_UI_DESIGN_2026-07-10.md`
- Current iOS structural reference: `C:\Refs\Telegram\Telegram-iOS-current`
- Harmony API: ArkUI `Image.objectRepeat(ImageRepeat.XY)`; raster only.

## Inputs
- `showPattern: boolean = true` — test/demo fallback switch only.

## State matrix
- qualified light tile + light base
- qualified dark tile + dark base
- pattern enabled
- pattern disabled/resource failure: solid themed base remains visible
- narrow, normal and tall containers

## Layout and interaction
- fills the parent without adding padding or safe-area ownership
- first/lowest child of the chat root `Stack`
- does not affect timeline measurement, scroll offsets or overlay geometry
- root and image use `HitTestMode.None`
- raster repeats on both axes; repeated SVG is forbidden by API contract

## Tokens and resources
- `TgUiTokens.COLOR_CHAT_WALLPAPER_BASE`
- `app.color.chat_wallpaper_base` in base/dark resource qualifiers
- `app.media.tg_chat_wallpaper_tile` in base/dark resource qualifiers

## Acceptance
- smoke contract passes
- clean `assembleHap` succeeds
- light/dark `zai` and `File` screenshots show visible but subordinate pattern
- incoming/outgoing bubbles and service chips remain legible
- timeline scrolling and composer/top-bar hit testing remain unchanged

## Current runtime witness
- API24, current entry HAP SHA-256
  `17E2576E36BED2A0FAABD7E4BBFB2D0BCE525C437E4C4811D3D164996BA65EAD`.
- Dark base/incoming/outgoing: `#0F2837 / #1E2E3D / #406D97`.
- Light base/incoming/outgoing: `#E9EFF2 / #FFFFFF / #E1FFC7`.
- A vertical `uinput -T -m` gesture changed the live `zai` timeline; composer
  focus resized the app root for the system IME; Back restored native HDS tabs.
- Captures and layout dumps:
  `.codex/ui-audit/2026-07-19/m1-chat-surface-current-hap/`.
