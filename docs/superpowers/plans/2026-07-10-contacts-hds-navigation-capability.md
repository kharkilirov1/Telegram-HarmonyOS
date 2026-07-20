# Contacts HdsNavigation Capability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove and, only if runtime acceptance passes, keep a native
`HdsNavigation` title/search/material path on Contacts while leaving Telegram
content, TDLib, Chats navigation and the accepted M2a root island unchanged.

**Architecture:** `MainTabsPage` owns one Contacts `Scroller` and the native
Search query because it owns the `HdsNavigation`. `ContactsPage` consumes the
same `Scroller`, filters only its already-built `ContactVO[]`, and adds the
known Search-lane height to its existing overlay clearance. No domain/store or
route contract changes.

**Tech Stack:** ArkTS `@ComponentV2`, ArkUI `Search`/`List`/`Scroller`, UI
Design Kit `HdsNavigation`, `HdsNavigationTitleMode.MINI`, `COMMON_BLUR`, API23 adaptive material, DevEco
`hvigor`, `hdc` + `uitest` runtime evidence.

## Global Constraints

- Contacts-only production scope; do not touch Chats/Calls/Settings navigation,
  `NavPathStack` routing, TDLib, store, or contact hydration.
- Use the same `Scroller` instance in `List({ scroller })` and
  `.bindToScrollable([scroller])`; a source-only binding is not runtime proof.
- Use native `Search` inside `titleBar.content.bottomBuilder`; no custom glass
  chrome and no fake Add/Sort actions.
- Preserve M2a TabBar bounds `[80,2607][1228,2775]`, island material, badge,
  safe-area policy and all five atomic render-state bindings.
- Keep `EntryAbility` Window system-bar handling; do not add
  `HdsNavigation.systemBarStyle` (official docs warn against combining paths).
- Reuse `TgUiTokens.SEARCH_BAR_HEIGHT`,
  `CHAT_LIST_NAV_SEARCH_AREA_HEIGHT`, and `SEARCH_BAR_SIDE_INSET`; do not add
  duplicate geometry constants.
- Search is local presentation filtering over existing `ContactVO` values only.
- Do not stage, commit, push, install a standalone ohosTest HAP, or alter the
  logged-in session.

## Grounding

- Official UI Design Kit docs:
  - `HdsNavigation` is the root container and supports
    `titleBar.content.bottomBuilder`.
  - `bindToScrollable(Array<Scroller>)` is the API20+ contract for dynamic
    scrolling/blur behavior.
  - `ScrollEffectType.COMMON_BLUR` is supported since API18 and is the default
    common blur mode.
  - `HdsNavigationTitleMode.MINI` is the documented fixed compact title lane;
    FREE is the default dynamic mode.
  - `TitleBarStyleOptions.systemMaterialEffect` is API23 and accepts
    `hdsMaterial.MaterialType/MaterialLevel`.
- Installed SDK declarations:
  `C:/Program Files/Huawei/DevEco Studio/sdk/default/hms/ets/api/@hms.hds.hdsBaseComponent.d.ets`
  (`ScrollEffectType:730`, `ScrollEffectOptions:1319`,
  `SystemMaterialParams:1386`, `systemMaterialEffect:1472`,
  `BottomBuilderParams:1794`, `HdsNavigationTitleBarOptions:2001`,
  `bindToScrollable:2436`).
- Telegram iOS:
  `C:/Refs/Telegram/Telegram-iOS-current/submodules/ContactListUI/Sources/ContactsController.swift:145-178`
  and `ContactsControllerNode.swift:348-390,479-525` establish Contacts title
  plus an external navigation search host; the full iOS global/device search
  semantics are deliberately not ported in this slice.
- Harmony reference:
  `C:/Refs/Telegram/HarmonyOSComponentUXExamples/entry/src/main/ets/components/navigation/titlebar/components/EmphasizedTitle.ets:25-125`
  demonstrates `COMMON_BLUR` title-bar styling.

## File Structure

- Modify `entry/src/main/ets/ui/pages/MainTabsPage.ets` — native title/search
  host, shared Scroller and query ownership.
- Modify `entry/src/main/ets/ui/pages/contacts/ContactsPage.ets` — Scroller/query
  consumer and local filtered projection.
- Modify `scripts/smoke-ui-phase0.ps1` and `.sh` — active source-contract gates.
- Create
  `entry/src/main/ets/ui/tg_ui/spec/HdsNavigationContactsCapability.md` — API,
  reference, state and stop-condition passport.
- Create runtime evidence under
  `.codex/ui-audit/2026-07-10/m2b-contacts-hds-navigation/`.
- Modify `STATUS.md`, `TASKS/TODO.md`, and `TASKS/LESSONS.md` only after the
  runtime decision is final, including a rejected-and-rolled-back result.

---

### Task 1: Capture the pre-edit Contacts baseline

**Files:**
- Create evidence under
  `.codex/ui-audit/2026-07-10/m2b-contacts-hds-navigation/before/`

**Interfaces:**
- Consumes: installed, verified M2a entry HAP and logged-in Pura API23 session.
- Produces: title/list/TabBar bounds and top/scrolled screenshots before code.

- [x] **Step 1: Confirm the exact frontend and runtime identity**

Run `aa start` for `com.telegram.harmonyos`, dump layout, and require the
Contacts/Calls/Chats/Settings root shell before sending coordinates. Record the
Emulator PID/start time and target API.

- [x] **Step 2: Capture Contacts top and scrolled states**

Open Contacts, scroll to absolute top, capture image/layout, then scroll upward
once and capture again. Record:

```text
TabBar bounds
Navigation/NavBar bounds
title Text bounds
Search node count (expected 0 before)
first visible ListItem bounds
```

- [x] **Step 3: Preserve a rollback witness**

Copy the two scoped production files and both smoke scripts into the ignored
evidence `before/source-backup/` directory. Never use destructive git restore
against the dirty worktree.

---

### Task 2: Add RED source-contract gates

**Files:**
- Modify `scripts/smoke-ui-phase0.ps1`
- Modify `scripts/smoke-ui-phase0.sh`

**Interfaces:**
- Consumes: exact M2b field/builder names below.
- Produces: symmetric gates that fail before production edits.

- [x] **Step 1: Require the native host contract in both scripts**

Require these MainTabs fragments:

```text
private contactsScroller: Scroller = new Scroller();
@Local contactsSearchQuery: string = '';
listScroller: this.contactsScroller
searchQuery: this.contactsSearchQuery
bottomBuilder:
scrollEffectType: ScrollEffectType.COMMON_BLUR
systemMaterialEffect:
.titleMode(HdsNavigationTitleMode.MINI)
.bindToScrollable([this.contactsScroller])
```

Require these Contacts fragments:

```text
@Param listScroller: Scroller = new Scroller();
@Param searchQuery: string = '';
List({ scroller: this.listScroller })
this.applySearchFilter();
  .height(this.topBarTotalHeight + TgUiTokens.CHAT_LIST_NAV_SEARCH_AREA_HEIGHT + TgUiTokens.SPACE_16)
```

- [x] **Step 2: Run both smokes and record RED**

Expected: both exit `1` because the shared Scroller/native Search contract is
not yet present. A failure from an unrelated existing gate is not accepted as
the M2b RED witness.

---

### Task 3: Implement the minimal native Contacts capability

**Files:**
- Modify `entry/src/main/ets/ui/pages/MainTabsPage.ets`
- Modify `entry/src/main/ets/ui/pages/contacts/ContactsPage.ets`

**Interfaces:**
- Produces `contactsScroller: Scroller`, `contactsSearchQuery: string`,
  `buildContactsSearchBar()`, `ContactsPage.listScroller`, and
  `ContactsPage.searchQuery`.

- [x] **Step 1: Add the MainTabs-owned Search/Scroller state**

Extend the UI Design Kit import with `BottomBuilderShowType` and
`ScrollEffectType`, then add:

```typescript
private contactsScroller: Scroller = new Scroller();
@Local contactsSearchQuery: string = '';

@Builder
buildContactsSearchBar() {
  Column() {
    Search({
      value: this.contactsSearchQuery,
      placeholder: $r('app.string.search_placeholder')
    })
      .width('100%')
      .height(TgUiTokens.SEARCH_BAR_HEIGHT)
      .cancelButton({ style: CancelButtonStyle.INPUT })
      .onChange((value: string) => {
        this.contactsSearchQuery = value;
      })
      .onSubmit((value: string) => {
        this.contactsSearchQuery = value;
      })
  }
  .width('100%')
  .height(TgUiTokens.CHAT_LIST_NAV_SEARCH_AREA_HEIGHT)
  .padding({
    left: TgUiTokens.SEARCH_BAR_SIDE_INSET,
    right: TgUiTokens.SEARCH_BAR_SIDE_INSET
  })
  .justifyContent(FlexAlign.Center)
}
```

- [x] **Step 2: Wire only the Contacts HdsNavigation branch**

Replace `ContactsPage()` with:

```typescript
ContactsPage({
  listScroller: this.contactsScroller,
  searchQuery: this.contactsSearchQuery
})
```

Use this title contract:

```typescript
.titleBar({
  style: {
    scrollEffectOpts: {
      enableScrollEffect: true,
      scrollEffectType: ScrollEffectType.COMMON_BLUR
    },
    systemMaterialEffect: {
      materialType: hdsMaterial.MaterialType.ADAPTIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    }
  },
  content: {
    title: { mainTitle: $r('app.string.contacts') },
    bottomBuilder: {
      builder: (): void => this.buildContactsSearchBar(),
      height: TgUiTokens.CHAT_LIST_NAV_SEARCH_AREA_HEIGHT,
      showType: BottomBuilderShowType.DIRECTLY_SHOW
    }
  }
})
.titleMode(HdsNavigationTitleMode.MINI)
.bindToScrollable([this.contactsScroller])
```

Keep `.mode`, `.hideBackButton`, tab style and every non-Contacts branch
unchanged.

- [x] **Step 3: Add a filtered Contacts projection**

In `ContactsPage` add:

```typescript
@Param listScroller: Scroller = new Scroller();
@Param searchQuery: string = '';
@Local private visibleContacts: ContactVO[] = [];

@Monitor('searchQuery')
private onSearchQueryChanged(_monitor: IMonitor): void {
  this.applySearchFilter();
}

private applySearchFilter(): void {
  const normalizedQuery = this.searchQuery.trim().toLowerCase();
  if (normalizedQuery.length === 0) {
    this.visibleContacts = this.contacts;
    return;
  }
  this.visibleContacts = this.contacts.filter((contact: ContactVO): boolean =>
    contact.sortKey.includes(normalizedQuery));
}

private emptyStateText(): string {
  if (this.searchQuery.trim().length > 0) {
    return localized($r('app.string.search_no_results').id, 'No results found');
  }
  return localized($r('app.string.no_contacts').id, 'No contacts yet');
}
```

After `this.contacts = result`, call `this.applySearchFilter()`.

- [x] **Step 4: Make the List consume the same Scroller and projection**

Runtime attempt 1 showed that keeping `contentStartOffset` with a bound HDS
Scroller immediately collapses and clips the title. Match the official HDS
example's real leading content instead:

```typescript
if (this.visibleContacts.length > 0) {
  List({ scroller: this.listScroller }) {
    ListItem() {
      Column() {
        Blank()
          .width('100%')
          .height(this.topBarTotalHeight + TgUiTokens.CHAT_LIST_NAV_SEARCH_AREA_HEIGHT + TgUiTokens.SPACE_16)
      }
      .width('100%')
    }
    ForEach(this.visibleContacts, ...)
  }
} else {
  Text(this.emptyStateText())
}
```

Use `this.visibleContacts.length` for separator placement, keep
`contentEndOffset`, and remove Contacts' `contentStartOffset`. Preserve row
atoms, bottom inset, listeners and contact rebuild lifecycle.

- [x] **Step 5: Verify source/build GREEN before runtime**

Run both UI smokes, the M2a host geometry suite, ohosTest compile-only, clean
entry build and focused `git diff --check`. Any ArkTS type error is fixed before
installing a HAP.

---

### Task 4: Write the capability passport

**Files:**
- Create
  `entry/src/main/ets/ui/tg_ui/spec/HdsNavigationContactsCapability.md`

**Interfaces:**
- Records exact ownership, references, states and rejection rules.

- [x] **Step 1: Record the contract**

Include:

- exact official/local reference paths listed in Grounding;
- `MainTabsPage` ownership of Search query + Scroller;
- same-Scroller invariant;
- local-only `ContactVO` filtering and empty-state rules;
- `COMMON_BLUR` + API23 adaptive material;
- M2a root island as a non-regression boundary;
- explicit exclusion of Add/Sort, global/device search, Chats routes and
  `HdsActionBar`;
- stop conditions: title/search overlap, first-row gap beyond the builder's
  vertical padding, zero top-vs-scrolled material delta, keyboard/island
  collision, stale query/inset after tab switching, or changed TabBar bounds.

---

### Task 5: Runtime accept or rollback

**Files:**
- Create evidence under
  `.codex/ui-audit/2026-07-10/m2b-contacts-hds-navigation/after/`
- Modify `STATUS.md`, `TASKS/TODO.md`, `TASKS/LESSONS.md` only on acceptance.

**Interfaces:**
- Consumes: rebuilt entry HAP and Task 1 baseline.
- Produces: an accepted production capability or a fully reverted scoped spike.

- [x] **Step 1: Install entry-only and prove a fresh process**

Install only `entry-default-unsigned.hap`, prove process absence, start the
ability, record raw `ps -ef`, trimmed before/after PID fields, app `TIME`, HAP
hash and preserved session.

- [x] **Step 2: Prove intended native paths engaged**

Capture Contacts top and scrolled light/dark states. Require:

- one title and one native Search node;
- first `ListItem` top at or below the bottom-builder area with no overlap and
  no unexplained gap larger than the builder's vertical padding;
- identical `Scroller` path demonstrated by a real list scroll plus an
  observable title-region material/blur delta;
- TabBar remains `[80,2607][1228,2775]`.

- [ ] **Step 3: Prove filtering, clear, keyboard and tab return** *(not run:
  the title-clipping stop condition had already rejected the capability)*

Input an ASCII prefix known to exist in the captured Contact list, verify every
visible result matches case-insensitively, clear it and verify the original list
returns. Show/hide keyboard, scroll to the final contact, then switch
Contacts -> Chats -> Contacts; require no island collision, stale inset, stale
filtered projection or lost Search state.

- [x] **Step 4: Apply the acceptance decision**

If every gate passes, keep the slice and write `measurements.txt` plus
`comparison.md`. If any stop condition fires, restore only the four scoped
source/smoke files from Task 1 backup, remove the unaccepted passport, rebuild,
and record the rejected capability and exact reason in evidence.

- [x] **Step 5: Final verification**

After the last accepted edit run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-ui-phase0.ps1
bash ./scripts/smoke-ui-phase0.sh
powershell -ExecutionPolicy Bypass -File .\scripts\test-root-tab-bar-geometry.ps1
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p product=default -p buildMode=debug -p 'module=entry@ohosTest' --no-daemon
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-build.ps1
git diff --check
git status --short
```

Do not install the ohosTest HAP and do not stage or commit.

## Outcome — REJECTED on target 26 / API 23 runtime

The native same-`Scroller` Contacts path engaged, but failed the title-region
acceptance gate on the Pura API23 emulator:

1. `contentStartOffset` made HDS treat the list as already scrolled; the title
   collapsed/clipped to `[56,137][487,168]`.
2. An in-list `104vp` clearance restored the expanded title, but Search
   `[56,424][1252,550]` overlapped the first contact
   `[0,500][1308,698]` by `50px`.
3. Reusing `SPACE_16` produced a valid `6px` top gap and preserved the M2a
   TabBar bounds, but FREE mode clipped the title at the root/status boundary
   after a real list scroll.
4. Explicit `HdsNavigationTitleMode.MINI` still clipped the title at
   `[56,137][487,151]` while Search rendered at `[56,228][1252,354]`.

The stop condition therefore fired before filtering/keyboard/tab-return tests.
The two production files and two smoke scripts were restored byte-for-byte from
`before/source-backup/`, and the unaccepted passport was removed. Evidence is
under `.codex/ui-audit/2026-07-10/m2b-contacts-hds-navigation/after/`.

## Self-review

- Spec coverage: Contacts title/search, same-Scroller binding, local filter,
  material delta, root-island non-regression, keyboard and rollback are covered.
- Scope: no independent subsystem is bundled; `HdsActionBar` remains a separate
  M2c demo-only slice.
- Type consistency: `contactsScroller`, `contactsSearchQuery`,
  `listScroller`, `searchQuery`, `visibleContacts`, and
  `buildContactsSearchBar` are used consistently across tasks.
- Placeholder scan: no implementation placeholder remains.
