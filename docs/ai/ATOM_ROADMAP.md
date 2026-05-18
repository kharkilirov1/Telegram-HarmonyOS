# Atom Roadmap — Telegram-HarmonyOS tg_ui pipeline

> Date: 2026-02-26
> Status: active
> Canonical contract: follows `MASTER_PLAN_TELEGRAM_UI.md`
> Maintenance note (2026-05-18): this roadmap captures the original A–E atom migration. For the current post-media-gallery/API23 HDS shell reality, prefer `STATUS.md` and `TASKS/TODO.md`. `TgSearchBar`, custom `TgTabBar`, `TgTextBubbleV2`, and standalone `TgUnreadBadge` are historical; active paths use stock `Search`, API23 `HdsTabs`, `TgTextBubbleV3`/`TgTextBodyV3`, and inline `TgChatMeta` unread capsules.

---

## DONE (rolling list)

### Phase A — Foundations
- [x] TgTokens
- [x] TgIcon
- [x] TgAvatar
- [x] TgUnreadBadge (historical standalone atom; active unread capsule is inline in `TgChatMeta`)
- [x] TgChatMeta

### Phase B — ChatList MVP
- [x] TgChatRow (+ ChatListPage feature-flag integration)

### Phase C — Chat Screen MVP (text-only)
- [x] TgMessageTextRules (contract, no atom)
- [x] TgMessageBubbleBase
- [x] TgMessageMeta
- [x] TgReplySnippet
- [x] TgDateSeparator + TgUnreadMarker
- [x] TgComposerInput
- [x] TgTopBar
- [x] TgChatScreenPage integration (text messages only)

---

## Phase C.1 — Media Bubbles

Current state:
- model/DTO layer already expanded with media fields (C.1-0 done),
- chat UI still renders media types as text fallback until router integration.

| Step | Atom | Description | Status |
|------|------|-------------|--------|
| C.1-0 | **Model expansion** | Extend `MessageContent` with media fields (photoPath, videoPath, fileName, fileSize, duration, waveform, etc.) + update DTO parsing in `MessageDto.ets` | DONE |
| C.1-1 | **TgPhotoBubble** | Photo in bubble: thumbnail/full, rounded corners, optional caption below | DONE |
| C.1-2 | **TgVideoBubble** | Video preview + play overlay icon + duration badge, optional caption | DONE |
| C.1-3 | **TgDocumentRow** | File attachment: type icon + file name + size + download progress bar | DONE |
| C.1-4 | **TgVoiceBubble** | Voice note: waveform visualization + duration + play/pause button | DONE |
| C.1-5 | **TgStickerView** | Sticker without bubble (transparent bg, fixed size, no caption) | DONE |
| C.1-6 | **TgMessageRouter** | Molecule — routes `contentType` to correct bubble atom | DONE |
| C.1-7 | **Integration** | Wire router into TgChatScreenPage replacing direct TgMessageBubbleBase | DONE |

### Dependencies
- C.1-0 is complete (foundation for media atoms)
- C.1-1..C.1-5 can be done in parallel (independent atoms)
- C.1-6 depends on at least C.1-1 + C.1-3 being done
- C.1-7 depends on C.1-6

---

## Phase D — Shell Polish

| Step | Atom | Description | Status |
|------|------|-------------|--------|
| D-1 | **TgTabBar** | Historical custom glass tab bar; active root shell now uses API23 `HdsTabs` / `HdsNavigation` | SUPERSEDED |
| D-2 | **TgSearchBar** | Historical standalone search atom; active chat-list header uses stock ArkUI `Search` inside `TgChatListNavigationBar` | SUPERSEDED |
| D-3 | **TgTopBar v2** | Top bar with blur-over-content (Stack overlay layout so list scrolls under bar) | DONE |

### Resolved issues from Phase D
- Tab bar: historical custom `TgTabBar` was later superseded by API23 `HdsTabs` with floating style
- Top bar: ChatListPage + TgChatScreenPage use Stack layout + contentStartOffset — list scrolls under translucent bar
- Background contrast: glass_tab_bg and glass_nav_bg are semi-transparent, blur works on content behind them

---

## Phase E — Secondary Tabs

| Step | Atom | Description | Status |
|------|------|-------------|--------|
| E-1 | **TgContactRow** | Contact row: avatar + name + last seen status | DONE |
| E-2 | **TgSettingsSection** | Grouped settings section (iOS insetGrouped style, V1 @BuilderParam) | DONE |
| E-3 | **TgSettingsRow** | Settings row: colored icon + title + trailing (text/toggle/arrow) | DONE |
| E-4 | **TgCallRow** | Call history row: avatar + name + call type icon + date | DONE |
| E-5 | **Integration** | Real ContactsPage, SettingsPage, CallsPage with store data | DONE |

### Notes
- Historical note: `TgSettingsSection` originally existed as a standalone migration atom; the current runtime no longer uses it and its legacy demo/spec artifacts were removed on 2026-03-22.
- ContactsPage reads real contacts from AppStore (filtered by `isContact`)
- SettingsPage shows real user profile + iOS insetGrouped sections
- CallsPage shows empty state (no call history model in store yet)
- All pages use Stack overlay + TgTopBar pattern (consistent with D-3)

---

## Execution order

```
C.1-0 (model) → C.1-1..C.1-5 (media atoms, parallel) → C.1-6 (router) → C.1-7 (integration)
    → D-1..D-3 (shell polish) ✓
    → E-1..E-5 (secondary tabs) ✓
ALL PHASES COMPLETE.
```

## Workflow per atom (unchanged)

1. iOS source inspection
2. SPEC (passport) in `tg_ui/spec/<Atom>.md`
3. Tokens extension in `TgUiTokens.ets` if needed
4. DEMO in `tg_ui/demos/<Atom>Demo.ets`
5. ATOM in `tg_ui/atoms/<Atom>.ets`
6. Integration (feature-flagged where applicable)
