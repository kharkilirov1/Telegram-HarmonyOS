# TgIosNativeLiquidComposer Passport

## Purpose

`TgComposerInput` reproduces the current Telegram iOS split composer while
using the newest material available on the running HarmonyOS version. It stays
a custom Telegram atom; `HdsActionBar` is not part of the production path.

## Reference files

- Runtime iPhone 16 Pro Max:
  `.codex/ui-audit/2026-07-10/iphone16promax-runtime/02-zai-chat-dark.jpg`
- Telegram iOS:
  `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift`
- Telegram iOS Menu/X animation:
  `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/MenuIconNode.swift`
- Telegram iOS command panel:
  `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/CommandMenuChatInputContextPanelNode.swift`
  and `CommandMenuChatInputPanelItem.swift`
- Nekogram gesture fallback:
  `C:/Refs/Telegram/Nekogram/TMessagesProj/src/main/java/org/telegram/ui/Components/ChatActivityEnterView.java`
- ArkGram clean-room visual reference:
  `C:/Refs/Telegram/ArkGram-RE/out/ArkGram-project/entry/src/main/ets/view/ChatInputArea.ets`

## Inputs

- Controlled text and placeholder.
- Disabled state.
- Attach and emoji visibility.
- Reply, edit, forward and attachment accessory data.
- Container width, glass mode and bottom safe-area inset.
- Existing send/text/attach/emoji/voice/cancel events.
- Bot Menu visibility/title/open state, command labels/descriptions and
  button/open-state/command-selection events.
- Recent attachment-media items/loading state, sheet open state and selected
  recent/category events.
- Current emoji/sticker-panel visibility and explicit keyboard-mode event.
- Recording state/duration/labels and start/send/cancel/lock events.

Existing event signatures remain unchanged; the new events are additive.

## Material matrix

| Runtime/capability | Feature flag | Glass policy | Surface |
| --- | --- | --- | --- |
| API 26+ | enabled | realtime | `uiMaterial.ImmersiveMaterial` |
| API 23-25 | enabled | realtime | adaptive `backgroundBlurStyle` |
| any | disabled | realtime | adaptive `backgroundBlurStyle` |
| any | any | fallback | opaque resource background |

The API 26 builders are annotated with
`@Available({ minApiVersion: '26.0.0' })` and are called only below an explicit
`deviceInfo.apiAvailable('26.0.0')` guard. The native material owns its shadow
and material color; it is not combined with the fallback border/background.

## Layout contract

- Leading attach control: separate 34vp visual circle with a 40vp response region.
- Optional private-bot Menu pill: leading 34vp capsule before attach; its compact
  state also retains a 40vp response region.
- The Menu icon is three horizontal lines while closed and morphs to a close X while its
  command panel is visible, following iOS `MenuIconNode(.menu/.close)`.
- With an empty unfocused input the pill shows icon + title. It collapses to the
  same 34vp icon-only circle as soon as `TextArea` receives focus (the cursor
  starts blinking), and remains collapsed while focused or non-empty. This
  releases the width before the first character is typed.
- Commands use an in-flow full-width glass context panel above the composer,
  not a system bottom action menu. Rows are 42vp, stack from the bottom, show at most 4.7
  rows before scrolling and keep description left with `/command` right. The
  complete TDLib command list is rendered; there is no artificial item cap.
- The attachment chooser uses native ArkUI `bindSheet` in bottom-overlay mode,
  matching Telegram iOS `AttachmentController` / Android `ChatAttachAlert` modal
  presentation. The native host keeps the platform transition and drag/dismiss
  behavior, while the Telegram content uses a dedicated opaque navy surface at
  67% of the runtime height, a 36×4vp iOS-style grabber, a compact Recent header,
  a three-column real `PhotoAsset` grid and a six-column
  Gallery/Camera/File/Location/Poll/Contact rail. Gallery keeps the selected
  category pill; Gallery, Camera and File are functional, while categories
  without a controller flow remain visible but disabled.
- Message long-press actions use the same glass row/radius/blur language and a
  4.7-row scrolling viewport, while remaining anchored to the pressed row.
- Menu-label removal/insertion and the resulting composer reflow use a 220ms
  `Curve.Smooth` layout transition. The bot context panel spans the chat width
  above the composer; bot, attachment and message-action surfaces share the
  asymmetric opacity + translate + scale entrance/exit transition language.
- Telegram emoji and sticker keyboard-slot panels use the same asymmetric
  opacity + vertical translate + scale transition instead of mounting or
  unmounting immediately. Their layout still owns the bottom slot and resizes
  the chat content rather than overlaying the last message.
- Text capsule: minimum 34vp, radius 17vp, controlled multiline `TextArea`.
- Emoji/keyboard mode glyph: inside the trailing side of the text capsule. It
  morphs to a keyboard icon while Telegram's custom panel is visible.
- Trailing action: one persistent external 34vp visual slot after the text capsule
  with a 40vp response region.
- Empty state shows the material mic; sendable text, forward or attachment state
  transforms that same slot into the solid accent send action without changing row geometry.
- Reply/edit/forward/selected-attachment snippets stay inside the text capsule.
  Emoji and sticker keyboards render after the composer and replace the system
  keyboard area. Touching `TextArea` clears both custom panels before IME focus;
  the keyboard glyph clears them, focuses the field and calls IME
  `showTextInput()`. Attachments are a separate modal sheet over the chat.
- Existing token values in `TgUiTokens` remain authoritative.
- Idle controls share one 34vp baseline with 4vp inter-control gaps and 1vp
  vertical insets. The complete idle/recording row uses 18vp left/right insets,
  making the visual line 8vp shorter than the preceding 14vp-inset pass. API23 fallback circles retain a 0.75vp glass edge and use
  primary icon contrast; API26 material owns its native edge/shadow.
- The visual shell is intentionally 2vp tighter than the current iOS constants,
  per product direction. HarmonyOS `responseRegion` expands every primary
  34vp control back to at least 40×40vp, so visual density does not shrink the
  supported touch target.
- The content layer reserves the measured composer height as bottom padding, so
  the List viewport physically ends at the composer top in idle, focused IME,
  emoji/sticker and multiline states. `contentEndOffset` is not used as a
  substitute for viewport geometry.
- If the user is already at the bottom, `TextArea` captures that intent on
  touch-down before ArkUI starts `KeyboardAvoidMode.RESIZE`. Page-height and
  composer-height changes then reapply
  `scrollToIndex(last, false, ScrollAlign.END)`. A user reading older messages
  is not forced to the bottom.
- The chat List scrollbar is hidden because the iOS reference has no indicator
  crossing the trailing microphone control.

## State matrix

| State | Expected result |
| --- | --- |
| empty | attach + capsule + external mic action |
| text | the same external action slot transforms from mic to send |
| multiline | capsule grows without opaque focused plate |
| focus/IME | keyboard and composer shorten the List; latest message remains at the moving List edge |
| reply | reply accessory and cancel action inside capsule |
| edit | edit accessory and prefilled text |
| forward | forward accessory is sendable without comment |
| attachment | attachment accessory is sendable without caption |
| disabled | callbacks remain gated and opacity is reduced |
| fallback glass | no realtime blur or API26 material |
| preparing | timer `0:00`, red indicator and bounded starting label |
| recording | red indicator, timer, slide-to-cancel and lock affordance |
| locked | delete, timer/waveform and explicit solid send action |
| sending | progress indicator and no duplicate send action |
| private bot commands | three lines → X; full-width glass context panel above composer contains every real TDLib command and scrolls after 4.7 rows |
| private bot focus | cursor focus immediately collapses Menu before any text is entered |
| private bot typing | focused or non-empty input keeps the 34vp three-line circle with a 40vp hit target |
| attachment menu | paperclip opens a native 67%-height bottom sheet with opaque Telegram navy content, real recent-media grid and six fixed-width categories |
| emoji/stickers | full-width Telegram panel renders below composer, owns the bottom safe inset and changes emoji to keyboard glyph |
| panel → IME | text-field or keyboard-glyph tap removes Telegram panel before the system keyboard opens; the two never stack |
| private bot web app | leading Menu opens the server URL through `Want` |

## Voice behavior contract

- Hold the idle mic to start `AVRecorder` preparation.
- Drag `<= -72vp` horizontally to cancel; drag `<= -72vp` vertically to lock.
- Releasing an unresolved hold sends; locked mode requires explicit send.
- Recordings shorter than 500ms are discarded.
- The page owns reactive state; `ChatVoiceRecordingController` owns permission,
  recorder/file lifecycle and the existing `SendMediaMessageUseCase` call.
- TDLib serialization uses `inputMessageVoiceNote` with duration and waveform.

## Camera and bot behavior

- Camera is a real attachment action backed by system `cameraPicker.pick`
  for PHOTO/VIDEO and feeds the existing pending-attachment pipeline.
- Recent media uses `READ_IMAGEVIDEO` plus `PhotoAccessHelper.getAssets`, sorted
  by `PhotoKeys.DATE_ADDED`, limited to 24 objects and closed in `finally`.
- Attachment choice is presented by the composer-owned native modal sheet;
  the controller receives only the selected index and keeps picker/business behavior.
- Menu is exposed only for `Chat.type == private` and `User.isBot == true`.
- `getUserFullInfo.bot_info` is the only source for title, URL and commands;
  no placeholder command or URL is invented.

## Verification

- `TgComposerMaterialPolicy.test.ets`
- `TgVoiceRecordingPolicy.test.ets`
- `LoadBotMenu.test.ets`
- `CommandSerializer.test.ets` voice-note case
- `scripts/test-ios-native-liquid-composer.ps1`
- `scripts/smoke-ui-phase0.ps1`
- target-26 `assembleHap`
- API23 production install plus fresh-process/chat/focus screenshots
- API23 idle/focused/multiline bounds under
  `.codex/ui-audit/2026-07-12/composer-push/`
- API23 emoji/sticker enter frames, settled bounds, fresh process and panel →
  IME handoff under `.codex/ui-audit/2026-07-13/composer-panel-motion/`
