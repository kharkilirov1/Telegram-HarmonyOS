# Chat Surface Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a clean-room, theme-aware Telegram chat wallpaper behind the
existing timeline without changing TDLib state, scrolling, native HDS chrome,
or composer behavior.

**Architecture:** A presentation-only `TgChatBackground` atom paints a themed
solid fallback and repeats a transparent raster resource with
`Image.objectRepeat(ImageRepeat.XY)`. `TgChatScreenPage` composes the atom as
the first child of its existing root `Stack`; the current timeline, top bar,
composer, media gallery, callbacks, and navigation stay above it unchanged.

**Tech Stack:** ArkTS/ArkUI API 26, `@ComponentV2`, qualified Harmony resources,
PowerShell smoke contracts, Python/Pillow only for deterministic asset creation,
DevEco `hvigor` build, `hdc` runtime witness.

## Global Constraints

- Target remains HarmonyOS API 26 with minimum/compatible `6.1.0(23)`.
- Keep `HdsTabs`, HDS material, navigation motion, and safe-area ownership native.
- UI-only slice: do not change TDLib commands, reducers, controllers, pagination,
  timeline keys, composer state, navigation routes, or callbacks.
- Use a clean-room raster PNG tile; never copy Telegram, Nekogram, or ArkGram
  wallpaper assets.
- Do not use SVG with `objectRepeat`; the installed API 26 declaration and
  official ArkUI documentation state that repeated SVG is unsupported.
- The wallpaper root and image must not participate in pointer hit testing.
- Keep the existing UI as the fallback: the themed solid color must remain
  visible if the image cannot load or render.
- No hardcoded color literals in ArkTS components; colors come through
  `TgUiTokens` and qualified resource JSON.
- Keep edits to `TgChatScreenPage.ets` limited to one import and one background
  composition. Preserve its existing outer fallback and safe-area contract.
- Do not commit, stage, push, or publish; this repository requires an explicit
  user command for Git publishing actions.

---

## File Structure

- `entry/src/main/ets/ui/tg_ui/atoms/TgChatBackground.ets` — presentation-only
  full-size fallback/pattern atom.
- `entry/src/main/ets/ui/tg_ui/demos/TgChatBackgroundDemo.ets` — six preview
  states covering patterned, fallback, narrow/tall, bubble contrast, and service
  contrast.
- `entry/src/main/ets/ui/tg_ui/spec/TgChatBackground.md` — component passport,
  reference provenance, inputs, state/layout/token contracts, acceptance gates.
- `entry/src/main/resources/base/media/tg_chat_wallpaper_tile.png` — clean-room
  light transparent raster tile.
- `entry/src/main/resources/dark/media/tg_chat_wallpaper_tile.png` — clean-room
  dark transparent raster tile selected through the `dark` qualifier.
- `entry/src/main/resources/base/element/color.json` — light fallback color.
- `entry/src/main/resources/dark/element/color.json` — dark fallback color.
- `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets` — resource token exposed to
  the atom and page.
- `scripts/smoke-ui-phase0.ps1` — RED/GREEN source/resource/integration contract.
- `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets` — two-site integration
  into the existing root `Stack`.
- `STATUS.md`, `TASKS/TODO.md`, `TASKS/LESSONS.md` — compact verified outcome
  after runtime evidence exists.

---

### Task 1: Build the `TgChatBackground` atom contract-first

**Files:**
- Create: `entry/src/main/ets/ui/tg_ui/atoms/TgChatBackground.ets`
- Create: `entry/src/main/ets/ui/tg_ui/demos/TgChatBackgroundDemo.ets`
- Create: `entry/src/main/ets/ui/tg_ui/spec/TgChatBackground.md`
- Create: `entry/src/main/resources/base/media/tg_chat_wallpaper_tile.png`
- Create: `entry/src/main/resources/dark/media/tg_chat_wallpaper_tile.png`
- Modify: `entry/src/main/resources/base/element/color.json`
- Modify: `entry/src/main/resources/dark/element/color.json`
- Modify: `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets`
- Test: `scripts/smoke-ui-phase0.ps1`

**Interfaces:**
- Consumes: `$r('app.color.chat_wallpaper_base')` and the qualified
  `$r('app.media.tg_chat_wallpaper_tile')` resource.
- Produces: `export struct TgChatBackground` with
  `@Param showPattern: boolean = true`.

- [ ] **Step 1: Add the failing atom/resource smoke contract**

Add `TgChatBackground.ets` to `$phase0Files`, then add these paths beside the
existing `$chatScreenFile` declarations:

```powershell
$chatBackgroundFile = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgChatBackground.ets'
$chatBackgroundLightTile = Join-Path $root 'entry/src/main/resources/base/media/tg_chat_wallpaper_tile.png'
$chatBackgroundDarkTile = Join-Path $root 'entry/src/main/resources/dark/media/tg_chat_wallpaper_tile.png'
```

Add these checks before the existing chat-screen composition checks:

```powershell
if (-not (Select-String -Path $chatBackgroundFile -Pattern '@ComponentV2')) {
  Write-Error 'TgChatBackground must be a ComponentV2 atom.'
  exit 1
}

if (-not (Select-String -Path $chatBackgroundFile -Pattern 'objectRepeat\(ImageRepeat\.XY\)')) {
  Write-Error 'TgChatBackground must repeat its qualified raster tile on both axes.'
  exit 1
}

if (-not (Select-String -Path $chatBackgroundFile -Pattern 'HitTestMode\.None')) {
  Write-Error 'TgChatBackground must not intercept timeline or chrome input.'
  exit 1
}

foreach ($tile in @($chatBackgroundLightTile, $chatBackgroundDarkTile)) {
  if (-not (Test-Path -LiteralPath $tile)) {
    Write-Error "Required qualified chat wallpaper tile not found: $tile"
    exit 1
  }
  $signature = [System.IO.File]::ReadAllBytes($tile)[0..7]
  if ([System.BitConverter]::ToString($signature) -ne '89-50-4E-47-0D-0A-1A-0A') {
    Write-Error "Chat wallpaper resource must be a PNG raster: $tile"
    exit 1
  }
}
```

- [ ] **Step 2: Run the smoke contract and verify RED**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-ui-phase0.ps1
```

Expected: FAIL with `Required file not found` for
`TgChatBackground.ets`. A parse error or an unrelated failure does not count as
RED; repair the smoke check until it fails for the missing atom.

- [ ] **Step 3: Generate two deterministic clean-room transparent PNG tiles**

Run this from the repository root. It creates only abstract generic doodles and
does not read any competitor asset:

```powershell
@'
from pathlib import Path
from math import cos, pi, sin
from PIL import Image, ImageDraw

SIZE = 192

def star(cx, cy, outer, inner):
    points = []
    for index in range(10):
        radius = outer if index % 2 == 0 else inner
        angle = -pi / 2 + index * pi / 5
        points.append((cx + cos(angle) * radius, cy + sin(angle) * radius))
    return points

def make_tile(path, stroke):
    image = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    width = 2

    # Generic speech bubble.
    draw.rounded_rectangle((12, 14, 58, 46), radius=10, outline=stroke, width=width)
    draw.line((24, 46, 19, 54, 35, 46), fill=stroke, width=width, joint='curve')
    draw.ellipse((24, 28, 27, 31), fill=stroke)
    draw.ellipse((34, 28, 37, 31), fill=stroke)
    draw.ellipse((44, 28, 47, 31), fill=stroke)

    # Generic camera.
    draw.rounded_rectangle((112, 15, 158, 49), radius=7, outline=stroke, width=width)
    draw.rectangle((124, 10, 143, 18), outline=stroke, width=width)
    draw.ellipse((127, 23, 145, 41), outline=stroke, width=width)

    # Generic star and heart.
    draw.line(star(84, 78, 17, 8) + [star(84, 78, 17, 8)[0]], fill=stroke, width=width, joint='curve')
    draw.line((132, 75, 123, 66, 113, 68, 108, 77, 111, 87, 132, 105,
               153, 87, 156, 77, 151, 68, 141, 66, 132, 75), fill=stroke, width=width, joint='curve')

    # Generic paper plane.
    draw.polygon((16, 112, 65, 94, 49, 145, 38, 123), outline=stroke)
    draw.line((38, 123, 65, 94), fill=stroke, width=width)
    draw.line((38, 123, 49, 145), fill=stroke, width=width)

    # Generic phone receiver and location pin.
    draw.arc((76, 116, 117, 158), start=15, end=165, fill=stroke, width=width)
    draw.line((82, 126, 76, 120, 82, 113), fill=stroke, width=width)
    draw.line((111, 126, 117, 120, 111, 113), fill=stroke, width=width)
    draw.ellipse((141, 126, 173, 158), outline=stroke, width=width)
    draw.ellipse((152, 137, 162, 147), outline=stroke, width=width)
    draw.line((157, 158, 157, 176), fill=stroke, width=width)

    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format='PNG', optimize=True)

make_tile(Path('entry/src/main/resources/base/media/tg_chat_wallpaper_tile.png'), (70, 111, 128, 34))
make_tile(Path('entry/src/main/resources/dark/media/tg_chat_wallpaper_tile.png'), (100, 151, 172, 30))
'@ | python -
```

Expected: both files are `192 × 192`, RGBA PNGs with transparent backgrounds.

- [ ] **Step 4: Add the light/dark fallback resource and token**

Add this entry to the base color array:

```json
{
  "name": "chat_wallpaper_base",
  "value": "#E9EFF2"
}
```

Add the same resource name to the dark color array:

```json
{
  "name": "chat_wallpaper_base",
  "value": "#0F2837"
}
```

Add this token directly after `COLOR_BG_SECONDARY`:

```typescript
static readonly COLOR_CHAT_WALLPAPER_BASE: Resource = $r('app.color.chat_wallpaper_base');
```

- [ ] **Step 5: Implement the minimal presentation atom**

Create `TgChatBackground.ets` with exactly this behavior:

```typescript
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgChatBackground {
  @Param showPattern: boolean = true;

  build() {
    Stack() {
      if (this.showPattern) {
        Image($r('app.media.tg_chat_wallpaper_tile'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.ScaleDown)
          .objectRepeat(ImageRepeat.XY)
          .draggable(false)
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_CHAT_WALLPAPER_BASE)
    .hitTestBehavior(HitTestMode.None)
  }
}
```

The solid root is the fallback. Do not add load state, logging, gesture state, or
domain dependencies.

- [ ] **Step 6: Create the six-state demo**

Create `TgChatBackgroundDemo.ets`. The complete demo API is:

```typescript
import { TgChatBackground } from '../atoms/TgChatBackground';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgChatBackground' })
@ComponentV2
export struct TgChatBackgroundDemo {
  @Builder
  private caseBlock(label: string, showPattern: boolean, height: number,
    outgoing: boolean, service: boolean) {
    Stack({ alignContent: Alignment.TopStart }) {
      TgChatBackground({ showPattern })

      Column({ space: TgUiTokens.SPACE_8 }) {
        Text(label)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)

        if (service) {
          Text('Today')
            .fontSize(TgUiTokens.FONT_META_SIZE)
            .fontColor(TgUiTokens.DATE_SEPARATOR_TEXT)
            .padding({ left: TgUiTokens.SPACE_8, right: TgUiTokens.SPACE_8,
              top: TgUiTokens.SPACE_4, bottom: TgUiTokens.SPACE_4 })
            .backgroundColor(TgUiTokens.DATE_SEPARATOR_BG)
            .borderRadius(TgUiTokens.DATE_SEPARATOR_RADIUS)
        } else {
          Text(outgoing ? 'Outgoing message contrast' : 'Incoming message contrast')
            .fontSize(TgUiTokens.MSG_TEXT_SIZE)
            .fontColor(outgoing ? TgUiTokens.MSG_TEXT_OUTGOING : TgUiTokens.MSG_TEXT_INCOMING)
            .padding({ left: TgUiTokens.BUBBLE_PADDING_H,
              right: TgUiTokens.BUBBLE_PADDING_H,
              top: TgUiTokens.BUBBLE_PADDING_V,
              bottom: TgUiTokens.BUBBLE_PADDING_V })
            .backgroundColor(outgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG :
              TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG)
            .borderRadius(outgoing ? TgUiTokens.BUBBLE_RADIUS_OUTGOING :
              TgUiTokens.BUBBLE_RADIUS_INCOMING)
        }
      }
      .width('100%')
      .padding(TgUiTokens.SPACE_12)
    }
    .width('100%')
    .height(height)
  }

  build() {
    Scroll() {
      Column({ space: TgUiTokens.SPACE_12 }) {
        this.caseBlock('01 patterned incoming', true, 160, false, false)
        this.caseBlock('02 patterned outgoing', true, 160, true, false)
        this.caseBlock('03 patterned service', true, 160, false, true)
        this.caseBlock('04 solid fallback', false, 160, false, false)
        this.caseBlock('05 narrow patterned', true, 120, true, false)
        this.caseBlock('06 tall patterned', true, 240, false, false)
      }
      .width('100%')
      .padding(TgUiTokens.SPACE_12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}
```

- [ ] **Step 7: Write the component passport**

The passport must record:

```markdown
# TgChatBackground passport

## References
- Runtime visual truth: `docs/ai/UI_RUNTIME_BASELINE_2026-07-10.md`
- Ownership/design contract: `docs/ai/HYBRID_NATIVE_CUSTOM_UI_DESIGN_2026-07-10.md`
- Current iOS structural reference: `C:\Refs\Telegram\Telegram-iOS-current`
- Harmony API: ArkUI `Image.objectRepeat(ImageRepeat.XY)`; raster only.

## Inputs
- `showPattern: boolean = true` — test/demo fallback switch only.

## State matrix
- qualified light tile + light base
- qualified dark tile + dark base
- pattern enabled
- pattern disabled/resource failure: solid themed base remains visible
- narrow, normal and tall containers

## Layout and interaction
- fills the parent without adding padding or safe-area ownership
- first/lowest child of the chat root `Stack`
- does not affect timeline measurement, scroll offsets or overlay geometry
- root and image use `HitTestMode.None`
- raster repeats on both axes; repeated SVG is forbidden by API contract

## Tokens and resources
- `TgUiTokens.COLOR_CHAT_WALLPAPER_BASE`
- `app.color.chat_wallpaper_base` in base/dark resource qualifiers
- `app.media.tg_chat_wallpaper_tile` in base/dark resource qualifiers

## Acceptance
- smoke contract passes
- clean `assembleHap` succeeds
- light/dark `zai` and `File` screenshots show visible but subordinate pattern
- incoming/outgoing bubbles and service chips remain legible
- timeline scrolling and composer/top-bar hit testing remain unchanged
```

- [ ] **Step 8: Verify GREEN for the atom slice**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-ui-phase0.ps1
```

Expected: `tg_ui shell smoke checks passed.`

Review checkpoint: inspect the two PNGs and the demo source. Reject copied
motifs, opaque tile backgrounds, any ArkTS hex color, or any input behavior.

---

### Task 2: Integrate the atom behind the existing chat timeline

**Files:**
- Modify: `scripts/smoke-ui-phase0.ps1`
- Modify: `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets:9-16`
- Modify: `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets:2832-3097`

**Interfaces:**
- Consumes: `TgChatBackground({ showPattern?: boolean })` from Task 1.
- Produces: the existing chat destination with a new lowest visual layer and no
  changed state/callback interface.

- [ ] **Step 1: Add the failing page-composition contract**

Append these checks after the current `TgMessageRouter` assertion:

```powershell
if (-not (Select-String -Path $chatScreenFile -Pattern 'TgChatBackground\(')) {
  Write-Error 'TgChatScreenPage must compose TgChatBackground behind the timeline.'
  exit 1
}

```

- [ ] **Step 2: Run the smoke contract and verify RED**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-ui-phase0.ps1
```

Expected: FAIL with `TgChatScreenPage must compose TgChatBackground behind the
timeline.`

- [ ] **Step 3: Make the two-site production integration**

Add the import beside the other `tg_ui` atoms:

```typescript
import { TgChatBackground } from '../../tg_ui/atoms/TgChatBackground';
```

Add the atom as the first child of the existing root `Stack`, before the comment
`Content layer`:

```typescript
TgChatBackground()
```

Do not add a background to the timeline `Column` or `List`; both must remain
transparent so the lowest layer is visible. Keep the existing outer
`.backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)` as the final page-level
fallback and keep `expandSafeArea` unchanged.

- [ ] **Step 4: Verify GREEN and compile the integrated slice**

Run, in order:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-ui-phase0.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-build.ps1
```

Expected:
- `tg_ui shell smoke checks passed.`
- clean/build stages complete with `BUILD SUCCESSFUL`;
- only the repository's known signing warning is allowed.

Review checkpoint: the diff in `TgChatScreenPage.ets` must contain no changes to
list offsets, pagination, timeline entries, top bar, composer, gallery,
navigation, callbacks, or lifecycle code.

---

### Task 3: Prove the intended runtime path and record the outcome

**Files:**
- Create captures under: `.codex/ui-audit/2026-07-10/m1-chat-surface/`
- Modify: `STATUS.md`
- Modify: `TASKS/TODO.md`
- Modify: `TASKS/LESSONS.md` only if a reusable pitfall was actually observed.

**Interfaces:**
- Consumes: built `entry-default-unsigned.hap`, connected emulator target
  `127.0.0.1:5555`, existing logged-in session.
- Produces: fresh-process evidence plus same-chat light/dark visual witnesses.

- [ ] **Step 1: Install only the entry HAP and start a fresh app process**

Run:

```powershell
$hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$hap = 'entry\build\default\outputs\default\entry-default-unsigned.hap'
& $hdc list targets
& $hdc install -r $hap
& $hdc shell aa force-stop -b com.telegram.harmonyos
& $hdc shell aa start -a EntryAbility -b com.telegram.harmonyos
& $hdc shell date
& $hdc shell "ps -ef | grep com.telegram.harmonyos"
```

Expected: target `127.0.0.1:5555`, successful install/start, and application
process `STIME` matching the fresh device time. Do not install the standalone
ohosTest HAP because it would recreate the bundle and wipe the session.

- [ ] **Step 2: Capture the same `zai` and `File` chat states**

Create the output directory and use `uitest uiInput` plus `snapshot_display`:

```powershell
$out = '.codex\ui-audit\2026-07-10\m1-chat-surface'
New-Item -ItemType Directory -Force -Path $out | Out-Null
& $hdc shell snapshot_display -f /data/local/tmp/chat-surface.jpeg
& $hdc file recv /data/local/tmp/chat-surface.jpeg "$out\current-chat.jpeg"
```

Navigate through the live chat list using UI element bounds from
`uitest dumpLayout`; capture `zai` and `File` without changing their message
content. Repeat after switching the emulator theme through Settings UI. Save:

```text
zai-light.jpeg
zai-dark.jpeg
file-light.jpeg
file-dark.jpeg
```

- [ ] **Step 3: Apply the visual acceptance rubric**

All four witnesses must satisfy:

- patterned chat surface is visible in empty gaps and around media;
- pattern stays subordinate to text/bubbles and does not resemble a copied
  Telegram/Nekogram/ArkGram tile;
- light incoming bubbles no longer disappear into a white page;
- dark incoming/outgoing bubbles remain distinguishable from the base;
- top bar, composer, scroll-to-bottom button, keyboard path, and root native tab
  visibility are unchanged;
- a vertical timeline swipe moves the list, proving the background did not
  intercept input.

If this rubric fails, change only the two generated tile alpha values or the two
`chat_wallpaper_base` resources, rebuild, reinstall, and replace the witnesses.
Do not change bubble geometry or chrome in M1.

- [ ] **Step 4: Record only verified outcomes**

Update the compact project docs:

```markdown
- M1 Chat Surface Foundation: `TgChatBackground` is integrated as the lowest
  chat stack layer with qualified light/dark clean-room PNG tiles and solid
  fallback; smoke/build and fresh runtime witnesses are recorded at
  `.codex/ui-audit/2026-07-10/m1-chat-surface/`.
```

Mark the M1 TODO complete only if all four captures and the fresh process witness
exist. Add a lesson only for an observed reusable ArkUI/resource/runtime pitfall;
do not add generic commentary.

- [ ] **Step 5: Final verification**

Run after the last edit:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-ui-phase0.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-build.ps1
git diff --check
git status --short
```

Expected: smoke/build success, no whitespace errors, and only intentional M1
files plus the repository's pre-existing dirty baseline. Do not stage or commit.
