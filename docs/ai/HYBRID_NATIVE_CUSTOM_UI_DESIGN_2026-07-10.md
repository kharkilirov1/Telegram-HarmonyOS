# Hybrid native/custom UI design — 2026-07-10

Status: design accepted in principle by the user on 2026-07-10 and independently
reviewed against the current source and installed API 26 SDK. User review of this
written boundary is required before the implementation plan.

## Goal

Keep the strongest new HarmonyOS SDK surfaces visibly native while rebuilding
Telegram-defining content as custom `tg_ui` components.

The target is not a pixel copy of iOS chrome and not a generic HDS messenger:

- HarmonyOS owns system material, navigation motion, safe areas and bar
  geometry;
- Telegram runtime references own information hierarchy, states and content
  density;
- custom code owns only the surfaces that make Telegram recognizably Telegram.

Visual evidence and current gaps are recorded in
`docs/ai/UI_RUNTIME_BASELINE_2026-07-10.md`.

## Ownership boundary

| Surface | Owner | Contract |
|---|---|---|
| Root bottom tabs | Native HDS | Keep `HdsTabs`, `BottomTabBarStyle`, `barFloatingStyle`, `barBackgroundStyle`, native safe-area/material/motion. Do not recreate the island in custom ArkUI. |
| Root/secondary navigation bars | Native HDS host | Prefer `HdsNavigation.titleBar`, native back/menu behavior, scroll effects and material. Custom builders may supply Telegram-specific title/subtitle/action content. |
| Chat navigation bar | Hybrid | Native navigation/material/back host; custom peer title, activity, avatar and Telegram actions passed into supported title/menu/builders. |
| Chat composer bar | Hybrid capability-gated | Evaluate `HdsActionBar` as the native material/action host. Keep text editing, reply/edit/recording/send semantics in the existing controller and custom inner builder. Retain `TgComposerInput` if HDS cannot preserve those states. |
| Search host | Native/hybrid | Use native `Search`/HDS title `bottomBuilder` or native action capsule where viable. Telegram folder/filter/story content remains custom. |
| Chat list rows | Custom `tg_ui` | Telegram avatar/title/preview/meta/badges/draft/mute/pin/read hierarchy. |
| Chat wallpaper and timeline | Custom `tg_ui` | Clean-room wallpaper, bubbles, media, service/date/unread items, reactions, pinned-message content. |
| Contacts/Calls/Settings content | Hybrid | Keep HDS navigation and section behavior; use custom rows only for Telegram-specific states. |

## Native HDS contract

### Bottom tabs

The active `MainTabsPage` path is correct and remains the production baseline:

```text
HdsTabs
  -> BottomTabBarStyle / bleedIconStyle
  -> barOverlap(!isChatDetailVisible())
  -> dynamic barHeight / opacity / bottom margin
  -> barFloatingStyle(systemMaterialEffect)
  -> dynamic barBackgroundStyle(maskColor, maskHeight)
  -> system safe-area expansion
```

The root bar must disappear as one coordinated state while a chat detail is
visible. `barOverlap`, height, opacity, bottom margin and mask height cannot be
changed independently: a partial hide can leave a dead or overlapping surface
above the composer.

`hdsMaterial.MaterialType.ADAPTIVE` and
`hdsMaterial.MaterialLevel.ADAPTIVE` are available since 6.1.0(23) and let the
system select the appropriate native material. `IMMERSIVE` may be evaluated in
an isolated demo/runtime spike, but must not replace `ADAPTIVE` merely because
it looks stronger on one emulator.

Preserve the accepted native HDS floating behavior, not the current duplicated
geometry constants. `MainTabsPage` and `SafeAreaUtils` currently disagree about
bottom margin/backplate compensation, so the dedicated tab contract patch must
establish one source of truth and prove no overlap or gap against the real
system bottom inset before changing production geometry.

### Navigation bars

For new or migrated bars, use HDS capabilities instead of painting glass. Keep
the installed SDK nesting contract explicit:

- `HdsNavigation.titleBar({ content: { ... }, style: { ... } })`;
- native `menu`, `subIcon`, title/subtitle and custom builders;
- `content.stackBuilder` and
  `content.bottomBuilder: { builder, height?, showType? }` for custom/accessory
  lanes;
- `style.scrollEffectOpts` and `style.systemMaterialEffect` for native material
  and scroll effects;
- `bindToScrollable(Array<Scroller>)` with the actual page `Scroller` before a
  scroll effect is credited as working;
- component safe-area options.

The page continues to derive Telegram state. HDS owns presentation of the bar,
not the chat/domain model.

Migrating the Chats stack has a separate parity gate because it currently uses
stock `Navigation` while the other root tabs use `HdsNavigation`. The prototype
must retain the same `NavPathStack`, route parameters, chat/profile destination
map, back handling, `chatScreenVisible` signal and scroll-position restoration
across push/pop before it may replace the active path.

### Composer capability spike

`HdsActionBar` supports a custom primary builder, start/end action buttons,
native blur policy and API23 margins. A custom primary builder must also pass
`primaryButtonBuilderWidth`; omitting it produces an incorrect back-panel width
according to the installed declaration. Before migration, a demo must prove
all of these states without regressions:

- empty mic/video;
- text/send;
- reply and edit accessory panels;
- slow mode;
- recording;
- emoji/media panel;
- multiline `TextArea` width/height and dynamic accessory height;
- focus/IME ownership, keyboard and bottom safe-area changes;
- recording gestures and cancellation.

If any required state cannot be represented, keep the custom composer and use
native material only where supported. Native-first does not justify losing
Telegram behavior.

## Custom Telegram content contract

### Chat surface foundation

Add a reusable `TgChatBackground` behind the timeline:

- two clean-room raster tiles (lossless PNG or WebP) for light/dark themes;
- rendered with ArkUI `Image.objectRepeat(ImageRepeat.XY)`;
- theme-specific base/tint tokens;
- full-size, non-interactive, excluded from message layout;
- solid-color fallback on resource load or rendering failure.

Repeated SVG is explicitly excluded: the installed API 26 `Image` declaration
states that `objectRepeat` is not applicable to SVG images. Canvas/manual tiling
is reserved as a fallback experiment only if a raster tile cannot meet quality
or memory gates.

No Telegram or decompiled ArkGram wallpaper asset is copied.

The first integration changes only page layering and wallpaper-aware surface
tokens. Message loading, grouping, scrolling and TDLib state remain untouched.

### Timeline and rows

Custom components continue to own:

- bubble grouping/tails and incoming/outgoing states;
- text/media/file/poll/contact/location/voice/video rendering;
- date/service/unread surfaces;
- pinned-message content;
- chat-list row hierarchy and right-side metadata;
- Telegram badges, drafts, typing and delivery state.

Generic spacing/color tokens are not globally changed for a single screen.
Add domain tokens where the runtime witness requires a different metric.
Visual slices consume only state/data already exposed by the current runtime.
If archive, folder/story, pinned, reaction or other required state is missing,
its contract becomes a separate typed runtime task rather than hidden scope in
a UI patch.

## State and event flow

```text
AppStore/AppStorage state
        |
page/controller derives UI state
        |
native HDS host configuration + custom tg_ui content params
        |
existing callbacks/use-cases
```

HDS components must not become a second state store. Tab selection, navigation
visibility, chat actions and composer commands continue through the existing
page/controller/store paths.

## Failure and fallback behavior

- Native material uses adaptive policy; do not manually imitate a failed blur
  with nearly transparent colors.
- A missing wallpaper resource falls back to the themed solid chat color.
- Low-memory material downgrade must be single-source and visually legible.
- The root tab bar must remain usable if custom badge content cannot render.
- Failed native capability spikes are discarded without changing the active
  custom component.

## Delivery sequence

1. **M1 — Chat Surface Foundation**
   - `TgChatBackground` spec/demo/resources/atom;
   - page layering behind the timeline;
   - wallpaper-aware bubble/service/media surface audit;
   - runtime comparison on `zai` and `File`, light and dark.
2. **M2 — Native Chrome Capability Pass**
   - preserve and contract-test the native `HdsTabs` behavior;
   - unify tab/safe-area geometry behind one source of truth only after runtime
     no-overlap/no-gap evidence;
   - prototype HDS navigation title/search builders;
   - prototype `HdsActionBar` composer host;
   - migrate only proven paths.
3. **M3 — Chat List Content Pass**
   - compact Telegram rows/meta;
   - archive state;
   - native search action/host with custom filters/stories.
4. **M4 — Timeline Completeness**
   - pinned-message panel;
   - media placeholder/collage parity;
   - remaining bubble/content polish.
5. **M5 — Secondary Screens**
   - Contacts, Calls, Settings content density inside native HDS navigation.

## Verification

Every production slice requires:

1. reference paths recorded in the component passport;
2. focused demo/state coverage;
3. `powershell -ExecutionPolicy Bypass -File .\scripts\smoke-ui-phase0.ps1`;
4. `powershell -ExecutionPolicy Bypass -File .\scripts\smoke-build.ps1`;
5. fresh emulator process and target-26 bundle witness.

Apply the relevant runtime matrix rather than forcing unrelated checks onto
every atom:

| Slice | Required runtime witnesses |
|---|---|
| Chat surface/timeline | Light/dark screenshots on the same `zai` and `File` states; scroll-position stability; raster-load fallback. |
| Composer | Empty/text/reply/edit/recording states; multiline growth; focus/IME; keyboard hidden/visible; bottom safe area. |
| Tabs | Phone plus one large-form-factor profile when available; portrait/landscape; real system bottom inset; tab reselect; chat detail push/pop; no overlap/gap. |
| HDS navigation | Matching `NavPathStack`/route parameters; back handling; scroll restore; actual bound `Scroller`; detail push/pop. |
| Rows/content atoms | Representative state demo plus light/dark list screenshot; ellipsis and right-cluster alignment. |

Native material slices also record supported material types where the SDK/runtime
exposes them, and prove a legible fallback when adaptive material is unavailable
or downgraded.

## Non-goals

- Replacing the HDS floating tab island with a custom iOS clone.
- Copying Telegram/Nekogram/ArkGram assets or code.
- Rewriting TDLib/domain behavior during visual slices.
- Forcing every Telegram content element into a native component.
- Large monolithic edits to `TgChatScreenPage` or `TgMessageRouter` when an
  isolated atom/token integration point exists.
