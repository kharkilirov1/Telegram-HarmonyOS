# TgCompose creation flows passport

## Scope

Functional first slice for the three current Telegram iOS Compose actions:

1. New Group;
2. New Contact;
3. New Channel.

The native HarmonyOS navigation and keyboard remain platform-owned. Telegram-specific rows, forms, state and TDLib hand-off remain custom.

## References

- Action order and icons: `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Sources\ComposeControllerNode.swift:44-54`.
- Flow hierarchy: `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Sources\ComposeController.swift:122-260`.
- Action-row geometry: `C:\Refs\Telegram\Telegram-iOS-current\submodules\ContactListUI\Sources\ContactListActionItem.swift:209-253,289-336`.
- TDLib contracts: `tdlib/td/generate/scheme/td_api.tl:11771-11785,12938-12946`.
- Runtime evidence: `.codex/ui-audit/2026-07-19/compose-actions/after/`.

Public iOS source establishes hierarchy and behavior. No shipped-runtime screenshot of the iOS Compose screen is available in this thread, so pixel parity is not claimed.

## Routes

- `TgNewGroupMembersPage` → `TgNewGroupInfoPage` → `createNewBasicGroupChat`.
- `TgNewContactPage` → `importContacts`; registered users continue through `createPrivateChat`.
- `TgNewChannelPage` intro → form → `createNewSupergroupChat(is_channel=true)`.

Every route returns a typed `ComposeCreationResult`. A zero `chatId` represents cancellation or a successfully imported unregistered contact, distinguished by `contactImportedUnregistered`.

## State and safety contract

- Creation and result delivery are separate state transitions.
- After TDLib commits an entity, the page retains `pendingCreationResult` and retries only hydration/navigation hand-off; it must not invoke creation again.
- Group creation accepts zero members because the local TDLib contract explicitly permits it, and caps selection at 200 users.
- Partial member failures are propagated to ChatList and surfaced as localized feedback.
- Imported-but-unregistered contacts close the form and produce localized feedback instead of leaving a disabled terminal screen.
- Channel Back from the form returns directly to Compose, matching the iOS replace-style intro transition.
- Forms explicitly use `Alignment.TopStart`; short `Scroll` content must not inherit the ArkUI default centered alignment.

## Layout contract

- Reuse the floating native-compatible navigation capsules already used by Compose.
- Form content begins below the top chrome and stays top-aligned on short and tall viewports.
- Inputs use platform focus and keyboard behavior; phone input requests `InputType.PhoneNumber` without emulating a custom keyboard.
- Repeated spacing, radii and touch geometry use `TgUiTokens`.
- Action rows preserve a minimum 44vp interaction target and iOS-derived 50vp visual height.

## Apple-design rubric

- Navigation is reversible and follows the same spatial path on entry and exit.
- Native navigation, keyboard and system material behavior take precedence over custom imitation.
- No visible row may be a no-op.
- A server commit remains recoverable if the visual hand-off is interrupted.
- Acceptance requires live navigation evidence, not only source assertions or screenshots.

## Current fidelity boundary

Still pending for full current-iOS parity:

- Group: global member search, selected-member tokens, avatar, auto-title, TTL and live configuration/invite-link behavior.
- Contact: OS Contacts authorization/sync, country picker, phone resolution, note and QR paths.
- Channel: visibility choice, public username validation and subscriber selection.
- Shipped iOS runtime capture and pixel-level comparison.

## Acceptance

- Compose renders Group → Contact → Channel with no Secret Chat row.
- Each action opens and cancels safely; repeated open after Back is possible.
- Group member selection and group-info navigation work without exceeding the domain limit.
- Contact phone focus opens the system keyboard.
- Channel intro opens the top-aligned form; one Back returns directly to Compose.
- No real contact/group/channel is created during navigation-only runtime verification.
- Focused contracts, both UI smokes, main build and ohosTest ArkTS compile pass after the final edit.
