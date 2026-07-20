# TgStickerSettingsSheet passport

## Reference

- Runtime visual truth: the user-provided Telegram iOS entity-keyboard screenshots from 2026-07-10 show the settings gear beside the centered `GIF / Stickers / Emoji` switch.
- iOS action: `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\ChatEntityKeyboardInputNode\Sources\ChatEntityKeyboardInputNode.swift:1306-1312` opens `makeInstalledStickerPacksController(... mode: .modal ...)`.
- iOS content hierarchy: `C:\Refs\Telegram\Telegram-iOS-current\submodules\SettingsUI\Sources\Stickers\InstalledStickerPacksController.swift`.

## Inputs

- Real installed regular-sticker pack tabs already loaded from TDLib.
- Localized sheet title, installed-section title, and empty state.

## State matrix

- Regular sticker or emoji mode: settings gear visible.
- GIF mode: settings gear hidden.
- Installed packs: thumbnail/fallback emoji and one-line title rows.
- Empty: localized empty state; no synthetic pack rows.

## Layout and presentation

- The mode pill remains geometrically centered by equal-width left/right slots.
- The gear uses a compact 34vp visual circle with a 42vp response region.
- ArkUI `bindSheet` provides the native bottom-modal transition, drag bar, title and close control.
- Telegram pack content remains custom and is sourced from the same TDLib-backed model as the keyboard strip.

## Current scope

- This slice exposes the truthful installed-pack list. Reorder, remove, archived, trending and preference controls remain outside this narrow UI pass until their TDLib command paths are implemented.
