# TgCallsSurface integration passport

## Reference
- iOS hierarchy: `C:\Refs\Telegram\Telegram-iOS-current\submodules\CallListUI\Sources\CallListController.swift` (`ItemListControllerSegmentedTitleView`, All/Missed state).
- iOS rows/date: `C:\Refs\Telegram\Telegram-iOS-current\submodules\CallListUI\Sources\CallListCallItem.swift` (`stringForRelativeTimestamp`, info action, 40pt avatar).
- Harmony implementation: native API18+ `CapsuleSegmentButtonV2` hosted by the API20+ `HdsNavigation` title-bar `bottomBuilder`.

## State and data contract
- `callsFilterIndex = 0`: TDLib `searchCallMessages(only_missed=false)`.
- `callsFilterIndex = 1`: a fresh typed query with `only_missed=true`; stale all-call responses are rejected by generation.
- Empty/loading copy follows the selected filter.

## Layout contract
- HDS keeps ownership of title material, safe area and title sizing.
- The native two-item capsule is fixed in the title bar; list content starts below its 48vp slot plus a 16vp separation gap.
- Rows keep 40vp avatars and the iOS title/status/date/info hierarchy.
- Direction labels use Telegram's compact `Incoming / Outgoing / Missed` strings; media detail remains in the call glyph rather than a wrapping sentence.
- Dates are time today, Yesterday, localized weekday inside seven days, `d MMM` this year and `d MMM yyyy` for older years.

## Acceptance
- [x] Russian title/tab labels are sourced from resources.
- [x] All/Missed changes the real TDLib query and empty state.
- [x] Same-year and older-year dates fit without pushing the info action.
- [x] API23 runtime has no title/filter/list overlap.

Runtime witnesses: `.codex/ui-audit/2026-07-13/calls/04-all-final.jpeg` and `05-missed-final.jpeg`.
