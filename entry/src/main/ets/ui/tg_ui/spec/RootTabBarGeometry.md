# RootTabBarGeometry passport

## Scope

`RootTabBarGeometry` is the single typed policy for the accepted native root
tab-bar render state and root-page bottom content clearance. This is a
zero-visual-delta contract, not a tab-bar redesign.

## Render state matrix

| State | Condition | `overlap` | `height` | `bottomMargin` | `opacity` | `maskHeight` |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Visible root tabs | `selectedIndex !== 2` or `chatScreenVisible === false` | `true` | `48` | `30` | `1` | `110` |
| Hidden on Chats detail | `selectedIndex === 2 && chatScreenVisible === true` | `false` | `0` | `0` | `0` | `0` |

A stale `chatScreenVisible=true` flag on Contacts, Calls, or Settings must keep
the visible tuple. Only an active Chats detail (`selectedIndex === 2`) hides
the root tab bar.

## Root content clearance

For valid non-negative avoid-area inputs, the preserved formula is exactly:

```text
48 + max(max(systemBottomInset, navigationBottomInset), 10) + 6
```

The pure helper first clamps its resolved avoid-area input at `0`, so invalid
negative inputs cannot reduce the accepted `10` content floor. If the window
stage or avoid-area lifecycle cannot produce a value, the explicit accepted
legacy fallback is exactly `82`.

The fallback is not derived from the visible tuple and its relationship to a
real runtime avoid-area measurement is currently unproven.

## Ownership boundaries

`RootTabBarGeometry` owns the atomic visible/hidden tuple, content formula, and
legacy fallback. HDS continues to own island width, radius, material, motion,
and system safe-area rendering.

These values have distinct meanings and must not be substituted for one
another:

- `maskHeight=110` controls the HDS background mask extent.
- `barHeight=48` controls the rendered tab-bar height.
- floating `bottomMargin=30` controls the island's render position.
- root content clearance uses actual system/navigation avoid areas, floor
  `10`, and breathing room `6`; its unavailable-window fallback is `82`.

The contract does not own tab order, labels, badges, icon metrics, routes,
controllers, selection lifecycle, swipe policy, or chat/composer safe-area
computation.

## Active consumers

- `MainTabsPage.ets` resolves one render tuple and feeds its five values to
  `barOverlap`, `barHeight`, `barBottomMargin`, `barOpacity`, and `maskHeight`.
- `SafeAreaUtils.ets` retains system and navigation-indicator acquisition and
  delegates only the root content formula to
  `computeRootTabContentBottomInset`.
- `ChatListPage.ets`, `ContactsPage.ets`, `CallsPage.ets`, and
  `SettingsPage.ets` use `ROOT_TAB_BAR_FALLBACK_CONTENT_INSET` for both initial
  and error fallback while retaining their existing resize/listener lifecycle.
- The host geometry suite, Hypium compile contract, and both UI smoke scripts
  enforce the pure policy and active-consumer boundaries.

## Stop conditions

- Do not tune any numeric value as part of M2a; stop if a change would alter
  current HDS rendering, page clearance, listener lifecycle, or chat inset
  behavior.
- Stop and collect runtime bounds if the last visible/tappable item is covered,
  an empty bottom gutter appears, the detail screen retains a TabBar hit
  surface, or repeated tab switching produces a stale inset.
- Do not claim zero visual delta until the separate before/after runtime matrix
  passes for all four root pages and Chats detail.
- Do not remove legacy custom-tab tokens in this slice; active native consumers
  stop referencing them, but token cleanup requires a separate accepted task.

## Explicitly deferred beyond M2a

Reconciling content floor `10` or fallback `82` with render margin `30`, or
deriving the fallback from real avoid-area values, requires multi-device
no-gap/no-overlap evidence. That investigation and any resulting numeric
change are explicitly not part of M2a.
