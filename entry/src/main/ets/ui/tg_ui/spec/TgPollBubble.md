# TgPollBubble (Phase 2 coverage passport)

## Goal
Document the Telegram-style poll message bubble atom currently routed by `TgMessageRouter` for `contentType === 'poll'`.

Scope for this step is contract/passport only. No ArkTS behavior, router wiring, or demo code is changed here.

## Local references inspected
- iOS visual/behavior source: `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\Chat\ChatMessagePollBubbleContentNode\Sources\ChatMessagePollBubbleContentNode.swift`
  - poll bubble owns the question text, poll type label, option rows, radio/check state, result percentages, result bars, voter count/footer, submit/view-results buttons, solution button, timer node, and selected/correct result icons
  - option rows use a leading radio/control area, multiline option text, optional percentage/result bar, separators, highlight feedback, and tap handling
  - iOS distinguishes unanswered polls, selected-but-not-submitted state, submitted/result state, closed polls, public result viewing, quiz solution/correct-answer affordances, and bot-chat footer hiding
- Harmony implementation: `entry/src/main/ets/ui/tg_ui/atoms/TgPollBubble.ets`
- Router integration: `entry/src/main/ets/ui/tg_ui/molecules/TgMessageRouter.ets`
- TDLib parse/model path:
  - `entry/src/main/ets/core/model/dto/MessageDto.ets`
  - `entry/src/main/ets/core/model/AppState.ets`
  - `entry/src/main/ets/ui/pages/chat/ChatTimelineVO.ets`

## Inputs
| Input | Type | Source / meaning |
| --- | --- | --- |
| `question` | `string` | TDLib poll question text, forwarded through DTO/state/view-model. |
| `options` | `TgPollOptionVO[]` | Poll answer rows. Each option has `text`, `voterCount`, `votePercentage`, and `isChosen`. |
| `totalVoterCount` | `number` | TDLib total voter count used by the current footer text. |
| `isClosed` | `boolean` | TDLib closed state. Current atom uses it to force result display and `Closed` type badge text. |
| `isAnonymous` | `boolean` | TDLib anonymity flag. Current atom folds it into `Anonymous Poll` / `Anonymous Quiz` label text. |
| `pollType` | `string` | Current model string: `regular` or `quiz`. Current atom uses it only for label text. |
| `isOutgoing` | `boolean` | Message direction. Current atom receives it; parent/router owns side, background, max width, and meta placement. |

## Derived display rules
1. `hasVoted()` is true when any option has `isChosen === true`.
2. `showResults()` is true when `hasVoted()` is true or `isClosed` is true.
3. Unanswered open polls show leading radio circles and no percentages/bars.
4. Result state hides radio circles, shows each option percentage, and renders a horizontal result bar.
5. Chosen option bars use the current accent color; other bars use secondary preview color.
6. Type badge text is localized:
   - `Closed` when `isClosed`;
   - `Anonymous Quiz` / `Quiz` for quiz polls;
   - `Anonymous Poll` / `Poll` for regular polls.
7. Footer text uses localized zero/one/few/many resources; the few/many split preserves Russian 2–4 vs 12–14 grammar without changing English/Chinese output.

## Current composition boundary
`TgPollBubble` owns only the visible poll body:
- question text;
- type/anonymity/closed label;
- option rows;
- current radio/result/percentage bar visuals;
- current voter-count footer.

`TgMessageRouter` owns the surrounding message presentation:
- incoming/outgoing alignment;
- group/channel sender name;
- bubble background, radius, bounded max width, and the independently inset meta row;
- inline time/status meta below the poll body;
- avatar slot outside the bubble.

Do not move router-owned meta/background behavior into this atom without a separate integration decision.

## State matrix
Required demo/review states before accepting full coverage:
1. open anonymous regular poll with no votes;
2. open non-anonymous regular poll;
3. voted regular poll showing chosen option and percentages;
4. closed regular poll showing results even without a chosen option;
5. quiz poll with a chosen answer;
6. closed quiz poll with result percentages;
7. long question and long option text wrapping/ellipsis stress;
8. zero-voter and uneven-percentage edge cases;
9. incoming vs outgoing parent background/alignment parity.

## Layout rules
1. Question is the primary text block and should stay above the type label.
2. Type label is secondary and should not compete with the question.
3. Options fill the parent-owned poll width and maintain stable text/percentage alignment.
4. Unanswered option rows reserve the leading radio/control area.
5. Result option rows keep the percentage column right-aligned and keep the bar below the option text.
6. Separators stay inside the poll body rhythm and should not look like router-owned bubble separators.
7. Footer voter text stays secondary and below the options.
8. Parent/router remains responsible for final bubble width, background, and incoming/outgoing placement. The atom owns its single set of inner content insets; the router must not add a second all-around padding layer.
9. The preferred poll minimum follows current Telegram iOS: `min(280vp, available content width)`. Narrow group/avatar lanes therefore shrink instead of pushing the bubble past the left edge.
10. Option controls start at 12vp and option text, separators, and result bars share the 50vp leading axis from `ChatMessagePollOptionNode`.

## Token mapping and current debt
Current implementation uses shared tokens for text colors, separator color, bubble padding, and one accent color.

Known debt before visual acceptance:
- poll geometry is tokenized; the remaining visual debt is runtime acceptance against populated open/result/quiz states and user-adjustable message font size;
- label/footer strings are localization-backed for base, Russian, and Chinese resources;
- `isOutgoing` currently does not change internal text/result visuals; router background/direction carries the visible direction difference;
- quiz correctness, solution text/button, timer/deadline, public result avatars, `View Results`, submit button, and multiple-answer selected-before-submit state from iOS are not represented in the current atom contract;
- result percentages are trusted from TDLib/model data and are not recomputed in the atom;
- option tap/vote behavior is not implemented.

## Action and behavior contract
The iOS poll bubble has option tap/selection behavior, submit/view-results actions, quiz solution display, and public-result affordances. The current Harmony atom exposes no callback/event params and should be treated as static visual content.

Before claiming behavior parity with iOS, add or explicitly assign ownership for:
- `onOptionTap` / vote selection;
- submit vote behavior for multi-answer or selected-before-submit states;
- `onViewResults` for public polls;
- quiz correct-answer and solution display behavior;
- timer/deadline rendering if TDLib data is later surfaced.

## Demo coverage
`entry/src/main/ets/ui/tg_ui/demos/TgPollBubbleDemo.ets` provides static preview/state coverage for the nine semantic states above plus a 220vp narrow-lane regression case.

The demo wraps the atom in a minimal parent-owned bubble shell to make the router boundary visible. It is not manual device/emulator acceptance and it does not claim poll vote, submit, view-results, quiz solution, timer/deadline, or public-result behavior parity.

## Acceptance checklist
- [x] Passport exists and names iOS/Harmony/router/model sources.
- [x] Demo covers representative poll states.
- [x] Long question/options and percentage alignment are runtime-verified on API23 through the real router (`.codex/ui-audit/2026-07-15/poll-bounded-layout/02-localized-final.jpeg`).
- [x] Router-owned sender/meta/background boundaries remain intact in the narrow incoming and outgoing-result bounds witness.
- [x] Voting/view-results/quiz-solution behavior is explicitly outside the current static atom and is not claimed by the geometry witness.
- [x] API23 geometry verification is explicit; static Preview coverage alone is not treated as runtime evidence.
