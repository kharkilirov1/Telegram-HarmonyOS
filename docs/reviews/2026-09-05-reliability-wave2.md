# Reliability wave 2 — R2, TDLib recovery и изоляция аккаунтов

Дата: 2026-09-05. Ветка `dev`, база `faf66b3`, изменения не закоммичены.

## Результат

**R2 исправлен на уровне source, host-проверок и ArkTS compile. Device acceptance остаётся открытым.** Исторический review-witness: **7 PASS / 1 FAIL**, открыт R6 — composer канала с правом публикации. Исправления R1/R3/R4/R5 не регрессировали в повторённых проверках.

Цель production parity не завершена: этот отчёт не подтверждает равную iOS надёжность, визуальную парность или публикационную готовность.

## Что изменено

- `infra/td/gateway/TdGateway.ets`: Closed действительно завершает текущий native client; pending requests отклоняются, stale envelopes фильтруются по верхнеуровневому `@client_id` и generation. Одна автоматическая попытка восстановления, single-flight manual retry, сохранён общий receive loop. Explicit destroy никогда не запускает recovery и закрывает также живой client в failed-состоянии.
- `app/bootstrap/AppCoreRuntime.ets`: перед recovery синхронно отзываются account capabilities и останавливаются side effects/watchers; queued reset очищает state до выдачи нового scope. Failure тоже выполняет этот barrier, а не просто показывает ошибку. Initialize/shutdown сериализованы; повторный запуск того же instance не выдаёт данные A новому клиенту.
- `core/store/AppStore.ets`: stable root для lifecycle-подписчиков; account-scoped views с generation и общей очередью. Старые views не пишут, не подписываются и не читают новый аккаунт. Pending root/scoped dispatch проверяет generation при dequeue.
- `infra/td/adapter/TdGatewayAdapter.ets`: adapter привязан к gateway identity + client generation; старые команды и поздние ответы отвергаются как non-retryable. Фабрика возвращает новый adapter для нового поколения.
- `core/model/AppEvent.ets`, `core/reducers/authReducer.ets`: безопасная общая recovery-error передаётся через auth state, без native/private деталей в UI.
- `app/bridge/AppStoreBridge.ets`: account navigation сбрасывается в AppStorage и V2 mirrors; предпочтение glassMode сохраняется.
- `ui/controllers/LoginController.ets`, `ui/pages/login/LoginRouter.ets`, `LoginRouterPage.ets`: logout-error не проглатывается; никакого выдуманного WaitPhoneNumber после logOut. Main UI/старый NavPathStack/transition timers снимаются при auth-loss; стабильная root-подписка переживает смену аккаунта; доступен явный recovery retry.
- `ui/pages/chat/ChatMediaDownloadController.ets`: request захватывает account store и adapter до уведомлений/await; late download A не получает новый store B через глобальный getter.

**Уточнение архитектурного плана:** сохраняются native gateway, lifecycle store и их постоянные подписки, но НЕ старые account adapters/views. Сохранение всех прежних domain capabilities позволило бы callback аккаунта A действовать от имени B.

## Evidence loop и независимое ревью

Три субагента разделили gateway, scoped store и login. Независимый повторный review воспроизвёл дополнительные P1: initialize поверх незавершённого shutdown; повторный запуск с данными A; позднюю bootstrap-error после Ready B; запись через scope failed-клиента. Эти случаи исправлены и закреплены тестами, а не закрыты одним успешным logout-сценарием.

- Runtime failure-scope witness: **6/7 → 7/7**, прежняя запись `userId=999` теперь отвергается.
- Gateway extended witness: reviewer/worker зафиксировал **30/44 → 44/44**; финальный **44/44** повторён основным агентом. Текущий native auth update подтверждает bootstrap своего поколения; поздние query-error/timeout больше не демотируют живой Ready/Wait* client. Closing/LoggingOut и чужой client подтверждением не считаются.
- Full chain лично повторён: client1 → настоящий Closed → сброс account state → client2 → настоящий WaitPhoneNumber → Ready/getMe пользователя B → explicit shutdown без client3. Дополнительно проверены bootstrap error до Ready (scope отозван) и после Ready/getMe (B остаётся готов).
- Первый compile обнаружил два реальных ArkTS ограничения: structural typing при передаче ошибки gateway и throw произвольного catch-value в logout. Они исправлены; последующие compile ниже действительно исполнились, не `UP-TO-DATE`.

## Проверки финального source

| Команда / witness | Результат |
|---|---|
| `node scripts/test-app-core-runtime.cjs` | 6/6 PASS |
| `node scripts/test-state-clone-file-pipeline.cjs` | 25/25 PASS |
| `node scripts/test-chat-media-download-controller.cjs` | 25/25 PASS |
| `node scripts/test-app-store-session.cjs` | 18/18 PASS |
| `node scripts/test-td-gateway-adapter-session.cjs` | 4/4 PASS |
| `node scripts/test-runtime-account-recovery.cjs` | 7/7 PASS |
| `node scripts/test-td-gateway-recovery.cjs` | 44/44 сценария PASS; вложенный прежний `TdGateway.test.ets` — 14/14 |
| `node scripts/test-login-recovery.cjs` | 33/33 PASS |
| `node scripts/test-full-account-recovery.cjs` | 3/3 совместных сценария PASS |
| `node scripts/test-runtime-lifecycle.cjs` | 5/5 PASS: overlap, reuse, initialize single-flight, shutdown during initialize, duplicate shutdown |
| `node scripts/test-recovery-supersession.cjs` | 2/2 PASS: старые failure-barrier/error publication не демотируют новый Ready/getMe после retry |
| `node docs/reviews/2026-09-05-review-witness.cjs` | 7 PASS / 1 FAIL; только R6, expected `none`, actual `mute` |
| `assembleHap --mode module -p product=default -p buildMode=debug --no-incremental --no-daemon` | PASS; CompileArkTS 40.246 s; build 61.553 s |
| `assembleHap --mode module -p product=default -p module=entry@ohosTest -p buildMode=debug --no-incremental --no-daemon` | PASS; OhosTestCompileArkTS 33.655 s; build 55.945 s |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/smoke-ui-phase0.ps1` | PASS |
| Дополнительные `scripts/test-*.ps1` | 33/33 PASS; те же три отдельные fixture scripts исключены, как в wave1 |

Исключены `test-chat-split-navigation.ps1`, `test-root-tab-bar-geometry.ps1`, `test-root-tab-unread-badge.ps1`. Их отсутствие в прогоне не превращено в PASS.

## Граница достоверности и следующий шаг

- Host harness исполняет actual `.ets` после снятия типов, но NAPI/таймеры/platform UI/network заменены fixtures. Full-chain использует actual gateway/dispatcher/runtime/adapter/auth side effect/auth normalizer/auth reducer/store; это не полный EventNormalizer, не native TDLib и не реальная ArkUI отрисовка. Navigation reset отдельно проверяет actual bridge-функцию и её AppStorage/V2 поля.
- `AppStoreSession.test.ets` зарегистрирован в `List.test.ets` и скомпилирован. Сборка ohosTest НЕ означает запуск suites на устройстве.
- Свежий `hdc list targets`: **`[Empty]`**; `build-profile.json5`: **`signingConfigs: []`**. HAP не устанавливался, пользовательский аккаунт/logout/сообщения не затрагивались.
- Следующий source-срез — **R6: status/posting rights/membership → panel selector**; затем безопасный device-прогон recovery, auth/reconnect и остальных reliability-сценариев. Не начинать косметическое расширение UI вместо этих проверок.
- Ранее созданные `2026-09-05-project-review.md` и `2026-09-05-reliability-wave1.md` остаются историческими baseline; в старом witness обновлён только gateway fixture для нового hook API, не expected results.

Rollback: весь срез остаётся локальным diff поверх `dev@faf66b3`; не делать destructive reset/clean. Отменять только согласованные файлы/фрагменты, сохраняя соседний wave1.
