# Playback: владение ресурсами и устаревшие операции — 28 сентября 2026

## Результат

**Исправлены гонки переключения/остановки аудио и голосовых сообщений, поздних playlist/cover результатов и фоновой audio-задачи.** Финальный локальный прогон: **49/49 host suites, 38/38 PowerShell, Bash smoke, main и ohosTest builds — PASS**.

**Это source/host/compile acceptance, не проверка звука на устройстве и не полная account isolation.** Новый HAP не устанавливался: существующая Telegram-сессия не затронута. Общая production parity цель остаётся активной.

## Что изменено

### 1. Controller

[VoicePlaybackController.ets](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/VoicePlaybackController.ets)

- Каждая операция владеет своими AVPlayer/FD/callbacks; cleanup захватывает ресурсы до await, конкурирующие release присоединяются к одному освобождению.
- Отменённые create/prepare не публикуют старый трек. Поздние callback, pause/seek и retry не меняют новый player/UI.
- Владение и prepared snapshot публикуются **до вызова play**: уже играющий native player доступен stop/pause даже при незавершённом play Promise.
- SDK event и завершение Promise моделируются независимо. Ранний completed сохраняет progress/time и вызывает completion; последующий settlement не сбрасывает результат.
- Ошибка listener освобождает текущие ресурсы. Cleanup-ошибка старой операции не выдаётся как ошибка нового playback; reentrant stop из completion listener не запускает старый auto-advance.

### 2. Global playback

[GlobalMediaPlayback.ets](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/GlobalMediaPlayback.ets)

- Generation и request ID проверяются после поиска/скачивания, до нового playback и после его ожидания. Последний next/previous intent имеет приоритет.
- Обложка привязана к поколению metadata, а не только к message ID: защищены повторяющиеся ID и initial zero → prepared переход.
- Background start/stop сериализованы. SDK stop работает на UIAbility context, поэтому одного guard после уже отправленного stop недостаточно.
- Отменённый linger timer не останавливает нового владельца; новый startup получает ограниченный grace period, а поздний stop не забирает background у нового трека.
- Публичные API и callers не менялись; бизнес-архитектура TDLib/AppStore и визуальная разметка сохранены.

## Доказательства

| Проверка | Исходник / отрицательный контроль | Финал |
|---|---|---|
| Actual controller, финальные 22 cases | HEAD: 6 PASS / 16 FAIL, exit 1 | 22/22, exit 0 |
| Controller mutations | В памяти удалены ownership/cleanup/ordering guards, включая возврат дефектного after-play publication | 8/8 отвергнуты |
| Actual Global, финальные 41 cases | Global из HEAD, текущий controller для интеграционных cases: 12 PASS / 29 FAIL, exit 1 | 41/41, exit 0 |
| Global mutations | 14 адресных мутаций; требуется падение конкретного behavioral witness | 14/14 отвергнуты |
| Дополнительный actual controller + actual Global integration | Success, stop при pending lookup/create, replacement | 4/4, exit 0 |
| Общий host runner | 49 исполняемых suites | 49 PASS / 0 FAIL |
| PowerShell / Bash | 37 test scripts + smoke; отдельный Bash smoke | 38/38; PASS |
| Main forced serial build | CompileArkTS 14.098 s | BUILD SUCCESSFUL 22.876 s, exit 0 |
| ohosTest forced serial build | OhosTestCompileArkTS 8.517 s | BUILD SUCCESSFUL 17.317 s, exit 0 |
| Стабильность входов | Source/test/resource snapshot; отдельно build inputs внутри entry | 610/610 и 514/514 hashes совпали |
| Whitespace | git -c core.whitespace=cr-at-eol diff --check | exit 0 |

Оба build выполнены последовательно с no-incremental/no-daemon. Это не clean-checkout и не remote CI. HAP unsigned; сохраняются предупреждения NAPI declarations, throwable APIs/MICROPHONE, missing previewer ICU. ohosTest **скомпилирован, но на устройстве не исполнен**.

### Что исправило независимое ревью

Первый вариант controller прошёл 18 tests, но reviewer обнаружил реальные P1/P2: player мог уже играть, оставаясь невидимым stop/pause до settlement Promise; ранний completed терялся. Основной агент воспроизвёл **18 PASS / 3 FAIL**, исправил ownership publication и включил сценарии в постоянный suite. Финальные 22 tests и mutation возврата ошибочного поведения проходят/падают ожидаемо.

[Независимое ревью controller с resolution](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-playback-controller-review.md) подтверждает F1/F2 на том же frozen hash. Дополнительные reviewer probes в общий parent test count не включены.

Во время разработки также исправлена слабость самого harness: незавершённый mocked Promise мог позволить Node выйти с кодом 0 до окончания всех cases. Добавлены реальные per-case deadline/keepalive; Global отдельно проверяет отказ на dangling Promise.

Global fixture сначала ожидал невидимость трека до settlement play. После исправления P1/P2 он проверяет настоящий контракт: initial zero → visible prepared с isPlaying=false → независимо доставленный playing → Promise completion. Проверки не удалялись; released в fake остаётся terminal.

## Сборки и контрольные суммы

- [Main HAP](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/build/default/outputs/default/entry-default-unsigned.hap) — 86 515 706 bytes. SHA-256:
  3b02f0e9d0f4c3bced0584b4c4a66729ac33e639e062d5925559bcfc254fbdd5
- [ohosTest HAP](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap) — 6 613 325 bytes. SHA-256:
  6a58f49f8c9d63ea8f8e64682029f3e97e4bdc7a6e1c3592f30a8ab30ee3847d
- В ets/modules.abc main HAP найдены новые bgTaskStopToken, bgTaskLingerStop, adjacentRequestId, releaseActive, disposeResources. Bytecode SHA-256:
  8ff2b48696b5081b28e75cdfaa2ae6a2f49ee71ce2592799fa28f615cabe934d
- Controller SHA-256: 496a9ddd8252dc775f434072014e1ff5e415524dbe0f24039841d1f0b64c9e92
- Global SHA-256: 187c105a3b81dc664e8b792b4da19fc3b4176442497ef4cb8cc7aea47654c35f

Последняя сверка 08:02:52 UTC: оба HAP и все зафиксированные source hashes совпали. Эти build-пути содержат свежие пакеты; hashes предыдущего native/recorder отчёта относятся к прежним сборкам.

## Изменённые файлы и воспроизведение

Production — два файла выше. Новые проверки:
- [Controller ownership](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-media-playback-ownership.cjs) — запуск с --negative-controls.
- [Global ownership](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-global-media-ownership.cjs) — mutations по умолчанию; --baseline-head для отрицательного контроля.
- [Actual pair integration](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-media-playback-integration.cjs).

Документация: [план](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/TASKS/PLAYBACK_OWNERSHIP_2026-09-28.md), [worker report](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-global-media-ownership.md), [review](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-playback-controller-review.md), [evidence JSON](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-playback-evidence.json), [STATUS](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/STATUS.md), [TODO](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/TASKS/TODO.md), [LESSONS](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/TASKS/LESSONS.md).

HEAD остался faf66b3e066afccdbbfa36442eb9122073f509b2; staging пустой. Старые dirty changes сохранены. Commit/push/fetch/публикация не выполнялись.

## Что не закрыто

1. **Account/session isolation и page-handler ownership.** Auth/reset не связан в этом patch с глобальным playback; snapshot/completion не получили chat/account owner. Это следующий существенный reliability-gate, а не мелкая полировка.
2. AVSession create/destroy и порядок применения уже отправленных metadata/state SDK запросов; другие владельцы continuous tasks той же UIAbility не координируются локальной audio-очередью.
3. SDK calls, которые никогда не завершаются, и постоянные release/close/background-stop ошибки: гарантированного cleanup/retry budget нет. Старое скачивание не отменяется, отменяется право его результата запускать следующий side effect.
4. Real AVPlayer.seek возвращает void: deferred-seek host case доказывает continuation ownership, не seekDone timing.
5. Физический звук, Control Center, background-kill, актуальная UI/device приёмка. Свежий HDC видит 127.0.0.1:5555 и старый процесс 3020; новый HAP не устанавливался. Разрешение на обновление с риском повторного входа ещё не получено.
6. Native enqueue/async stop/open_count, unknown forward outcome, clean-checkout, полный UI/features/release roadmap.

Grounding: harmonyos_docs AVPlayer release/play/stateChange и Background Tasks Kit; локальные HarmonyOS codelabs и Telegram iOS MediaManager/SharedMediaPlayer, TDLib schema для download/search. Конкретные ссылки и ограничения источников сохранены в связанных review/worker report. Host fake не выдаётся за установленный SDK binary или device evidence.

