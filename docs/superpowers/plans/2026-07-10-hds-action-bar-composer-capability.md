# HdsActionBar Composer Capability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Determine whether `HdsActionBar` can host the Telegram composer state
surface on target 26 / Pura API23 without changing the live composer, and keep
only an isolated demo/passport unless every parity gate passes.

**Architecture:** A preview/demo component owns synthetic presentation state and
renders a custom text/accessory builder inside `HdsActionBar`, with explicit
`primaryButtonBuilderWidth` and native start/end actions. A temporary,
byte-restored `EntryAbility` + `main_pages.json` harness is used only to capture
runtime behavior. `TgChatScreenPage`, `TgComposerInput`, controllers, TDLib and
root navigation remain untouched.

**Tech Stack:** ArkTS `@ComponentV2`, ArkUI `TextArea`, UI Design Kit
`HdsActionBar` / `ActionBarButton` / `ActionBarStyle`, `LengthMetrics`, DevEco
`hvigor`, `hdc`, `uitest`, `snapshot_display`.

## Global Constraints

- Demo-only production scope: no import or call site from live pages.
- Do not modify `TgChatScreenPage.ets`, `TgComposerInput.ets`,
  `ChatComposerController.ets`, stores, use cases or TDLib.
- Always pass `primaryButtonBuilderWidth` when `primaryButtonBuilder` is used;
  installed SDK lines 43-52 warn that omission corrupts the back-panel width.
- Exercise empty/mic, text/send, reply, edit, forward, attachment, slow mode,
  recording, emoji/media panel, multiline, focus/IME and bottom-safe-area
  states. A synthetic visual state is not proof of its gesture/semantic parity.
- Native `ActionBarButton` exposes only `onClick` directly; press/hold/drag
  recording remains unproven unless a real runtime gesture reaches distinct
  begin/update/end/cancel witnesses.
- Stop on clipping, stale builder width, keyboard collision, inaccessible
  actions, or any state that requires weakening current composer semantics.
- A failed capability remains useful as a checked-in demo/passport; it must not
  be integrated into the live composer.
- Temporary runtime harness edits must be backed up and restored byte-for-byte,
  followed by a clean production rebuild, entry-only install and logged-in root
  witness.
- Do not install the standalone ohosTest HAP, stage, commit, push or deploy.

## Grounding

- Official HarmonyOS docs: `HdsActionBar` is an API20+ `@ComponentV2` stage
  component with `primaryButtonBuilder`, explicit builder width, start/end
  `ActionBarButton[]`, `ActionBarStyle`, expand state and adaptive blur strategy.
- Installed SDK:
  `C:/Program Files/Huawei/DevEco Studio/sdk/default/hms/ets/api/@hms.hds.HdsActionBar.d.ets`
  lines 20-114, 124-260 and 470-683.
- Harmony example:
  `C:/Refs/Telegram/HarmonyOSComponentUXExamples/entry/src/main/ets/components/action/actionbar/components/`
  demonstrates horizontal, collapsed and vertical HDS button arrangements.
- Telegram iOS:
  `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift`
  lines 639-736 and 817-903 establish separate glass/accessory/action surfaces,
  slow mode and recording begin/end/cancel/update/lock/switch callbacks.
- Live Harmony composer:
  `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets:2969-3091` owns panel
  visibility and height; `TgComposerInput.ets:13-64,446+` owns the current
  presentation/event contract.

## File Structure

- Create `entry/src/main/ets/ui/tg_ui/demos/TgHdsActionBarComposerDemo.ets` —
  isolated interactive capability surface.
- Create `entry/src/main/ets/ui/tg_ui/spec/HdsActionBarComposerCapability.md` —
  references, state/parity matrix, observed runtime result and migration gate.
- Create `scripts/test-hds-action-bar-composer-demo.ps1` — source contract gate.
- Create evidence under
  `.codex/ui-audit/2026-07-10/m2c-hds-action-bar-composer/`.
- Temporarily modify, then byte-restore,
  `entry/src/main/ets/entryability/EntryAbility.ets` and
  `entry/src/main/resources/base/profile/main_pages.json` for runtime only.
- Modify `STATUS.md`, `TASKS/TODO.md`, `TASKS/LESSONS.md` only after the final
  accept/reject decision.

---

### Task 1: Freeze scope and create a RED demo contract

**Files:**
- Create: `scripts/test-hds-action-bar-composer-demo.ps1`
- Create evidence under
  `.codex/ui-audit/2026-07-10/m2c-hds-action-bar-composer/before/`

**Interfaces:**
- Produces a gate requiring the demo to use the intended HDS path while
  forbidding live composer imports/call sites.

- [ ] **Step 1: Back up the temporary harness files and record live hashes**

Copy `EntryAbility.ets` and `main_pages.json` into
`before/runtime-harness-backup/`; record SHA-256 for those files plus
`TgChatScreenPage.ets` and `TgComposerInput.ets`.

- [ ] **Step 2: Write the source contract before the demo exists**

Require these fragments in the demo:

```text
HdsActionBar({
primaryButtonBuilder:
primaryButtonBuilderWidth: LengthMetrics.vp(
startButtons:
endButtons:
new ActionBarStyle({
TextArea({
MODE_REPLY
MODE_EDIT
MODE_FORWARD
MODE_ATTACHMENT
MODE_SLOW
MODE_RECORDING
showAuxPanel
```

Require zero references to `TgHdsActionBarComposerDemo` outside the demo,
passport, dedicated test script and temporary ignored evidence.

- [ ] **Step 3: Run and record RED**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-hds-action-bar-composer-demo.ps1
```

Expected: exit `1` because the demo file is absent; unrelated failures do not
count as RED.

---

### Task 2: Implement the smallest interactive capability demo

**Files:**
- Create: `entry/src/main/ets/ui/tg_ui/demos/TgHdsActionBarComposerDemo.ets`
- Create: `entry/src/main/ets/ui/tg_ui/spec/HdsActionBarComposerCapability.md`

**Interfaces:**
- Produces one `@Entry`/`@Preview` demo with local synthetic state only.
- Does not produce a reusable production composer or a live call site.

- [ ] **Step 1: Add explicit synthetic state selectors**

The demo must allow switching among normal, reply, edit, forward, attachment,
slow and recording states; toggling an emoji/media panel; clearing/prefilling
text; and loading a multiline value. `lastAction` must expose button engagement
in the UI.

- [ ] **Step 2: Build the custom primary content**

Render an optional accessory row plus controlled `TextArea`. Derive builder and
bar height from the selected state and bounded line count. Use existing
`TgUiTokens` for text, spacing, radius and composer colors.

- [ ] **Step 3: Host it in HdsActionBar**

Use explicit `LengthMetrics.vp(...)` for both the builder width contract and
`ActionBarStyle` geometry. Use native start/end `ActionBarButton` instances for
attach and current right action. Set `isExpand: true` so both sides are visible.

- [ ] **Step 4: Write the passport without claiming parity**

Record every required state as `runtime-proven`, `layout-only`, `unsupported`
or `not-tested`. Explicitly distinguish button click evidence from recording
press/hold/drag semantics.

- [ ] **Step 5: Run GREEN source/build checks**

Run the dedicated source gate, PowerShell/Bash UI smokes, root geometry test and
ohosTest compile/package. Then run a clean main entry build; the clean main
build is required because ohosTest compilation can miss main-tree nesting
errors.

---

### Task 3: Exercise the demo on the real API23 emulator

**Files:**
- Temporarily modify then restore: `EntryAbility.ets`, `main_pages.json`
- Create evidence under
  `.codex/ui-audit/2026-07-10/m2c-hds-action-bar-composer/runtime/`

**Interfaces:**
- Consumes the exact permanent demo source.
- Produces runtime bounds/images/layouts and an accept/reject decision.

- [ ] **Step 1: Enable the temporary demo harness**

Add the demo page to `main_pages.json` and point only the temporary
`windowStage.loadContent(...)` path at it. Confirm the diff is restricted to
those two backed-up harness files before building.

- [ ] **Step 2: Install entry-only and prove a fresh demo process**

Record target, API, emulator PID/start, HAP SHA-256, process absence, fresh app
PID and the demo title from `dumpLayout`.

- [ ] **Step 3: Capture the state matrix**

Capture normal-empty, text/send, reply/edit/forward/attachment, slow,
recording, multiline and auxiliary-panel states. Require stable explicit
builder/back-panel bounds and non-overlapping HDS actions.

- [ ] **Step 4: Capture focus/IME and bottom behavior**

Focus the `TextArea`, enter text, capture keyboard-visible layout, then hide the
keyboard. Require the action bar/input to remain visible, tappable and within
the resized viewport with no stale height after keyboard dismissal.

- [ ] **Step 5: Apply the stop decision**

Accept for future production integration only if all approved design states,
including recording gesture/cancel semantics, are proven. Otherwise mark the
capability rejected for live migration and keep the current custom composer.

---

### Task 4: Restore production and close evidence

**Files:**
- Restore: `EntryAbility.ets`, `main_pages.json`
- Modify: `STATUS.md`, `TASKS/TODO.md`, `TASKS/LESSONS.md`

**Interfaces:**
- Produces the original logged-in production shell plus a durable demo/passport
  and evidence report.

- [ ] **Step 1: Restore the temporary harness byte-for-byte**

Compare both restored SHA-256 hashes with Task 1. Also compare live composer
file hashes to prove they never changed.

- [ ] **Step 2: Run final production verification**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-hds-action-bar-composer-demo.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-ui-phase0.ps1
bash ./scripts/smoke-ui-phase0.sh
powershell -ExecutionPolicy Bypass -File .\scripts\test-root-tab-bar-geometry.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-build.ps1
git diff --check
```

- [ ] **Step 3: Reinstall production entry and prove session/root restoration**

Install only `entry-default-unsigned.hap`, force-stop/start, require the logged-in
four-tab root shell and M2a TabBar bounds `[80,2607][1228,2775]`.

- [ ] **Step 4: Record the final decision**

Write `runtime/decision.md`, update the compact project docs and mark this plan
complete. Never imply that a demo visual state proves domain or gesture parity.

## Self-review

- Scope: the live composer, routes, domain and TDLib are explicitly excluded.
- Spec coverage: every composer capability from the approved hybrid design is
  either exercised or must be marked unsupported/not-tested.
- Engagement: explicit builder width, native HDS nodes, action callbacks and
  runtime bounds distinguish the intended path from a custom fallback.
- Rollback: both temporary production files and the two protected composer
  files have hash witnesses.
- Placeholder scan: no implementation placeholder or deferred production
  migration remains in the plan.
