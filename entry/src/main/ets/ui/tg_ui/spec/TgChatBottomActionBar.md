# TgChatBottomActionBar

Bottom panel that replaces the composer in chats where composing is unavailable.
iOS dispatcher: `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Sources\ChatInterfaceStateInputPanels.swift:13`
(`inputPanelForChatPresentationInterfaceState`).

## iOS source grounding
- `ChatChannelSubscriberInputPanelNode` —
  `submodules\TelegramUI\Components\Chat\ChatChannelSubscriberInputPanelNode\Sources\ChatChannelSubscriberInputPanelNode.swift`
  (glass rail, one centered button, no input field)
- `ChatRestrictedInputPanelNode` — `submodules\TelegramUI\Sources\ChatRestrictedInputPanelNode.swift`
  (text-only panel: restriction reason, no buttons)
- Button labels: `Channel.JoinChannel` = "Join", `Group.JoinGroup` = "Join Group",
  `Conversation.Mute` = "Mute", `Conversation.Unmute` = "Unmute",
  `Conversation.DefaultRestrictedText` = "Writing messages isn't allowed in this group."

## Inputs
- `mode`: `action` | `restricted`
- `actionText`: label of the single centered button (action mode)
- `isActionAccent`: accent text for Join; primary text for Mute/Unmute
- `messageText`: restriction reason (restricted mode)
- `glassMode`, `bottomInset`

## State matrix (production mapping)

Wave9: basic-group per-kind defaults, bounded unknown-permission getChat, explicit reactive UI capability snapshot and fresh dispatch guards: `docs/reviews/2026-09-06-reliability-wave9.md` (52 focused; forced main/ohosTest compile). This is not device/visual acceptance. Ordinary megagroup booster/full-info policy remains open.
| Chat state (our data) | iOS panel | Our surface |
|---|---|---|
| Channel creator-member / admin with `can_post_messages` | Composer | atom hidden |
| Channel member / admin without posting rights, unmuted | Subscriber: "Mute" | action, primary |
| Channel member without posting rights, muted (`muteForSeconds > 0`) | Subscriber: "Unmute" | action, primary |
| Channel left / creator `is_member=false` | Subscriber: "Join" (accent) | action, accent |
| Channel admin with `can_edit_messages`, currently editing | Composer (iOS dispatcher edit exception) | atom hidden |
| Unknown channel/basic-group access / pending getSupergroup/getBasicGroup or default-permission getChat | Not a confirmed membership/permission state | restricted, Loading |
| Access hydration failed | Retry recovery | action, Retry |
| Channel banned | iOS DeleteChat; destructive action parity still pending | restricted, channel unavailable; no Join/send |
| Basic group left/removed | iOS DeleteChat (`ChatInterfaceStateInputPanels.swift:396–409`); destructive parity pending | restricted, group unavailable; no channel Join/send |
| Basic group `is_active=false`, including creator/admin | Cannot send to an inactive basic group; migration CTA parity pending | restricted, group unavailable |
| Active basic-group creator/admin member | Composer; group defaults do not restrict admin sending | atom hidden |
| Active basic-group member: any of 9 effective send kinds / all denied | Composer / Restricted | hidden / restricted; individual/default intersection per kind, caption follows media |
| Ordinary supergroup with `canSendBasicMessages === false` | Restricted: current basic-only mapping; role/booster policy pending | restricted |
| Private/secret chat / ordinary supergroup with basic send allowed | composer (this atom hidden); megagroup role/booster policy pending | — |

Access comes from `supergroup.status` / `updateSupergroup` and scoped `getSupergroup`, never main/archive order or default chat permissions. `joinChat → ok` is not membership confirmation. Parser/store, request controller and pure `ChatInputPanelPolicy` are separate; the atom remains presentation-only.

Basic-group access (2026-09-06 wave8) uses its own `basicGroup.status`, strict `is_active`, `updateBasicGroup`, map and scoped `getBasicGroup`. Numeric ID collision with a channel does not grant access. Unknown hydration is one-shot with explicit failure/retry; inactive status is known, not a retry loop. Live deactivation revokes actual page send capabilities, including the next item of an in-flight media batch. Full per-media `sendSomething` parity remains open.

The edit-only exception grants text editing, not new-message/media capability. Page callbacks and context getters recheck the current scoped store. Attach is hidden while editing; stale sticker/GIF/media callbacks cannot send a new post. Unknown invalid group IDs show unavailable info, not a Retry button that cannot issue a request.

Deferred: kicked → red "Delete and Exit"
(`DeleteChatInputPanelNode`), per-user `bannedRights` restricted variants,
bot "Start", blocked "Unblock", slow-mode countdown, Premium-required.

## Layout rules
- Height 48, capsule radius 24, side inset 14 (mirrors the pinned panel lane).
- Content: single centered line; action 16fp medium; restricted text 13fp regular, preview color.
- Same bottom lane as the composer: the panel must reserve identical layout space
  (page renders it in the composer slot; fade backdrop still applies).

## Material contract (LESSON 121)
- API 26 real device (`TgGlassPolicy.supportsNativeMaterial()`): `ImmersiveMaterial` THIN,
  `interactive` only in action mode.
- API 23-25 / emulator: `backdropBlur(GLASS_CAPSULE_BACKDROP_BLUR)` + `chat_top_bar_scroll_capsule_bg`
  tint; opaque fallback token when glass policy is off. No `renderGroup(true)`.

## Acceptance
- [x] iOS source constants recorded.
- [x] Channel/basic-group source state mapping uses current-member status/rights/activity, not list-order heuristics (R6 + wave8). Ordinary supergroup effective policy is still open.
- [ ] Fresh device acceptance for basic-group member/admin/left/inactive/unknown transitions; wave8 host/compile does not prove visual parity.
- [ ] Fresh device acceptance for R6 access transitions, editor-only admin, unknown/error retry and banned info. Host tests/compile do not prove this.
- [x] Glass recipe per lesson 121, token-only geometry/colors.
- [x] Runtime witness (Pura API24, 2026-08-31, `.codex/ui-audit/2026-08-31/bottom-bar-glass/`):
  opened broadcast channel «Автомания» (2 009 236 подписчиков) → glass capsule
  «Без звука» (Mute) instead of the composer (`05-channel-avtomania.jpeg`); tap →
  live flip to «Со звуком» (Unmute) through setChatNotificationSettings round-trip,
  post content reads through the backdropBlur capsule (`06-crop-bottom.png`);
  private-bot chat keeps the composer (`03-channel-open.jpeg`).
- [x] Join search entry point (2026-08-31/09-01 slice): Compose global search
  now renders public channels/supergroups («Каналы и группы» section,
  `searchPublicChats` + `getChat` hydration; negative chat ids preserved —
  TDLib ids for groups/channels are negative and a positive-only filter
  dropped them). Channel «Дуров's Channel» rendered in the section at runtime
  (`19-atdurov.jpeg`). Tap → `newChat` store hydration → ComposeResult pop →
  chat screen.
- [ ] Join-state runtime witness remains open. The old disk-full blocker is stale: wave6 booted existing API24/API26 and a clean isolated API24, all reached SceneBoard panic; no project installation on the clean instance. Wave8 HDC check: targets Offline. See `docs/reviews/2026-09-05-reliability-wave6.md`; retry the UI scenario only after guest boot is stable, without resetting existing sessions.
