# TgTgsPlayer passport

## References

- Shipped Telegram iOS runtime: animated chat stickers loop while visible and
  disappear with the chat surface rather than becoming static thumbnails.
- Telegram iOS source:
  `submodules/TelegramUI/Components/Chat/ChatMessageAnimatedStickerItemNode/Sources/ChatMessageAnimatedStickerItemNode.swift`
  (`visibilityStatus && !forceStopAnimations`; default playback is `.loop`,
  Energy Saving may select `.once`).
- Telegram Android / Nekogram native renderer:
  `TMessagesProj/jni/lottie.cpp` (`loadFromData`, `renderSync`, explicit
  destroy) and `TMessagesProj/jni/CMakeLists.txt` (`rlottie` source set).
- HarmonyOS official APIs: `displaySync.create/on/start/stop`, reusable
  `ImageData`, `CanvasRenderingContext2D.putImageData`, and Node-API typed
  arrays.

## Inputs

- `tgsPath: string` — local `file://` URI or sandbox path to a gzipped TGS.
- `renderWidth: number` — logical Canvas width.
- `renderHeight: number` — logical Canvas height.

## State matrix

| State | Native path | Fallback path | Expected result |
| --- | --- | --- | --- |
| Visible + valid TGS (production default) | disabled by token | `@ohos/lottie` | Loop at requested 30 Hz |
| Visible + valid TGS (experiment enabled) | `tg_rlottie` + `DisplaySync` | inactive | Loop at requested 30 Hz |
| Offscreen cached row | stopped | coordinator-paused | No frame callback or Canvas repaint |
| Native create/render failure | destroyed | `@ohos/lottie` | Same visible sticker behavior |
| Component disappears | stop + destroy | destroy + unbind | No retained timer or animation |
| Path changes during load | discard stale load | none | New path remains the only owner |

## Layout and alignment

- The atom owns exactly the caller-provided width and height.
- It adds no padding, background, status chrome, or gesture region.
- The rendered transparent frame must preserve the existing message-shell and
  freeform sticker-meta geometry.

## Token mapping

- Playback cadence: `TgUiTokens.TGS_PLAYBACK_FRAME_RATE` (`30`).
- Native experiment gate: `TgUiTokens.TGS_NATIVE_RLOTTIE_ENABLED`.
- Geometry remains caller-owned; no new size token is introduced.

## Acceptance gates

- Native hilog proves `telegram-rlottie` create/render and DisplaySync start.
- Two live captures prove changing sticker pixels rather than a static frame.
- Native and old fallback captures retain the same occupied geometry and
  acceptable edge/color fidelity.
- Back/offscreen produces zero TGS Canvas updates and zero app VSync markers.
- Same-session visible trace/CPU is lower than the `@ohos/lottie` baseline;
  otherwise the native path is not accepted as the default.
- Focused contracts, shell smokes and clean build pass after the final source.

## Current disposition

The native renderer is retained as an opt-in experiment, not the production
default. The API 23 emulator proved correct geometry, color channels, looping,
and zero offscreen work, but the Canvas/ImageData upload used `3.736` host
cores versus the `2.371`-core `@ohos/lottie` witness. The next credible native
step is a direct surface/XComponent path rather than another Canvas upload.
