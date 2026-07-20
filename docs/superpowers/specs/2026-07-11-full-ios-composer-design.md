# Full iOS Composer Design

## Outcome

Complete the already accepted iOS-native material composer with the missing
Telegram interaction states that were explicitly deferred from C1:

1. hold-to-record voice notes;
2. drag left to cancel and drag up to lock;
3. locked recording controls (delete and send);
4. real microphone permission, AVRecorder lifecycle and TDLib voice-note send;
5. direct system camera action through CameraPicker;
6. the leading bot Menu pill backed by real TDLib bot metadata.

The rest of the Telegram client and the current custom `TgComposerInput` remain
intact. `HdsActionBar` stays demo-only.

## Reference grounding

- Shipped iPhone 16 Pro Max captures:
  `.codex/ui-audit/2026-07-10/iphone16promax-runtime/02-zai-chat-dark.jpg`.
- Telegram iOS structure and state machine:
  `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift`.
- Telegram iOS component decomposition:
  `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelComponent.swift`.
- Nekogram gesture fallback:
  `C:/Refs/Telegram/Nekogram/TMessagesProj/src/main/java/org/telegram/ui/Components/ChatActivityEnterView.java`.
- TDLib contract:
  `tdlib/td/generate/scheme/td_api.tl` — `inputMessageVoiceNote` accepts an
  Opus/OGG voice file or MP3/M4A regular audio, duration, 5-bit waveform,
  caption and optional self-destruct type.

## Platform contract

- `ohos.permission.MICROPHONE` is already declared and must be requested from
  the user before `AVRecorder.prepare`.
- ArkTS `media.AVRecorder` records mono AAC into an M4A container and writes to
  an application-owned `fd://` target.
- `LongPressGesture` plus `PanGesture` provide the native hold/drag interaction;
  the policy thresholds stay pure and unit-tested.
- `cameraPicker.pick` provides system photo/video capture from a UIAbility. The
  explicit camera action does not require a custom camera surface.
- API26 immersive material remains guarded by literal
  `deviceInfo.apiAvailable('26.0.0')`; API23 keeps adaptive blur.

## Runtime architecture

```text
TgComposerInput gesture + visual state
        |
        v
TgChatScreenPage @Local recording state
        |
        v
ChatVoiceRecordingController
  permission -> AVRecorder -> local .m4a
        |
        v
SendMediaMessageUseCase(mediaKind='voice')
        |
        v
CommandSerializer -> inputMessageVoiceNote -> TDLib
```

The recorder controller owns only platform lifecycle and send coordination.
The page owns reactive UI state. The atom remains UI-only.

## Recording state matrix

| State | Composer UI | Release/action |
| --- | --- | --- |
| idle | attach, text capsule, mic | long press starts preparation |
| preparing | recording surface, timer `0:00` | release queues send; cancel queues cleanup |
| recording | red dot, timer, slide-to-cancel, lock affordance | release sends |
| locked | delete, timer/waveform, solid send | explicit send or delete |
| sending | disabled recording surface/progress label | waits for TDLib |
| error | returns to idle and shows a bounded toast | retry by holding again |

Threshold policy:

- horizontal offset `<= -72vp` -> cancel;
- vertical offset `<= -72vp` -> lock;
- otherwise release -> send;
- recordings shorter than `500ms` are discarded as too short.

## Bot Menu

`User.isBot` is derived from TDLib `user.type.@type == userTypeBot`. For a
private bot chat, `getUserFullInfo` supplies `bot_info.menu_button` and
`bot_info.commands`:

- the leading pill uses the server title when present, otherwise localized
  `Menu`;
- command-only bots show an action menu and send the selected `/command`;
- web-app metadata remains represented explicitly; no fake URL is invented.

## Camera

The attachment action menu gains a direct Camera item implemented with
`cameraPicker.pick([PHOTO, VIDEO])`. The confirmed result is copied through the
existing pending-attachment pipeline and uses the existing media send path.

## Failure and cleanup contract

- Permission denial never creates a recorder or file.
- Every stop/cancel/error/disappear path releases `AVRecorder`, closes the file
  descriptor and deletes abandoned recordings.
- A send failure retains no stuck recording state and is surfaced through the
  existing bounded composer toast path.
- Lifecycle tokens prevent an old chat from updating or sending into a newly
  opened chat.

## Verification

- RED/GREEN tests for gesture policy and voice TDLib serialization.
- Focused controller/source contract.
- ohosTest compile/package, both UI smoke scripts and clean target-26 build.
- API23 runtime visual witness for bot Menu, recording permission/state and
  safe-area/IME layout when the emulator capabilities allow it.
- A successful real-device voice send remains the strongest final gate; if the
  emulator has no microphone input, that limitation is reported rather than
  hidden.

