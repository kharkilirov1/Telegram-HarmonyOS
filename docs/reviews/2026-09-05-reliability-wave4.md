# Надёжность — срез 4: live permissions и потерянные event routes

2026-09-05. Локальный dirty worktree `dev`; без commit/push/deploy и account-действий.

## Результат

Исправлены три подтверждённых разрыва runtime-пути:

1. **Unread aggregate не доходил до root badge.** `ChatNormalizer` и `chatsReducer` знали `chatListUnreadMessageCountChanged`, но combined reducer молча возвращал старый state. Добавлен маршрут. Теперь authoritative main/archive counters работают и без загруженных chat rows; ноль не подменяется старым fallback.
2. **Изменение default permissions не доходило до открытого чата.** `updateChatPermissions` отсутствовал в registry; в partial DTO/reducer не было соответствующего поля. Подключены strict parser → `ChatUpdateDto.canSendBasicMessages` → immutable reducer → существующие page subscription/policy/send getters. `false` сохраняется через соседние updates и `applyChatUpdate`; live grant восстанавливает существующий send path. Broadcast posting по-прежнему определяется статусом пользователя, не default permissions.
3. **Jump-to-message не очищал прежнее окно истории.** Аудит маршрутов дополнительно обнаружил `chatMessagesReset`: `loadAroundMessage()` отправлял событие, но combined reducer его терял. Маршрут восстановлен; тест actual jump coordinator подтверждает очистку до границы `execute()` новой загрузки, сохранение других чатов и предыдущего snapshot.

Это source/host/compile результат, **не доказательство iOS parity или публикационной готовности**. Индивидуальные group permissions, per-media capabilities, admin overrides и device acceptance остаются открытыми.

## Изменённые файлы

Production, относительно `entry/src/main/ets/`:

- `core/reducers/index.ets` — два пропущенных маршрута.
- `core/events/normalizers/ChatNormalizer.ets` — `handleChatPermissions` и регистрация.
- `core/model/dto/ChatDto.ets` — partial поле, сохранение и применение явного boolean в DTO helper.
- `core/reducers/chatsReducer.ets` — поле в known-chat и placeholder partial paths.
- `models/td/common/index.ets` — `getTopLevelBooleanStrict` / `getTopLevelObjectStrict`; старые getters не переписаны. Missing/malformed отличается от explicit false; вложенные поля и legacy cache не задают authoritative права.

Тесты:

- Новые `scripts/test-live-chat-permissions.cjs`, `test-live-permissions-review.cjs`, `test-unread-count-routing.cjs`.
- Новый `entry/src/ohosTest/ets/test/LiveChatPermissions.test.ets`, регистрация в `List.test.ets`.
- `ChatListUnreadBadge.test.ets` — постоянный combined-reducer case.
- `MessagesReducer.test.ets` — существующий reset case теперь проходит через реальный combined reducer, а не только sub-reducer.

Документы: `STATUS.md`, `TASKS/TODO.md`, `TASKS/LESSONS.md`, `TASKS/PRODUCTION_PARITY_PLAN.md`, этот отчёт и [машинное свидетельство](2026-09-05-reliability-wave4-evidence.json). Исторические wave1–wave3 не переписаны.

## Baseline → delta

| Проверка | До | После |
|---|---:|---:|
| Live permissions matrix, actual complete normalizer registry/state/page methods | 27 PASS / 11 FAIL | 38/38; затем добавлены 6 actual ohosTest bodies: **44/44** |
| Unread routing: лично выполненное in-memory удаление только aggregate route | 29 PASS / 10 FAIL | **39/39** на сохранённом route |
| Добавленные history-reset witnesses до второго router fix | 40 PASS / 2 FAIL | 42/42; затем обязательный audit всех declared routes: **43/43** |
| Независимый permissions review | — | **31/31**, лично повторно исполнен |

В permissions harness после первого исправления обнаружена ошибка самого fixture: вызов несуществующего `reset()` заменён на реальный `resetStateQueued()`. Production не менялся ради этой ошибки теста; исходный RED нормализатора падал до этого вызова.

Независимый review suite проверяет nested/malformed rejection, legacy-cache independence, immutable revoke/grant и old scope при повторном использовании chat ID. Лично исполненные in-memory mutations выявлены: убрать регистрацию — **30 FAIL**, потерять explicit false — **3 FAIL**, мутировать предыдущий chat — **2 FAIL**. Диск при mutations не менялся.

Routing audit проверяет **27 объявленных sub-reducer event types**, сейчас **0 omissions / 0 misroutes**. Это полнота известных локальных reducer cases, **не всех TDLib updates или всех функций клиента**. Unknown event остаётся no-op. Проверка не выводит ожидаемый маршрут из самого router.

## Финальная проверка

- Все **21** `scripts/test-*.cjs` завершились с exit 0. Точные индивидуальные счётчики записаны в evidence JSON; предыдущие R1–R6 suites не регрессировали.
- `docs/reviews/2026-09-05-review-witness.cjs`: **8/8**. Уточнение role fixture из wave3 сохранено; исторически неизменённым harness не объявляется.
- Все **36** `scripts/test-*.ps1` плюс `smoke-ui-phase0.ps1`: **37/37 PASS**. Впервые в этом reliability-прогоне включены и прошли три ранее исключённых host/source fixtures: split navigation, root tab geometry, root unread badge. Эти проверки не являются свежим визуальным сравнением.
- Последний последовательный forced build с `--no-incremental --no-daemon`, main затем `-p module=entry@ohosTest`: **exit 0**.
  - Main `CompileArkTS`: **26 s 277 ms**, `BUILD SUCCESSFUL in 52 s 601 ms`.
  - `OhosTestCompileArkTS`: **46 s 368 ms**, `BUILD SUCCESSFUL in 1 min 9 s 627 ms`.
- SHA256 **38** изменённых/новых production и ohosTest `.ets` совпали до/после compile и при повторном чтении evidence. Более ранний успешный main compile до history-route исправления не используется как итоговое доказательство.

Host adapters исполняют actual `.ets` bodies, но заменяют платформенный logging/presentation/transport. В jump witness `execute()` — явная граница fixture: новая history-fetch/normalization не объявлена проверенной этим case. Шесть native test bodies исполнены через host Hypium adapter и скомпилированы в test HAP; **на устройстве suite не запускался**.

## Свежая проверка среды: блокер теперь конкретный

Старую запись «мало места» не приняли за текущую истину. Перед попыткой было **53 554 110 464 bytes** свободно на C:, около 7.5 GiB свободной RAM. CLI `Emulator -list -details` подтвердил существующий остановленный **Pura API24**, HarmonyOS 6.1.1(24), 4 GiB RAM.

После завершения build запущен только этот экземпляр: `Emulator.exe -start "Pura API24" -noWindow`, launcher PID **27236**, **20:33:23**. Boot наблюдался по живому процессу и свежим логам, без перезапуска из-за timeout. `hdc tconn 127.0.0.1:5555` вернул `[Fail]Connect failed`; `hdc list targets` оставался `[Empty]`.

Авторитетное завершение guest boot в `C:/Users/Kharki/AppData/Local/Huawei/Emulator/deployed/Pura API24/Log/kernel.log`:

```text
2026-09-05 20:36:50.324 ... DoRebootPanic panic caused by reboot.panic: reboot,panic:SceneBoard exits 4times in 240000ms
2026-09-05 20:37:10.700 ... Kernel panic - not syncing: sysrq triggered crash
```

Это повторные падения системного SceneBoard и последующий guest panic. **Первопричина SceneBoard ещё не установлена; GPU/драйвер и наш Telegram-код причиной не объявляются.** Новая HAP не устанавливалась, приложение не запускалось, аккаунт не трогался. После подтверждённого panic собственный экземпляр остановлен штатным `-stop`; повторная inventory показывает оба экземпляра `isRunning=false`.

CLI screenshot вывел success/default-path сообщение, но проверенного нового файла нет: **screenshot/runtime witness не заявляется**. Signing остаётся незаполненным; системные настройки безопасности, драйверы, emulator image и пользовательские данные не менялись.

## iOS visual reference: подготовлен публичный fallback

Субагент сохранил [инвентаризацию](2026-09-05-ios-visual-reference-inventory.md) и 10 публичных JPEG в `.codex/ui-reference/ios-2026-09-05/`; затем его выполнение закончилось usage-limit ошибкой. Артефакты реально существуют: ведущий агент проверил список/размеры, лично просмотрел App Store ChatList и августовский group/composer poster, повторно открыл официальные страницы. Непросмотренные им остальные кадры не выдаются за его личный visual review.

Официальный [App Store listing](https://apps.apple.com/us/app/telegram-messenger/id686449807) и [Telegram blog от 25 августа 2026](https://telegram.org/blog/welcome-messages-buttons-TG-13) дают пригодные примеры иерархии/состояний. Но это marketing/developer demos, не version-pinned framebuffer установленной текущей iOS-сборки. Геометрические размеры в pt/vp, динамика стекла и parity по ним не доказаны. Приватные локальные переписки/изображения не включены в public reference.

## Grounding и следующий шаг

- `harmonyos_docs`: прочитано V2/@Monitor guidance; локальный `td_api.tl` подтвердил `updateChatPermissions chat_id:int53 permissions:chatPermissions`, boolean shape и unread aggregates. iOS source `ChatInterfaceStateInputPanels.swift` — group permission restriction и отдельный broadcast posting/edit path.
- CPL context завершился timeout 300 s; использован прямой source fallback. В конце продолжения context-mode инструменты отсутствовали в callable catalog; использован bounded native read/processing fallback, без переустановки.
- Независимые workers: unread routing и permissions review; их результаты проверены ведущим агентом. Все workers завершены/закрыты.
- Дальше: индивидуальные group/per-media permissions и admin exceptions; безопасная диагностика причины SceneBoard crash без удаления существующего эмулятора/сессии; затем fresh matching-state device UI и comparison по подготовленным iOS references. Полная цель надёжность → имеющийся UI → функции/UI → публикационная готовность остаётся активной.
