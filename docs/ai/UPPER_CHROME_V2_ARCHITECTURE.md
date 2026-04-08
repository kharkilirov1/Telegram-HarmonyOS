# UPPER CHROME V2 ARCHITECTURE — Telegram-HarmonyOS

Last updated: 2026-03-22

## Purpose
This document fixes the **target V2 architecture** for the upper Telegram chrome in this repo before further implementation work.

Method used:
1. **Reference Decomposition** — inspect Telegram iOS upper areas and break them into layers, states, and layout contracts.
2. **Platform Mapping** — map those responsibilities to HarmonyOS/ArkUI capabilities.
3. **Assembly** — decide how the repo should compose them with `@ComponentV2`.

This doc is not an implementation log. It is the **assembly target**.

---

## 1. Scope

Upper chrome means the full top-area composition for:
- **Chat list upper area**
- **Chat screen upper area**

It does **not** mean just the visible title row.

---

## 2. iOS decomposition summary

Grounded from:
- `рефенсы/Telegram-iOS-master/submodules/TelegramUI/Components/ChatListHeaderComponent/Sources/ChatListNavigationBar.swift`
- `рефенсы/Telegram-iOS-master/submodules/TelegramUI/Components/ChatListHeaderComponent/Sources/ChatListHeaderComponent.swift`
- `рефенсы/Telegram-iOS-master/submodules/TelegramUI/Sources/ChatControllerNode.swift`
- `рефенсы/Telegram-iOS-master/submodules/TelegramUI/Sources/ChatControllerContentData.swift`
- `рефенсы/Telegram-iOS-master/submodules/TelegramUI/Sources/ChatHistoryNavigationButtonNode.swift`

### What iOS actually does
- top safe/status area is part of the composition
- blur/effect background lives **under** content
- top edge has extra emphasis (`EdgeEffectView`)
- title row uses **independent geometry** for left / center / right
- search is part of the header system, not a random list row
- chat title/subtitle are **stateful content**, not just two strings
- accessory/title panels can live under the main row
- many controls are separate glass atoms, not bare icons

---

## 3. HarmonyOS grounding

Official HarmonyOS docs used for mapping:
- `@ComponentV2`, `@Param`, `@Local` in State Management V2
- `backgroundBlurStyle`
- `backgroundEffect` (high overhead warning)
- `linearGradient`
- ArkUI `Search` (`searchIcon`, `cancelButton`, `placeholderFont`, `textFont`, `onChange`, `onSubmit`)

### Constraints from HarmonyOS + this repo
- New upper-chrome work must be **`@ComponentV2`-first**
- Do not reintroduce V1-only mental models
- `backgroundEffect` is possible but should be treated as a later/perf-sensitive option
- `backgroundBlurStyle + gradient overlay` is the preferred base composition

---

## 4. Target V2 architecture

## 4.1 Shared ownership model

### Screen/page level owns
- safe-area / avoid-area values
- derived UI state
- active modes (search active, accessory visible, title mode, etc.)
- layout placement of the upper zone

### V2 composition components own
- rendering of the upper content contract
- layout of side slots / centered title / lower lanes

### V2 visual primitives own
- blur/tint/edge-emphasis presentation
- glass action surfaces
- small reusable visual pieces

---

## 4.2 Required shared primitive

### `TgTopChromeBackground` (new target primitive)

**Role**
- shared visual background for upper chrome

**Must contain**
1. safe-area fill
2. material blur/tint surface
3. top-edge emphasis layer
4. optional bottom separator/light edge

**Must NOT contain**
- title text
- search logic
- action callbacks
- page business state

**V2 shape**
- `@ComponentV2`
- `@Param`-driven visual inputs
- only small `@Local` state if absolutely required for measurement/platform adaptation

---

## 4.3 Chat list upper composition

### `TgChatListNavigationBar` (existing, target role clarified)

**Should own**
- left action slot (`Edit`)
- centered title lane
- right action slot (`Compose`)
- integrated search lane
- optional future lower lanes (filters/header panels)

**Should NOT own**
- the shared chrome background engine
- page scroll offset policy
- search business state derivation beyond emitted events

**Layout contract**
- side slots are independent from centered title
- search remains a header lane, not list content
- title geometry stays stable under localization

---

## 4.4 Chat screen upper composition

### `TgChatTopBar` (existing, target role clarified)

**Should own**
- left cluster rendering
- centered stateful title block rendering
- right cluster rendering
- optional accessory-under-title slot in future evolution

**Should NOT own**
- all upper background/effect logic internally
- business derivation of title/subtitle modes
- screen-level orchestration

**Important correction**
- current “three capsules inside one atom” is only a temporary rendering shape
- target architecture is **screen-owned upper chrome + composition component + visual primitives**, not one monolith

---

## 4.5 Stateful title contract

### Required concept
Upper chat title must be driven by a typed derived model, not ad-hoc raw strings.

### Minimal target contract
- title text/items
- subtitle mode
  - none
  - online/offline
  - member count
  - custom
  - thread/reply/custom mode
- avatar data
- left/right action visibility
- enabled/disabled interaction flags

### Ownership
- state derivation happens **outside** the visual atom
- the V2 component receives normalized `@Param`

---

## 5. Primitive mapping table

| iOS primitive/layer | Function | Invariant | Harmony candidate | Repo assembly target |
|---|---|---|---|---|
| `statusBarHeight` zone | top breathing room | top chrome does not start abruptly | avoid area / safe-area inset | page + shared top background |
| `GlassBackgroundContainerView` | shared upper material | blur lives under bars | `backgroundBlurStyle` | `TgTopChromeBackground` |
| `EdgeEffectView` | stronger top edge | upper edge is visually denser | `linearGradient` overlay over blur; later optional `backgroundEffect` if needed | `TgTopChromeBackground` |
| title containers | independent geometry | center title is stable vs side slots | `Stack` + side containers | `TgChatListNavigationBar` / `TgChatTopBar` |
| `NavigationBarSearchContentNode` | integrated search lane | search is part of header | ArkUI `Search` | chat-list composition component |
| `ChatTitleContent` | stateful title model | title/subtitle are not raw text only | derived VO + `@Param` contract | screen/state layer feeding top bar |
| title accessory panel | secondary upper lane | upper zone can be multi-level | optional V2 subcomponent slot | screen-owned accessory host |
| glass navigation buttons | standalone action atoms | controls have their own shell | tokenized V2 action atoms | left/right clusters / future shared action atom |

---

## 6. Assembly rules for this repo

1. **Do not** start from “which ArkUI widget looks close”.
2. Build upper chrome as:
   - shared background primitive
   - content composition
   - derived state model
3. Keep state derivation above the visual atom.
4. Keep the whole stack **`@ComponentV2`-first**.
5. Do not overfit the current temporary capsule rendering if it conflicts with the layered model.

---

## 7. Immediate next implementation implications

### For chat list
- current `TgChatListNavigationBar` is structurally closer to the target
- next improvements should focus on:
  - extracting/introducing shared top chrome background
  - making search visually part of that shared background

### For chat screen
- `TgChatTopBar` still carries too much visual/background responsibility internally
- next architecture pass should:
  - separate background from content composition
  - strengthen the typed title-state contract
  - reserve space for an accessory-under-title layer

---

## 8. Acceptance signal

We are close to the target when:
- upper chrome reads as **one layered top zone**, not a dark bar plus controls
- title geometry stays stable under long localized side actions
- chat top bar no longer feels like three improvised capsules fighting each other
- search and accessory lanes read as first-class header layers
- stateful title behavior is explicit in data contracts, not hidden in ad-hoc UI conditionals
