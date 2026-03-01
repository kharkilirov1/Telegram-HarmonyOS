# tg_ui (Telegram-style UI v2 scaffold)

This folder contains the component-by-component Telegram iOS → HarmonyOS UI port.

## Structure
- `tokens/` — visual tokens only (color/spacing/typography/radius/elevation)
- `atoms/` — smallest reusable UI elements
- `molecules/` — composed blocks from atoms
- `demos/` — isolated preview screens with state matrix
- `spec/` — component passports (contract before implementation)

## Rules
1. iOS code inspection first, implementation second.
2. One atom per patch.
3. No magic constants in component code when token exists.
4. Each atom must have:
   - passport in `spec/`
   - demo screen in `demos/`
   - reusable implementation in `atoms/` or `molecules/`
