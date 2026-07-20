# UI runtime baseline — 2026-07-10

Status: current visual evidence for the next UI refresh. This supersedes the
March 2026 screenshot comparisons where they conflict.

## Reference order

1. User-provided Telegram iOS runtime captures from an iPhone 16 Pro Max.
2. Official App Store 12.8.1 screenshots and Telegram's 2026 Liquid Glass announcement.
3. Current public Telegram iOS source: `C:\Refs\Telegram\Telegram-iOS-current`
   at `6e370e06d147b091b07903071cb1b8a22152492d`.
4. Live HarmonyOS emulator captures from the freshly installed target-26 HAP.
5. Nekogram 12.8.1 on the connected MI 9, used only for Android behavior and
   state comparison.

## Runtime witnesses

### iPhone 16 Pro Max

- Chat list: `C:\Users\Kharki\Downloads\Telegram Desktop\photo_2026-07-10_18-29-03.jpg`
- `zai` chat: `C:\Users\Kharki\Downloads\Telegram Desktop\photo_2026-07-10_18-29-02.jpg`
- `File` chat: `C:\Users\Kharki\Downloads\Telegram Desktop\photo_2026-07-10_18-29-01.jpg`

### HarmonyOS emulator

Local ignored evidence root:
`C:\Users\Kharki\Desktop\Telegram-HarmonyOS\.codex\ui-audit\2026-07-10`

Key captures:

- `01-chatlist-light.jpeg`, `10-chatlist-dark.jpeg`
- `14-direct-chat-light-bottom.jpeg`, `15-direct-chat-dark-bottom.jpeg`
- `16-file-chat-dark.jpeg`
- `07-settings-dark.jpeg`, `08-contacts-dark.jpeg`, `09b-calls-dark-recheck.jpeg`

The installed bundle reported `apiTargetVersion=260000026`. The app was
started after the fresh HAP install and the process time was checked against
device time before these captures.

### Nekogram on MI 9

Local ignored evidence root:
`C:\Users\Kharki\Desktop\Telegram-HarmonyOS\.codex\ui-audit\2026-07-10\android-mi9`

- `01-nekogram-chatlist.png`
- `02-nekogram-zai-chat.png`
- `03-nekogram-file-chat.png`

Installed artifact: official GitHub release
`Nekogram-12.8.1-6916-arm64-v8a.apk`, package
`tw.nekomimi.nekogram`.

## Confirmed gaps

### P0 — chat surface has no wallpaper layer

`TgChatScreenPage` paints only `COLOR_BG_PRIMARY`; no background image or
pattern layer exists. Consequences visible in the same `zai` chat:

- light incoming bubbles use white on a white page and visually disappear;
- dark chat is a flat near-black surface instead of the textured Telegram
  canvas visible on both iOS and Nekogram;
- date/service capsules and media overlays have no wallpaper context.

This is the highest-confidence first visual correction because it changes no
TDLib or message behavior and fixes both themes at once.

### P0 — current iOS chrome is capsule-based

The iPhone captures and current source agree:

- chat navigation actions are separate 44-point glass capsules;
- title/subtitle sit in a centered glass capsule;
- composer controls are independent 40-point capsules with 6-point gaps;
- the chat list uses floating top actions and a separate bottom search action.

HarmonyOS still uses a full-width rectangular chat header and keeps a
54-vp search lane permanently expanded above the chat list.

### P0 — `File` state is incomplete visually

The same chat proves the delta:

- iOS and Nekogram show a persistent pinned-message panel;
- HarmonyOS does not surface the pinned panel;
- HarmonyOS can show a large flat media placeholder before/alongside the
  loaded album, while the references preserve the collage hierarchy.

Pinned-message behavior is a separate runtime slice; it must not be hidden
inside a wallpaper-only patch.

### P1 — chat-list density and right cluster

- HarmonyOS reserves a fixed 76-vp right cluster and uses a fixed 76-vp row
  with a 60-vp avatar.
- The iPhone runtime keeps mute/read/pin/unread metadata compact and shows
  more useful rows in the same viewport.
- Search/header height, rather than row height alone, is a major source of
  lost vertical space.

Do not globally shrink generic spacing tokens: their blast radius includes
login, demos and secondary pages. Use chat-list-specific tokens.

### P1 — bottom geometry has multiple sources of truth

`MainTabsPage` and `SafeAreaUtils.computeTabBottomInset()` independently
encode tab height/margins. The custom Chats tab also uses different geometry
from the three stock HDS tab items. This needs a dedicated runtime-verified
slice; it must preserve the accepted HDS floating-island behavior.

### P1 — glass fallback is not consistently reactive

Live top/composer components choose tint from their local `glassMode`, while
blur style comes from global `TgGlassPolicy`. A low-memory downgrade can
therefore disable blur while leaving a nearly transparent tint. Fix this as a
single-source policy slice, not by increasing arbitrary opacity.

## Constraints for the refresh

- No Telegram or decompiled ArkGram assets are copied.
- Runtime iPhone captures define visual intent; public source defines
  hierarchy, constants and states.
- HDS/HarmonyOS behavior remains where it is already accepted and platform
  correct.
- UI patches stay independent from TDLib/domain changes.
- Every visual slice is witnessed on the same chats (`zai`, `File`) in light
  and dark mode, then checked with `smoke-ui-phase0` and `smoke-build`.

## First decision boundary

The next implementation design should start with a clean-room, repeating
light/dark chat background layer and wallpaper-aware surface tokens. Chat
chrome, pinned messages, chat-list search/density and bottom geometry remain
separate follow-up slices so each visual delta can be verified independently.
