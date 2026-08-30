# STATUS — Telegram-HarmonyOS

Snapshot date: 2026-08-31 (target API 26; live runtime floor API 23/24)

## Текущее состояние

- **Ветка:** `dev` — каноничная; `main` не тронут, решение dev→main отложено.
- **Фаза:** «production quality по iOS-референсу» (мандат пользователя 2026-08-31 — тег v0.1.0 как цель отменён). Аудит 08-31 (3 агента: доки / стекло / нижняя панель чата) → три волны работ, см. `TASKS/TODO.md` → «Режим production quality».
- **Срез 08-31:** волна 1 готова (рецепт урока 121 на всех 10 поверхностях, единый гейт `supportsNativeMaterial`, плита фона бара списка чатов снесена — контент читается под баром; build + ui-smoke зелёные). Волна 2 критичный срез готов кодом: `TgChatBottomActionBar` (Mute/Unmute/Join/Restricted) заменяет компосер в каналах/ограниченных группах по iOS-диспетчеру `ChatInterfaceStateInputPanels.swift`; `joinChat` команда/use case; ждёт runtime-витнесс на эмуляторе. Волна 3: спеки стекла и CLAUDE.md синхронизированы с уроком 121 и новым мандатом.
- **Готово:** Login (QR + phone code), список чатов (stories, archive, search, pinned), чат-скрин (messages, replies, forwards, drafts, voice, media, emoji/sticker/GIF keyboard), компонентная система `ui/tg_ui/` (atoms → molecules → layout), Island Player Suite v1–v3.1.
- **Срез 2026-08-29:** градиентные фейд-бары (топ-бар/компосер) прошли двойное ревью (агент по коду + агент по гигиене) и ревью на эмуляторе; 4 should-fix исправлены с runtime-витнессом (инверсия градиента топ-бара, невидимая полоса компосера, двойной blur капсул, дубли emulator-чека). Незакоммичено — закоммитить как базу перед волнами.
- **Среда:** эмулятор API 26 Beta1 сломан после обновлений Windows 2026-08-28 (фриз гостя ~100-я секунда бута, LESSONS 120) — рабочая цель «Pura API24» (HarmonyOS 6.1.1); сессия TDLib переживает рестарт эмулятора.
- **Тесты:** 52+ юнит/интеграционных файла в `entry/src/ohosTest/ets/test/`, включая end-to-end pipeline (`EventPipeline.test.ets`).
- **Архитектурное решение:** solo-режим — без слоя `presentation/viewmodels/`, контроллеры чат-страниц централизованы.
- **Референсы UI Telegram iOS в интернете:** App Store (прямые mzstatic-ссылки на скрины текущей сборки), блог Telegram (Liquid Glass — `/blog/new-design-ai-summaries`), `t.me/s/TelegramTips`, Wayback Machine страницы App Store.

## Ключевые документы

| Документ | Назначение |
|---|---|
| `TASKS/TODO.md` | Активные задачи и «Порядок v0.1.0» |
| `TASKS/LESSONS.md` | Свежие уроки (83–122); полная история — `TASKS/ARCHIVE/LESSONS-full-archive-2026-07-22.md` |
| `docs/specs/2026-07-22-island-player-suite-design.md` | Живая спека Island Player Suite |
| `AGENTS.md`, `CLAUDE.md` | Инструкции для ИИ-ассистентов |

## Уборка 2026-08-26

- Удалены: `docs/superpowers/` (13 отчётов; живая спека сохранена в `docs/specs/`), дубли `GEMINI.md`/`QWEN.md`, временные файлы (`.tmp_kit_stats.ps1`, `hs_err_pid*.log`).
- Архивированы: старый `STATUS.md` → `TASKS/ARCHIVE/STATUS-history-2026-07-22.md`; LESSONS 1–82 → там же.
- `core/models/` удалён как dead code (re-export shim без потребителей).

## История

Полная история состояния проекта (включая период заморозки 2026-07…08): `TASKS/ARCHIVE/STATUS-history-2026-07-22.md`.
