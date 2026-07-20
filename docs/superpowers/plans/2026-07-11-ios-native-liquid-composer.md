# iOS-Native Liquid Composer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an API26 immersive-material path to the active iOS-style composer while preserving the accepted API23 adaptive-blur fallback and all current callbacks.

**Architecture:** A pure policy resolves `nativeImmersive`, `realtimeBlur`, or `fallback`. `TgComposerInput` renders its existing custom Telegram layout over the selected native/fallback background; it does not adopt `HdsActionBar`.

**Tech Stack:** ArkTS `@ComponentV2`, ArkUI `uiMaterial.ImmersiveMaterial`, `deviceInfo.apiAvailable`, `@Available`, `backgroundBlurStyle`, Hypium, PowerShell source contracts, hvigor.

## Global Constraints

- Target API is `26.0.0`; compatible/runtime floor is `6.1.0(23)`.
- Keep the existing production composer as the active atom; no root/demo route swap.
- Do not change TDLib, send, attachment, draft or message behavior in this slice.
- Do not claim native immersive runtime engagement without an API26 device.
- Do not commit, stage, push or publish without explicit user confirmation.

---

### Task 1: Material selection policy

**Files:**
- Create: `entry/src/main/ets/ui/tg_ui/utils/TgComposerMaterialPolicy.ets`
- Create: `entry/src/ohosTest/ets/test/TgComposerMaterialPolicy.test.ets`
- Modify: `entry/src/ohosTest/ets/test/List.test.ets`

**Interfaces:**
- Produces: `TgComposerMaterialMode` and `resolveComposerMaterialMode(nativeApiAvailable, nativeEnabled, realtimeBlurEnabled)`.

- [x] **Step 1: Write the failing Hypium test**

```ts
expect(resolveComposerMaterialMode(true, true, true)).assertEqual('nativeImmersive');
expect(resolveComposerMaterialMode(false, true, true)).assertEqual('realtimeBlur');
expect(resolveComposerMaterialMode(true, false, true)).assertEqual('realtimeBlur');
expect(resolveComposerMaterialMode(true, true, false)).assertEqual('fallback');
```

- [x] **Step 2: Run the ohosTest build and record the expected missing-module failure**

Run: `hvigorw --mode module -p module=entry@ohosTest -p product=default assembleHap --no-daemon`

Expected: FAIL because `TgComposerMaterialPolicy` does not exist.

- [x] **Step 3: Implement the pure resolver**

```ts
export type TgComposerMaterialMode = 'nativeImmersive' | 'realtimeBlur' | 'fallback';

export function resolveComposerMaterialMode(
  nativeApiAvailable: boolean,
  nativeEnabled: boolean,
  realtimeBlurEnabled: boolean
): TgComposerMaterialMode {
  if (!realtimeBlurEnabled) return 'fallback';
  if (nativeEnabled && nativeApiAvailable) return 'nativeImmersive';
  return 'realtimeBlur';
}
```

- [x] **Step 4: Rebuild ohosTest and record GREEN**

### Task 2: Guarded native material backgrounds

**Files:**
- Modify: `entry/src/main/ets/ui/tg_ui/TgUiFeatureFlags.ets`
- Modify: `entry/src/main/ets/ui/tg_ui/atoms/TgComposerInput.ets`

**Interfaces:**
- Consumes: `resolveComposerMaterialMode`.
- Preserves: every existing `TgComposerInput` parameter and event.

- [x] **Step 1: Add the native immersive feature flag**

Add `USE_NATIVE_IMMERSIVE_COMPOSER_MATERIAL = true`; use control style `THIN`,
capsule style `REGULAR`, and no additional opaque background on the native path.

- [x] **Step 2: Render the native branch only inside an explicit API guard**

```ts
if (deviceInfo.apiAvailable('26.0.0')) {
  if (this.materialMode() === 'nativeImmersive') {
    this.buildNativeActionButton()
  } else {
    this.buildFallbackActionButton()
  }
} else {
  this.buildFallbackActionButton()
}
```

The native builder is annotated with
`@Available({ minApiVersion: '26.0.0' })` and owns the `systemMaterial(...)`
call. The version passed to `apiAvailable` must remain a literal.

- [x] **Step 3: Apply the guarded background to attach, idle mic and text capsule**

Keep send as the existing solid accent action. Keep `TextContentStyle.DEFAULT`
and every callback unchanged.

### Task 3: Contract and state coverage

**Files:**
- Create: `scripts/test-ios-native-liquid-composer.ps1`
- Modify: `entry/src/main/ets/ui/tg_ui/demos/TgComposerInputDemo.ets`
- Create: `entry/src/main/ets/ui/tg_ui/spec/TgIosNativeLiquidComposer.md`

- [x] **Step 1: Add source-contract assertions**

Assert the API guard, immersive material constructor, API23 blur fallback,
feature flag, live `TgComposerInput` integration and absence of live
`HdsActionBar`.

- [x] **Step 2: Keep representative demo states**

Cover empty, text/send, multiline, reply, edit, forward, attachment, disabled
and narrow width without adding fake recording behavior.

- [x] **Step 3: Run the source contract**

Run: `powershell -ExecutionPolicy Bypass -File .\scripts\test-ios-native-liquid-composer.ps1`

Expected: `iOS native-liquid composer source contract passed.`

### Task 4: Verification and runtime witness

**Files:**
- Create evidence under `.codex/ui-audit/2026-07-11/ios-native-liquid-composer/`
- Modify compactly: `STATUS.md`, `TASKS/TODO.md`, `TASKS/LESSONS.md`

- [x] **Step 1: Run focused tests, UI smoke, full build and diff check**
- [x] **Step 2: Install the entry HAP only and prove a fresh process**
- [x] **Step 3: Open the same chat and capture light/dark plus focused TextArea**
- [x] **Step 4: Record that API23 engaged `realtimeBlur`, not API26 immersive material**
- [x] **Step 5: Update project memory with verified results and remaining API26 runtime gap**
