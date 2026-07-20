# TgMessageMeta (Phase C / Step 2)

## Goal
Create a stable right-aligned message meta cluster for chat bubbles:
- time text
- send status icon (`sending/sent/read/failed`)

UI-only in this step. No reply markers, reactions, edits, views, or business logic.

## iOS References
- `submodules/TelegramUI/Components/Chat/ChatMessageDateAndStatusNode/Sources/ChatMessageDateAndStatusNode.swift`
  - outgoing status model (`Sent(read:)`, `Sending`, `Failed`)
  - date/status icon rendering and color/theme mapping
  - right-side status cluster layout in trailing mode
- `submodules/TelegramUI/Components/Chat/ChatMessageTextBubbleContentNode/Sources/ChatMessageTextBubbleContentNode.swift`
  - trailing content integration with text (`LayoutInput.trailingContent`)
  - reserved status width decision path in text bubble layout
- `submodules/TelegramPresentationData/Sources/Resources/PresentationResourcesChat.swift`
  - check/clock/warning icon resources for message state visuals

## Props
- `timeText: string`
- `sendStatus: TgMessageSendStatus`
  - `None | Sending | Sent | Read | Failed`
- `isOutgoing: boolean`
- `minWidth: number`
- `rowHeight: number`
- `reserveTimeSlot: boolean` (anti-jump)
- `reserveStatusSlot: boolean` (anti-jump)

## State Matrix (demo)
- outgoing: time only
- outgoing: sending / sent / read / failed
- incoming: time only
- no-time variants (with slot reserve)
- long time text variant (`Yesterday`)
- jump-probe sequence (same width, status only changes)

## Token Mapping
- Text:
  - `MSG_META_SIZE`
  - `MSG_META_TEXT_INCOMING`
  - `MSG_META_TEXT_OUTGOING`
- Status colors:
  - `MSG_META_STATUS_PENDING`
  - `MSG_META_STATUS_SENT`
  - `MSG_META_STATUS_READ`
  - `MSG_META_STATUS_FAILED`
  - outgoing time, sent and read checks share the semantic
    `app.color.message_meta_outgoing`; it is intentionally independent from
    global `text_secondary` and the saturated Telegram accent
- Layout/anti-jump:
  - `MSG_META_ROW_HEIGHT`
  - `MSG_META_MIN_WIDTH`
  - `MSG_META_ICON_SIZE`
  - `MSG_META_ICON_GAP`
  - `MSG_META_TIME_PLACEHOLDER_WIDTH`
  - `MSG_META_STATUS_PLACEHOLDER_WIDTH`
- Icons:
  - `ICON_RES_CLOCK`
  - `ICON_RES_CHECK_SINGLE`
  - `ICON_RES_CHECK_DOUBLE`
  - `ICON_RES_FAILED`
- Overlay surfaces:
  - media/location uses `MSG_MEDIA_META_OVERLAY_BG`
  - standalone sticker status uses `MSG_STICKER_META_OVERLAY_BG`, matching
    Telegram iOS `FreeIncoming` / `FreeOutgoing` service-date fill rather than
    the stronger image-media overlay

## Layout Rules (contract)
1) Right-aligned cluster uses:
   - `constraintSize({ minWidth: ... })`
   - `justifyContent(FlexAlign.End)`
   - `alignItems(VerticalAlign.Center)`
2) Time text is optional; status icon is shown only for outgoing messages and non-`None` status.
3) Anti-jump reserve:
   - if `reserveTimeSlot=true` and `timeText` empty, render invisible time placeholder width
   - if `reserveStatusSlot=true` and status hidden, render invisible icon placeholder width
4) Gap between time and icon is tokenized and stable.
5) Incoming meta keeps the global secondary foreground. Outgoing time and
   delivered/read checks use the bubble-aware outgoing secondary foreground,
   matching the iOS `theme.message.outgoing.secondaryTextColor` contract.
6) Overlay text/check geometry is shared, but standalone sticker status and
   image-media status keep separate background semantics. In the default dark
   iOS theme the free-date fill is black at 20% alpha.

## Acceptance Checklist
- [ ] Meta cluster width is stable when status toggles (`none↔sending↔sent↔read↔failed`)
- [ ] Baseline alignment of time and icon looks visually centered
- [ ] No overflow for long time labels
- [ ] Incoming case does not render outgoing status icon
- [ ] All geometry/colors are tokenized (no magic numbers)

## Demo Requirements (`TgMessageMetaDemo.ets`)
At least 10 cases including:
1) outgoing time only
2) sending
3) sent
4) read
5) failed
6) incoming time only
7) no-time + sending
8) no-time + none (placeholder reserve)
9) long time text
10) jump-probe sequence

## Known Risks
- Real localized time labels can exceed placeholder width; may need token tuning in calibration pass.
- Dark outgoing meta is calibrated against the current shipped iOS runtime on
  the `#406D97` outgoing bubble; recalibrate only the dedicated semantic resource,
  not the global secondary or Telegram accent.
