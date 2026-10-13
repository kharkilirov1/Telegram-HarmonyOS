# Надёжность — первый срез, 2026-09-05

**Результат: четыре из шести дефектов baseline исправлены и воспроизводимо проверены на host. R2 и R6 остаются открытыми. До надёжности iOS и публикационной готовности ещё не доведено.**

Рабочая ветка `dev`, baseline `faf66b3`. Commit/push, публикация, установка HAP и действия с аккаунтом не выполнялись. Историческое ревью сохранено отдельно: `2026-09-05-project-review.md`.

## Production-изменения

| Дефект | Изменение | Свидетельство |
|---|---|---|
| R1: edit обгоняет newMessage | `AppCoreRuntime.ets`: normalize/enqueue до первого await; sender hydration после dispatch | В исходном witness порядок стал create→edit, итоговый текст `edited` вместо `original` |
| R1: очередь после shutdown, найдено reviewer | `AppStore.ets`: optional dequeue guard для dispatch/batch; runtime передаёт lifecycle predicate | До исправления subscriber получал запись в stopped runtime; новый тест проверяет отсутствие записи/notification, single/batch paths и живую последующую очередь |
| R3: потеря cross-chat reply при download | `filesReducer.ets`: копируется `replyToChatId` | Matching branch обновляет photoPath, сохраняет reply chat 202 вместо 0; unrelated branch и исходный объект не меняются |
| R4: сброс запрета отправки | `stateClone.ets`: копируется `canSendBasicMessages` | Restricted chat остаётся false после clone и readInbox update; default true сохранён |
| R5: поздний callback отменённого download портит retry | `ChatMediaDownloadController.ets`: per-attempt IDs, invalidation cancel/clear/resolved/failure, guards после listener notifications при старте | Поздние failure/success не меняют pending/failed/version и не создают stale FileDownloadedEvent |

Полные production-пути начинаются с `entry/src/main/ets/`: `app/bootstrap/AppCoreRuntime.ets`, `core/store/AppStore.ets`, `core/reducers/filesReducer.ets`, `core/utils/stateClone.ets`, `ui/pages/chat/ChatMediaDownloadController.ets`.

## Проверки, исполненные ведущим агентом

| Проверка | Baseline / RED | После изменений |
|---|---|---|
| Исходный `docs/reviews/2026-09-05-review-witness.cjs` | 2 PASS / 6 FAIL | **6 PASS / 2 FAIL**, exit 1 ожидаемо: R2/R6 не исправлены |
| `scripts/test-app-core-runtime.cjs` | первоначально 0/5; после расширения shutdown/guard 4/6 | **6/6 PASS**, exit 0 |
| `scripts/test-state-clone-file-pipeline.cjs` | исходный witness воспроизводил R3/R4; worker видел 22 PASS / 3 FAIL в focused suite | **25/25 PASS**, лично повторено, exit 0 |
| `scripts/test-chat-media-download-controller.cjs` | исходный witness воспроизводил R5; worker добавил матрицу RED; два дополнительных reentry-теста лично RED 23 PASS / 2 FAIL | **25/25 PASS**, лично повторено: 24 .ets случая + аварийный cleanup probe |
| `scripts/smoke-ui-phase0.ps1` | PASS | **PASS** |
| 33 `scripts/test-*.ps1` | свежий запуск шести известных failing scripts: 6 FAIL | **33/33 PASS** |
| Main `--no-incremental` | baseline compile PASS | **BUILD SUCCESSFUL**, финальный actual CompileArkTS 14.513 s, build 26.449 s |
| ohosTest `--no-incremental` | baseline compile PASS | **BUILD SUCCESSFUL**, финальный actual OhosTestCompileArkTS 11.526 s, build 24.124 s |
| `git diff --check` | — | exit **0** |
| `hdc list targets` | `[Empty]` | **`[Empty]`**, device suites не исполнялись |

Три не включённых fixture scripts: `test-chat-split-navigation.ps1`, `test-root-tab-bar-geometry.ps1`, `test-root-tab-unread-badge.ps1`. Не выдавать 33/33 за полный прогон всех проверок репозитория.

Main/ohosTest builds unsigned: `No signingConfigs profile is configured`. Сборка содержит предупреждения NAPI verification и exception/permission handling в существующих media/voice компонентах; «нулевых warnings» не заявляется.

Последние две сборки выполнены последовательно после финальных production/test изменений. Дополнительно закрыты два reentrancy-дефекта controller API с искусственным listener: cancel command должен предшествовать новому retry, а success cleanup не должен стирать failure новой попытки. Оба лично воспроизведены RED → GREEN. В существующем production listener такая reentry не найдена; это defensive API coverage, не отдельное подтверждение TDLib/network-поведения.

### Воспроизведение

```powershell
node --disable-warning=ExperimentalWarning scripts/test-app-core-runtime.cjs
node --disable-warning=ExperimentalWarning scripts/test-state-clone-file-pipeline.cjs
node --disable-warning=ExperimentalWarning scripts/test-chat-media-download-controller.cjs
node --disable-warning=ExperimentalWarning docs/reviews/2026-09-05-review-witness.cjs
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/smoke-ui-phase0.ps1

& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p product=default -p buildMode=debug --no-incremental --no-daemon
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p product=default -p module=entry@ohosTest -p buildMode=debug --no-incremental --no-daemon
```

Host harness выполняет текущий .ets source после удаления типов/import wiring. Runtime suite использует fixture normalizer, real store/reducers/hydrator и отключённые invariants; это не parser/native/ArkUI test. Clone/file harness исполняет actual .ets suites с Node assertions. Download harness исполняет actual .ets tests/controller и локальный Hypium mock implementation; network/native/account boundaries подменены. Device runtime не подменяется этими результатами.

Новые/изменённые tests: `StateClone.test.ets`, `FilePipeline.test.ets`, `ChatMediaDownloadController.test.ets`, registry `List.test.ets`.

## Source-contract синхронизация — без изменения визуального production-кода

- ChatList/Forward/Profile/composer: прежнее требование `backgroundBlurStyle` заменено на действующий `backdropBlur` + policy gate + отключение blur в fallback (рецепт LESSON 121).
- Composer test также требовал старую viewport-обрезку padding. Действующий контракт от 08-29 — under-glass timeline с `contentEndOffset`, без обрезки, с сохранением focus/bottom alignment.
- Album: source и существующая policy suite с коммита `f6478db` используют immediate `downloadAndOpen`, тогда как старый textual test и паспорт требовали ожидания local file. Test/паспорт синхронизированы; прежняя галочка iOS parity снята, новый side-by-side обязателен.
- Scroll FAB делегирует форматирование `TgCompactCount`; проверяется делегирование и сохранение thousand/million thresholds, не нахождение токена в самом atom.

Зелёные source-contract scripts не доказывают улучшения визуального качества. Ни одного нового UI fidelity/runtime заявления в этом срезе нет.

## Независимая проверка и следующий срез

Два непересекающихся implementer-а работали над R3/R4 и R5. Ведущий агент повторил их tests и просмотрел diff. Независимый reviewer нашёл shutdown-регрессию R1; она воспроизведена ведущим, добавлена в RED и исправлена dequeue guard; повторное review блокеров в этом diff не нашло. Отдельный read-only critic подготовил R2 boundary/account-isolation анализ.

- **R2 P1:** безопасный relogin требует не только нового native client, но и account-state barrier, stale-response/retry filtering и login/main UI lifecycle. План: `TASKS/TDLIB_RECOVERY_PLAN.md`; automatic recovery пока не включён.
- **R6 P2:** полноценные current-member/posting rights, не list order или default chat permissions.
- **Device:** подтверждены config.ini HVD `Pura API24` и `Pura X Vie`; они не запускались. На последней проверке C: 52.18 GiB свободно, `hdc` пуст. Не устанавливать один ohosTest HAP поверх пользовательской сессии.
- **Визуальные референсы:** три iPhone captures, перечисленные в `docs/ai/UI_RUNTIME_BASELINE_2026-07-10.md`, отсутствуют по документированным путям. Наличие других локальных captures не исключено. Для UI-фазы нужен актуальный официальный Telegram/App Store baseline; Harmony `.codex/ui-audit` не считать iOS.
- Полный маршрут: `TASKS/PRODUCTION_PARITY_PLAN.md`; старая MVP-цель явно выведена из исполнения.
