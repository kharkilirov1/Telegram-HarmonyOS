# TgLocationBubble (Phase 2 coverage passport)

## Goal
Document the Telegram-style location/venue message bubble atom currently routed by `TgMessageRouter` for `contentType === 'location'`.

Scope for this step is contract/passport only. No ArkTS behavior, router wiring, or demo code is changed here.

## Local references inspected
- iOS visual/behavior source: `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\Chat\ChatMessageMapBubbleContentNode\Sources\ChatMessageMapBubbleContentNode.swift`
  - map bubble owns map snapshot image, pin node, optional venue title/address text, and map tap/open-message handling
  - title text is 14pt-class medium; address text is 14pt-class regular
  - normal location uses a map image with a centered pin; venue/live-location variants add text below the map and keep the message status outside/over the map depending on variant
- Harmony implementation: `entry/src/main/ets/ui/tg_ui/atoms/TgLocationBubble.ets`
- Router integration: `entry/src/main/ets/ui/tg_ui/molecules/TgMessageRouter.ets`
- TDLib parse/model path:
  - `entry/src/main/ets/core/model/dto/MessageDto.ets`
  - `entry/src/main/ets/core/model/AppState.ets`
  - `entry/src/main/ets/ui/pages/chat/ChatTimelineVO.ets`

## Inputs
| Input | Type | Source / meaning |
| --- | --- | --- |
| `latitude` | `number` | TDLib location/venue latitude. Rendered as debug coordinate text in the current placeholder map. |
| `longitude` | `number` | TDLib location/venue longitude. Rendered as debug coordinate text in the current placeholder map. |
| `venueTitle` | `string` | Venue title from TDLib `messageVenue`; empty for plain `messageLocation`. |
| `venueAddress` | `string` | Venue address from TDLib `messageVenue`; hidden when empty. |
| `isOutgoing` | `boolean` | Message direction. Current atom receives it; router owns side, background, max width, and meta placement. |

## Current composition boundary
`TgLocationBubble` owns only the visible map/venue content:
- map placeholder area with a centered pin marker and coordinate text;
- `2:1` map aspect ratio;
- optional venue title;
- optional venue address.

`TgMessageRouter` owns the surrounding message presentation:
- incoming/outgoing alignment;
- group/channel sender name;
- bubble background, padding, radius, and max width;
- overlay meta pill for plain location messages;
- inline meta row for venue messages.

Do not move router-owned meta/background behavior into this atom without a separate integration decision.

## State matrix
Required demo/review states before accepting full coverage:
1. plain incoming location with no venue title/address;
2. plain outgoing location with no venue title/address;
3. venue with title + address;
4. venue with title only;
5. long venue title truncation/wrapping stress;
6. long venue address truncation/wrapping stress;
7. zero/unknown coordinates fallback (`0, 0`) so placeholder output stays deterministic;
8. narrow parent width stress for map aspect ratio + venue text.

## Layout rules
1. Map area keeps `2:1` aspect ratio and fills the parent-owned bubble width.
2. Pin marker stays centered inside the map area.
3. Plain location uses map-only content; router overlays the meta pill on top of the map.
4. Venue content appears below the map and keeps title/address left-aligned.
5. Venue title is primary, medium-weight, max two lines with ellipsis.
6. Venue address is secondary, max two lines with ellipsis, and hidden when empty.
7. Parent/router remains responsible for final bubble width, outer padding, background, and incoming/outgoing placement.

## Token mapping and current debt
Current implementation uses shared tokens for title/preview text colors, message radius, and bubble horizontal padding.

Known debt before visual acceptance:
- map placeholder background is a hardcoded `#E8E8ED` instead of a token/resource;
- pin is an emoji placeholder instead of a Telegram/Harmony icon asset;
- coordinate text is a debug placeholder, not iOS map snapshot chrome;
- map snapshot/image loading is not implemented yet;
- `isOutgoing` currently does not change internal map/text visuals; router background/direction carries the visible direction difference;
- live location state from the iOS reference is out of scope for the current DTO/atom contract.

## Action and behavior contract
The iOS map bubble opens the message/location flow on activation/tap. The current Harmony atom exposes no callback/event params and should be treated as static visual content.

Before claiming behavior parity with iOS, add or explicitly assign ownership for:
- `onOpenLocation` / map tap behavior;
- map snapshot loading or platform map preview ownership;
- live-location timer/heading state if TDLib data is later surfaced.

## Demo coverage
`entry/src/main/ets/ui/tg_ui/demos/TgLocationBubbleDemo.ets` now provides static preview/state coverage for the eight required states above.

The demo wraps the atom in a minimal parent-owned bubble shell to make the router boundary visible. It is not manual device/emulator acceptance and it does not claim map snapshot, overlay-meta, or open-location behavior parity.

## Acceptance checklist
- [x] Passport exists and names iOS/Harmony/router/model sources.
- [x] Demo covers representative location and venue states.
- [ ] Map placeholder or snapshot strategy is tokenized and reviewed.
- [ ] Plain-location overlay meta and venue inline meta stay router-owned after review.
- [ ] Behavior ownership for opening map/location is explicit before behavior parity is claimed.
- [x] No manual device/emulator verification is implied by this passport/demo.
