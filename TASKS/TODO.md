# TODO — observed current work

Last updated: 2026-03-18

This is a **working snapshot**, not a product roadmap. It is derived from:
- current git status on branch `dev`
- current repo docs
- current file layout

Canonical execution order for agents now lives in:
- `TASKS/AGENT_EXECUTION_PLAN.md`

## Active now

### 0aa. Device-verify tab bar badge + selected-pill cleanup (2026-03-18)
- **Evidence:** `TgTabBar` no longer mutates `AppStorage` directly, the Chats tab now actually passes `showBadge = true`, the selected pill blur/border is driven by `selectedIndex` instead of a temporary timer-gated `pillGlassActive` flash, and the island now uses tab-specific glass colors/material tokens plus a subtler selected-vs-unselected content scale/opacity split.
- **Current action:** verify on emulator/device:
  1. unread badge appears on the Chats tab when `totalUnread > 0`,
  2. badge clamps cleanly at `99+`,
  3. repeated fast tab switching does not produce stale glass flashes or selected-pill desync,
  4. tapping the already-selected tab still behaves normally and does not break `TabsController` state,
  5. tab selection continues to persist through the page-owned shell state only,
  6. light/dark tab bar material reads as a real glass capsule instead of an almost-invisible outline,
  7. selected tab content feels slightly stronger than unselected without looking over-animated.

### 0z. Device-verify full media playback + download pipeline (2026-03-16, session 8)
- **Evidence (visual):** `TgAudioBubble` — 44vp round circle (radius 22, iOS parity) with gradient `#51b4ff→#2b88d4`, download arrow on idle, play/pause/ring-progress on states, 4vp seek bar below performer. `TgInstantVideoBubble` — radial `Progress(Ring)` around circle, semi-transparent overlays. Voice button 40vp, waveform range 3-20vp.
- **Evidence (behavioral):** Critical `shouldReactToStoreChange` fix — `files.transfers` now triggers timeline rebuild → all download progress indicators visible. Unified `MediaPlaybackController` (voice+audio inline playback, auto-advance). Voice/GIF/VideoNote auto-download. `pendingFileIds` cleanup fix in downloadMessageMedia. FileNormalizer guard fix.
- **IMPORTANT:** Use **Clean Build** (Build → Clean Project → Build) to avoid DevEco cache.
- **Current action:** verify on emulator/device (CLEAN BUILD):
  1. audio bubbles show gradient circle with download arrow (idle) → play (downloaded) → pause (playing),
  2. tapping audio plays inline (NOT opens external app),
  3. audio seek bar fills during playback,
  4. after one audio finishes, next audio auto-plays,
  5. download progress ring visible on art tile during audio/document download,
  6. voice messages auto-download on chat open (no manual tap needed),
  7. voice tap toggles play/pause with waveform color fill,
  8. after voice finishes, next voice auto-plays,
  9. video note circles show radial ring progress during download,
  10. video note / GIF / animation auto-download,
  11. document download shows progress bar,
  12. photo download shows progress overlay on bubble,
  9. all demo states render correctly in TgAudioBubbleDemo and TgInstantVideoBubbleDemo.

### 0y. Device-verify new media transfer indicators + identify next audio/file visual pass (2026-03-16)
- **Evidence:** store-level transfer state now exists (`AppState.files.transfers` + `fileTransferUpdated`), and transfer/progress props are wired through `ChatTimelineVO` → `TgMessageRouter` into `TgPhotoBubble`, `TgVideoBubble`, `TgInstantVideoBubble`, `TgDocumentRow`, `TgAudioBubble`, and `TgVoiceBubble`.
- **Current action:** verify on emulator/device:
  1. single photo bubbles show a visible transfer overlay while the full photo is still downloading,
  2. video / GIF / instant-video bubbles show download spinner/percent instead of silently changing state,
  3. document rows now display real progress bar/percent instead of a static download affordance only,
  4. audio bubbles show download meta/progress and no longer look inert while waiting,
  5. voice bubbles expose download progress in the trailing label before playback is possible,
  6. re-evaluate after the new visual pass whether any remaining media drift is now concentrated in token tuning only.

### 0r. Device-verify bubble improvements: GIF, reply quotes, meta overlay, avatars (2026-03-14)
- **Evidence:** TgMessageRouter rewritten with avatar support, media sizing fix, tighter inline meta, media overlay tokens, regular-width bubble helper, and avatar-lane fallback logic. Rounded media/avatar/reply images now use `.clip(true)`. TgPhotoViewerPage + TgVideoPlayerPage added. Bubble colors aligned to iOS. overlayMode wired in TgMessageMeta.
- **Current action:** device-check:
  1. Wider bubbles (0.85 ratio) — text and media fill more of screen width,
  2. Avatars appear left of incoming group messages (last in sender group),
  3. Avatar space stays reserved for all incoming group messages even before avatar photo hydration,
  4. GIFs auto-play without play button overlay,
  5. Reply quotes have subtle background tint plus top-right quote accent inside bubbles,
  6. Photo/video/avatar/reply thumbnail corners stay cleanly clipped (no square bleed),
  7. Photo/video without caption: time overlays on bottom-right dark pill with white text and no oversized empty width,
  8. Photo/video with caption: time below caption (normal style) and no overlap with trailing text,
  9. Photo tap opens fullscreen viewer with pinch-to-zoom,
  10. Video tap opens fullscreen player with controls,
  11. Bubble colors match iOS (outgoing green #E1FFC7, dark incoming #182533),
  12. On tablet/regular width chats, bubbles shrink to the iOS-style narrower lane instead of staying phone-wide.
  13. Media captions no longer lose the first characters on the left edge (especially channel/photo posts).
  14. Tall portrait photos fit fully inside the bubble instead of cropping the lower part.
  15. Bubble body/caption text now reads less oversized in HarmonyOS runtime after the 16/21 typography tightening.

### 0s. Device-verify grouped photo albums + voice playback path (2026-03-15)
- **Evidence:** `media_album_id` now flows through DTO/state/reducer, `ChatTimelineVO` collapses album clusters into `photoAlbum`, `TgGroupedPhotoBubble` renders the mosaic, and `TgMessageRouter` / `TgChatScreenPage` now drive real voice download+playback via `VoicePlaybackController`.
- **Current action:** device-check:
  1. paired photos now render as one grouped bubble instead of two separate photo bubbles,
  2. 3-up / 4-up / `5+` album layouts look stable and clipped,
  3. tapping the `+N` overlay cell still opens the tapped photo,
  4. album caption/time layout still reads correctly under the grouped bubble,
  5. voice bubble shows download icon before file exists, then play/pause after download,
  6. voice playback starts from local file, pauses/resumes, and progress colors move across the waveform,
  7. listened-state styling stays correct after local playback,
  8. switching chats or reopening the same chat does not leave stale active voice state behind.

### 0t. Emulator/device-verify hardened media viewers (2026-03-15)
- **Evidence:** `TgChatScreenPage` no longer uses `bindContentCover` for photo/video viewing; fullscreen viewers are rendered as direct overlay layers in the root `Stack`. `TgVideoBubble` now opens on tap anywhere on the preview, not only on the center play button.
- **Current action:** verify on emulator/device:
  1. tapping a photo bubble opens `TgPhotoViewerPage`,
  2. tapping an album cell opens the selected photo in the viewer,
  3. tapping a video bubble preview opens `TgVideoPlayerPage`,
  4. tapping a GIF/animation preview opens the viewer path again,
  5. dismiss/close returns cleanly to the chat without leaving a stale black overlay.

### 0u. Device-verify document bubbles + empty-bubble fallback fix (2026-03-15)
- **Evidence:** `TgDocumentRow` now renders a Telegram-style extension badge in the leading tile and allows a 2-line file title; `TgMessageRouter` now routes `unknown` / `location` / `contact` / `poll` through the text-fallback path instead of letting them fall into an empty visual shell.
- **Current action:** verify on emulator/device:
  1. document/file bubbles show an extension badge (`PDF`, etc.) when not downloading,
  2. long file names wrap to two lines without breaking the meta row,
  3. download-progress document rows still show the progress state instead of the extension badge,
  4. previously blank bubbles now render fallback text for location/contact/poll/unknown content,
  5. no new width/alignment regression appeared in file bubbles after the leading-tile change.

### 0v. Device-verify voice bubble meta alignment fix (2026-03-15)
- **Evidence:** `TgUiTokens.resolveVoiceBubbleWidth(...)` now drives both `TgVoiceBubble` and `TgMessageRouter`, and the router no longer uses a generic `width('100%')` meta row for voice messages.
- **Current action:** verify on emulator/device:
  1. time/status stays inside outgoing voice bubbles,
  2. time/status stays inside incoming voice bubbles,
  3. short voice messages do not push time off the right edge,
  4. long voice messages still keep the time cluster aligned to the bubble body,
  5. group-chat voice messages with sender name / reply snippet do not reintroduce width drift.

### 0w. Device-verify channel bubble width / wrap parity pass (2026-03-15)
- **Evidence:** channel posts no longer reserve the hidden group avatar lane, and text/caption paths now use `lineBreakStrategy(LineBreakStrategy.HIGH_QUALITY)` in addition to the existing word-break rules.
- **Current action:** verify on emulator/device:
  1. incoming channel posts are visibly wider than before,
  2. channel text bubbles stop wrapping too early because of a hidden avatar lane,
  3. long Russian/Cyrillic text reads closer to iOS rhythm,
  4. media captions in channels also wrap more naturally,
  5. normal group chats still keep the reserved avatar lane behavior.

### 0x. Device-verify P0 media reliability pass (2026-03-15)
- **Evidence:** `MessageDto` now extracts thumbnails for `messageAnimation` / `messageVideoNote`; `ChatTimelineVO` propagates their `videoFileId` and thumb-first preview path; `TgChatScreenPage` now queues pending video opens and auto-opens after `downloadFile` makes the local path available; grouped photo albums no longer drop empty-path cells.
- **Current action:** verify on emulator/device:
  1. tapping a not-yet-local video opens it automatically after download instead of requiring a second tap,
  2. GIF/animation bubbles show preview thumbnails before the full animation file is downloaded,
  3. videoNote bubbles show preview thumbnails before the full file is local,
  4. partially downloaded photo albums stay grouped and show placeholder cells instead of collapsing into one photo,
  5. special-media fullscreen open still works when the file is already local,
  6. switching chats clears any stale pending-video-open state.

### 0q. Device-verify media pipeline + badge reset (2026-03-14)
- **Evidence:** Full media pipeline activated: file:// URI conversion, on-demand document download, badge reset fix, badge styling alignment.
- **Current action:** device-check:
  1. Photos display in chat bubbles (not placeholder icons),
  2. Stickers display correctly,
  3. Video thumbnails show in video bubbles,
  4. Document tap triggers download, icon changes after completion,
  5. Unread badges reset when exiting a previously unread chat,
  6. Tab bar badge decrements correctly,
  7. Muted chat badges show gray (#B6B6BB) not text_secondary gray,
  8. Voice messages auto-download (bubble should show waveform ready for playback).

### 0p. Device-verify chat opening performance + unread marker (2026-03-14)
- **Evidence:** TgChatScreenPage rewritten for instant chat positioning via `List({ initialIndex })`, race condition fix (`HISTORY_INITIAL_DELAY_MS=600`), placeholder release deadlock fix (`INITIAL_HISTORY_PLACEHOLDER_RELEASE_COUNT=1`), sticky unread marker (`stickyLastReadMessageId`).
- **Current action:** device-check:
  1. Chat opens at correct position (bottom for read chats, unread boundary for unread),
  2. No eternal loading spinner on any chat,
  3. Old messages load normally via pagination (not broken by delay change),
  4. Unread marker ("Unread Messages") persists while in chat, disappears on re-entry after reading,
  5. Chats with <12 messages render content immediately (no spinner),
  6. Saved scroll position restored correctly on back-navigate to previously opened chat.

### 0n. Device-verify glass system overhaul + composer + status bar (2026-03-14)
- **Evidence:** Full glass/blur/composer/status bar rework in session 5.
- **Current action:** device-check:
  1. Status bar icons visible and correct color in both light/dark themes,
  2. Composer no longer shows blue focus outline on tap,
  3. Composer sizing/padding feels closer to iOS (slightly thicker capsule),
  4. Glass elements (top bar, tab bar, composer, filter bar) show frosted tint (not nearly-invisible),
  5. Glass edge highlights visible as thin light border on all glass capsules,
  6. Tab bar pill is gray (not blue) with glass blur effect,
  7. Tab bar island still full capsule shape (radius 999),
  8. BlurStyle.COMPONENT_REGULAR renders properly on device (not all devices support it equally).

### 0j. Device-verify long-press context menu + reply bar
- **Evidence:** TgChatScreenPage now uses LongPressGesture(300ms) → `promptAction.showActionMenu()` with Reply/Copy actions. Old PanGesture swipe-to-reply removed (was hacky, caused perf issues with shared @State). Reply bar uses proper tokens (REPLY_SNIPPET_*), height 45vp (iOS reference). Member count uses localized string resources.
- **Current action:** device-check:
  1. long-press on message shows action menu (Reply + Copy),
  2. Reply action opens reply bar above composer,
  3. Copy action copies text to clipboard with toast feedback,
  4. reply bar appears/disappears properly,
  5. sent message includes reply-to reference,
  6. reply state clears after send,
  7. group/channel subtitle shows localized member count.

### 0k. Device-verify emoji media prefixes in chat list
- **Evidence:** `fallbackMessageTextForType()` now returns emoji prefixes (`📷 Photo`, `📹 Video`, etc.) instead of brackets.
- **Current action:** device-check chat list to confirm media type previews show emoji.

### 0l. Device-verify group/channel member count in top bar
- **Evidence:** `updateChatTopBarData()` now shows "X members"/"X subscribers" for groups/channels.
- **Current action:** device-check group and channel chat screens to confirm subtitle shows member count.

### 0m. Device-verify long-press copy
- **Evidence:** parallelGesture(LongPressGesture) on message bubbles copies text to clipboard.
- **Current action:** device-check long-press on text message, paste elsewhere to verify.

### 0d. Device-verify controlled TgComposerInput + emoji lane
- **Evidence:** `TgComposerInput` was brought back to a controlled contract: `TgChatScreenPage` now owns the live draft text, the atom exposes `text` + `onTextChange`, the optional emoji lane is present again, and the main geometry moved into `TgUiTokens`.
- **HarmonyOS grounding:** the atom now uses `TextArea.style(TextContentStyle.INLINE)` plus `onSubmit(..., SubmitEvent).keepEditableState()` for send-style keyboard behavior.
- **Current action:** device-check the live chat composer and confirm:
  1. typing updates stay stable across page rebuilds,
  2. send-style Enter does not unnecessarily dismiss the keyboard,
  3. emoji/send/mic spacing reads correctly inside the unified capsule,
  4. draft clearing after send still feels natural.

### 0e. Device-verify TgChatRow prefix states
- **Evidence:** `ChatItemVO` + `TgChatRow` now split preview prefixes from the preview body instead of flattening everything into one plain string.
- **What changed locally:**
  - drafts now render as a red `Draft:` prefix + normal body text,
  - group sender prefixes (`You:` / sender name) now render as a separate accent fragment,
  - group typing rows now use the same split-prefix rhythm (`Alice` + `typing...`) instead of one flat string.
- **Current action:** device-check the Chats tab and confirm:
  1. draft rows read like Telegram instead of one monochrome sentence,
  2. group sender prefixes visually separate from the body,
  3. typing rows still ellipsize correctly on narrow widths,
  4. right meta cluster does not jump when prefix states change.

### 0f. Device-verify TgChatMeta optical tuning
- **Evidence:** `TgChatMeta` / `TgUnreadBadge` were re-tuned against current iOS refs:
  - time text now uses a dedicated 14pt-style token,
  - unread badge text uses a dedicated 14pt token plus tighter horizontal padding,
  - pin icon size was reduced,
  - status icon size was increased.
- **Current action:** device-check several row states and confirm:
  1. time/status cluster no longer looks undersized,
  2. unread badge width/weight feels closer to Telegram iOS,
  3. pin icon no longer looks oversized beside the badge lane,
  4. no jump/regression appeared in the right meta cluster.

### 0g. Device-verify typing preview correction
- **Evidence:** iOS `ChatListTypingNode.swift` renders typing activity through `ChatListInputActivitiesNode` using the regular chat-list message text color, not the draft/error accent and not the split author-prefix accent path.
- **What changed locally:** group typing rows went back to a single preview string (`Alice typing...`), and `TgChatRow` no longer paints typing body text in the primary accent color.
- **Current action:** device-check typing states and confirm:
  1. typing rows no longer look over-accented,
  2. group typing text still reads clearly,
  3. ellipsis still behaves correctly on narrow rows,
  4. the state feels closer to Telegram iOS than the previous blue/accent version.

### 0h. Device-verify row rhythm / separator lane tuning
- **Evidence:** `ChatListItem.swift` shows a tighter vertical title/preview rhythm than the old tg_ui row, and the iOS separator lane for the standard avatar path lands around `80pt`, not at the full text-start inset.
- **What changed locally:** `TgUiTokens` now use a tighter title/preview gap and an explicit iOS-like separator inset lane.
- **Current action:** device-check the Chats tab and confirm:
  1. rows no longer feel too airy vertically,
  2. separator starts closer to Telegram iOS,
  3. pinned/background transitions still look clean,
  4. no clipping/regression appeared in narrow rows.

### 0i. Device-verify row typography tuning
- **Evidence:** `ChatListItem.swift` uses row-specific title/preview typography (`16/17`-scaled title, `15/17`-scaled preview) rather than generic screen-title sizing.
- **What changed locally:** `TgChatRow` now uses dedicated row typography tokens (`CHAT_ROW_TITLE_FONT_SIZE`, `CHAT_ROW_PREVIEW_FONT_SIZE`) instead of the shared global title token.
- **Current action:** device-check the Chats tab and confirm:
  1. row titles no longer feel oversized,
  2. preview/body balance looks closer to Telegram iOS,
  3. nothing else in the app regressed because the old global token is no longer driving chat rows.

### 0j. Device-verify `videoNote` / instant-video parity
- **Evidence:** special videos still looked unlike Telegram iOS because `videoNote` was routed through the generic rectangular `TgVideoBubble` shell even after preview/open-flow fixes.
- **What changed locally:** added `entry/src/main/ets/ui/tg_ui/atoms/TgInstantVideoBubble.ets`, `entry/src/main/ets/ui/tg_ui/spec/TgInstantVideoBubble.md`, `entry/src/main/ets/ui/tg_ui/demos/TgInstantVideoBubbleDemo.ets`, plus a dedicated `videoNote` branch in `TgMessageRouter` with iOS-like compact/regular size targets (`212 / 240`) and circular `.clip(true)` media rendering.
- **Current action:** device-check special-video rows and confirm:
  1. `videoNote` bubbles are circular instead of rectangular,
  2. preview thumbnails appear before the full file is local,
  3. one tap still opens the viewer after the pending-download path completes,
  4. sender name / reply snippet / caption cases do not reintroduce a hidden rectangular shell.

### 0k. Device-verify album gallery viewer paging
- **Evidence:** grouped-photo bubbles already merged correctly, but fullscreen open still showed only one photo and had no way to move through the rest of the album.
- **What changed locally:** `TgChatScreenPage` now passes normalized album path arrays + selected index into `TgPhotoViewerPage`, and `TgPhotoViewerPage` now uses ArkUI `Swiper` for multi-photo fullscreen paging while preserving the old zoom/dismiss path for single-photo viewers.
- **Current action:** device-check album viewer behavior and confirm:
  1. tapping any album cell opens the correct initial photo,
  2. horizontal swipe moves through the whole album,
  3. empty placeholder cells from partial downloads are skipped instead of creating blank viewer pages,
  4. single-photo viewer still pinch-zooms and drag-dismisses as before.

### 0l. Device-verify dedicated audio/music bubble path
- **Evidence:** music/audio messages were still routed through `TgDocumentRow`, so even downloaded tracks looked like generic files instead of Telegram music bubbles.
- **What changed locally:** added `TgAudioBubble` + spec/demo, extended chat VO/router with `audioDuration/audioTitle/audioPerformer`, and wired page-owned tap handling so local audio opens through Ability Kit `viewData` while missing audio still triggers download.
- **Current action:** device-check music/audio bubbles and confirm:
  1. `audio` messages no longer look like document rows,
  2. long title/performer pairs ellipsize cleanly,
  3. tap on undownloaded audio starts download,
  4. tap on downloaded audio opens the local file correctly.

### 0c. Device-verify corrected iOS-style tab bar capsule
- **Evidence:** same-day re-check of current Telegram iOS refs showed that the active tab shell is still a centered glass capsule (`TabBarComponent` / `GlassBackgroundContainerView`), so the brief full-width shelf rewrite was wrong.
- **What changed locally:** `entry/src/main/ets/ui/tg_ui/atoms/TgTabBar.ets` was corrected back toward a centered capsule model; dead atom-local bottom-inset bookkeeping was removed so the page remains the only owner of bottom safe-area math; `entry/src/main/ets/ui/pages/MainTabsPage.ets` again positions it above the bottom safe area; `entry/src/main/ets/ui/utils/SafeAreaUtils.ets` again reserves capsule height + safe area + breathing gap.
- **Current action:** device-check root tabs and confirm:
  1. the capsule sits at the correct bottom offset safely,
  2. all 4 tabs remain easy to tap,
  3. unread badge placement still looks right,
  4. the overall bottom chrome reads like the current Telegram iOS capsule.

### 0a. Device-verify TgChatTopBar centering on chat screen
- **Evidence:** screenshot `C:\Users\Kharki\Pictures\Screenshot_2026-03-12T022356.png` showed the chat top bar cluster packed to the left instead of using the full width.
- **What changed locally:** `entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets` now uses fixed left/right capsules plus a weighted center lane for the title capsule; title/subtitle text are centered inside the capsule; each capsule is now a layered `Stack` so glass blur/specular stay behind the content instead of compositing over it; the atom again exposes `glassMode` and no longer hardcodes opaque fallback surfaces as the only path.
- **Current action:** run device check on the same chat screen and confirm (1) avatar is pinned right, (2) title capsule is centered, and (3) text/icons look crisp above the glass on a dark chat background.

### 0b. Device-verify new integrated ChatList header
- **Evidence:** the previous ChatList shell used `TgTopBar` plus a separate scrolling `Search` list item, which visually produced a double-strip header and clipped left `Edit` text in Russian (`C:\Users\Kharki\Pictures\Screenshot_2026-03-12T101849.png`).
- **What changed locally:** `ChatListPage` now uses the new atom `entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets`; the search field moved into the header surface; the page now offsets list content by a tokenized integrated header height instead of rendering search as the first list row. A follow-up fix on 2026-03-13 gave the header atom an explicit root height, because without it the `Stack` overlay could expand and swallow all chat-list gestures/taps.
- **Current action:** device-check the Chats tab and confirm:
  1. the left action text is no longer clipped,
  2. the search field reads as part of the header chrome,
  3. list content scrolls under the header cleanly with no extra strip/gap,
  4. the list is scrollable and rows are tappable again.

### 0. Device-verify chat-list blank-cell regression fix
- **Evidence:** local code updates in:
  - `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets`
  - `entry/src/main/ets/ui/tg_ui/atoms/TgChatRow.ets`
  - `entry/src/main/ets/core/events/normalizers/ChatNormalizer.ets`
  - `entry/src/main/ets/core/reducers/chatsReducer.ets`
  - `entry/src/main/ets/ui/pages/chatlist/ChatItemVO.ets`
- **What changed locally:** restored stable `LazyForEach` identity (`chatId` key + per-chat `reuseId`), removed debug row instrumentation, blocked empty `updateChatTitle` overwrite path, and added phone-number private-title fallback.
- **Current action:** run device HiLog/UI pass to confirm blank/empty chat cells no longer reproduce under fast scroll + initial hydration.

### 1. Stabilize runtime reset and chat loading flows
- **Evidence:** modified files in:
  - `entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets`
  - `entry/src/main/ets/core/store/AppStore.ets`
  - `entry/src/main/ets/domain/usecases/loadChats.ets`
  - `entry/src/main/ets/domain/usecases/loadChatHistory.ets`
  - `entry/src/main/ets/domain/usecases/openChat.ets`
  - `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets`
  - `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`
- **Likely focus:** avoid stale caches, duplicate in-flight loads, bad reopen behavior, unread/history restore glitches, and list churn from non-persistent `LazyForEach` keys.
- **Latest evidence from 2026-03-08 HiLog:** reopening into `savedIndex = 0` / unread-boundary restore can immediately trigger repeated `loadOlder`/`loadNewer` bursts in `TgChatScreenPage` before any real user scroll.
- **Latest pagination fix from 2026-03-09:** edge latch replaced with `recheckPaginationEdge()` pattern — after each completed load, if viewport is still near edge, auto-triggers next batch (iOS-like continuous loading). Added `lastVisibleEndIndex` for accurate newer-edge detection.
- **Follow-up after the latest 2026-03-08 HiLog pass:** restore-triggered burst and edge-pinned pagination storm are fixed in `TgChatScreenPage`; next runtime verification should confirm the reduced `loadOlder` / `loadNewer` counts stay at zero.
- **Current runtime cleanup focus:** `loadChatHistory` sender hydration cap was widened to cover a full default history page before dispatch; remaining work is to re-check HiLog and see whether any missing-user warnings are true misses vs transient hydration lag.
- **Newest runtime finding from 2026-03-08 HiLog:** the remaining startup/live missing-user warnings correlate with direct `getUser`/`getMe` responses being parsed with the wrong `id` source, not with chat history pagination anymore.
- **Newest patch target completed locally:** user parsing now uses top-level `user.id` extraction instead of generic nested-key regex matching; next device run should confirm that `getMe resolved` becomes sane and repeated `Message references non-existent user` warnings collapse.
- **Latest verification from 2026-03-08 `[27274]` HiLog:** runtime stabilization target is effectively satisfied — missing-user warnings dropped to `0`, stale-lastMessage warnings dropped to `0`, and `loadOlder` / `loadNewer` stayed at `0`.
- **Newest finding from 2026-03-08 `[8081]` HiLog:** a chat open can still get a **tiny but non-zero** default `getChatHistory` batch (`1 events` observed for `ClawdBot`), after which the old `messageCount >= limit` rule incorrectly froze `canLoadOlder=false`.
- **Newest patch completed locally:** `LoadChatHistoryUseCase` now treats TDLib short batches as ambiguous, keeps pagination progress-based, and performs one controlled older top-up for suspiciously tiny first-open default batches.
- **Newest polish completed locally:** short initial batches are now held back from visible timeline dispatch until the controlled top-up returns, and `TgChatScreenPage` shows a loading placeholder while the initial timeline is still pending.
- **Newest finding from 2026-03-08 `[21342]` HiLog:** the defer-placeholder path worked, but one top-up was not always enough — at least one chat still progressed only `1 -> 2` messages while `canLoadOlder` stayed true.
- **Newest local refinement completed:** initial top-up now retries in a bounded loop while oldest-message progress continues, and the chat screen keeps the loading placeholder until the initial timeline is large enough or older history is genuinely exhausted.
- **Current action:** device-verify that problematic chats now land on a fuller first-open timeline without showing a misleading tiny partial history in between.
- **Newest local fix (2026-03-11):** prepend compensation for older-history loading in `TgChatScreenPage` now freezes the viewport and re-anchors the saved visible item synchronously in the same turn as `applyDiff()`. The delayed second-pass `setTimeout(16ms)` compensation was removed from the prepend path because it still allowed a visible jump/autoscroll when older rows were inserted above the viewport.
- **Newest local perf fix (2026-03-12):** initial `getChatHistory` dispatch now lands in store/UI before missing sender hydration. Sender users are hydrated in background, in parallel chunks, and their normalized events are dispatched as one batch instead of one store update per user. Message selectors now memoize per-chat sorted arrays by message-map reference, so those follow-up user updates no longer force a full re-sort of the active chat.
- **Newest local scroll fix attempt (2026-03-12):** chat history `List` now enables native `maintainVisibleContentPosition(true)` and the old custom prepend `scrollToIndex` compensation hot path was removed. Prepend now relies on ArkUI's built-in off-screen insert preservation and only keeps the anti-cascade guard.
- **Newest local runtime fix (2026-03-12):** `ChatTimelineDataSource` stopped mixing `onDatasetChange(...)` with `onDataAdd/onDataDelete/onDataChange`, which was matching the device HiLog error `onDatasetChange cannot be used with other interface`. `TgChatScreenPage` now also blocks pagination callbacks while `applyDiff()` is running and defers `recheckPaginationEdge()` to the next tick so it does not fire against stale pre-prepend indices/counts.
- **Verification status:** `bash ./scripts/smoke-ui-phase0.sh` ✅, `./scripts/smoke-build.ps1` ✅, `./scripts/smoke-ui-phase0.ps1` ✅.
- **Current action:** device-verify three runtime cases on a long/big chat: (1) hitting the top edge loads older messages without shifting the visible viewport under native `maintainVisibleContentPosition`, (2) the `Loading older messages...` loop no longer cascades without user scroll after each batch, and (3) `Timeline rebuild failed: onDatasetChange cannot be used with other interface` no longer appears in HiLog.

### 2. Finish and commit the new tg_ui docs/demo batch
- **Evidence:** untracked files include:
  - `entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets`
  - specs for `TgCallRow`, `TgChatTopBar`, `TgContactRow`, `TgSearchBar`, `TgSettingsRow`, `TgSettingsSection`, `TgTabBar`
  - demos for `TgCallRow`, `TgChatTopBar`, `TgContactRow`, `TgMessageBubbleBase`, `TgMessageRouter`, `TgSearchBar`, `TgSettingsRow`, `TgSettingsSection`, `TgTabBar`
- **Goal:** get the repo history aligned with the current tg_ui runtime path and documentation claims.
- **Boundary note:** these untracked tg_ui support files are explicitly classified as part of the current batch in `TASKS/CURRENT_PATCHSET_BOUNDARY.md`.

### 3. Resync human-facing docs with current runtime reality
- **Evidence:** local modifications in:
  - `README.md`
  - `docs/ai/AI_MEMORY.md`
  - `docs/ai/UI_MIGRATION_PLAN.md`
- **Goal:** remove drift between historical notes and the current shell/chat path.

### 4. Replace the Calls placeholder with real TDLib-backed call history
- **Evidence:** modified / added files in:
  - `entry/src/main/ets/core/model/AppCommand.ets`
  - `entry/src/main/ets/infra/td/serialization/CommandSerializer.ets`
  - `entry/src/main/ets/core/events/normalizers/ChatNormalizer.ets`
  - `entry/src/main/ets/domain/usecases/loadCalls.ets`
  - `entry/src/main/ets/ui/pages/calls/CallsPage.ets`
  - `entry/src/main/ets/ui/tg_ui/atoms/TgCallRow.ets`
- **What changed locally:** `CallsPage` now uses TDLib `searchCallMessages` instead of the hardcoded empty state, paginates with `next_from_message_id`, and hydrates missing chat/user metadata via direct `getChat` / `getUser` response normalization.
- **Current limitation:** this pass maps TDLib `messageCall` / `messageGroupCall` into the existing single-peer `TgCallRow`; there is still no dedicated missed-only segmented header or richer group-call row treatment.
- **Next verification:** fresh device run + HiLog to confirm the real payload shape on this repo/runtime and verify that row titles/avatars hydrate correctly on non-trivial histories.

### 5. Stock ArkUI atom replacement (2026-03-09) ✅
- Replaced 3 thin wrapper atoms with stock components inline in pages:
  - `TgSearchBar` → stock `Search` in ChatListPage
  - `TgSettingsSection` → inline `Column` with tokens in SettingsPage
  - `TgContactRow` → inline `TgAvatar` + Row/Column in ContactsPage
- Kept: TgTabBar, TgTopBar, TgCallRow, TgSettingsRow (real custom logic)
- Smoke scripts updated. `bash ./scripts/smoke-ui-phase0.sh` ✅
- Orphaned demos/specs for removed atoms still exist (cleanup later)

---

## Improvement plan — "demo → real app" (derived from iOS comparison 2026-03-09)

Priority order is by **visual/functional impact**, not by architectural purity.

### P0-P5 Improvement plan — ALL COMPLETE (2026-03-09)
- **P0 Avatar download:** ✅ Full pipeline: `photoSmallFileId` in AppState/DTOs/reducers/stateClone, `DownloadFileCommand` + `CommandSerializer`, `FileNormalizer` (updateFile → FileDownloadedEvent), `filesReducer`, `downloadAvatars` usecase in AppCoreRuntime. Fixed two bugs: (1) `getTopLevelNumber('id')` for file IDs (Lesson #28), (2) direct response parsing via TdObject native accessors instead of broken `JSON.stringify(TdObject)` (Lesson #29). Needs device verification.
- **P1 Sender names in groups:** ✅ `buildChatItemVO()` prepends "You: " / "firstName: " for group previews
- **P2 Checkmark order:** ✅ TgChatMeta status icon before time (iOS: ✓✓ 17:47)
- **P3 Date format:** ✅ Same-year dates → `dd.MM` (no year)
- **P4 TgTopBar actions:** ✅ Edit + Compose buttons in ChatListPage
- **P5 Pinned separator:** ✅ `isLastPinned` + 8vp gap after last pinned chat

### P6 Profile screen — COMPLETE (2026-03-09)
- **TgProfilePage**: full pipeline from model through usecase to UI
- Navigation wired from TgChatScreenPage (avatar + title taps)
- getUserFullInfo (bio), getSupergroupFullInfo (description, memberCount)
- Needs device verification

### P8 TgTabBar Android-style rewrite — COMPLETE (2026-03-11)
- Pill highlight replaces ring (full-tab capsule, 9% alpha, scale+opacity animation 320ms)
- Sizes: 56vp height, 24vp icon, 12vp text, Bold font on selection
- Reference: Android `GlassTabView.java`

### P9 Pagination Android/iOS alignment — COMPLETE (2026-03-11)
- Older threshold 10→25, newer 6→5 (Android/iOS values)
- Latch system removed → simple `!isLoading` guard (Android pattern)
- Scroll compensation: synchronous (removed setTimeout 16ms flicker)
- Reason: `'restore'` → `'default'` for scroll pagination

### P7 Unified bubble container — COMPLETE (2026-03-10)
- TgMessageRouter: sender name, reply, content, meta all INSIDE bubble
- Stack(BottomEnd) for text bubble shrink-wrap + meta overlay
- All bubble atoms gained noBubbleWrap support
- Nav lock double-tap fix (ChatListPage.onPageShow + aboutToDisappear)
- Composer safe area fix (margin→padding, expandSafeArea BOTTOM)

### Future (beyond current sprint)
- Media download/open (photos, videos, documents)
- Voice message playback
- Push notifications
- Create new chat/group
- Search within messages
- Message context menu (reply, copy, forward, delete)
- Unread counter badge on chat list tab
- Typing indicator in chat screen
- Online status in chat list

## Next after the current patchset

### Re-run verification
- `scripts/smoke-ui-phase0.ps1` — passed on 2026-03-09
- `scripts/smoke-ui-phase0.sh` — passed on 2026-03-09
- latest runtime HiLog verification — passed on 2026-03-08 via `[27274]` trace
- `scripts/smoke-build.ps1` — passed on 2026-03-08
- next verification actions are:
  1. device run + HiLog for the new Phase 4 calls path
  2. device-verify P0 avatar download flow (fileId → downloadFile → updateFile → photo path in store → TgAvatar renders)

### Clean up stale historical references
- Only after demos/specs/integration are safely committed.
- Orphaned demos/specs for removed atoms (TgSearchBar, TgSettingsSection, TgContactRow) can be deleted.
- Do not remove old docs or fallback paths blindly while the branch is still unstable.

## External blockers / prerequisites
- TDLib prebuilts under `entry/src/main/cpp/third_party/tdlib`
- local credentials in `entry/src/main/ets/services/ConfigLocal.ets`

### 0m. Device-verify tightened media download policy + pending bubble states
- Verify the 2026-03-15 session 21 patch on a real device/emulator:
  - repeated taps on the same video/file no longer spam repeated `downloadFile` HiLog entries
  - voice/audio/document bubbles show download → spinner → open/play transitions
  - video / GIF / instant-video previews show a download affordance before the file is local and a spinner while pending
  - downloaded documents open via Ability Kit `viewData`
  - background auto-download noise is reduced by keeping voice/GIF/videoNote on-demand while preserving photo/thumb preview behavior
