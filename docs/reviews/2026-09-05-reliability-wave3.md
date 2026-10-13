# Надёжность — срез 3: channel access и безопасное завершение отправки

Дата: 2026-09-05. Ветка `dev`, изменения локальные, без commit/push/deploy.

## Результат

**R6 исправлен в source и проверен host-тестами/компиляцией.** Все шесть находок исходного ревью теперь имеют source-исправления; review-witness — **8 PASS / 0 FAIL**. Это не доказательство полной надёжности клиента, iOS parity или готовности к публикации. Полная задача продолжается по `TASKS/PRODUCTION_PARITY_PLAN.md`.

Панель broadcast-канала использует реальный статус текущего пользователя, а не позицию в main/archive или default permissions:

- Creator-member и admin с posting rights получают composer.
- Участник без posting rights получает Mute/Unmute; left — Join.
- Banned и unknown не получают права отправки. Unknown загружается одним запросом; после ошибки валидного ID доступен явный Retry. Некорректный ID не создаёт бесконечную загрузку или бесполезную кнопку.
- Admin с правом редактирования, но без posting rights может выполнить разрешённый text edit. Это не открывает новые text/sticker/GIF/voice/media sends; пустой edit не превращает кнопку в микрофон.
- Потеря права отправки или переход в edit во время pending send не оставляет `isSending` навсегда. Завершение принадлежит operation/lifecycle/chat; старый callback не очищает новую отправку и не продолжает старый media batch.

## Что изменено

Пути production ниже относительно `entry/src/main/ets/`:

| Слой | Файлы и назначение |
|---|---|
| Access state | Новый `core/model/dto/GroupAccessDto.ets`; `core/model/AppState.ets`, `AppEvent.ets`, `core/utils/stateClone.ets`: typed role/membership/rights, maps по group ID, immutable ingress, сохранение identity на несвязанных обновлениях, очистка при reset |
| Live path | `core/events/normalizers/ChatNormalizer.ets`, `core/reducers/chatsReducer.ets`, `core/reducers/index.ets`: direct/group updates проходят весь normalizer → combined reducer путь, в том числе до newChat |
| Hydration | Новый `domain/usecases/loadChatAccess.ets`; `core/model/AppCommand.ets`, `infra/td/serialization/CommandSerializer.ets`: exact getSupergroup/getBasicGroup, scoped dependencies, single-flight, stale-live guard при dequeue; в `joinChat.ets` уточнён комментарий, успешный запрос не выдумывает membership |
| TDLib parsing | `models/td/common/index.ets`: новый `getTopLevelNumberStrict`; старые accessor-методы не переписаны. Group ID должен быть literal top-level number и positive safe integer |
| UI policy | Новые `ui/pages/chat/ChatInputPanelPolicy.ets`, `ChatAccessController.ets`; `TgChatScreenPage.ets`: active-group subscription, scoped state, loading/retry/error, immediate edit transition, fresh permission guards |
| Send lifecycle | `ui/pages/chat/ChatComposerController.ets`: operation-owned cleanup, безопасное восстановление failed draft, остановка устаревшего media batch до/после await |
| Composer atom | `ui/tg_ui/atoms/TgComposerInput.ets`: empty edit без voice tap/hold; новых layout/tokens API не добавлено |
| UI contract | `ui/tg_ui/demos/TgChatBottomActionBarDemo.ets`, `spec/TgChatBottomActionBar.md`, `spec/TgIosNativeLiquidComposer.md`; `entry/src/main/resources/{base,ru_RU,zh_CN}/element/string.json`: loading/retry/banned cases и локализованное unavailable |

Новые host harness: `scripts/test-group-access-state.cjs`, `test-load-chat-access.cjs`, `test-chat-access-controller.cjs`, `test-chat-input-panel.cjs`, `test-channel-access-integration.cjs`, `test-edit-only-send-guard.cjs`, `test-send-cleanup-ownership.cjs`.

Обновлены `STATUS.md`, `TASKS/TODO.md`, `TASKS/LESSONS.md` (урок 127), `TASKS/CHAT_ACCESS_PLAN.md`, `TASKS/PRODUCTION_PARITY_PLAN.md`. Исторические markdown-отчёты wave1/wave2 и исходное ревью не переписаны.

## Доказательства изменения поведения

1. Matrix старой page: **19 PASS / 55 FAIL**, actual selector не вызывался. После подключения новой policy и расширения cases: **79/79**, зафиксировано 78 actual selector calls; остальные проверки включают subscription gate, а не вызов selector. Проверяется state/поведение, не наличие строки в source.
2. Проверка combined reducer обнаружила пропущенный маршрут `groupAccessUpdated`: **98 PASS / 1 FAIL → 99/99** после исправления. Расширенная итоговая suite — **124/124**.
3. Hydration suite обнаружила принятие вложенного/дробного ID старым numeric accessor: **55 PASS / 4 FAIL → 59/59** со strict top-level accessor. Старый regex fallback мог вернуть правдоподобное неверное число.
4. Независимое review проверило edit-only обходы через sticker/GIF/voice и затем permission-gated cleanup. Итог: **51/51 send-guard checks**, **52/52 ownership checks**. Дополнительный лично исполненный mutation witness вернул **только два finally guard** к permission-based проверкам в памяти: **24 PASS / 28 FAIL**, exit 1. Файлы при mutation не менялись. Обычный source-run — **52 PASS / 0 FAIL**. Это подтверждает, что suite различает новый ownership path и прежнюю ошибку.
5. Сквозной harness — **4/4**: actual normalizer/AppEvent/combined reducer/scoped store/use case/controller/page gate/policy; live status сильнее поздней hydration, status до newChat, error→retry, reset не допускает возврата старого access.

### Уточнение исходного review fixture

`docs/reviews/2026-09-05-review-witness.cjs` теперь передаёт настоящий `GroupAccessDto` creator-member с group ID и `canSendBasicMessages=false`. Старый fixture не имел role model и не мог доказать именно posting rights. Expected composer (`none`) **не ослаблен**; дополнительно проверяется отсутствие restricted. Текущие **8/8** нельзя выдавать за прогон байт-в-байт неизменённого исторического harness.

## Проверки после production-правок

### Host suites

| Команда `node scripts/<file>` | Результат |
|---|---:|
| `test-group-access-state.cjs --combined` | 124/124 |
| `test-load-chat-access.cjs` | 59/59 |
| `test-chat-access-controller.cjs` | 32/32 |
| `test-chat-input-panel.cjs` | 79/79 |
| `test-channel-access-integration.cjs` | 4/4 |
| `test-edit-only-send-guard.cjs` | 51/51 |
| `test-send-cleanup-ownership.cjs` | 52/52 |
| `test-app-core-runtime.cjs` | 6/6 |
| `test-state-clone-file-pipeline.cjs` | 25/25 |
| `test-chat-media-download-controller.cjs` | 25/25 |
| `test-app-store-session.cjs` | 18/18 |
| `test-td-gateway-adapter-session.cjs` | 4/4 |
| `test-runtime-account-recovery.cjs` | 7/7 |
| `test-td-gateway-recovery.cjs` | 44/44; вложенный existing TdGateway suite 14/14, не прибавлять повторно |
| `test-login-recovery.cjs` | 33/33 |
| `test-full-account-recovery.cjs` | 3/3 |
| `test-runtime-lifecycle.cjs` | 5/5 |
| `test-recovery-supersession.cjs` | 2/2 |

Общий запуск 18 scripts прошёл; cleanup suite в нём имела 44 cases и затем была расширена агентом. Её окончательный 52-case файл отдельно повторно исполнен ведущим агентом, exit 0; production при этом не менялся.

`node docs/reviews/2026-09-05-review-witness.cjs` — **8/8**. PowerShell `smoke-ui-phase0.ps1` + 33 source-contract scripts — **34/34 PASS**. Отдельные `test-chat-split-navigation.ps1`, `test-root-tab-bar-geometry.ps1`, `test-root-tab-unread-badge.ps1` в этот прогон не включены и прошедшими не объявляются. Source-contract checks не измеряют визуальную точность.

Финальная гигиена: `node --check` — **19/19** (18 scripts + review harness); JSON ресурсов и evidence разобраны; `git diff --check` — exit 0, только предупреждения LF/CRLF. Production SHA256 повторно сверены после обновления отчётов: 29/29 совпадают.

### Forced compile

Последний последовательный запуск `hvigorw.bat assembleHap --mode module -p product=default -p buildMode=debug --no-incremental --no-daemon`, затем тот же запуск с `-p module=entry@ohosTest`:

- `:entry:default@CompileArkTS` — **32 s 767 ms**; main **BUILD SUCCESSFUL in 55 s 675 ms**.
- `:entry:ohosTest@OhosTestCompileArkTS` — **14 s 581 ms**; test HAP **BUILD SUCCESSFUL in 32 s 445 ms**.
- Общий процесс завершился с **exit 0**. Это реально выполненный forced compile, не UP-TO-DATE свидетельство.
- SHA256 всех 29 изменённых/новых production `.ets` сверены до и после compile: **изменений нет**. Снимок включает предыдущие reliability-срезы: [машинное свидетельство](2026-09-05-reliability-wave3-evidence.json).

## Grounding, границы и остаточный риск

- Работали три независимых субагента: access state, hydration, controller/review. Их существенные выводы проверены ведущим агентом по actual source и повторным запуском harness; агенты закрыты после результата.
- Прочитан локальный TDLib `tdlib/td/generate/scheme/td_api.tl`: group statuses, administrator rights, getGroup/updateGroup. iOS behavior reference: `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/ChatInterfaceStateInputPanels.swift:234–255,351–365`. Это source behavior, не свежий визуальный эталон.
- `harmonyos_docs` запрос `Monitor decorator` вернул V2/@Monitor guidance; исходный более широкий запрос результата не дал. CPL retrieval завершился с confidence 0.83, но точные решения проверены чтением файлов, не предположением по найденным docs.
- Host tests используют actual `.ets` source, однако platform/NAPI/network/file I/O/recording и presentation effects подменены fixtures. ArkUI rendering и actual TDLib service ими не проверены. Test HAP **скомпилирован, не исполнен на устройстве**.
- В этой сессии `hdc list targets` → **`[Empty]`**, `build-profile.json5` → **`signingConfigs: []`**. Установка, вход/выход, отправка сообщений, смена прав, destructive действия с каналами не выполнялись.
- Banned сейчас показывает безопасное unavailable; iOS Delete and Exit parity не реализована. Индивидуальные group permissions, group join/threads/forums и прочие access panels не закрыты этим broadcast slice. Старые numeric accessors вне нового строгого path не считаются автоматически исправленными.
- Нет свежего device процесса, screenshot/video или визуального сравнения этого изменения. Старые runtime-снимки не принимают новый slice. Native compatibility/performance и публикационная готовность остаются открытыми.

## Следующий срез

Сначала executable-аудит полноты combined reducer routing (`chatListUnreadMessageCountChanged`) и live `updateChatPermissions`; это пока кандидаты из чтения source, а не подтверждённые новые дефекты. Затем оставшиеся group-access сценарии и безопасный device regression по R2/R6. После reliability gate — существующий UI по свежему shipped iOS visual reference, функциональные вертикали и release checklist. Цель не сокращена до закрытия R6.
