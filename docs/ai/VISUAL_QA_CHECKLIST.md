# Visual QA Checklist (Phase 0+)

Use before marking any UI phase as done.

## 1) Consistency
- [ ] No random hardcoded brand colors in shell screens.
- [ ] Typography uses shared token sizes.
- [ ] Spacing/radius values are tokenized.

## 2) Shell quality
- [ ] Bottom tab bar height and icon/text density are consistent.
- [ ] Active/inactive tab states are clearly readable.
- [ ] Badge placement is stable for 1/2/3-digit values.
- [ ] Top bar title and action alignment are centered and balanced.

## 3) List quality
- [ ] Row heights are consistent across tabs.
- [ ] Avatar/title/subtitle baselines are aligned.
- [ ] Separator inset is visually correct.

## 4) Safe areas & devices
- [ ] No clipping with system bars.
- [ ] Bottom bar is correct on phone and tablet.
- [ ] Landscape layout keeps controls reachable.

## 5) Dark/Light
- [ ] Text contrast is readable in both themes.
- [ ] Icons/badges/backgrounds preserve hierarchy in dark mode.

## 6) Interaction quality
- [ ] Tap targets are not too small (<40vp areas).
- [ ] No janky transitions between tabs.
- [ ] Loading/empty states visually match the shell style.

