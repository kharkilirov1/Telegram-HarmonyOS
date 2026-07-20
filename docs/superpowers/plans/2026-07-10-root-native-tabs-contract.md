# Root Native Tabs Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the accepted native `HdsTabs` render/hide geometry and the
existing root-page content clearance into one typed, testable contract without
changing any current numeric value or visual behavior.

**Architecture:** A pure ArkTS `RootTabBarGeometry` module owns the visible and
chat-detail render tuples plus the current safe-content formula. `MainTabsPage`
consumes the atomic render tuple; `SafeAreaUtils` delegates inset math; root
pages take their initial fallback from the same module. HDS continues to own
the actual island width, radius, material, motion, and system safe-area layout.

**Tech Stack:** ArkTS/ArkUI API 26, UI Design Kit `HdsTabs` API 23+,
`@ohos/hypium` compile-time test suite, PowerShell/Bash source contracts,
DevEco `hvigor`, `hdc` + `uitest` runtime bounds.

## Global Constraints

- This is a zero-visual-delta refactor, not a redesign.
- Keep native `HdsTabs`, `BottomTabBarStyle`, `bleedIconStyle`,
  `barFloatingStyle`, `barBackgroundStyle`, and `ADAPTIVE/ADAPTIVE` material.
- Preserve the exact visible tuple:
  `overlap=true, height=48, bottomMargin=30, opacity=1, maskHeight=110`.
- Preserve the exact chat-detail tuple:
  `overlap=false, height=0, bottomMargin=0, opacity=0, maskHeight=0`.
- Preserve the existing valid-input content formula:
  `48 + max(max(systemBottom, navigationBottom), 10) + 6`.
- Preserve the existing fallback content inset `82` as an explicitly legacy,
  accepted value. Its relationship to a real runtime avoid-area value is not
  proven in M2a and must not be reverse-derived.
- A stale `chatScreenVisible=true` must not hide the bar when the selected root
  tab is not Chats (`selectedIndex !== 2`).
- Do not change Chats badge/icon/label metrics, island width/radius/material,
  tab order, routes, controllers, selection state, animation, swipe policy, or
  listener lifecycle.
- Do not change chat/composer safe-area computation.
- Do not remove legacy custom-tab tokens in this slice; stop using them from
  the active native root-shell path only.
- Never install the standalone ohosTest HAP over the logged-in emulator
  session; compile it only.
- Do not stage, commit, push, publish, or deploy.

---

## File Structure

- `entry/src/main/ets/ui/utils/RootTabBarGeometry.ets` — pure constants,
  atomic visible/hidden resolver, content-inset formula and explicit legacy
  fallback.
- `entry/src/ohosTest/ets/test/RootTabBarGeometry.test.ets` — pure contract
  cases for both render states and inset behavior.
- `entry/src/ohosTest/ets/test/List.test.ets` — registers the test module.
- `scripts/test-root-tab-bar-geometry.ps1` — executes the exact pure production
  `.ets` module through Node's built-in TypeScript stripping on a temporary
  `.ts` copy; this is the behavioral RED/GREEN witness without installing the
  ohosTest HAP.
- `entry/src/main/ets/ui/pages/MainTabsPage.ets` — consumes the atomic state;
  retains all HDS components and style APIs.
- `entry/src/main/ets/ui/utils/SafeAreaUtils.ets` — obtains avoid-area values
  and delegates pure math.
- `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets` — shared fallback.
- `entry/src/main/ets/ui/pages/contacts/ContactsPage.ets` — shared fallback.
- `entry/src/main/ets/ui/pages/calls/CallsPage.ets` — shared fallback.
- `entry/src/main/ets/ui/pages/settings/SettingsPage.ets` — shared fallback.
- `entry/src/main/ets/ui/tg_ui/spec/RootTabBarGeometry.md` — active native
  geometry/state contract and explicit deferred reconciliation.
- `scripts/smoke-ui-phase0.ps1` and `scripts/smoke-ui-phase0.sh` — prevent
  reintroduction of per-file native geometry.
- `STATUS.md`, `TASKS/TODO.md`, `TASKS/LESSONS.md` — verified outcome only.

---

### Task 1: Capture the pre-refactor native runtime baseline

**Files:**
- Create evidence under:
  `.codex/ui-audit/2026-07-10/m2a-native-tabs-contract/before/`

**Interfaces:**
- Consumes: current installed M1 entry HAP and preserved session.
- Produces: root light/dark screenshots/layout dumps, chat-detail hidden-state
  proof, and exact TabBar bounds before source integration.

- [ ] **Step 1: Rebuild/install the pre-refactor source and start a fresh process**

Before any M2a source edit, run the current smoke build, install only the entry
HAP, and prove a fresh process exactly as the after gate will:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-ui-phase0.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-build.ps1
$hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$hap = 'entry\build\default\outputs\default\entry-default-unsigned.hap'
& $hdc install -r $hap
& $hdc shell aa force-stop com.telegram.harmonyos
& $hdc shell "ps -ef | grep com.telegram.harmonyos"
& $hdc shell aa start -a EntryAbility -b com.telegram.harmonyos
& $hdc shell date
& $hdc shell "ps -ef | grep com.telegram.harmonyos"
```

Record process absence after stop, before/after PID, process `TIME`, device date,
and preserved logged-in session in `before/fresh-process.txt`. Do not credit
STIME alone if this emulator shows the already-observed wall-clock offset.

- [ ] **Step 2: Capture the root Chats list in the current light theme**

Use the connected target and create the evidence directory:

```powershell
$out = '.codex\ui-audit\2026-07-10\m2a-native-tabs-contract\before'
New-Item -ItemType Directory -Force -Path $out | Out-Null
& $hdc shell snapshot_display -f /data/local/tmp/m2a-root-light.jpeg
& $hdc file recv /data/local/tmp/m2a-root-light.jpeg "$out\root-light.jpeg"
& $hdc shell uitest dumpLayout -p /data/local/tmp/m2a-root-light.json
& $hdc file recv /data/local/tmp/m2a-root-light.json "$out\root-light-layout.json"
```

Record the actual `TabBar` bounds and screen size from the layout dump. The M1
witness currently shows `[86,2583][1234,2751]` on a `1320×2856` screen; do not
copy that value if the fresh dump differs.

- [ ] **Step 3: Capture dark root and chat-detail hide through UI only**

Switch theme through system Settings UI (`Экран и яркость` → `Темный`), return
to the app, capture `root-dark.jpeg/layout.json`, open `zai`, and capture
`chat-detail-dark.jpeg/layout.json`.

Expected baseline:
- root light/dark contains one native `TabBar` with identical bounds;
- chat destination contains no `TabBar` node;
- root badge/stock tab geometry and material remain visibly unchanged.

- [ ] **Step 4: Save baseline measurements**

Create
`.codex/ui-audit/2026-07-10/m2a-native-tabs-contract/before/measurements.txt`
with device theme, screen size, root TabBar bounds, bottom gap, and the
chat-detail presence/absence result. Values must come from fresh dumps.

Review checkpoint: no source file is modified in Task 1.

---

### Task 2: Add the pure geometry contract test-first

**Files:**
- Create: `entry/src/main/ets/ui/utils/RootTabBarGeometry.ets`
- Create: `entry/src/ohosTest/ets/test/RootTabBarGeometry.test.ets`
- Create: `scripts/test-root-tab-bar-geometry.ps1`
- Modify: `entry/src/ohosTest/ets/test/List.test.ets`
- Modify: `scripts/smoke-ui-phase0.ps1`
- Modify: `scripts/smoke-ui-phase0.sh`

**Interfaces:**
- Produces:
  - `RootTabBarRenderState`
  - `resolveRootTabBarRenderState(selectedIndex, chatScreenVisible)`
  - `computeRootTabContentBottomInset(systemBottomInset, navigationBottomInset)`
  - `ROOT_TAB_BAR_FALLBACK_CONTENT_INSET`

- [ ] **Step 1: Write and register the failing ArkTS contract test**

Create `RootTabBarGeometry.test.ets`:

```typescript
import { describe, expect, it } from '@ohos/hypium';
import {
  computeRootTabContentBottomInset,
  resolveRootTabBarRenderState,
  ROOT_TAB_BAR_FALLBACK_CONTENT_INSET
} from '../../../main/ets/ui/utils/RootTabBarGeometry';

export default function rootTabBarGeometryTest() {
  describe('RootTabBarGeometry', () => {
    it('resolves the accepted visible native tuple', 0, () => {
      const state = resolveRootTabBarRenderState(2, false);
      expect(state.overlap).assertTrue();
      expect(state.height).assertEqual(48);
      expect(state.bottomMargin).assertEqual(30);
      expect(state.opacity).assertEqual(1);
      expect(state.maskHeight).assertEqual(110);
    });

    it('resolves the coordinated chat-detail hidden tuple', 0, () => {
      const state = resolveRootTabBarRenderState(2, true);
      expect(state.overlap).assertFalse();
      expect(state.height).assertEqual(0);
      expect(state.bottomMargin).assertEqual(0);
      expect(state.opacity).assertEqual(0);
      expect(state.maskHeight).assertEqual(0);
    });

    it('does not hide on a non-Chats tab with a stale detail flag', 0, () => {
      const state = resolveRootTabBarRenderState(1, true);
      expect(state.overlap).assertTrue();
      expect(state.height).assertEqual(48);
    });

    it('preserves the existing content-clearance formula', 0, () => {
      expect(computeRootTabContentBottomInset(0, 0)).assertEqual(64);
      expect(computeRootTabContentBottomInset(20, 24)).assertEqual(78);
      expect(computeRootTabContentBottomInset(40, 20)).assertEqual(94);
      expect(computeRootTabContentBottomInset(-10, -20)).assertEqual(64);
      expect(ROOT_TAB_BAR_FALLBACK_CONTENT_INSET).assertEqual(82);
    });
  });
}
```

Register it in `List.test.ets`:

```typescript
import rootTabBarGeometryTest from './RootTabBarGeometry.test';
```

and call it under `// UI view models`:

```typescript
rootTabBarGeometryTest();
```

Also create `scripts/test-root-tab-bar-geometry.ps1` with this executable host
test. It copies the exact pure `.ets` source to a temporary `.ts` extension so
Node 24 can execute it with built-in type stripping:

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'entry/src/main/ets/ui/utils/RootTabBarGeometry.ets'
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
  throw 'node is required for RootTabBarGeometry host tests.'
}
if (-not (Test-Path -LiteralPath $source)) {
  throw "RootTabBarGeometry source not found: $source"
}

$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$tempDir = Join-Path $tempRoot ("telegram-root-tab-geometry-{0}" -f [System.Guid]::NewGuid().ToString('N'))
$resolvedTempDir = [System.IO.Path]::GetFullPath($tempDir)
if (-not $resolvedTempDir.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
  $resolvedTempDir -eq $tempRoot) {
  throw "Unsafe temporary test directory: $resolvedTempDir"
}

New-Item -ItemType Directory -Path $resolvedTempDir | Out-Null
try {
  $modulePath = Join-Path $resolvedTempDir 'RootTabBarGeometry.ts'
  $testPath = Join-Path $resolvedTempDir 'RootTabBarGeometry.test.mjs'
  Copy-Item -LiteralPath $source -Destination $modulePath

  @'
import assert from 'node:assert/strict';
import {
  computeRootTabContentBottomInset,
  resolveRootTabBarRenderState,
  ROOT_TAB_BAR_FALLBACK_CONTENT_INSET
} from './RootTabBarGeometry.ts';

assert.deepEqual(resolveRootTabBarRenderState(2, false), {
  overlap: true,
  height: 48,
  bottomMargin: 30,
  opacity: 1,
  maskHeight: 110
});
assert.deepEqual(resolveRootTabBarRenderState(2, true), {
  overlap: false,
  height: 0,
  bottomMargin: 0,
  opacity: 0,
  maskHeight: 0
});
assert.equal(resolveRootTabBarRenderState(1, true).overlap, true);
assert.equal(resolveRootTabBarRenderState(1, true).height, 48);
assert.equal(computeRootTabContentBottomInset(0, 0), 64);
assert.equal(computeRootTabContentBottomInset(20, 24), 78);
assert.equal(computeRootTabContentBottomInset(40, 20), 94);
assert.equal(computeRootTabContentBottomInset(-10, -20), 64);
assert.equal(ROOT_TAB_BAR_FALLBACK_CONTENT_INSET, 82);
'@ | Set-Content -LiteralPath $testPath -Encoding utf8

  & $node.Source --experimental-strip-types $testPath
  if ($LASTEXITCODE -ne 0) {
    throw "RootTabBarGeometry host tests failed with exit code $LASTEXITCODE."
  }
  Write-Host 'RootTabBarGeometry host tests passed.'
} finally {
  if (Test-Path -LiteralPath $resolvedTempDir) {
    $cleanupPath = [System.IO.Path]::GetFullPath($resolvedTempDir)
    if ($cleanupPath.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
      $cleanupPath -ne $tempRoot) {
      Remove-Item -LiteralPath $cleanupPath -Recurse -Force
    }
  }
}
```

- [ ] **Step 2: Verify behavioral RED, then compile-time RED**

Run the host test first:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-root-tab-bar-geometry.ps1
```

Expected: FAIL because `RootTabBarGeometry.ets` does not exist. This is the
behavioral RED gate.

Then compile the registered Hypium suite:

Run:

```powershell
$hvigor = 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat'
& $hvigor assembleHap --mode module -p product=default -p buildMode=debug `
  -p 'module=entry@ohosTest' --no-daemon
```

Expected: FAIL because `RootTabBarGeometry` cannot be resolved. This second
failure is compile-only coverage; the Hypium assertions are intentionally not
claimed as executed. Do not install the generated ohosTest HAP at any point.

- [ ] **Step 3: Implement the minimal pure contract**

Create `RootTabBarGeometry.ets`:

```typescript
export interface RootTabBarRenderState {
  overlap: boolean;
  height: number;
  bottomMargin: number;
  opacity: number;
  maskHeight: number;
}

export const ROOT_TAB_BAR_VISIBLE_HEIGHT: number = 48;
export const ROOT_TAB_BAR_FLOATING_BOTTOM_MARGIN: number = 30;
export const ROOT_TAB_BAR_BACKPLATE_MASK_HEIGHT: number = 110;
export const ROOT_TAB_BAR_CONTENT_AVOID_FLOOR: number = 10;
export const ROOT_TAB_BAR_CONTENT_BREATHING_ROOM: number = 6;

export function resolveRootTabBarRenderState(selectedIndex: number,
  chatScreenVisible: boolean): RootTabBarRenderState {
  const hidden = selectedIndex === 2 && chatScreenVisible;
  if (hidden) {
    return {
      overlap: false,
      height: 0,
      bottomMargin: 0,
      opacity: 0,
      maskHeight: 0
    };
  }
  return {
    overlap: true,
    height: ROOT_TAB_BAR_VISIBLE_HEIGHT,
    bottomMargin: ROOT_TAB_BAR_FLOATING_BOTTOM_MARGIN,
    opacity: 1,
    maskHeight: ROOT_TAB_BAR_BACKPLATE_MASK_HEIGHT
  };
}

export function computeRootTabContentBottomInset(systemBottomInset: number,
  navigationBottomInset: number): number {
  const resolvedBottomInset = Math.max(0, systemBottomInset, navigationBottomInset);
  return ROOT_TAB_BAR_VISIBLE_HEIGHT
    + Math.max(resolvedBottomInset, ROOT_TAB_BAR_CONTENT_AVOID_FLOOR)
    + ROOT_TAB_BAR_CONTENT_BREATHING_ROOM;
}

// Accepted legacy fallback. Its relationship to a runtime avoid-area value is
// unproven and intentionally deferred beyond the zero-delta M2a refactor.
export const ROOT_TAB_BAR_FALLBACK_CONTENT_INSET: number = 82;
```

- [ ] **Step 4: Add source-smoke existence and value gates**

Both smoke scripts must require the new policy file and exact declarations for
`48`, `30`, `110`, the resolver, the inset function, and the explicit legacy
fallback `82`.
These checks protect the contract file itself but do not yet require consumers;
consumer RED checks belong to Tasks 3 and 4.

- [ ] **Step 5: Verify GREEN for the pure contract**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-ui-phase0.ps1
bash ./scripts/smoke-ui-phase0.sh
powershell -ExecutionPolicy Bypass -File .\scripts\test-root-tab-bar-geometry.ps1
& $hvigor assembleHap --mode module -p product=default -p buildMode=debug `
  -p 'module=entry@ohosTest' --no-daemon
git diff --check -- entry/src/main/ets/ui/utils/RootTabBarGeometry.ets `
  entry/src/ohosTest/ets/test/RootTabBarGeometry.test.ets `
  entry/src/ohosTest/ets/test/List.test.ets scripts/smoke-ui-phase0.ps1 `
  scripts/smoke-ui-phase0.sh
```

Expected: both smokes, the host behavioral suite, and ohosTest compilation
succeed. Only the host suite is claimed as executed assertions.

---

### Task 3: Make MainTabs consume one atomic render state

**Files:**
- Modify: `scripts/smoke-ui-phase0.ps1`
- Modify: `scripts/smoke-ui-phase0.sh`
- Modify: `entry/src/main/ets/ui/pages/MainTabsPage.ets:19-50,237-256`

**Interfaces:**
- Consumes: `RootTabBarRenderState` and
  `resolveRootTabBarRenderState(selectedIndex, chatScreenVisible)`.
- Produces: unchanged HDS rendering driven from one state tuple.

- [ ] **Step 1: Add failing consumer smoke checks**

In both scripts require that `MainTabsPage.ets`:

- imports/uses `resolveRootTabBarRenderState`;
- has no local `TAB_BAR_FLOATING_VISIBLE_HEIGHT`,
  `TAB_BAR_FLOATING_BOTTOM_MARGIN`, or `TAB_BAR_BACKPLATE_HEIGHT` declaration;
- keeps `HdsTabs`, `barOverlap`, `barHeight`, `barFloatingStyle`,
  `barBackgroundStyle`, `ADAPTIVE`, and TOP+BOTTOM `expandSafeArea`.

Run both smokes. Expected: FAIL because the page still owns local constants.

- [ ] **Step 2: Replace local expressions with the shared atomic state**

Add:

```typescript
import {
  resolveRootTabBarRenderState,
  RootTabBarRenderState
} from '../utils/RootTabBarGeometry';
```

Remove the three local geometry constants, `isChatDetailVisible()`, and
`rootTabBarHeight()`. Add:

```typescript
private rootTabBarRenderState(): RootTabBarRenderState {
  return resolveRootTabBarRenderState(this.selectedIndex, this.navState.chatScreenVisible);
}
```

Replace only the five distributed values:

```typescript
.barOverlap(this.rootTabBarRenderState().overlap)
.barHeight(this.rootTabBarRenderState().height)
```

```typescript
barBottomMargin: this.rootTabBarRenderState().bottomMargin,
barOpacity: this.rootTabBarRenderState().opacity,
```

```typescript
maskHeight: this.rootTabBarRenderState().maskHeight
```

Do not change any neighboring HDS/material/background/safe-area/tab code.

- [ ] **Step 3: Verify MainTabs integration GREEN**

Run both smokes, the host behavioral suite, compile the ohosTest HAP, then run
`scripts/smoke-build.ps1`. Expected: all succeed with only known warnings.

Review checkpoint: MainTabs diff is limited to the import, removed local
constants/helpers, one resolver helper, and five property sources.

---

### Task 4: Delegate root-page content clearance to the same contract

**Files:**
- Modify: `scripts/smoke-ui-phase0.ps1`
- Modify: `scripts/smoke-ui-phase0.sh`
- Modify: `entry/src/main/ets/ui/utils/SafeAreaUtils.ets:1-70`
- Modify: `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets:1-70,323-326`
- Modify: `entry/src/main/ets/ui/pages/contacts/ContactsPage.ets:1-40,135-138`
- Modify: `entry/src/main/ets/ui/pages/calls/CallsPage.ets:1-140,262-265`
- Modify: `entry/src/main/ets/ui/pages/settings/SettingsPage.ets:1-35,108-111`
- Create: `entry/src/main/ets/ui/tg_ui/spec/RootTabBarGeometry.md`

**Interfaces:**
- Consumes: `computeRootTabContentBottomInset` and
  `ROOT_TAB_BAR_FALLBACK_CONTENT_INSET`.
- Produces: the exact pre-refactor valid-input formula and fallback for all four
  root content pages.

- [ ] **Step 1: Add failing active-consumer smoke checks**

Both scripts must require:

- `SafeAreaUtils.ets` imports/calls `computeRootTabContentBottomInset`;
- none of `SafeAreaUtils`, ChatList, Contacts, Calls, or Settings references
  `TAB_BAR_FLAT_HEIGHT`, `TAB_BAR_ISLAND_BOTTOM_MARGIN`, or
  `TAB_BAR_CONTENT_SAFE_BOTTOM`;
- all four pages use `ROOT_TAB_BAR_FALLBACK_CONTENT_INSET` for initial/error
  fallback.

Run both smokes. Expected: FAIL on the current token-based consumers.

- [ ] **Step 2: Delegate avoid-area math without changing lifecycle**

In `SafeAreaUtils.ets`, import:

```typescript
import {
  computeRootTabContentBottomInset,
  ROOT_TAB_BAR_FALLBACK_CONTENT_INSET
} from './RootTabBarGeometry';
```

Within `computeTabBottomInset`, preserve the current `windowStage`, system
avoid-area, navigation-indicator try/catch, and outer fallback lifecycle. Rename
the local values to `systemBottomInset` and `navigationBottomInset`, then return:

```typescript
return computeRootTabContentBottomInset(systemBottomInset, navigationBottomInset);
```

The final fallback becomes:

```typescript
return ROOT_TAB_BAR_FALLBACK_CONTENT_INSET;
```

Do not touch `computeChatBottomInset` or window listener functions.

- [ ] **Step 3: Point all root pages at the shared fallback**

Each of ChatList, Contacts, Calls, and Settings imports
`ROOT_TAB_BAR_FALLBACK_CONTENT_INSET` from its relative
`../../utils/RootTabBarGeometry` path and replaces both occurrences of
`TgUiTokens.TAB_BAR_CONTENT_SAFE_BOTTOM` with that constant. Do not change
`contentEndOffset`, spacer layout, resize listeners, or page behavior.

- [ ] **Step 4: Write the contract passport**

`RootTabBarGeometry.md` records:

- exact visible/hidden tuples;
- exact current content formula and explicit legacy fallback `82`;
- HDS owns island width/radius/material/motion/safe-area rendering;
- `maskHeight`, `barHeight`, floating margin and content clearance are distinct;
- stale detail flag behavior;
- active consumers and stop conditions;
- deferred follow-up: reconciling content floor `10`/fallback `82` with render
  margin `30` or deriving fallback from real avoid-area evidence requires
  multi-device no-gap/no-overlap evidence and is not M2a.

- [ ] **Step 5: Verify the full source/build contract**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-ui-phase0.ps1
bash ./scripts/smoke-ui-phase0.sh
powershell -ExecutionPolicy Bypass -File .\scripts\test-root-tab-bar-geometry.ps1
$hvigor = 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat'
& $hvigor assembleHap --mode module -p product=default -p buildMode=debug `
  -p 'module=entry@ohosTest' --no-daemon
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-build.ps1
git diff --check
```

Expected: both smokes, ohosTest compilation, clean entry build, and diff check
succeed.

---

### Task 5: Prove zero visual delta and atomic hide at runtime

**Files:**
- Create evidence under:
  `.codex/ui-audit/2026-07-10/m2a-native-tabs-contract/after/`
- Modify: `STATUS.md`
- Modify: `TASKS/TODO.md`
- Modify: `TASKS/LESSONS.md` only for an observed reusable pitfall.

**Interfaces:**
- Consumes: rebuilt entry HAP and the Task 1 before baseline.
- Produces: before/after bounds comparison and fresh-process proof.

- [ ] **Step 1: Install only the entry HAP and prove a fresh process**

Install `entry-default-unsigned.hap`, use the emulator-supported positional
`aa force-stop com.telegram.harmonyos`, prove process absence, start the ability,
and record before/after PID plus `TIME`. Preserve the logged-in session.

- [ ] **Step 2: Repeat the before matrix after the refactor**

Capture root Chats light/dark and `zai` chat detail under `after/`, with matching
layout dumps. Navigate Contacts, Calls, and Settings and capture their bottom
content/inset state at least once; switch back through all tabs and reopen/close
chat detail.

Required acceptance:

- root TabBar bounds and bottom gap equal the fresh Task 1 values in both themes;
- chat detail has no TabBar node/hit surface; back restores one TabBar;
- Chats badge/bleed and stock tabs are unchanged;
- last visible/tappable content is not covered on all four root pages;
- no new empty gutter appears;
- repeated tab switching does not stale the inset;
- session survives entry-only reinstall and fresh process.

- [ ] **Step 3: Record comparison and verified project state**

Write `after/measurements.txt` and `comparison.md` with actual before/after
bounds and pass/fail per acceptance item. Update project memory pack only after
the evidence exists:

```markdown
- M2a native root-tab contract: `RootTabBarGeometry` now owns the unchanged
  visible/hidden HDS tuples and existing content-inset policy; before/after
  runtime bounds show zero visual delta and atomic chat-detail hide.
```

Do not claim that content floor `10` has been reconciled with render margin
`30`; it is intentionally preserved and explicitly deferred.

- [ ] **Step 4: Final verification**

After the last edit, rerun both UI smokes, the host behavioral suite, ohosTest
compilation, clean entry build, `git diff --check`, and `git status --short`.
Do not stage or commit.
