# Playback ownership — reliability continuation

Предыдущий turn: progress — native startup/recorder patch, regression witnesses и HAP builds сохранены. Общая production parity цель не завершена.

## Ожидания до изменений

- [x] Controller: captured player/FD, startup/callback/control ownership; playing startup доступен stop/pause до settlement Promise, ранний completed сохранён.22/22 и8 controls.
- [x] Global worker: adjacent/cover ownership, serial background effects, canceled linger guards.41/41 и14 controls;actual pair4/4.
- [x] RED→GREEN: final harness HEAD controller6/22 и Global12/41; independent startup P1/P2 лично воспроизведены, исправлены и перепроверены. Device equivalence не заявляется.
- [x]49/49 host suites,38/38PS+Bash,forced serial main/ohosTest builds;610/610 hashes и514/514 build-source hashes совпали. STATUS/TODO/LESSONS и docs/reviews/2026-09-28-playback-remediation.md обновлены.
- [ ] Device acceptance текущего HAP остаётся отдельным gate: saved emulator session не переустанавливать без полученного согласия.

## Границы

Parent owns VoicePlaybackController.ets и test-media-playback-ownership.cjs. Worker owns GlobalMediaPlayback.ets и test-global-media-ownership.cjs. Не менять UI/TDLib архитектуру, не отправлять сообщения/не записывать микрофон, не коммитить/публиковать.

Grounding: harmonyos_docs AVPlayer.release — any state except released, Promise<void>; локальный HarmonyOS Media codelab; iOS MediaManager.swift setPlaylistByTypeDisposables/context/player-index. Это источники lifecycle semantics, не доказательство device/visual parity. Проверки SDK failures и account-wide reset требуют явной границы, не объявлять их закрытыми по controller-only тесту.
