# <AtomName> Component Passport

## 1) Scope
- Atom: `<AtomName>`
- Target layer: `atoms | molecules`
- Status: `draft | in-progress | accepted`

## 2) iOS source mapping
- iOS files:
  - `<path/to/file1.swift>`
  - `<path/to/file2.swift>`
- Evidence notes:
  - subcomponents:
  - state handling:
  - measured constants:

## 3) Inputs contract
- Props / input model fields:
  - `<field>: <type> — meaning`
- Optional callbacks:
  - `<callback>`

## 4) State matrix
- Required states:
  - default
  - selected
  - pressed
  - disabled (if applicable)
  - domain-specific states

## 5) Layout contract
- Container size rules:
- Horizontal paddings:
- Vertical paddings:
- Baselines/alignment rules:
- Ellipsis behavior:
- Safe-area interaction rules:

## 6) Token mapping
- colors:
- typography:
- spacing:
- radius:
- elevation/blur:

## 7) Demo matrix (must be implemented)
- Case 01:
- Case 02:
- ...

## 8) Acceptance checklist
- [ ] Visual parity (close to iOS)
- [ ] No magic constants where token exists
- [ ] Light/Dark pass
- [ ] Safe area pass
- [ ] Demo covers all required states
