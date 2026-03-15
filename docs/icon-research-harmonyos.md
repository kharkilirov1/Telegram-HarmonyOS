# HarmonyOS app icon research for Telegram client

## Sources

- HarmonyOS docs: **Configuring an Application Icon and Label**
- HarmonyOS docs: **Configuring a Layered Icon and Label**
- HarmonyOS docs: **Resource Categories and Access**
- Local official template package:
  - `C:\Users\Kharki\Downloads\HarmonyOS-app-icons-en\HarmonyOS-app-icons-en\HarmonyOS App Icons.sketch`
  - `C:\Users\Kharki\Downloads\HarmonyOS-app-icons-en\HarmonyOS-app-icons-en\HarmonyOS App Icons.pix`

## Verified findings from the local HarmonyOS template package

The official template file contains the following 1024x1024 artboards:

- `A` — circular grid
- `B` — square grid
- `C` — rectangular grid 1
- `D` — rectangular grid 2
- `Foreground`
- `Background`
- `LIGHT-2D`
- `DARK-2D`
- `LIGHT-3D`
- `DARK-3D`
- device scenario artboards: `Phone`, `Pad`, `Foldable`, `PC`, `Wearable`

This confirms that HarmonyOS expects icon work to be built from:

1. a strict layout grid
2. a separate foreground/background workflow
3. style references for both 2D and 3D light/dark variants
4. validation in real device scenarios

## What this means for our Telegram icon

### Best base grid

Use **artboard A (circular grid)** as the main construction base because the visual idea is a ring/halo around the Telegram plane.

### Best style reference

Use **DARK-3D** as the mood reference, but keep the execution closer to **DARK-2D** in complexity.

Reason:

- DARK-3D gives the premium HarmonyOS feel
- DARK-2D keeps the icon readable in the launcher
- full 3D/glow stacks become noisy very quickly at small sizes

### Recommended layer split

#### Background

- dark rounded-square base
- subtle deep blue / black gradient
- optional soft halo or ring behind the main mark
- if reflection is used, keep it extremely weak

#### Foreground

- Telegram plane only
- clean silhouette
- minimal internal detail
- no lens flare crossing the plane
- no text

## Drawing workflow

1. Start on a **1024x1024** artboard.
2. Place the composition on **grid A**.
3. Build the icon in **two logical layers** from the beginning:
   - background atmosphere
   - foreground Telegram plane
4. First make the icon work in pure flat form:
   - dark base
   - plane
   - ring/halo
5. Only after that add restrained depth:
   - one soft glow
   - one soft inner shadow or lower reflection
6. Check against small-size readability:
   - 128 px
   - 96 px
   - 64 px
7. Validate on dark and light contexts, then compare against the device scenario boards.

## What to avoid

- making the Harmony-style ring brighter than the Telegram plane
- crossing the center with a hard light streak
- strong lower blur that turns into a dirty smudge
- poster-style effects that do not survive launcher scaling
- exact use of HarmonyOS branding marks or wordmarks

## Telegram-specific recommendation

The correct hierarchy should be:

1. Telegram plane
2. dark premium base
3. HarmonyOS-style halo
4. tiny amount of atmosphere

If the eye reads the ring before the plane, the icon is wrong.

## Practical direction for the next iteration

### Safer version

- dark rounded square
- faint halo behind
- centered Telegram plane
- almost no reflection

### More native HarmonyOS version

- dark rounded square
- thicker but softer halo
- lower half slight fade, not a strong water reflection
- plane remains fully dominant

## Local extracted references

Extracted previews are stored here:

- `C:\Users\Kharki\Downloads\HarmonyOS-app-icons-en\HarmonyOS-app-icons-en\extracted\template_summary.png`

## FigJam support

Simple layer-stack diagram:

- https://www.figma.com/online-whiteboard/create-diagram/6585965d-7639-437e-94e7-db825bf8dc5d?utm_source=other&utm_content=edit_in_figjam&oai_id=&request_id=ed95e28a-714f-481b-9943-af5f42b8bdfb
