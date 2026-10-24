# TgTgsPlayer passport

## References

- Shipped Telegram iOS runtime: animated chat stickers loop while visible and
  disappear with the chat surface rather than becoming static thumbnails.
- Telegram iOS source:
  - `submodules/TelegramUI/Components/Chat/ChatMessageAnimatedStickerItemNode/Sources/ChatMessageAnimatedStickerItemNode.swift`
    — `updateVisibility()`: `isPlaying = visibilityStatus == true && !forceStopAnimations` (line 618),
    `animationNode.visibility = isPlaying` (line 652), and the renderer is set up lazily only on the
    first play (lines 654–669). Default playback is `.loop`; energy saving may select `.once`
    (lines 599–601).
  - `submodules/Postbox/Sources/MediaBox.swift` — `shortLivedResourceCachePathPrefix` (line ~157):
    the animation is played from a per-resource cache path (`short-cache/<fileNameForId(id)>`), i.e.
    the decoded payload is cached by resource identity, not by the message or the visible path.
  - `submodules/TelegramUI/Components/Chat/ChatMediaInputStickerGridItem/Sources/ChatMediaInputStickerGridItem.swift`
    — the keyboard grid *does* animate visible cells (line 431:
    `isPlaying = isPanelVisible && isVisibleInGrid && energyUsageSettings.loopStickers`), again with
    lazy node setup (line 436).
- Telegram Android / Nekogram native renderer:
  `TMessagesProj/jni/lottie.cpp` (`loadFromData`, `renderSync`, explicit destroy) and
  `TMessagesProj/jni/CMakeLists.txt` (`rlottie` source set).
- HarmonyOS official APIs: `displaySync.create/on/start/stop`, reusable
  `ImageData`, `CanvasRenderingContext2D.putImageData`, `onVisibleAreaChange`, Node-API typed
  arrays.
- Environment limitation (2026-10-25): the `harmonyos_docs` MCP server is **not available** in this
  session (only `colab`, `rea`, `rea-linux` are exposed). Platform claims below therefore rest on the
  local SDK surface already used in this repository (`onVisibleAreaChange`, `displaySync`,
  `@Monitor`), not on a fresh documentation query.

## Inputs

- `tgsPath: string` — local `file://` URI or sandbox path to a gzipped TGS.
- `fileId: number` — TDLib file identity; the decoded-payload cache key. `0` means "identity
  unknown": playback still works, caching is skipped (previous behaviour).
- `renderWidth: number` — logical Canvas width.
- `renderHeight: number` — logical Canvas height.

## Playback policy (`TgsPlaybackPolicy`)

One owner for the rules that the timeline row (D13), the sticker viewer (F6), custom emoji (D16) and
the composer grid (D13) share, so no surface grows its own copy:

| Rule | Contract |
| --- | --- |
| Visibility | `shouldPlay(visible, surface)` — an offscreen node never keeps a running loop; the animation is paused where it stands |
| Surface | `allowsAnimation(surface)` — `timeline`, `stickerViewer`, `customEmoji` animate; `panelPreview` never does |
| Decoded cache | keyed by `fileId` only (`recallDecoded`/`rememberDecoded`), LRU bounded to 8 entries; a `fileId <= 0` is never cached; the cache survives an offscreen transition |
| Admission | `acquirePlayer()`/`releasePlayer()` bound concurrent renderers to 4; an over-budget sticker stays paused and retries on the next visibility change |

Rationale for the budget: every live instance owns a Canvas, an animation timeline and a frame
callback; the measured Canvas/ImageData path costs 3.736 host cores for a single visible TGS
(`TASKS/CAPABILITY_MATRIX.md` D13 history and §Current disposition), so an unbounded set of them
cannot be admitted on the API23 emulator.

## State matrix

| State | Native path | Fallback path | Expected result |
| --- | --- | --- | --- |
| Visible + valid TGS (production default) | disabled by token | `@ohos/lottie` | Loop at requested 30 Hz |
| Visible + valid TGS (experiment enabled) | `tg_rlottie` + `DisplaySync` | inactive | Loop at requested 30 Hz |
| Offscreen cached row | stopped | paused by the policy | No frame callback, no Canvas repaint |
| Second message with the same `fileId` | reuses cached JSON | reuses cached JSON | No second gunzip/parse of the same file |
| More than 4 visible TGS nodes | admission refused | admission refused | Over-budget nodes stay paused |
| `fileId == 0` (identity not passed) | no cache | no cache | Plays, but re-decodes per instance |
| Native create/render failure | destroyed | `@ohos/lottie` | Same visible sticker behaviour |
| Component disappears | stop + release + destroy | pause + release + destroy | No retained timer, animation or admission slot |
| Path changes while mounted | stale load discarded | stale load discarded | `@Monitor('tgsPath')` reloads the new file |
| Decode failure | — | warn log + empty frame | Failure is visible in hilog at warn level |

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

- Focused policy test: `entry/src/ohosTest/ets/test/TgsPlaybackPolicy.test.ets` (visibility, surface,
  `fileId` cache + LRU, cache survives offscreen, admission budget, `fileId == 0` skip, reset).
- Native hilog proves `telegram-rlottie` create/render and DisplaySync start.
- Two live captures prove changing sticker pixels rather than a static frame.
- Native and old fallback captures retain the same occupied geometry and
  acceptable edge/color fidelity.
- Back/offscreen produces zero TGS Canvas updates and zero app VSync markers.
- Same-session visible trace/CPU is lower than the `@ohos.lottie` baseline;
  otherwise the native path is not accepted as the default.
- Focused contracts, shell smokes and clean build pass after the final source.

## Current disposition

The native renderer is retained as an opt-in experiment, not the production
default. The API 23 emulator proved correct geometry, color channels, looping,
and zero offscreen work, but the Canvas/ImageData upload used `3.736` host
cores versus the `2.371`-core `@ohos.lottie` witness. The next credible native
step is a direct surface/XComponent path rather than another Canvas upload.

Visibility, the `fileId` cache and the admission budget above are independent of that experiment: they
apply to the `@ohos.lottie` production path as well.
