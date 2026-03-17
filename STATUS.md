# STATUS — Telegram-HarmonyOS

Snapshot date: 2026-03-18

## Current snapshot
- **Branch:** `dev`
- **Repo state:** working tree is **not clean** (media bubble interaction hotfix + seek wiring + animation bubble split pending commit)
- **Observed changes:** photo/video surface tap handlers, correct fileId routing for all media downloads, audio/voice onPlayToggle+onSeek wired to MediaPlaybackController with seekToProgress(), document preview URI fix (double file://), dedicated TgAnimationBubble atom (split from TgVideoBubble), motion transitions (press feedback, overlay fade/scale) across all media bubbles, audio seek bar smooth progress animation
- **Primary app target:** HarmonyOS NEXT / API 22+
- **Local reference root:** `C:\Users\Kharki\Desktop\Telegram-HarmonyOS\рефенсы`

## What is working conceptually
- `EntryAbility` boots `AppCoreRuntime`
- TDLib bridge exists through NAPI
- Event pipeline is in place: gateway -> dispatcher -> normalizer -> store -> UI
- Auth/login shell exists
- Chat list page exists and uses `tg_ui` shell pieces
- Chat screen page exists and uses `TgChatTopBar`, `TgMessageRouter`, and `TgComposerInput`
- Contacts / Calls / Settings tabs exist
- Calls tab now has a **local real TDLib-backed data path** via `searchCallMessages`, but this Phase 4 pass is still **not device-runtime-verified**

## Current tg_ui inventory
- **27 atoms** (3 removed: TgSearchBar, TgSettingsSection, TgContactRow → replaced with stock ArkUI)
- **2 molecules**
- **34 demos** (orphaned demos for removed atoms still present)
- **37 spec files** (orphaned specs for removed atoms still present)

## Current active UI path
- Shell/chat runtime currently routes through:
  - `TgTabBar`
  - `TgChatListNavigationBar`
  - `TgChatRow`
  - `TgChatTopBar`
  - `TgMessageRouter`

## Stock ArkUI migration (2026-03-09)
- Replaced thin wrapper atoms with stock components used inline in pages:
  - `TgSearchBar` → stock `Search` in ChatListPage
  - `TgSettingsSection` → inline `Column` with tokens in SettingsPage
  - `TgContactRow` → inline `TgAvatar` + Row/Column in ContactsPage
- Kept atoms with real custom logic: TgTabBar, TgTopBar, TgCallRow, TgSettingsRow
- Smoke scripts updated to match new structure

## P0-P5 improvement plan (2026-03-09) — COMPLETE
- **P0 Avatar download:** full pipeline implemented — fileId stored in User/Chat, `DownloadFileCommand` + serialization, `FileNormalizer` handles `updateFile`, `filesReducer` updates photo paths, `downloadAvatars` usecase watches store and triggers downloads, wired in AppCoreRuntime. Fixed: direct response parsing was broken (`JSON.stringify(TdObject)` can't access private `rawJson`), switched to native TdObject accessors. Needs device verification.
- **P1 Sender names in groups:** `buildChatItemVO()` prepends "You: " / "firstName: " for group chat previews
- **P2 Checkmark order:** TgChatMeta renders status icon BEFORE time (iOS pattern: ✓✓ 17:47)
- **P3 Date format:** same-year dates now show `dd.MM` instead of `dd.MM.yy`
- **P4 TgTopBar actions:** Edit + Compose buttons added to ChatListPage TgTopBar
- **P5 Pinned separator:** `isLastPinned` detection + visual gap after last pinned chat

## Profile screen (2026-03-09)
- **TgProfilePage** created: large avatar, name, online status, phone, username, bio (users), description + member count (groups/channels), notifications toggle
- Full info pipeline: `getUserFullInfo` / `getSupergroupFullInfo` commands → serializer → direct response → `UserFullInfoEvent` / `ChatFullInfoEvent` → reducers update `User.bio`, `Chat.description`, `Chat.memberCount`
- Model extended: `User.bio`, `Chat.memberCount`, `Chat.description`, `Chat.supergroupId`
- Navigation: `onTitlePress` + `onAvatarPress` in TgChatScreenPage push to TgProfilePage via chatNavStack
- Registered in MainTabsPage `chatPageMap`
- Needs device verification

## Recent changes (2026-03-18, session 22)

### Tab bar contract cleanup: live Chats badge + state-driven selected pill
- **Chats badge path is live again:** `TgTabBar` now actually enables the unread badge on the Chats tab instead of carrying a dead `chatBadgeCount` prop and `buildBadge()` path.
- **Atom ownership cleaned up:** `TgTabBar` no longer writes `StorageKeys.MAIN_TAB_INDEX` into `AppStorage`; tab selection ownership remains in `MainTabsPage` / shell state only.
- **Selected pill is state-driven now:** removed the temporary `pillGlassActive` timer hack and made the selected capsule blur/border depend directly on `selectedIndex` + realtime blur mode, which avoids transient visual desync during fast tab switches.
- **Spec sync:** `entry/src/main/ets/ui/tg_ui/spec/TgTabBar.md` now explicitly states that page-level shell owns AppStorage/controller state and that the atom only emits selection callbacks.
- **Local verification pending:** run `scripts/smoke-build.ps1` and device-check Chats unread badge, repeated tab switching, and selected-pill consistency.

## Recent changes (2026-03-18, session 23)

### Tab bar material polish: stronger capsule body + tab-specific glass colors
- **Tab bar glass is now tuned independently from other chrome:** introduced dedicated `tab_bar_glass_bg` and `tab_bar_edge_highlight` resources instead of reusing the generic glass colors that also affect filter/composer/top-bar surfaces.
- **Material body strengthened:** the tab bar capsule background alpha and selected pill alpha are slightly higher now, so the island reads as a real object over busy content instead of only as border + shadow.
- **Micro hierarchy polish:** the tab content now uses a small selected/unselected opacity+scale difference and lighter unselected label weight, which gives the selected tab a clearer premium focus without changing the shell contract.
- **Token sync:** `TgUiTokens` now includes tab-bar-specific inner padding, pill border width, shadow tuning, and selected/unselected content scale-opacity values.
- **Local verification pending:** device-check light/dark backgrounds, selected/unselected readability, and whether the stronger material still feels glass-like rather than opaque.

## Recent changes (2026-03-14, session 8)

### Bubble improvements: GIF, reply quotes, meta overlay, avatars, wider bubbles
- **Wider bubbles:** `BUBBLE_MAX_WIDTH_RATIO` 0.75 → 0.85 (iOS `freeMaximumFillFactor = 0.85`)
- **Avatars on incoming group messages:** iOS pattern — 34vp avatar + 4vp gap, ALWAYS reserved for incoming group messages (invisible spacer when avatar not shown). Avatar shows on last message in each sender group. Tokens: `MSG_AVATAR_SIZE`, `MSG_AVATAR_GAP`, `MSG_AVATAR_FONT_SIZE`.
- **Media sizing fix:** media atoms now receive `maxBubbleWidth()` (containerWidth minus avatarInset, times ratio) with `maxWidthRatio: 1.0` — prevents overflow beyond bubble.
- **GIF auto-play:** `TgVideoBubble` gained `hidePlayButton` param. `TgMessageRouter` sets it for `animation` contentType — GIFs play without play button overlay.
- **Reply snippet background:** `TgReplySnippet` gained `bgColor()` + `borderRadius` — quotes have subtle tinted background inside bubbles. Tokens: `REPLY_SNIPPET_BG_INCOMING`, `REPLY_SNIPPET_BG_OUTGOING`, `REPLY_SNIPPET_BG_RADIUS`.
- **Meta overlay on visual media (iOS pattern):** photo/video/animation without caption — time + checkmarks overlay on bottom-right with `rgba(0,0,0,0.4)` pill + borderRadius(10). With caption — meta below caption.
- **TgMessageMeta overlayMode:** white text/icons on dark overlay for media bubbles. Failed status stays red.
- **Photo/video viewer pages:** `TgPhotoViewerPage` (pinch-to-zoom Matrix4 + PanGesture drag-to-dismiss), `TgVideoPlayerPage` (ArkUI Video + custom controls). Both via `bindContentCover`.
- **Bubble colors aligned to iOS:** outgoing `#EFFFDE` → `#E1FFC7` (light), incoming dark `#1E2C3A` → `#182533`.
- **ChatTimelineVO avatar data:** populates `showAvatar`, `avatarImageSrc`, `avatarInitials`, `avatarColorIndex` from User/Chat photo paths.
- Needs device verification.

## Recent changes (2026-03-14, session 9)

### Bubble stabilization pass: avatar lane, clipping, inline meta, regular width
- **Avatar lane reservation fixed:** `TgMessageRouter` now reserves the incoming group avatar lane from message-group context (`senderName`) instead of depending on hydrated avatar image data. This removes bubble width jumps when sender photo data arrives late.
- **Avatar fallback initials:** `ChatTimelineVO` now marks `showAvatar` for the last incoming message in a sender group even when photo data is missing, and `TgMessageRouter` falls back to sender-name initials for the visible avatar chip.
- **Rounded media clipping fixed:** `TgPhotoBubble`, `TgVideoBubble`, router avatar images, and reply thumbnails now use `.clip(true)` with rounded corners, matching HarmonyOS clipping guidance and preventing image bleed outside the radius.
- **Inline meta width tightened:** inline/overlay `TgMessageMeta` usage in `TgMessageRouter` now overrides `minWidth` and hidden reserve slots (`minWidth: 0`, `reserveTimeSlot: false`, `reserveStatusSlot: false`) so text/caption reserve width matches the rendered time/check cluster more closely.
- **Media overlay tokens:** bottom-right media meta pill spacing/radius/background moved into `TgUiTokens` (`MSG_MEDIA_META_OVERLAY_*`) instead of hardcoded numbers.
- **Regular-width bubble behavior:** `TgUiTokens` now exposes compact-vs-regular bubble width helpers (`0.85` compact / `0.65` regular, boundary `500`). Text/media/document/voice/reply atoms use the shared width helper, and photo/video bubbles now allow regular-width max dimensions (`440x440`) when the outer chat lane is wide enough.
- **Reply quote polish:** `TgReplySnippet` now clips thumbnails, aligns quote blocks from the top, and adds a lightweight quote mark accent for quote mode.
- **Local verification:** `./scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- Still needs device verification for real chat runtime.

## Recent changes (2026-03-14, session 10)

### Media caption geometry fix
- **Fixed clipped left edge on media captions:** `TgMessageRouter` now gives both visual-media stacks (with and without caption) an explicit width equal to the actual media bubble width instead of relying on a shrink-wrapped `Stack` child with `Text.width('100%')`.
- **Root cause:** in the media+caption path, `Stack({ alignContent: Alignment.BottomEnd })` had no explicit width, while the caption `Text` used `width('100%')`. ArkUI aligned the oversized child against the stack end edge, pushing the left side of the caption outside the bubble clip area.
- **Local verification:** `./scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- Still needs device verification on real media captions/channel posts.

## Recent changes (2026-03-15, session 11)

### Tall photo fit + bubble typography tightening
- **Tall photos no longer crop from the bottom:** `TgPhotoBubble` now fits image content inside the allowed media box with `ImageFit.Contain` and computes the final bubble width from the fitted media width instead of always using a max-width photo frame.
- **Caption/router width stays aligned with fitted photos:** `TgMessageRouter.photoVisualBubbleWidth()` mirrors the photo fit logic so caption/meta stacks use the same effective bubble width as the rendered image.
- **Message typography tightened for HarmonyOS runtime:** `TgUiTokens` message body and media-caption text were reduced from `17/22` to `16/21` (`fontSize/lineHeight`) to compensate for the optically larger HarmonyOS text metrics in chat bubbles.
- **Local verification:** `./scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- Still needs device verification for tall portrait photos, media captions, and overall text density in real chats.

## Recent changes (2026-03-15, session 12)

### Grouped photo albums + voice playback bubble path
- **Grouped media albums are now merged in timeline:** `media_album_id` is propagated through `MessageDto` → `AppState.Message` → `messagesReducer`, and `ChatTimelineVO` now collapses consecutive photo messages from the same album/sender into one `photoAlbum` entry instead of rendering separate single-photo bubbles.
- **New grouped-media atom:** `TgGroupedPhotoBubble` renders 2-up / 3-up / 4-up mosaics plus `5+` overflow overlay, with tokenized geometry and clipped rounded cells. `TgMessageRouter` now routes `photoAlbum` through this atom and forwards tapped cell paths to the page-level photo viewer.
- **Voice playback contract is now real:** `ChatTimelineVO` keeps `voicePath` as the raw local sandbox path for playback and propagates `voiceFileId`; `TgMessageRouter` passes play/download state into `TgVoiceBubble`; `TgChatScreenPage` owns a `VoicePlaybackController` that toggles download-vs-play behavior and tracks active playback progress.
- **HarmonyOS grounding:** `VoicePlaybackController` uses `@ohos.multimedia.media` `AVPlayer` with `fdSrc` (`@ohos.file.fs.openSync/statSync`) for local voice playback. This keeps `Image`/viewer paths on `file://` while voice playback stays on raw local paths, which matches HarmonyOS component vs media-player API expectations.
- **Voice bubble parity pass:** `TgVoiceBubble` now uses iOS-style duration-based width (`minVoiceWidth = 120`, duration-scaled up to lane max width), real 5-bit waveform decoding from TDLib/base64 payloads, and explicit download/play/pause icon states.
- **Controller race tightened:** `TgChatScreenPage` setup/teardown no longer lets an async release from an old `VoicePlaybackController` reset state after a new controller is already attached.
- **Local verification:** `./scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Still needs device verification:** grouped photo mosaics (`2/3/4/5+`), `+N` overlay tap, local voice playback/pause/resume, listened-state visuals, and on-demand voice download → play transition.

## Recent changes (2026-03-15, session 13)

### Media viewer opening path hardened for emulator/runtime
- **Removed `bindContentCover` dependency for chat media viewers:** `TgChatScreenPage` now renders `TgPhotoViewerPage` / `TgVideoPlayerPage` as direct full-screen overlays in the root `Stack` instead of relying on `bindContentCover(...)`.
- **Why this pass was needed:** the user reported that media viewers were not opening on the emulator even though tap callbacks and viewer pages were already wired.
- **Video tap target widened:** `TgVideoBubble` now opens the viewer from the whole media preview surface, not only from the small center play button. This also restores tap-to-open for animation/GIF previews where the play button is intentionally hidden.
- **Local verification:** `./scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Still needs emulator/device verification:** photo viewer open/dismiss, video viewer open/play/pause, GIF tap-to-open, and overlay z-order over the chat screen.

## Recent changes (2026-03-15, session 14)

### Empty-bubble fallback fix + document bubble polish
- **Unsupported secondary message types no longer render empty shells:** `TgMessageRouter.isTextLike()` now treats `unknown`, `location`, `contact`, and `poll` as text-fallback content, so messages that already carry DTO fallback text (`[Location]`, `[Contact]`, `[Poll]`, `[messageType]`) render inside the normal text bubble path instead of producing a blank bubble body.
- **Document bubble leading tile now mirrors Telegram file affordance more closely:** `TgDocumentRow` gained a file-extension badge path (`PDF`, etc.) inside the leading rounded tile when the row is not in download-progress mode, and document titles can now wrap to two lines instead of collapsing into an over-tight single-line row.
- **Layout cleanup:** the no-bubble-wrap `TgDocumentRow` content path now reuses the same leading tile builder directly instead of introducing an unnecessary nested `Row`, keeping the file-row geometry consistent between wrapped and unwrapped modes.
- **HarmonyOS grounding:** the row keeps `Text.maxLines(...)` + `TextOverflow.Ellipsis` on the weighted text column, which matches ArkUI guidance for truncating text inside adaptive horizontal layouts.
- **Local verification:** `./scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Still needs emulator/device verification:** real file rows (`pdf/doc/audio`) for extension badge/title wrapping balance, plus fallback rendering for location/contact/poll/unknown messages to confirm the previous “empty bubble” cases now show placeholder text instead of blank bodies.

## Recent changes (2026-03-15, session 15)

### Voice bubble meta width stabilization
- **Voice bubble time/meta is now width-locked to the voice bubble body:** `TgUiTokens` exposes a shared `resolveVoiceBubbleWidth(...)` helper, so both `TgVoiceBubble` and `TgMessageRouter` use the same duration-based bubble width contract.
- **Router fix:** `TgMessageRouter` now treats `voice` as a dedicated sub-path inside the non-visual media branch and renders the time/status row with an explicit inner width derived from the shared voice-width helper instead of a generic `width('100%')` row inside a shrink-wrapped bubble container.
- **Why this pass was needed:** user reported that the time for voice messages had shifted outside / away from the bubble, which is consistent with ArkUI shrink-wrap width ambiguity in the previous separate-meta-row layout.
- **Local verification:** `./scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Still needs emulator/device verification:** incoming/outgoing voice bubbles, short vs long durations, and group-chat voice rows with sender name / reply snippet to confirm the time cluster now stays visually inside the bubble bounds.

## Recent changes (2026-03-15, session 16)

### Channel text-bubble width parity pass
- **Channel posts no longer reserve the group avatar lane by default:** `ChatTimelineVO` now computes an explicit `reserveAvatarLane` flag, enabled for groups/supergroups but disabled for channels, and `TgMessageRouter` uses that flag instead of inferring the lane from `senderName`.
- **Why this pass matters:** the previous router logic reserved `34 + 4` avatar width for any incoming message with a sender name, which made many channel bubbles narrower than iOS even when no avatar was actually shown.
- **Text wrapping quality tightened:** `TgMessageBubbleBase` and media-caption text paths now use ArkUI `lineBreakStrategy(LineBreakStrategy.HIGH_QUALITY)` on top of the existing word-break rules, aiming for less greedy wrapping and a closer visual rhythm to iOS text layout.
- **Diff stability:** `ChatTimelineDataSource` now includes `reserveAvatarLane` in row equality, and `TgChatScreenPage` forwards the new flag into `TgMessageRouter`.
- **HarmonyOS grounding:** ArkUI docs note that `lineBreakStrategy` affects line wrapping when `wordBreak` is not `BREAK_ALL`; this pass keeps `BREAK_ALL` only for forced long-token cases and upgrades normal text/caption wrapping quality instead of switching to a harsher break mode.
- **Local verification:** `./scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Still needs device verification:** broadcast/channel posts, long mixed-language text bubbles, and media captions to confirm bubbles expand more like iOS and stop wrapping early due to the previously hidden avatar lane.

## Recent changes (2026-03-15, session 18)

### Dedicated instant-video bubble for `videoNote`
- **`videoNote` no longer reuses the rectangular video bubble path:** `TgMessageRouter` now routes `videoNote` through a dedicated `TgInstantVideoBubble` atom and a separate router branch without the generic rectangular media-shell background.
- **New atom:** `entry/src/main/ets/ui/tg_ui/atoms/TgInstantVideoBubble.ets` renders a circular media surface with a centered play affordance, thumbnail-first preview fallback, and an in-circle duration badge.
- **iOS-like sizing contract:** `TgUiTokens` now exposes dedicated instant-video tokens plus `resolveInstantVideoBubbleSize(...)` with compact/regular targets `212 / 240` and a safe minimum clamp.
- **Spec + demo added:** `entry/src/main/ets/ui/tg_ui/spec/TgInstantVideoBubble.md` and `entry/src/main/ets/ui/tg_ui/demos/TgInstantVideoBubbleDemo.ets`.
- **HarmonyOS grounding:** the new atom uses rounded/circular clipping with `.clip(true)` in line with ArkUI clipping guidance, avoiding the old bleed/rectangular-corner artifact path.
- **Why this pass matters:** device feedback said special videos still looked unlike iOS even when previews/layout were otherwise correct; the old router kept wrapping `videoNote` inside the rectangular visual-media shell.
- **Local verification:** `powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Still needs device verification:** round `videoNote` bubble shape, preview visibility before full download, tap-to-open after pending download, and sender/reply/caption compositions for instant-video rows.

## Recent changes (2026-03-15, session 19)

### Album photo viewer now supports gallery paging
- **Album taps now open a gallery instead of a single detached photo:** `TgChatScreenPage.openPhotoViewer(...)` now accepts the whole album path list, normalizes out empty placeholder cells, stores the selected index, and passes gallery state into the fullscreen photo viewer overlay.
- **`TgPhotoViewerPage` now has a gallery mode:** it accepts `photoPaths` + `initialIndex` and uses ArkUI `Swiper` with `index(...)`, `onChange(...)`, `indicator(false)`, and `loop(false)` to page horizontally between album photos.
- **Single-photo path is preserved:** when there is only one photo, the old pinch-to-zoom + pan + vertical-drag-dismiss path still runs unchanged.
- **Viewer chrome for galleries:** the fullscreen overlay now shows an in-view counter (`current / total`) for albums while keeping the existing close button / caption shell.
- **Why this pass matters:** grouped album bubbles already existed, but tapping them still opened only one image with no way to move across the rest of the album, which was the main remaining gap after grouped-photo support landed.
- **HarmonyOS grounding:** this patch uses ArkUI `Swiper`'s `index` + `onChange` contract for deterministic horizontal page switching in fullscreen media UI.
- **Local verification:** `powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Still needs device verification:** horizontal paging across 2/3/4/5+ albums, correct initial page when tapping any album cell, behavior with partially downloaded albums (empty cells filtered out), and single-photo zoom/dismiss path after the gallery refactor.

## Recent changes (2026-03-15, session 20)

### Dedicated audio/music bubble path
- **`audio` no longer reuses the generic document bubble:** `TgMessageRouter` now routes `audio` through a dedicated `TgAudioBubble` atom instead of `TgDocumentRow`.
- **New atom/spec/demo:** added `entry/src/main/ets/ui/tg_ui/atoms/TgAudioBubble.ets`, `entry/src/main/ets/ui/tg_ui/spec/TgAudioBubble.md`, and `entry/src/main/ets/ui/tg_ui/demos/TgAudioBubbleDemo.ets`.
- **VO/runtime plumbing:** `ChatTimelineVO` now carries `audioDuration`, `audioTitle`, and `audioPerformer`; `ChatTimelineDataSource` diffs them; `TgChatScreenPage` forwards them into the router.
- **Tap contract improved:** if the audio file is not local yet, tap still triggers `downloadFile`; if it is already local, `TgChatScreenPage` now opens it via Ability Kit `startAbility` with `ohos.want.action.viewData` using the existing `file://...` URI plus MIME type.
- **Visual contract:** audio bubbles now use a round play/download affordance plus title/performer-meta rhythm instead of a document extension tile, which is closer to Telegram music bubbles than the old file fallback.
- **HarmonyOS grounding:** this pass uses the documented `startAbility({ action: 'ohos.want.action.viewData', uri, type, flags })` pattern for opening local files in another app and keeps media URIs in the `file://bundle/path` form required by that API.
- **Local verification:** `powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Still needs device verification:** downloaded music files should open correctly from the chat bubble, undownloaded ones should trigger download only, and long track/performer strings should ellipsize cleanly without regressing bubble width.

## Recent changes (2026-03-16, session 21)

### Reference-driven audio/file bubble rewrite
- **Refs rechecked before changing the atoms:** Telegram iOS `ChatMessageInteractiveFileNode.swift` and Android `AudioPlayerCell.java` / `SharedDocumentCell.java` all point to the same visual rule: file/audio bubbles are organized around a **dominant primary control area**, not around a subtle chip attached to a mostly flat tile.
- **Why the previous pass was not enough:** emulator feedback said audio/file bubbles still looked unchanged, which matched the refs — the earlier square-tile + small-chip pass was too soft to materially change the perceived hierarchy.
- **`TgAudioBubble` rewritten to a control-first composition:** the leading affordance is now a prominent `44vp` primary control with ring-progress / spinner / play-download states, while the text stack is `title (up to 2 lines) -> performer/fallback -> duration/size/status`.
- **`TgDocumentRow` rewritten around a stronger leading tile:** the file tile is now `48vp`, uses an in-tile ring progress / spinner / extension face, and keeps the secondary action chip visually separate from the identity tile so document rows scan faster.
- **Integration safeguard:** `TgMessageRouter` already routes `document` payloads with `mimeType = audio/*` through `TgAudioBubble`, so the rewrite is visible even for real-world audio files that do not arrive as TDLib `messageAudio`.
- **Local verification:** `powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Still needs device verification:** real `audio/*` documents, real file rows under download progress, and the optical strength of the new primary-control hierarchy in incoming/outgoing chat bubbles.

## Recent changes (2026-03-15, session 17)

### P0 media reliability pass: special-video previews, pending open, resilient albums
- **Animation / videoNote previews now use real thumbnail fields:** `MessageDto.parseMessageContent(...)` now fills `videoThumbPath` / `videoThumbFileId` for both `messageAnimation` and `messageVideoNote`, so these special media types no longer depend on the full media file path just to show a preview.
- **Timeline VO now propagates special-video download/open contract:** `ChatTimelineVO` maps `animation` and `videoNote` into the shared video lane with explicit `videoFileId` plus thumbnail-first preview fallback (`videoThumbPath` first, full local media path second).
- **Photo albums no longer collapse just because some cells are still not local:** `buildPhotoAlbumEntry(...)` now preserves every album slot even when a given cell currently has an empty local URI, allowing `TgGroupedPhotoBubble` placeholders to keep the album grouped instead of degrading to a single photo bubble.
- **Video tap now supports on-demand open:** `TgChatScreenPage` keeps a pending video-open latch (`fileId + caption + thumb`) and, when the user taps a video/GIF/videoNote without a local full file yet, it triggers `downloadFile`, waits for the timeline/store to expose the downloaded local path, and auto-opens the fullscreen player on the next rebuild.
- **Why this pass matters:** device feedback showed that some albums merged only partially, some videos did nothing on tap, and special media often had no preview despite otherwise correct bubble layout.
- **Local verification:** `powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`; post-build cleanup still warns if DevEco keeps the generated HAP file locked, but the assemble/smoke result is successful).
- **Still needs device verification:** partial-download videos/GIFs/video notes should open after one tap, album bubbles should stay grouped with placeholder cells while media is still downloading, and special-video thumbnails should appear before the full file is local.

## Recent changes (2026-03-14, session 7)

### Media pipeline activation
- **Critical fix: `file://` URI conversion** in `ChatTimelineVO.ets` — all media paths (photo, video thumb, sticker, voice, document, animation, video note) now converted via `fileUri.getUriFromPath()` before passing to UI components. Without this, ArkUI `Image()` silently failed on raw sandbox paths.
- **New VO fields:** `documentPath`, `documentFileId`, `audioPath`, `audioFileId`, `videoFileId`, `voicePath` — enables on-demand download and future playback.
- **On-demand document download:** `TgDocumentRow` gained `documentPath` param + `onTap` event. Shows download icon when not downloaded, document icon when ready. Tap triggers `requestMediaDownload()` in `TgChatScreenPage`.
- **`requestMediaDownload()` in TgChatScreenPage:** sends `downloadFile` command to TDLib, handles direct response → `FileDownloadedEvent` → store update → UI re-render with file path.
- **TgMessageRouter:** new params `documentPath`, `documentFileId`, `audioPath`, `audioFileId`, `onMediaDownloadRequest` event.
- Auto-download (photos, stickers, voice, animations, video notes) was already wired via `DownloadMessageMediaUseCase` — now actually visible thanks to URI fix.
- Needs device verification for all media display and document download.

### Badge fix + styling
- **Badge not resetting fix:** removed premature `maybeMarkChatRead()` calls from `aboutToAppear`/`onActiveChatChanged`. Only store subscription calls it now (after `openChat` has been processed by TDLib).
- **Badge color alignment:** light `#0088CC` → `#0088FF` (iOS match), dedicated `unread_badge_muted` color `#B6B6BB` (iOS match, was using `text_secondary`).
- **Tab bar badge size:** 16→18vp, radius 8→9 (iOS: 18pt).

## Recent changes (2026-03-14, session 6)

### Chat opening performance + unread marker

- **List `initialIndex` for instant positioning:** `TgChatScreenPage` now uses `List({ initialIndex })` to render at the correct position immediately (unread boundary → saved scroll → bottom). No more scroll-from-top animation. Follows official HarmonyOS chat history pattern with `maintainVisibleContentPosition(true)`.
- **Race condition fix (OpenChatUseCase vs screen history load):** `HISTORY_INITIAL_DELAY_MS` changed from 0 to 600ms. Previously TgChatScreenPage grabbed the bucket lock before OpenChatUseCase could send `openChat` to TDLib, causing TDLib to return only locally cached messages (1-2 instead of full page). The delay lets OpenChatUseCase run first.
- **Placeholder release deadlock fix:** `INITIAL_HISTORY_PLACEHOLDER_RELEASE_COUNT` changed from 12 to 1. The old threshold blocked rendering for chats with <12 messages when `canLoadOlder=true`, preventing `onScrollIndex` from ever firing, which prevented pagination from triggering — eternal loading spinner.
- **Static list pagination recheck:** Added `schedulePaginationRecheck(PROGRAMMATIC_SCROLL_GUARD_MS + 50)` after all restore paths. After initial load with few messages, static lists don't re-fire `onScrollIndex` when the guard expires, so pagination needs an explicit recheck.
- **Sticky unread marker:** `stickyLastReadMessageId` captured at chat entry (from `chat.lastReadInboxMessageId` when `unreadCount > 0`). Used instead of live `unreadCount` for the entire chat session, so `markChatRead()` no longer causes the unread separator to disappear instantly. Reset on `aboutToDisappear`.
- **`computeInitialIndex()` method:** Priority: (1) unread boundary, (2) saved scroll position via `scrollPositionCache`, (3) bottom (newest messages). Called before `restoreScrollPosition()` in `rebuildTimeline`.
- **Removed `.opacity(prependScrollMask)` hack** from List — no longer needed with initialIndex approach.
- Needs device verification for all chat opening changes.

## Recent changes (2026-03-14, session 5)

### Glass system overhaul + composer fix + status bar fix
- **Status bar theme-aware icons:** `EntryAbility` now explicitly sets `statusBarContentColor` via `setWindowSystemBarProperties` — white for dark mode, black for light. Listens to `onConfigurationUpdate` for runtime theme changes. Fixes blurry/invisible battery/network/time icons.
- **Composer focus border fix:** `TgComposerInput` switched from `TextContentStyle.INLINE` (shows blue focus outline) to `TextContentStyle.DEFAULT` (no visual focus change). Added `.caretColor(TgUiTokens.COMPOSER_ACTION_ACTIVE)` for telegram blue cursor, `.borderRadius(0)` to remove TextArea's own border, explicit padding since DEFAULT has no internal padding.
- **Composer sizing aligned to iOS:** button 34→36, min capsule height 36→38, capsule radius 18→19, text padding top 6→5 / bottom 5→4, vertical inset 6→5, attach left inset 3→4 (all matching iOS `ChatTextInputPanelNode` values).
- **BlurStyle upgrade:** all glass elements switched from `BlurStyle.Thin`/`BlurStyle.Regular` to `BlurStyle.COMPONENT_REGULAR` (purpose-built for UI component blur). Tab bar pill uses `BlurStyle.COMPONENT_THIN`. Changed in `TgGlassPolicy` (all 5 methods) + `TgChatTopBar` capsules + `TgTabBar` pill.
- **Glass edge highlights:** added `glass_edge_highlight` color resource (`#55FFFFFF` light, `#33FFFFFF` dark). Applied as 0.75vp border to: composer capsule, chat top bar capsules, tab bar island, filter bar. Replaces old `separator` borders — mimics iOS glass catching light on edges.
- **Glass overlay alpha increased:** `glass_nav_bg` / `glass_tab_bg` alpha raised from 2% to 15-20% for visible frosted glass tint (was nearly invisible before).
- **Tab bar pill color:** changed from blue 9% to gray 10% (`tab_pill_bg`: light `#1A767680`, dark `#1AFFFFFF`). Tab bar pill now has glass blur (`COMPONENT_THIN`) + edge highlight border. Island radius kept at 999 (full capsule, matching iOS `backgroundSize.height * 0.5`).
- **Smoke test:** `bash ./scripts/smoke-ui-phase0.sh` ✅
- Needs device verification for all glass/blur/composer/status bar changes.

## Recent changes (2026-03-13, session 4)

### Refactor: hacky gestures → proper system APIs
- **Removed PanGesture swipe-to-reply** — was using shared `@State swipeOffsetX` causing all LazyForEach items to re-render on every gesture frame. Performance anti-pattern.
- **Replaced with LongPressGesture(300ms) → `promptAction.showActionMenu()`** — system-native action sheet with Reply + Copy buttons. No per-item state, no gesture conflicts.
- **Reply bar token alignment** — bar width/radius/gaps now use `TgUiTokens.REPLY_SNIPPET_*` tokens instead of hardcoded values. Height 45vp (iOS ReplyAccessoryPanelNode = 45pt). Author fontColor uses `REPLY_SNIPPET_BAR_INCOMING` for blue bar.
- **Member count localized** — group/channel subtitle now uses `localized($r('app.string.group_members_count'))` / `localized($r('app.string.subscribers_count'))` with `%s` replacement. Fallback labels also localized.
- **String resources added:** `action_reply`, `action_copy`, `subscribers_count`, `channel_label`, `group_label` in `string.json`.
- **Removed unused state vars:** `contextMenuMessageId`, `contextMenuText`, `contextMenuAuthor`, `contextMenuPreview`.
- Needs device verification: long-press action menu, reply flow, copy with toast, localized member count.

## Recent changes (2026-03-13, session 3)

### Interactive features + polish pass
- **Emoji media prefixes:** Chat list preview now shows `📷 Photo`, `📹 Video`, `📎 File`, `🎤 Voice message`, `📍 Location`, `📊 Poll`, `👤 Contact` instead of bracketed `[Photo]`, `[Video]` etc. Matches iOS Telegram style.
- **Group/channel top bar subtitle:** `updateChatTopBarData()` now shows localized member count for groups/channels. Typing indicator still overrides subtitle.
- **Sender name token consistency:** Fixed sticker and media bubble paths in TgMessageRouter — were using hardcoded `fontSize(13)/fontWeight(Medium)`, now use `MSG_SENDER_NAME_SIZE`(14)/`MSG_SENDER_NAME_WEIGHT`(Bold) matching the text bubble path.
- **`showMessageActions()`:** `promptAction.showActionMenu()` with Reply + Copy. Copy uses `pasteboard` API + toast feedback.
- **Reply bar:** above composer with author, preview, close button. `replyToMessageId` wired into `SendMessageParams`. Reply state resets after send.

## Recent changes (2026-03-13, session 2)

### iOS reference alignment — full pixel-level token pass
- **Deep comparison with iOS Telegram source** (ChatListItem.swift, ChatMessageBubbleItemNode, ChatMessageDateAndStatusNode, TabBarComponent.swift, PeerInfoHeaderNode, ChatTextInputPanelNode) produced 4 detailed reports in `docs/ai/`.
- **Unread badge color**: red `#FF3B30` → blue `#0088CC` (light), `#FF453A` → `#3390EC` (dark) — matches iOS accent color.
- **Chat list row**: left padding 16→10, height 72→76, title font 17→16, preview 1→2 lines, separator 1→0.5vp, title-preview gap 2→0, separator inset 80→82, author name color blue→black.
- **Message bubbles**: max width 85%→75%, padding H 10→11, meta font 12→11, sender name 13 Medium→14 Bold, reply title 13 Medium→14 Bold, reply preview 13→14, photo/video radius 17→16, document padding V 10→15. Added same-sender (2vp) vs different-sender (8vp) message spacing.
- **Date separator**: height 24→34, padding H 10→6.
- **Tab bar**: icon 23→24, badge font 11→13.
- **Composer**: text left padding 4→12, capsule radius 18→20.
- **Profile**: title 22 Bold→28 Medium, subtitle 15→17, online color blue→green, phone color→blue (accent), info labels 16→17/14.
- **Chat top bar**: subtitle online color blue→green.
- New color resource: `author_name` (black/white by theme).
- New tokens: `MSG_SENDER_NAME_SIZE`, `MSG_SENDER_NAME_WEIGHT`, `MSG_SPACING_SAME_SENDER`, `MSG_SPACING_DIFF_SENDER`, `CHAT_ROW_PREVIEW_MAX_LINES`, `COLOR_AUTHOR_NAME`.
- Local verification:
  - `bash ./scripts/smoke-ui-phase0.sh` ✅
  - `./scripts/smoke-build.ps1` ✅ (BUILD SUCCESSFUL)
- Still needs device verification.

## Recent changes (2026-03-13)

### TgChatTopBar glass contract restored
- `TgChatTopBar.ets` no longer hardcodes opaque fallback capsules while the passport claims glass behavior.
- Restored the actual glass path:
  - `glassMode` param,
  - realtime blur vs fallback background selection,
  - separate glass shell + specular highlight + content layers inside each capsule,
  - chat-top-bar geometry moved into `TgUiTokens`.
- `TgChatTopBarDemo.ets` now includes an explicit fallback-glass state, so the demo matches the passport's blur/fallback matrix again.
- Local verification:
  - `./scripts/smoke-build.ps1` ✅
  - `./scripts/smoke-ui-phase0.ps1` ✅

### TgChatRow preview prefixes now render like Telegram states
- `ChatItemVO` no longer flattens all preview states into one plain string. Drafts and group author prefixes are now carried separately from the preview body.
- `TgChatRow.ets` now renders preview prefixes as a dedicated left fragment:
  - `Draft:` uses the error/draft accent color,
  - group sender prefixes (`You:` / sender name) use the Telegram accent color,
  - the preview body keeps its own ellipsis and color contract.
- Group typing rows now also reuse the split-prefix path (`Alice` + `typing...`) instead of a single flat blue string, which is closer to the iOS `authorName + activity` rhythm.
- `TgChatRowDemo.ets` now includes explicit draft, typing, and group-author prefix cases, and the passport documents the new split-prefix contract.
- Local verification:
  - `./scripts/smoke-build.ps1` ✅
  - `./scripts/smoke-ui-phase0.ps1` ✅

### TgChatMeta / unread badge optical tuning moved closer to iOS
- Re-grounded the right meta cluster against `ChatListItem.swift`, `ChatListBadgeNode.swift`, and `ChatListStatusNode.swift`.
- Tuned the visible metrics toward the iOS values:
  - time text now uses a 14pt-style token instead of the smaller generic meta size,
  - unread badge text now uses a 14pt token and slightly tighter horizontal padding, closer to the iOS stretchable badge width formula,
  - pinned icon size was reduced so it no longer reads oversized against the unread badge lane,
  - status icon size was increased to better match the iOS right-cluster visual weight.
- Local verification:
  - `./scripts/smoke-build.ps1` ✅
  - `./scripts/smoke-ui-phase0.ps1` ✅

### Typing preview no longer overuses author/accent styling
- Re-checked iOS typing behavior against `ChatListTypingNode.swift` and the `inputActivitiesLayout(...)` call site in `ChatListItem.swift`.
- Important correction: current iOS chat-list typing text is rendered through `ChatListInputActivitiesNode` using the chat-list message text color, not the draft/error accent and not the group-author accent path.
- Local tg_ui path now follows that closer:
  - group typing rows go back to a single preview string (`Alice typing...`) instead of a split accent prefix,
  - typing preview body stays on the normal preview tone,
  - demo/spec were updated to reflect this.
- Local verification:
  - `./scripts/smoke-build.ps1` ✅
  - `./scripts/smoke-ui-phase0.ps1` ✅

### TgChatRow rhythm and separator optics tightened toward iOS
- Re-grounded row spacing against `ChatListItem.swift`:
  - iOS uses a compact vertical rhythm (`titleSpacing = -1`, `authorSpacing = -3`),
  - the separator lane starts around `80pt` on the standard 60pt-avatar path instead of following the full text-start inset.
- Local tg_ui tuning now reflects that better:
  - title/preview gap was tightened,
  - chat-row separator inset is now anchored to the iOS-like lane instead of the previous overly deep text-start position.
- Local verification:
  - `./scripts/smoke-build.ps1` ✅
  - `./scripts/smoke-ui-phase0.ps1` ✅

### TgChatRow typography no longer depends on generic screen title tokens
- Re-grounded row typography against the active iOS source:
  - `ChatListItem.swift` uses a `16/17`-scaled medium title and a `15/17`-scaled preview text.
- The HarmonyOS row now uses dedicated row-level typography tokens:
  - `CHAT_ROW_TITLE_FONT_SIZE = 16`
  - `CHAT_ROW_PREVIEW_FONT_SIZE = 15`
- This avoids coupling chat rows to the generic app-wide `FONT_TITLE_SIZE` token and makes the list typography closer to Telegram iOS without affecting other screens.
- Local verification:
  - `./scripts/smoke-build.ps1` ✅
  - `./scripts/smoke-ui-phase0.ps1` ✅

### TgTabBar cleanup after the reference correction
- Removed dead safe-area bookkeeping from `TgTabBar.ets`: the atom no longer computes/stores a bottom inset it never uses.
- Bottom safe-area ownership remains explicitly at the page level (`MainTabsPage` + `computeTabBottomInset()`), while the atom only adapts its capsule width from the live window width.
- `spec/TgTabBar.md` source mapping now points to the current active iOS files:
  - `TabBarComponent.swift`
  - `TabBarContollerNode.swift`
  - `TabBarNode.swift`
- Local verification:
  - `./scripts/smoke-build.ps1` ✅
  - `./scripts/smoke-ui-phase0.ps1` ✅

### TgComposerInput moved back to a controlled, tokenized contract
- `TgComposerInput` no longer owns draft text locally. The live chat screen now owns the composer draft and passes it down as a controlled `text` prop, which keeps the atom aligned with its passport and avoids hidden local-state drift.
- Added the optional emoji lane back into the unified capsule contract (`showEmojiButton`) and updated the demo/spec to show the real shell states again.
- Pulled the main composer geometry into `TgUiTokens` so the atom is no longer carrying a private block of hardcoded visual constants.
- HarmonyOS grounding applied in the atom:
  - `TextArea.style(TextContentStyle.INLINE)` for custom input-shell composition
  - `EnterKeyType.Send` + `onSubmit(..., SubmitEvent)` + `keepEditableState()` so send-style submit does not unnecessarily dismiss the keyboard
- Local verification:
  - `./scripts/smoke-build.ps1` ✅
  - `./scripts/smoke-ui-phase0.ps1` ✅
- Still needs device verification for:
  1. keyboard/focus feel on real device,
  2. emoji icon spacing inside the capsule,
  3. send/mic transition and draft clearing behavior in a live chat.

### Chat list interaction restored after integrated-header regression
- `TgChatListNavigationBar` now sets an explicit root height equal to `topInset + CHAT_LIST_NAV_TOTAL_HEIGHT`.
- Root cause: after moving to the new integrated header atom, the top overlay inside `ChatListPage` no longer had an explicit height, so in the `Stack` composition it could expand to the full screen and swallow list gestures/taps.
- Result: the Chats list should no longer become effectively non-clickable / non-scrollable underneath the header overlay.
- Local verification:
  - `./scripts/smoke-ui-phase0.ps1` ✅
  - `./scripts/smoke-build.ps1` ✅
- Still needs device verification on the Chats tab to confirm:
  1. the list scrolls normally,
  2. row taps open chats again,
  3. the integrated header still behaves visually as intended.

### TgTabBar corrected after deeper iOS reference check
- The previous same-day rewrite to a full-width bottom shelf was incorrect.
- After re-checking the current iOS refs, the active Telegram iOS implementation uses a centered glass capsule shell (`TabBarComponent` + `GlassBackgroundContainerView`) with bottom outer insets, not a full-width shelf.
- `TgTabBar` was corrected back toward that model:
  - centered capsule root,
  - blurred glass background,
  - inner per-tab highlight/lens behavior,
  - bottom safe-area handled outside the capsule by page margin/inset math.
- `MainTabsPage` again positions the custom bar above the bottom safe area, and `computeTabBottomInset()` was restored to reserve capsule height + safe area + breathing gap.
- Grounding:
  - iOS refs: `TabBarContollerNode.swift`, `TabBarComponent.swift`, `TabBarNode.swift`
  - HarmonyOS docs/patterns: custom overlaid chrome + bottom safe-area reservation via page content inset
- Local verification:
  - `./scripts/smoke-ui-phase0.ps1` ✅
  - `./scripts/smoke-build.ps1` ✅
- Still needs device verification for:
  1. capsule geometry vs Telegram iOS,
  2. correct bottom safe-area handling on gesture-navigation devices,
  3. unread badge placement and tap targets on all 4 tabs.

### Chat screen visual polish (reference-aligned)
- **Bubble tokens aligned to iOS/Android references:** radius 18→17 (Android default), padding H 12→10 / V 8→6 (iOS: 10-11/~6), max width ratio 0.80→0.85 (iOS compact), photo/video bubble radius unified to 17
- **Inter-message spacing reduced:** 8vp (4+4) → 3vp (1+2), closer to iOS ~2-3pt
- **TgChatTopBar glass fix:** `.clip(true)` + `.renderGroup(true)` on blur Columns in all 3 capsules (back, title, avatar) — fixes square blur visible behind rounded capsules (Lesson #43)
- **TgChatTopBar bottom padding:** 6vp breathing room between capsules and content; `computeTopBarHeight()` updated to include `TOP_BAR_BOTTOM_PADDING`
- **TgComposerInput rewrite (iOS-aligned):** unified single glass capsule `[📎 Message... ➤]` instead of separate attach + input capsules; max lines 6→12 (iOS); buttons 40→34vp inside capsule
- **LazyForEach prepend fix (Lesson #42):** `ChatTimelineDataSource` prepend path changed from bulk array replacement + batch notify to per-item `splice(0,0,item)` + `notifyDataAdd(0)` — matches official HarmonyOS example for `maintainVisibleContentPosition(true)`
- Needs device verification

## Recent changes (2026-03-12)

### Chat list header realigned to iOS-style integrated nav + search
- Added new atom `entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets` with:
  - centered title row,
  - intrinsic left `Edit` action,
  - right compose action,
  - integrated search lane inside the header surface.
- `ChatListPage` no longer composes `TgTopBar` plus a scrolling `Search` list item. It now offsets the list under a single integrated header, which is closer to iOS `ChatListNavigationBar` (`searchScrollHeight = 54.0`).
- Added tokenized metrics `CHAT_LIST_NAV_SEARCH_AREA_HEIGHT`, `CHAT_LIST_NAV_TOTAL_HEIGHT`, and `ICON_RES_EDIT`.
- Added `computeChatListTopBarHeight()` to keep `List.contentStartOffset(...)` aligned with the new header height.
- Added passport + demo:
  - `entry/src/main/ets/ui/tg_ui/spec/TgChatListNavigationBar.md`
  - `entry/src/main/ets/ui/tg_ui/demos/TgChatListNavigationBarDemo.ets`
- Smoke scripts updated to validate `TgChatListNavigationBar` instead of the old ChatList `TgTopBar + Search` assumption.
- Local verification:
  - `./scripts/smoke-build.ps1` ✅
  - `bash ./scripts/smoke-ui-phase0.sh` ✅
  - `./scripts/smoke-ui-phase0.ps1` ✅
- Still needs device verification on the chat list tab to confirm:
  1. `Edit` is no longer clipped in Russian,
  2. search visually belongs to the header instead of looking like a second strip,
  3. scroll-under-header behavior feels closer to Telegram iOS.

### TgChatTopBar centering fix
- `TgChatTopBar` content row no longer packs all capsules from the left. The layout now uses fixed left/right side capsules and a weighted center lane, which keeps the title capsule visually centered and the avatar anchored to the right edge.
- Title and subtitle text inside the center capsule are now centered as well, matching the component passport and the intended Telegram-style navigation balance.
- Triggering evidence: screenshot `C:\Users\Kharki\Pictures\Screenshot_2026-03-12T022356.png` showed the whole top bar cluster shifted left.
- Local verification: `./scripts/smoke-build.ps1` ✅, `bash ./scripts/smoke-ui-phase0.sh` ✅
- Still needs device verification on the chat screen itself.

### TgChatTopBar glass layering fix
- `TgChatTopBar` capsules now use a layered `Stack`: blur/tint/border background at the bottom, specular highlight in the middle, and icon/text/avatar content on the top layer.
- This fixes the previous composition where title/icon/avatar lived in the same node that owned the glass blur and top `overlay(...)`, which visually made the content look embedded into the glass instead of sitting above it.
- Grounding: local HarmonyOS blur API notes via `backgroundBlurStyle` docs/search + existing Telegram iOS navigation-bar visual principle (content over blur, not under highlight).
- Local verification: `./scripts/smoke-build.ps1` ✅, `bash ./scripts/smoke-ui-phase0.sh` ✅
- Still needs device verification on a dark chat background to confirm text/icon highlights no longer “shine through” the glass layer incorrectly.

### Chat history runtime stabilization (LazyForEach datasource + delayed edge recheck)
- `ChatTimelineDataSource` no longer mixes `DataChangeListener.onDatasetChange(...)` with `onDataAdd/onDataDelete/onDataChange`. The chat timeline now uses a single notification family only, which matches the ArkUI LazyForEach contract and removes the runtime error seen in HiLog: `onDatasetChange cannot be used with other interface`.
- `TgChatScreenPage` now guards pagination callbacks while `applyDiff()` is mutating the datasource, so `onScrollIndex` / `onDidScroll` signals triggered by ArkUI during prepend cannot recursively fire another `loadOlderMessages()` in the same update cycle.
- Post-load `recheckPaginationEdge()` is now deferred to the next tick via `schedulePaginationRecheck()`, instead of running immediately in the `loadOlder/loadNewer` promise `finally`. This avoids rechecking against stale pre-diff indices/counts before the scheduled timeline rebuild has applied the new batch.
- Grounding: local HarmonyOS SDK typings in `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\ets\component\lazy_for_each.d.ts` (`DataChangeListener`, `onDataAdd/onDataDelete/onDataChange/onDatasetChange`) and `...\component\list.d.ts` (`maintainVisibleContentPosition` note that prepend emits `onDidScroll` / `onScrollIndex`).
- Triggering evidence: device HiLog `C:\Users\Kharki\AppData\Local\Huawei\DevEcoStudio6.0\tmp\HiLog-Mate 80 Pro-All logs of selected app-[9918]com.telegram.harmonyos-DEBUG-1773260285706.txt`.
- Local verification: `./scripts/smoke-build.ps1` ✅, `bash ./scripts/smoke-ui-phase0.sh` ✅
- Still needs device verification on the reproduction chat to confirm the `Loading older messages...` storm and `Timeline rebuild failed` errors are gone.

### Big-chat open fast path (history first, peers after)
- `LoadChatHistoryUseCase` now dispatches the `getChatHistory` batch **before** hydrating missing sender users, so large chats no longer wait on a blocking pre-render `getUser` loop.
- Missing sender hydration now runs in **parallel chunks** (`6` at a time) and dispatches normalized user events in **one batched store update** instead of one dispatch per user.
- `selectChatMessages()` / `selectChatMessagesForChatView()` now memoize sorted arrays by the per-chat message-map reference, so user-only updates reuse the existing message order instead of re-sorting the whole chat every time.
- `TgChatScreenPage` store subscription now ignores updates that do not touch the active chat's messages/chat/users/typing state.
- Grounding: Android `MessagesController.putUsers/putChats` + cached sender lookup in `MessageObject`, iOS `MessageHistoryView` / `ChatController` history-view path.
- Local verification: `./scripts/smoke-build.ps1` ✅, `bash ./scripts/smoke-ui-phase0.sh` ✅
- Still needs device verification on a large group/channel history.

### Native List prepend stabilization
- `TgChatScreenPage` chat history `List` now uses HarmonyOS native `maintainVisibleContentPosition(true)` for LazyForEach prepends.
- Removed the custom prepend `scrollToIndex` compensation hot path; it was still fighting ArkUI layout and could visibly yank the viewport during older-history insertion.
- Prepend path now only guards against pagination cascades while ArkUI performs the native visible-position preservation.
- Official grounding available in local HarmonyOS SDK typings: `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\ets\component\list.d.ts` (`maintainVisibleContentPosition`, since 12).
- Local verification: `./scripts/smoke-build.ps1` ✅, `bash ./scripts/smoke-ui-phase0.sh` ✅
- Still needs device verification on the exact reproduction chat.

## Recent changes (2026-03-11)

### TgTabBar Android-style rewrite
- **Ring → Pill highlight**: full-tab capsule bg (9% alpha telegram_blue), scale 0.6→1.0 + opacity animation (320ms EaseOut)
- **Sizes aligned to Android**: island height 50→56vp, icon 23→24vp, text 10→12vp, font weight Normal→Bold on selection
- **Tokens**: removed 5 ring tokens, added `TAB_BAR_PILL_BG`, `TAB_BAR_PILL_ANIM_DURATION`
- **Colors**: `tab_selection_ring_bg` + `tab_selection_ring_stroke` → `tab_pill_bg` (light `#170088CC`, dark `#173390EC`)
- **Padding 8vp** inside island, `clip(false)` for badge overflow
- Reference: Android `GlassTabView.java` + `MainTabsLayout.java`

### Pagination aligned to Android/iOS patterns
- **Older trigger threshold**: 10 → 25 items (Android: 25 when scrolling)
- **Newer trigger threshold**: 6 → 5 items (iOS: 5)
- **Latch system removed**: replaced with simple `!isLoading` guard (Android pattern). Removed `olderPaginationEdgeArmed`, `newerPaginationEdgeArmed`, `refreshPaginationEdgeLatches()`. `recheckPaginationEdge` is now the sole continuous-loading mechanism.
- **Reason fix**: scroll pagination now uses `reason: 'default'` instead of `'restore'`

### Scroll compensation fix v2 (prepend flash elimination)
- **Pre-capture indices + yOffset BEFORE `applyDiff`**: prevents stale/double-counted `lastVisibleStartIndex` if `onScrollIndex` fires during `notifyBatchChange`
- **Viewport freeze**: `scrollTo({ yOffset: savedYOffset, animation: false })` called immediately after `applyDiff` to anchor viewport before ArkUI layout pass — prevents flash frame where prepended items are briefly visible
- **`contentStartOffset` gap preservation**: when user was near top (yOffset < topBarTotalHeight), `scrollToIndex` with `extraOffset: LengthMetrics.vp(gap)` preserves the top bar visual gap
- **Cascade block**: `blockAutoPaginationUntilUserScroll = true` during prepend — prevents repeated load→flash→load chains that the old 320ms guard couldn't stop
- Reference: Android `ChatActivity.scrollToPositionWithOffset()`, iOS `stationaryItemRange`
- Needs device verification

### Chat older-history prepend autoscroll fix
- `TgChatScreenPage` prepend compensation now performs the viewport freeze + anchor `scrollToIndex` **synchronously in the same turn as `applyDiff()`**
- Removed the delayed second-pass prepend compensation from the hot path; the old deferred `setTimeout(16ms)` re-scroll was the remaining source of visible jump/autoscroll while older messages were inserted above the viewport
- Grounding: HarmonyOS docs `Maintaining the Scroll Position When Off-Screen Data Changes`, Android `LinearLayoutManager.scrollToPositionWithOffset()`, iOS `stationaryItemRange`
- Local verification: `bash ./scripts/smoke-ui-phase0.sh` ✅, `./scripts/smoke-build.ps1` ✅
- Still needs device/runtime verification on a long chat

## Recent changes (2026-03-10)

### Unified bubble container (sender name + time INSIDE bubbles)
- **TgMessageRouter** rewritten: now unified bubble container with bg/radius, renders sender name, reply snippet, content (via noBubbleWrap atoms), and TgMessageMeta all inside a single bubble
- Text path uses Stack(BottomEnd) for shrink-wrap + meta overlay (no width('100%') forcing max width)
- Media path: content atoms set fixed width, Column adapts
- Sticker path: no bubble bg, content + meta stacked
- All bubble atoms (TgPhotoBubble, TgVideoBubble, TgDocumentRow, TgVoiceBubble, TgMessageBubbleBase) gained `@Param noBubbleWrap`
- TgChatScreenPage simplified: sender name, reply, meta all passed to TgMessageRouter

### Nav lock fix (double-tap to open chat)
- ChatListPage.onPageShow(): unconditionally clears nav lock (was checking expired time, always failing)
- TgChatScreenPage.aboutToDisappear(): removed duplicate CHAT_NAV_LOCK_UNTIL set (handleBackPress already sets it)

### Composer safe area fix
- Removed double bottom inset: `.margin({ bottom: bottomOverlayInset })` → `.padding({ bottom: bottomOverlayInset })`
- Added `SafeAreaEdge.BOTTOM` to expandSafeArea so page bg extends behind nav bar
- Composer now floats as capsule island above navigation indicator

### QR Login (from earlier in session)
- Full pipeline: PhoneInputPage button → requestQrCodeAuthentication → QrLoginPage with QRCode component
- AppState extended with `waitQrCode` status + `qrCodeLink`

### NAPI batch fix (THREAD_BLOCK_6S)
- C++ receive loop: batches up to 50 responses per napi_call_threadsafe_function
- ArkTS dispatchBatch() parses JSON array

### Group/Channel profile
- TgProfilePage extended for groups/channels: description, invite link, member/admin count
- loadProfileInfo extracts invite_link (nested chatInviteLink) + administrator_count

## What is clearly in progress right now
- Latest local patch from 2026-03-09: fixed chat-list blank-cell regression by restoring stable `LazyForEach` identity (`chatId` key + per-chat `reuseId`), removing debug render noise from `TgChatRow`/`ChatListPage`, and guarding chat title updates against empty overwrite in normalizer/reducer.
- Latest local UX fallback from 2026-03-09: private chat row title can now fall back to `user.phoneNumber` before `Unknown`, reducing empty/placeholder rows for incomplete contact profiles.
- Latest local pagination fix from 2026-03-09: `TgChatScreenPage` now auto-rechecks pagination edge after each completed load via `recheckPaginationEdge()`. Fixes iOS-style continuous older/newer loading — no longer requires scroll-away-and-back to trigger the next batch. Added `lastVisibleEndIndex` tracking for accurate bottom-edge detection.
- Runtime stabilization around:
  - `AppCoreRuntime`
  - `AppStore`
  - `loadChats`
  - `loadChatHistory`
  - `openChat`
  - `ChatListPage`
  - `TgChatScreenPage`
- Latest log-driven runtime fix target: prevent `TgChatScreenPage` unread-boundary / saved-index restore from triggering automatic history pagination before the user actually scrolls.
- Latest verified outcome from 2026-03-08 HiLog: restore-triggered and edge-pinned pagination storms are closed in `TgChatScreenPage`; the loudest remaining runtime noise is now incomplete sender hydration during history loads.
- Latest local patch from 2026-03-08: `LoadChatHistoryUseCase` now allows a full default history page worth of missing sender hydrations (`MAX_MISSING_USER_HYDRATION_PER_LOAD = 64`) before dispatching the history batch, to reduce residual `Message references non-existent user` soft invariants.
- Latest log-driven root cause from 2026-03-08 HiLog: direct TDLib `user` payloads could parse nested `profile_photo.id` instead of the real top-level `user.id`, which explains bogus `getMe resolved` values and why repeated `getUser` calls still left sender users missing in store.
- Latest local patch from 2026-03-08: `TdObject` now exposes top-level int64 extraction, and user parsing / `getMe` resolution switched to `getTopLevelNumber('id')` so hydrated users land under the correct store key.
- Latest verified runtime outcome from the 2026-03-08 `[27274]` HiLog: `Message references non-existent user = 0`, `lastMessage is older than newest message in map = 0`, `Loading older/newer messages = 0`.
- New follow-up finding from the 2026-03-08 `[8081]` HiLog: a default `getChatHistory` open can return a **very short non-zero batch** (observed `1 events`) while older history may still plausibly exist, so treating `messageCount < limit` as end-of-history is too aggressive for TDLib.
- Latest local runtime patch from 2026-03-08: `LoadChatHistoryUseCase` now keeps pagination progress-based instead of `messageCount >= limit`-based, and performs one controlled `older` top-up when the first default history batch is suspiciously tiny.
- Latest local UX polish from 2026-03-08: tiny initial history batches are now **deferred from UI dispatch** until the controlled top-up finishes, and `TgChatScreenPage` shows a loading placeholder instead of a misleading temporary `No messages yet` / one-message state while the initial timeline is still settling.
- Latest follow-up from the 2026-03-08 `[21342]` HiLog: one controlled top-up is still not always enough — some chats can progress from `1` to only `2` visible messages before older history is still available.
- Latest local refinement from 2026-03-08: initial history top-up is now **bounded multi-step** (up to 3 older top-ups while progress continues), and the chat screen keeps the loading placeholder until the initial timeline reaches a reasonable size or older history is actually exhausted.
- Immediate operator focus has moved from **Phase 1 runtime bug-hunting** to **Phase 2 batch consolidation**; current patchset boundary is documented in `TASKS/CURRENT_PATCHSET_BOUNDARY.md`.
- Phase 3 verification gate has now been attempted on the current batch:
  - `./scripts/smoke-ui-phase0.ps1` ✅
  - `bash ./scripts/smoke-ui-phase0.sh` ✅
  - `./scripts/smoke-build.ps1` ✅ now finds DevEco hvigor automatically and completes successfully
- Latest local Phase 4 patch from 2026-03-08: `CallsPage` no longer renders a hardcoded placeholder; it now loads real recent calls through TDLib `searchCallMessages`, paginates with `next_from_message_id`, and hydrates missing peers via direct `getChat` / `getUser` response normalization.
- Latest local verification from 2026-03-08 for the Phase 4 patch:
  - `./scripts/smoke-ui-phase0.ps1` ✅
  - `bash ./scripts/smoke-ui-phase0.sh` ✅
- Latest local build verification from 2026-03-08:
  - `./scripts/smoke-build.ps1` ✅
  - discovered hvigor wrapper: `C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat`
- Current operator focus has moved beyond the Phase 3 gate into **Phase 4 — Real Calls implementation**, but this new calls path still needs **device HiLog verification**.
- A batch of tg_ui specs/demos/components is present but still untracked in git.
- High-level docs (`README.md`, `docs/ai/AI_MEMORY.md`, `docs/ai/UI_MIGRATION_PLAN.md`) also have local edits.

## Risks / caveats
- This is an active refactor branch, not a clean release snapshot.
- Some older docs contain historical names (`AppTopBar`, `AppTabBarItem`, older feature-flag wording); prefer current runtime path over stale names.
- `scripts/smoke-ui-phase0.ps1` and `scripts/smoke-ui-phase0.sh` were re-run successfully on **2026-03-08** after the latest sender-hydration patch.
- Local HarmonyOS smoke build is now **verified** on **2026-03-08** through the DevEco-installed wrapper at `C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat`.
- The new short-initial-history fix is only **local-script/build-verified** so far; a fresh device HiLog is still required to confirm that chats with previously tiny first batches now expand correctly on first open.
- The new Phase 4 calls path is only **local-smoke-verified** so far; a fresh device run / HiLog is still required to confirm `searchCallMessages` payload shape and row hydration behavior.
- TDLib prebuilts and local `ConfigLocal.ets` remain external prerequisites.

## Read order for a new contributor/agent
1. `AGENTS.md`
2. `STATUS.md`
3. `DECISIONS.md`
4. `ARCHITECTURE.md`
5. `TASKS/AGENT_EXECUTION_PLAN.md`
6. `TASKS/TODO.md`
7. `TASKS/LESSONS.md`
8. Deep docs under `docs/ai/`

## Recent changes (2026-03-16, session 22)

### Media transfer state foundation + visible download indicators
- **Unified file transfer state added to AppState:** `AppState.files.transfers` now keeps `fileId -> transfer` metadata (`active/completed/path/size/progress-related fields`) instead of relying only on a page-local pending set.
- **`updateFile` now feeds UI transfer state:** `FileNormalizer` emits a new `fileTransferUpdated` event on every TDLib `updateFile`, and `filesReducer` stores that transfer state while still applying `fileDownloaded` local paths into users/chats/messages.
- **Photo bubbles now finally expose transfer UX:** `TgPhotoBubble` gained explicit `hasLocalPhoto + isDownloading + downloadProgress`, so photo thumbs/full-photo auto-download can show a visible overlay instead of silently loading in the background.
- **Video / instant-video overlays upgraded:** `TgVideoBubble` and `TgInstantVideoBubble` now show progress-aware download overlays (spinner + percent when available) instead of a boolean-only pending state.
- **Document/audio/voice now consume real progress:** `TgDocumentRow` now uses live reducer-fed `downloadProgress`, `TgAudioBubble` shows download meta/progress bar, and `TgVoiceBubble` reflects transfer progress in its trailing label while downloading.
- **Timeline/runtime wiring completed:** `ChatTimelineVO`, `ChatTimelineDataSource`, `TgMessageRouter`, and `TgChatScreenPage` now propagate transfer state/progress from store to bubbles, while still preserving the page-owned dedupe latch for instant on-tap pending feedback.
- **Reducer safety fix:** `filesReducer.cloneMessageWithContent(...)` now preserves `mediaAlbumId` when file paths are patched into message content.
- **Local verification:** `powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Still needs emulator/device verification:** photo auto-download overlay visibility, video/animation/videoNote percent overlays, document/audio/voice progress behavior, and follow-up visual polish pass for audio/file bubble aesthetics.

## Recent changes (2026-03-16, session 23)

### Audio/file bubble visual polish pass
- **`TgAudioBubble` no longer reads like a document row:** the leading affordance is now a square media tile with a small play/download overlay chip in idle states, while active downloads reuse the tile center for spinner/percent feedback.
- **Audio hierarchy is clearer:** music bubbles now render `title` → `performer/fallback` → smaller duration/size/status line, which better matches the dedicated Telegram music-message family.
- **`TgDocumentRow` leading cluster is richer:** idle file bubbles keep the extension label in the main tile but now add a small action chip for open/download affordance, making the file state easier to parse at a glance.
- **Reference grounding:** this pass was based on the Telegram iOS interactive file/music node pattern where the leading media/file control is a composed cluster, not a flat single icon block.
- **HarmonyOS grounding:** the pass stays within ArkUI `Stack` + `Row/Column` composition and the existing `Progress`/loading control model already verified in this repo.
- **Local verification:** `powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Still needs emulator/device verification:** whether the new audio tile / file action-chip composition feels sufficiently close to Telegram on real message histories, and whether any remaining drift is now limited to token tuning rather than missing state/structure.

## Recent changes (2026-03-16, session 24)

### Integration fix for audio-like documents + stronger visual contrast
- **Likely runtime cause of “nothing changed” identified:** real chats can contain audio payloads that still travel through the `document` content path with `mimeType = audio/*`, so they were bypassing the dedicated `audio` router branch entirely.
- **Router fallback added:** `TgMessageRouter` now routes `contentType = 'document'` + `mimeType.startsWith('audio/')` through `TgAudioBubble` while preserving the existing document open/download tap contract.
- **Visual contrast strengthened:** audio tile icon tint and action-chip sizes were increased, and document extension labels now use the stronger icon tint so the leading cluster reads more clearly at a glance.
- **Local verification:** `powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Still needs emulator/device verification:** whether the user-visible audio cases were indeed document-backed audio payloads and whether this router fallback now makes the visual delta finally obvious in real chats.

## Recent changes (2026-03-15, session 21)

### Media download policy tightened + pending-state UI parity pass
- **Broad auto-download was intentionally reduced:** `DownloadMessageMediaUseCase` now limits background fetches to `photoThumb`, full `photo`, `videoThumb`, and `sticker`. Voice notes, GIF/animation files, and video notes now stay on-demand instead of being fetched in the background.
- **On-demand spam guard added:** `TgChatScreenPage.requestMediaDownload(...)` now deduplicates repeated taps with a page-owned pending-file set, directly addressing the 2026-03-16 `[31799]` HiLog pattern where one file ID could trigger many repeated `downloadFile` requests before the local path appeared.
- **Pending download UI is now explicit in chat bubbles:** document/audio/voice/video/instant-video atoms now render an indeterminate loading control while a file is pending, and video/instant-video bubbles fall back to a centered download affordance when only the preview/thumbnail is local.
- **Document rows now behave like real files:** downloaded document bubbles now open through Ability Kit `viewData`, instead of staying as download-only rows after the file becomes local.
- **Reference grounding:** this pass follows the Telegram iOS interactive media/file pattern where fetch/playback is surfaced through a prominent radial control, not a silent background transfer.
- **HarmonyOS grounding:** file opening remains on Ability Kit `startAbility` with `action = 'ohos.want.action.viewData'`, `uri`, `type`, and URI permission flags.
- **Local verification:** `powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Still needs device verification:** no-repeat `downloadFile` logging for repeated taps, spinner/download states for voice/audio/document/video/videoNote bubbles, document open after download, and the reduced background-download footprint in voice/GIF/videoNote-heavy chats.
