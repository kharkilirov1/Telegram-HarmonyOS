# iOS Composer Panels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Match current Telegram iOS composer panel switching and recent-media attachment sheet on HarmonyOS.

**Architecture:** Keep the existing custom composer and native `bindSheet` boundary. Add a focused sheet atom, keep reactive state in the page, and keep media permission/query logic in `ChatComposerController`.

**Tech Stack:** ArkTS, ArkUI `@ComponentV2`, `bindSheet`, `PhotoAccessHelper`, PowerShell contract tests, API23 emulator.

## Global Constraints

- UI-only slice; no TDLib/domain rewrite.
- Telegram panel and system IME are mutually exclusive.
- Recent thumbnails come from real `PhotoAsset.uri` values.
- Unsupported category flows are visibly disabled, never simulated.
- No commit, staging or push without explicit user confirmation.

---

### Task 1: Lock the source contract

**Files:**
- Modify: `scripts/test-ios-native-liquid-composer.ps1`

**Interfaces:**
- Consumes: current composer/page/controller source.
- Produces: a failing structural witness for the missing panel and sheet behavior.

- [ ] Add assertions for `emojiPanelOpen`, keyboard-mode callback, focus-time panel dismissal, `TgAttachmentSheet`, `SheetSize.LARGE`, recent-media state and PhotoAccessHelper loading.
- [ ] Run `powershell -ExecutionPolicy Bypass -File .\scripts\test-ios-native-liquid-composer.ps1` and confirm failure is caused by those missing contracts.

### Task 2: Implement mutual exclusion and glyph morph

**Files:**
- Modify: `entry/src/main/ets/ui/tg_ui/atoms/TgComposerInput.ets`
- Modify: `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`
- Create: `entry/src/main/resources/base/media/ic_keyboard.svg`
- Modify: `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets`

**Interfaces:**
- Consumes: `emojiPanelOpen: boolean` and `onKeyboardModePress(): void`.
- Produces: custom panel closes before IME focus and composer button renders the correct mode glyph.

- [ ] Pass the current custom-panel state into `TgComposerInput`.
- [ ] Close both custom panels in `handleComposerWillFocus()` before IME resize.
- [ ] When the panel is open, render keyboard icon and focus the text controller after closing it.
- [ ] Re-run the focused contract test.

### Task 3: Implement the recent-media attachment sheet

**Files:**
- Create: `entry/src/main/ets/ui/tg_ui/atoms/TgAttachmentSheet.ets`
- Modify: `entry/src/main/ets/ui/tg_ui/atoms/TgComposerInput.ets`
- Modify: `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`
- Modify: `entry/src/main/ets/ui/pages/chat/ChatComposerController.ets`
- Modify: localized resource files under `entry/src/main/resources/*/element/string.json`

**Interfaces:**
- Produces: `TgAttachmentRecentItem` model and `TgAttachmentSheet` events.
- Consumes: `loadRecentAttachmentMedia(): Promise<TgAttachmentRecentItem[]>` and existing attachment action dispatch.

- [ ] Replace the four-action 220vp body with a `SheetSize.LARGE` sheet atom.
- [ ] Query at most 24 recent image/video assets ordered by `DATE_ADDED`, always closing `FetchResult`.
- [ ] Render a three-column thumbnail grid plus six-category bottom rail.
- [ ] Route Gallery, Camera and File to existing picker paths; keep unsupported categories disabled.
- [ ] Re-run focused contract and UI smoke.

### Task 4: Verify and document

**Files:**
- Modify: `entry/src/main/ets/ui/tg_ui/spec/TgIosNativeLiquidComposer.md`
- Modify: `STATUS.md`
- Modify: `TASKS/TODO.md`
- Modify: `TASKS/LESSONS.md`

**Interfaces:**
- Produces: fresh build/runtime evidence and compact project snapshot.

- [ ] Run `scripts/test-ios-native-liquid-composer.ps1`.
- [ ] Run `scripts/smoke-ui-phase0.ps1`.
- [ ] Run `scripts/smoke-build.ps1`.
- [ ] Install entry HAP, prove a fresh process using STIME, and capture both transitions on API23.
- [ ] Record only witnessed results and any remaining gaps.
