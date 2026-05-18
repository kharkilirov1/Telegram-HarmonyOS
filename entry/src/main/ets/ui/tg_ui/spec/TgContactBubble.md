# TgContactBubble (Phase 2 coverage passport)

## Goal
Document the Telegram-style contact message bubble atom currently routed by `TgMessageRouter` for `contentType === 'contact'`.

Scope for this step is contract/passport only. No ArkTS behavior, router wiring, or demo code is changed here.

## Local references inspected
- iOS visual/behavior source: `рефенсы/Telegram-iOS-master/submodules/TelegramUI/Components/Chat/ChatMessageContactBubbleContentNode/Sources/ChatMessageContactBubbleContentNode.swift`
  - contact bubble owns avatar, title, phone/info text, `Message` and `Add Contact` attached action nodes, separators, and contact tap handling
  - title and phone/info are 14pt-class text; title is semibold, info is regular
  - action buttons are separate from regular bubble tap handling
- Harmony implementation: `entry/src/main/ets/ui/tg_ui/atoms/TgContactBubble.ets`
- Router integration: `entry/src/main/ets/ui/tg_ui/molecules/TgMessageRouter.ets`
- TDLib parse/model path:
  - `entry/src/main/ets/core/model/dto/MessageDto.ets`
  - `entry/src/main/ets/core/model/AppState.ets`
  - `entry/src/main/ets/ui/pages/chat/ChatTimelineVO.ets`

## Inputs
| Input | Type | Source / meaning |
| --- | --- | --- |
| `firstName` | `string` | TDLib contact first name, forwarded through message DTO/state/view-model. |
| `lastName` | `string` | TDLib contact last name, forwarded through message DTO/state/view-model. |
| `phoneNumber` | `string` | TDLib contact phone number. Used as the visible secondary line and as display-name fallback. |
| `contactUserId` | `number` | TDLib user id when the contact maps to a Telegram user. Current atom receives it but has no visual branch. |
| `isOutgoing` | `boolean` | Message direction. Current atom receives it; parent/router owns bubble side/background and inline meta. |

## Derived display rules
1. `displayName = trim(firstName + ' ' + lastName)`.
2. If `displayName` is empty, use `phoneNumber` as the title fallback.
3. Initials are the uppercase first character of `firstName` plus the uppercase first character of `lastName`.
4. If `phoneNumber` is empty, the secondary phone line is hidden.
5. Long title text must stay one line with ellipsis.

## Composition boundary
`TgContactBubble` owns only the contact-card body and the visual action row:
- leading `TgAvatar` at the current 40vp size;
- title/name line;
- optional phone line;
- horizontal separator;
- two action-looking labels: `Message` and `Add Contact`.

`TgMessageRouter` owns the surrounding message presentation:
- incoming/outgoing alignment;
- sender name for group/channel contexts;
- bubble background and radius;
- inline time/status meta;
- avatar slot outside the bubble.

Do not move router-owned sender/meta/background behavior into this atom without a separate integration decision.

## State matrix
Required demo/review states before accepting full coverage:
1. full `firstName + lastName` with phone number;
2. first-name-only contact;
3. last-name-only contact;
4. phone-only fallback title;
5. long contact name truncation;
6. empty phone number with hidden secondary line;
7. incoming vs outgoing parent background/alignment parity;
8. `contactUserId > 0` vs `0` while action behavior remains explicitly documented.

## Layout rules
1. Contact card row keeps avatar, text column, and action row visually separated.
2. Avatar remains the strongest leading identity marker.
3. Text column starts after an 8vp-class gap and consumes remaining width.
4. Title is one line with ellipsis; phone/info is one line and secondary-colored.
5. Separator spans the bubble content width and should align with the current bubble rhythm.
6. Action row height and vertical divider must keep touch targets visually distinct from regular message tap areas.
7. Parent/router remains responsible for max bubble width and direction-specific placement.

## Token mapping and current debt
Current implementation already uses shared tokens for avatar color, bubble horizontal padding, title/preview colors, separator, and accent text color.

Known debt before visual acceptance:
- internal constants such as avatar size `40`, text size `14`, row padding, gaps, separator thickness, and action height are still hardcoded in the atom;
- action labels are hardcoded English strings and are not localization-backed;
- `isOutgoing` currently does not change internal text/action colors; router background/direction carries the visible direction difference;
- `contactUserId` currently has no visual or behavior branch.

## Action and behavior contract
The current Harmony atom renders `Message` and `Add Contact` labels but exposes no callback/event params. Treat both action labels as **visual-only** until behavior ownership is added.

Before claiming behavior parity with iOS, add or explicitly reject:
- `onMessageTap` for opening the Telegram user/chat when possible;
- `onAddContactTap` for contact-add/open-contact behavior;
- optional row/contact-card tap handling if router should open a contact preview.

The iOS reference separates button taps from regular bubble taps; this distinction should be preserved if behavior is implemented later.

## Demo coverage
`entry/src/main/ets/ui/tg_ui/demos/TgContactBubbleDemo.ets` now provides static preview/state coverage for the eight required states above.

The demo wraps the atom in a minimal parent-owned bubble shell to make the router boundary visible. It is not manual device/emulator acceptance and it does not claim `Message` / `Add Contact` behavior parity.

## Acceptance checklist
- [x] Passport exists and names iOS/Harmony/router/model sources.
- [x] Demo covers representative contact states.
- [ ] Long title and missing phone states are visually accepted on device/emulator.
- [ ] Action row remains visually separated from the contact card after review.
- [ ] Behavior ownership for `Message` / `Add Contact` is explicit before action parity is claimed.
- [x] No manual device/emulator verification is implied by this passport/demo.
