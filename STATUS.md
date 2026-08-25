# STATUS — Telegram-HarmonyOS

Snapshot date: 2026-08-26 (target API 26; live runtime floor API 23)

## Текущее состояние

- **Ветка:** `dev` — каноничная; `main` не тронут, решение dev→main отложено.
- **Фаза:** активная разработка UI-фич поверх зрелого ядра (TDLib-синк, EventNormalizer → AppStore → AppState).
- **Готово:** Login (QR + phone code), список чатов (stories, archive, search, pinned), чат-скрин (messages, replies, forwards, drafts, voice, media, emoji/sticker/GIF keyboard), компонентная система `ui/tg_ui/` (atoms → molecules → layout).
- **Тесты:** 52+ юнит/интеграционных файла в `entry/src/ohosTest/ets/test/`, включая end-to-end pipeline (`EventPipeline.test.ets`: raw TDLib JSON → Normalizer → Store → State).
- **Архитектурное решение:** solo-режим — без слоя `presentation/viewmodels/`, контроллеры чат-страниц централизованы.

## Ключевые документы

| Документ | Назначение |
|---|---|
| `TASKS/TODO.md` | Активные задачи и пластины |
| `TASKS/LESSONS.md` | Свежие уроки (83–118); полная история — `TASKS/ARCHIVE/LESSONS-full-archive-2026-07-22.md` |
| `docs/specs/2026-07-22-island-player-suite-design.md` | Живая спека Island Player Suite |
| `AGENTS.md`, `CLAUDE.md` | Инструкции для ИИ-ассистентов |

## Уборка 2026-08-26

- Удалены: `docs/superpowers/` (13 отчётов; живая спека сохранена в `docs/specs/`), дубли `GEMINI.md`/`QWEN.md`, временные файлы (`.tmp_kit_stats.ps1`, `hs_err_pid*.log`).
- Архивированы: старый `STATUS.md` → `TASKS/ARCHIVE/STATUS-history-2026-07-22.md`; LESSONS 1–82 → там же.
- `core/models/` удалён как dead code (re-export shim без потребителей).

## История

Полная история состояния проекта (включая период заморозки 2026-07…08): `TASKS/ARCHIVE/STATUS-history-2026-07-22.md`.
