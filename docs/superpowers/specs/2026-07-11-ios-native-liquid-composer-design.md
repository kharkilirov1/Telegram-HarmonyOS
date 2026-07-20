# iOS-Native Liquid Composer Design

## Outcome

Rebuild the active Telegram composer as the current iOS composition rendered
with HarmonyOS-native material. The Telegram state/interaction model remains
project-owned; HarmonyOS owns blur, immersive material, adaptation, shadows,
safe-area behavior and motion primitives.

## Grounding

- Shipped visual truth:
  `.codex/ui-audit/2026-07-10/iphone16promax-runtime/02-zai-chat-dark.jpg`.
- Telegram iOS structure:
  `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift`.
- Nekogram recording interaction fallback:
  `C:/Refs/Telegram/Nekogram/TMessagesProj/src/main/java/org/telegram/ui/Components/ChatActivityEnterView.java`.
- HarmonyOS platform contract: `uiMaterial.ImmersiveMaterial` and
  `systemMaterial` start at API 26; `backgroundBlurStyle` remains the API 23
  runtime fallback. `LongPressGesture` followed by `PanGesture` is the supported
  recording gesture composition.

## Architecture

The active `TgComposerInput` remains a UI-only atom and retains its existing
events. `HdsActionBar` is not used in the live path: its click-oriented action
buttons do not satisfy Telegram recording gestures.

Material selection is isolated in a pure `TgComposerMaterialPolicy`:

1. API 26+, feature enabled, realtime glass allowed -> native immersive material.
2. API 23-25 or native feature disabled, realtime glass allowed -> adaptive
   `backgroundBlurStyle`.
3. Low-memory/fallback glass mode -> opaque resource fallback.

The API 26 path uses `uiMaterial.ImmersiveMaterial` with system shadow,
interactive light feedback and color inversion. The API 23 path stays visually
stable and is the only path that can be runtime-verified on the current Pura
API23 emulator.

## Component shape

```text
TgComposerInput
|- optional leading Menu pill (separate follow-up integration)
|- attach liquid circle
|- text liquid capsule
|  |- forward/edit/reply/attachment accessory
|  |- transparent controlled TextArea
|  `- emoji + inline send action
`- idle mic liquid circle
```

This slice changes the material host only. Existing send, attachment, emoji,
reply, edit and forward callbacks remain unchanged.

## Explicit scope boundary

This slice does **not** pretend that voice recording exists. The current
`ChatComposerController.handleVoicePress` still reports that voice recording is
unavailable. Hold/drag/cancel/lock plus audio capture/send require a separate
runtime slice with microphone permission, recorder lifecycle and TDLib send
witnesses.

## Acceptance

- Pure policy tests cover API 26 native, API23 blur, feature-off blur and
  low-memory fallback.
- The live composer contains no `HdsActionBar`.
- API 26 code compiles in the target-26 build.
- API23 production HAP launches the logged-in root and opens a chat without a
  crash, proving the guarded fallback path.
- Light/dark composer screenshots show no opaque focus plate, clipping or safe
  area collision.
- Existing UI smoke, geometry test and `git diff --check` remain green.

## Rollback

The change is reversible by restoring `TgComposerInput.ets`, removing the
material policy/test files and leaving the current `TgGlassPolicy` fallback
untouched. No TDLib/domain files are modified.
