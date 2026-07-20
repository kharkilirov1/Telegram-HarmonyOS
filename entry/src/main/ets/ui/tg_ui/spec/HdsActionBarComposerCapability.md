# HdsActionBar Composer Capability Passport

## Scope

Demo-only evaluation of `HdsActionBar` as a native material/action host for a
custom Telegram composer surface. There is no live page import, route or domain
integration. The current `TgComposerInput` remains the production composer.

## Grounding

- Official UI Design Kit docs: `HdsActionBar` is an API20+ `@ComponentV2`
  stage-model component with a custom primary builder, start/end buttons,
  `ActionBarStyle`, expand state and adaptive blur strategy.
- Installed declaration:
  `C:/Program Files/Huawei/DevEco Studio/sdk/default/hms/ets/api/@hms.hds.HdsActionBar.d.ets:20-114,124-260,470-683`.
  Lines 43-52 require `primaryButtonBuilderWidth` for correct back-panel width.
- Harmony reference:
  `C:/Refs/Telegram/HarmonyOSComponentUXExamples/entry/src/main/ets/components/action/actionbar/components/`.
- Telegram iOS:
  `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift:639-736,817-903`.
- Current Harmony integration boundary:
  `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets:2969-3091` and
  `entry/src/main/ets/ui/tg_ui/atoms/TgComposerInput.ets:13-64,446+`.

## Demo contract

- `primaryButtonBuilder` owns only synthetic accessory/text/recording content.
- `primaryButtonBuilderWidth` is explicitly `216vp` and matches the builder.
- native `ActionBarButton` instances own synthetic attach and right actions;
- `ActionBarStyle.height` follows bounded text/accessory height;
- local controls expose empty, text, multiline, reply, edit, forward,
  attachment, slow, recording and emoji-panel states;
- visible `lastAction` text is the engagement witness for clicks and input.

## State/parity matrix

| State | Demo representation | Result on target 26 / Pura API23 |
| --- | --- | --- |
| empty / microphone | empty `TextArea` + native mic action | layout and click path proven |
| text / send | text preset + native send action | layout, reactive icon and click path proven |
| reply | synthetic accessory row | dynamic-height layout proven |
| edit | synthetic accessory row + prefill | dynamic-height layout proven |
| forward | synthetic accessory row | dynamic-height layout proven |
| attachment | native attach action + accessory row | layout and native click path proven |
| slow mode | disabled native right action | disabled state proven |
| recording | synthetic timer content + click stop | layout and click-only transition proven |
| emoji/media panel | real `TgComposerEmojiPanel` above HDS | no overlap/clipping proven |
| multiline | four-line controlled `TextArea` + dynamic height | four-line layout proven |
| focus / IME | controlled `TextArea` under RESIZE keyboard mode | keyboard resize and dismissal proven |
| recording hold/drag/cancel/lock | no distinct gesture callbacks in the demo | unsupported |

## Runtime findings

- The explicit primary builder rendered at `[276,2628][1032,2768]` in the
  normal state: `756px / 3.5 = 216vp`, exactly matching
  `primaryButtonBuilderWidth`.
- Native attach and right actions remained separated from the builder by
  `21px` on each side across normal, accessory and multiline states.
- The HDS outer bounds expanded from `[66,2600][1242,2796]` (normal) to
  `[66,2446][1242,2796]` (reply/edit/forward/attachment) and
  `[66,2390][1242,2796]` (four-line input), always inside the app root.
- The real emoji panel plus four-line HDS composer fitted without overlap.
- With IME visible, the app root resized to `[0,137][1308,1823]` and HDS moved
  to `[66,1543][1242,1739]`; after dismissal it returned to
  `[66,2600][1242,2796]`.
- Recreating `ActionBarButton` objects per render left the text/send icon stale.
  Keeping one `@ObservedV2` button instance and mutating its `@Trace` fields
  fixed the runtime icon transition; the final text state shows the send icon.
- Native start/end click callbacks were witnessed by visible
  `lastAction=attach`, `lastAction=send: Ready to send`, and recording
  start/stop status transitions.

## Decision

**Rejected as a live composer replacement.** HDS geometry, material, dynamic
height, reactive button state and IME behavior are viable, but the approved
parity gate also requires press/hold/drag recording, cancel and lock semantics.
This demo has only native button `onClick` evidence, so visual success cannot
justify replacing `TgComposerInput`.

`HdsActionBar` remains a future material-host candidate only if recording and
all controller states stay in a custom inner builder with an explicit gesture
contract. Until then, production keeps the current custom composer.

## Acceptance boundary

The demo can validate native material geometry, explicit builder width, click
actions, dynamic content and keyboard interaction. It cannot claim controller,
TDLib, send, edit, forward, attachment or recording semantic parity.

Production migration is allowed only if every state required by
`docs/ai/HYBRID_NATIVE_CUSTOM_UI_DESIGN_2026-07-10.md` is runtime-proven. Any
clipping, keyboard collision, stale height, or missing recording gesture/cancel
contract rejects live migration and preserves `TgComposerInput`.
