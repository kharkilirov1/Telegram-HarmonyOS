# Production parity — исполняемый маршрут

Мандат: пользователь, 2026-09-05. Статус: **в работе; публикационная готовность не доказана**.

Этот файл задаёт **критерии «готово» по фазам и границы доказательств**. Порядок фаз и текущую
очередь см. в `TASKS/AGENT_EXECUTION_PLAN.md` и `TASKS/TODO.md`; журнал надёжностных волн внутри §1 —
история, а не очередь (`last updated: 2026-10-24`).

## Конечный результат

Telegram-HarmonyOS должен быть сопоставим с оригинальным iOS-клиентом по надёжности, качеству имеющегося UI и функциональной полноте. Нативные HarmonyOS элементы использовать там, где они улучшают платформенную корректность и взаимодействие, сохраняя семантику Telegram. «Лучше iOS» — только по воспроизводимому сравнению, не по впечатлению или числу зелёных тестов.

Продолжать последовательно, не считать отдельную исправленную регрессию, зелёную сборку или MVP окончанием задачи. Публикация, signing credentials, действия с аккаунтом, отправка сообщений и commit/push требуют отдельного разрешения. Локальная работа и проверки идут без повторных согласований.

## Рабочий цикл каждого среза

1. Реальный baseline: код, контракты TDLib, ближайшие тесты; для UI — iOS screenshot/video с происхождением и датой плюс исходники `Telegram-iOS-current`.
2. Узкий failing case и границы изменений; независимый worker/reviewer для непересекающихся задач.
3. Минимальный обратимый patch, без переделки `TDLib → dispatcher → normalizer → AppStore → UI`.
4. Тот же witness до/после; затем focused suites, main/ohosTest compile, UI-smoke. Compile не означает исполнение suites.
5. Свежая проверка на устройстве/эмуляторе: процесс новой сборки, логи, сценарий, screenshot/video. Не переустанавливать один ohosTest HAP поверх пользовательской сессии.
6. Короткое обновление STATUS/TODO/LESSONS: доказательства, открытый риск, следующий срез. Исторические отчёты не переписывать как будто дефектов не было.

## 1. Надёжность — активная фаза

Baseline: `dev@faf66b3`, `docs/reviews/2026-09-05-project-review.md`. Шесть воспроизведённых дефектов, два P1. Оригинальный source-harness — `docs/reviews/2026-09-05-review-witness.cjs`.

- R1: порядок create/edit при cached/missing sender, pending/rejected hydration, shutdown. Файлы: `app/bootstrap/AppCoreRuntime.ets`, `scripts/test-app-core-runtime.cjs`.
- R2: терминальный `authorizationStateClosed`, новый native client, подписки, pending requests, account-state isolation, explicit shutdown без самоперезапуска. Source/host/compile реализованы: `docs/reviews/2026-09-05-reliability-wave2.md`; device acceptance открыт в `TASKS/TDLIB_RECOVERY_PLAN.md`.
- R3/R4: сохранение `replyToChatId` и `canSendBasicMessages` в clone/reducer paths; focused FilePipeline/StateClone tests.
- R5: cancel/retry/late success/failure, lifecycle invalidation в `ChatMediaDownloadController`; focused tests.
- R6: выбор channel panel по реальным `supergroup.status`/posting rights/membership, не по положению в списке и не по default permissions; DTO → reducer → selector → UI + state matrix. Source/host/compile реализованы, включая edit-only send guards и operation-owned cleanup: `docs/reviews/2026-09-05-reliability-wave3.md`. Device acceptance открыт: `TASKS/CHAT_ACCESS_PLAN.md`.
- Wave4: live default permissions и missing unread/history-reset routes исправлены, full host/source regression и forced main/ohosTest compile PASS (`docs/reviews/2026-09-05-reliability-wave4.md`). Следующий reliability-срез — individual group/per-media permissions/admin exceptions. Boot Pura API24 дал системный SceneBoard crash → kernel panic; причина и device acceptance открыты. Исправленные cases не доказывают надёжность всего клиента.
- Синхронизировать шесть устаревших source-contract scripts с действующим UI-контрактом, не возвращая ошибочную реализацию ради зелёного grep.
- Затем проверить существующие auth/reconnect, pagination/search cursors, drafts/reply/forward, media/open/retry, shutdown/resume, multi-chat и ограниченные права. Расширять tests по реально найденным дефектам.
- Wave5: strict group payload и transport 9 individual send bits/deep clone, 115/115 host и forced main/ohosTest build PASS (`docs/reviews/2026-09-05-reliability-wave5.md`). Effective group/media policy остаётся следующим: учесть admin/creator и booster path TDLib, не объявлять transport готовыми UI/guards. Повторный headless guest дал SceneBoard panic; обычный launcher отдельно остановился на commit-charge preflight. Device acceptance открыт, образы/аккаунты не сбрасывались.
- Wave6: forward dispatch revalidation и общий page-owned send token; account/draft/attachment restore guards. 51/51 focused, mutation failures 17/26/12/6; 23 CJS / 37 PS+smoke, forced main/ohosTest build PASS, 41 hashes стабильны (`docs/reviews/2026-09-05-reliability-wave6.md`). По просьбе пользователя запущены existing API24/API26 и новый isolated API24: все дошли до SceneBoard panic; новый до установки проекта дал временный shell/чёрный screenshot. Свои процессы остановлены, HDC Offline, native/device gate открыт. Следующий source-срез group/media сохраняется; системный root cause требует отдельного focused capture, не blind reboot.

- Wave7 (09-06): найденный при продолжении аудита forward ID/result contract исправлен до перехода к group/media. Preflight до comment, positional null handling, partial-only retry; 65/65 + ownership 53/53, 24 CJS / 37 PS+smoke, main/ohosTest build PASS, 44 hashes стабильны (`docs/reviews/2026-09-06-reliability-wave7.md`). Eligibility UI, ambiguous transport/delivery failures и effective group/media policy ещё открыты; HDC Offline, новых boots/install не было.

- Wave9 (09-06): Basic-group defaults: 9 bits end-to-end, per-kind send/voice/forward/picker guards, media-only composer и bounded getChat hydration. Explicit @Local UI snapshot + scalar @Param flags. 52/52 (6 native bodies через host adapter), 26 CJS / 37 PS+smoke / review 8/8; final main/ohosTest compile PASS, 48 hashes стабильны. HDC [Empty], device/visual acceptance открыта. Отчёт: `docs/reviews/2026-09-06-reliability-wave9.md`. Далее: ordinary megagroup/booster policy, conservative unknown forward source, migration/Delete CTA и native/device acceptance.

- Wave11 (09-06): ordinary supergroup per-kind/booster snapshot, FullInfo/live/account fencing и UI subscription/dispatch реализованы. Ревью обнаружило partial-load retry gap; исправлен native Retry без отключения composer/draft. 32/32, 9 native bodies через host, 27 CJS / 38 PS+smoke / review 8/8; final main/ohosTest compile PASS, 50 hashes стабильны (`docs/reviews/2026-09-06-reliability-wave11.md`). Следующее — source-forward eligibility, edit/expiry/thread exceptions. Device/visual/publication gates открыты; новых boots/install после Wave10 нет.

- Wave12 (09-06): source forward eligibility до comment и повторно до dispatch, strict copy/local/secret flags, cancellation callbacks; supergroup forward больше не обходит per-kind guard. 75/75, 25 native bodies через host, 28 CJS / 38 PS+smoke / review 8/8; final main/ohosTest compile PASS, 51 hashes стабильны (`docs/reviews/2026-09-06-reliability-wave12.md`). Properties не гарантируют input-media/server acceptance; comment+forward не атомарны.

- Wave13 (09-06): lifecycle-bound source menu states + pre-picker batch route checks, readonly-source capability, stable action/context IDs, route filtering, dismiss/intent/duplicate-result fencing. 62/62, 12 native bodies через host, 29 CJS / 38 PS+smoke / review 8/8; final main/ohosTest compile, 54 ArkTS + 3 resource hashes стабильны (`docs/reviews/2026-09-06-reliability-wave13.md`). Disabled Forward — осознанная Harmony adaptation, не визуальное совпадение iOS.
- Wave14 (09-06): Delete больше не выполняет немедленный revoke=true без confirmation. Native Cancel/self/everyone по strict flags, fresh exact-mode recheck, strict Ok/no replay и async intent fencing; найденный reviewer прямой channel-share race воспроизведён и исправлен. 101/101 (20 native bodies через host), 30 CJS / 38 PS+smoke / review 8/8, final обе compile и 60 stable hashes (`docs/reviews/2026-09-06-reliability-wave14.md`). Undo/special iOS flows и native dialog/device acceptance остаются открытыми.
- Wave15 (09-06): strict edit source/properties/result, text/caption и empty-caption UI-chain; retention до подтверждения, новые ввод/operation защищены. Scheduled canonical IDs, received entities/preview serialization; исправлен межаккаунтный persistDraft. 174/174 (46 native bodies через host), UI-chain 53/53, draft 32/32; 32 CJS / 38 PS+smoke / review 8/8, final обе compile и 65 stable hashes (`docs/reviews/2026-09-06-reliability-wave15.md`). Далее closeChat/draft-restore ownership, edit menu/entry и previous-compose restore, full rich text/dynamic limits, expiry/thread/special-delete/metadata. Single-splice fallback не rich-text parity; native-cache properties не server guarantee. HDC [Empty], новых boots/install нет; native/device/visual/publication gates открыты.
- Wave17 (09-06, текущий): captured route provenance, unique navigation token, logical lease вместо трёх caller-open, forward handoff owner и early-read snapshot. Lifecycle86/86, callers69/69, lease78/78; 36CJS/38PS/review8, final serial main/ohosTest compile и72 stable hashes (`docs/reviews/2026-09-06-reliability-wave17.md`). Следующий узкий срез — `TASKS/CHAT_ROUTE_OWNERSHIP_PLAN.md`: late-first-chat после Ok (отдельный host probe FAIL), затем session/native-count coordination. Shared media/jump/search isolation и device/visual/publication gates открыты. Граница надёжности iOS не достигнута.

Выход: нет открытых P1/P2 в проверяемых сценариях; все связанные регрессионные проверки исполняются; длительный сценарий использования не даёт crash/freeze/потери сообщений/межаккаунтных данных. Длительность, устройство, версия SDK/сборка, счётчики и ограничения фиксируются. Без сравнительного iOS-прогона нельзя заявлять равную или лучшую надёжность.

## 2. Качество имеющегося UI

Сначала инвентаризация локальных iOS-визуальных референсов; не путать Harmony runtime capture с iOS. Если актуального witness нет — получить из официальных онлайн-источников Telegram/App Store, зафиксировать URL/дату/ограничения.

Public fallback подготовлен: `docs/reviews/2026-09-05-ios-visual-reference-inventory.md`, 10 JPEG в `.codex/ui-reference/ios-2026-09-05/`. Это official marketing/developer demos с provenance, не version-pinned raw current iOS capture. Fresh matching-state Harmony runtime для сравнения ещё нужен.

Порядок: shell/chat list → chat timeline/top bar/composer/action panels → media/gallery/input keyboards → profile/search/settings → login. Для каждого atom: iOS source → паспорт inputs/state/layout/tokens → demo 6–10 состояний → узкая интеграция → fresh side-by-side.

Гейты: light/dark, длинные строки, unread/status alignment, safe areas/keyboard, touch targets, accessibility/font scaling, navigation transitions, phone/tablet/2in1, scroll/frame/memory budget. Нативные меню/pickers/keyboard/navigation согласуются с платформенными docs, не имитируются без необходимости. Legacy fallback сохранять до приёмки.

## 3. Функциональная полнота и UI новых функций

После стабилизации текущих сценариев составить проверяемую матрицу возможностей iOS ↔ Harmony: доступно / частично / отсутствует / ограничено платформой, со ссылкой на код и runtime witness. Она должна охватывать сообщения и медиа, поиск, папки/архив, профили, группы/каналы/права, настройки/приватность, уведомления/background, звонки, stories и иные пользовательские возможности актуального референса; наличие названия/кнопки не означает рабочую функцию.

Реализовывать по одной законченной вертикали: TDLib contract/use case → state/events → tests → UI states → device scenario. Сначала недостающие обязательные действия в существующем UI, затем оставшиеся функции. Платформенные ограничения документировать, не скрывать за неработающими кнопками.

## 4. Публикационная готовность

Release checklist с фактами: supported devices/SDK, signing и release build, native ABI, installation/update/data migration, cold/warm start, offline/reconnect, notifications/background, accessibility/localization, privacy/permissions/storage/logging, лицензии/атрибуция/брендинг, security review, store metadata/screenshots, восстановление после ошибок и регрессионный прогон.

Измерения сравнивать с iOS на одинаковых сценариях/данных и явно оговаривать разницу аппаратуры. Внешнюю публикацию и связанные с аккаунтами необратимые действия не выполнять без разрешения. Вся работа считается завершённой только когда полный согласованный результат подтверждён, а не когда закончился текущий turn.
