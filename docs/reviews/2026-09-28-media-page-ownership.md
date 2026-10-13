# Media page ownership — 2026-09-28

## Граница работы

Изменены только:
- `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`
- `scripts/test-chat-media-page-ownership.cjs`
- этот отчёт.

Рабочая копия изначально содержала изменения других workers. GlobalMediaPlayback,
AppStore, существующая lifecycle-фикстура и общие STATUS/TODO/LESSONS не редактировались.
Ни сборка, ни эмулятор, ни установка HAP, ни commit/push не запускались.

## Источники и выбранная граница

Прочитаны актуальные рабочие STATUS/TODO, DECISIONS, ARCHITECTURE,
AGENT_EXECUTION_PLAN, REFERENCES и MEDIA_ACCOUNT_OWNERSHIP_2026-09-28.
Активный срез — reliability/account/page ownership, не визуальный порт атома.

- `harmonyos_docs`: запрос `"aboutToDisappear" "NavDestination"`, EN,
  документы ArkUI **Page Lifecycle** и **Lifecycle**. Unmount/disappear и
  повторный show — разные события: уничтожение снимает регистрацию, возврат
  retained route должен восстановить её и свежий playback snapshot.
- `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/ChatController.swift`,
  строки 6800–6847: локальные disposable освобождаются отдельно от shared media manager;
  строки 7632–7637: globalMediaPlayerState находится в sharedContext.mediaManager.
  Это source-level ориентир, не свидетельство актуального iOS runtime.
- `C:/Refs/Telegram/HarmonyOSComponentUXExamples/entry/src/main/ets/components/presentation/toast/BottomToast.ets`,
  строки 32–54: lifecycle-owned reference и cleanup на aboutToDisappear.
- Фактические `ChatScreenRouteParams`, `ownsNavigationContext()` и
  `isRouteContextCurrent()` задают route/account authority; новая граница Global
  задана согласованным `MediaPlaybackPageHandle` API.

## Изменение

Страница больше не получает raw controller и не вызывает global setPageHandlers/
setNowPlaying. Единственный прямой вызов Global — createPageHandle.

Handle захватывает account/chat; page guard дополнительно захватывает lifecycle,
route object, accountStore и identity конкретной регистрации. Проверяются
routeActivated, isClosing, текущий account scope, текущий runtime account,
lease release и navigation owner token. Метаданные, taps, auto-advance и seeks
не заходят даже в handle при утраченном владении. Старый объект страницы A не
может публиковать/переключать трек B при совпадающих chat/message IDs.

Teardown сначала отзывает page guard и локальные ссылки, затем вызывает сохранённый
identity-owned unsubscribe. App-global player не останавливается. Повторный
onShown восстанавливает регистрацию retained route и текущий filtered snapshot.
Синхронный initial snapshot может повторно войти в setup/disappear: возвращённый
unsubscribe сохраняется лишь для ещё текущего handle, иначе сразу освобождается.
Reattach сохраняет локальные отметки прослушанных voice, настоящий disappear очищает их.
Перед reset запоминаются прежние active IDs: initial snapshot при возвращении
уведомляет и старую строку, даже если B сменил трек или принадлежит другому чату.

Metadata передаётся как `(title, subtitle, coverPath, coverFileId)` без chatId;
fallback title берётся из собственного route. Zero/paused cross-type snapshot
снимает оба старых playback состояния, включая repaint затронутых строк.

## Исполняемые проверки

Команда: `node scripts/test-chat-media-page-ownership.cjs` (Node >=24).

Тест извлекает целиком production-методы страницы и исполняет callbacks, а не
проверяет наличие строк. Existing lifecycle harness импортируется без правок:
реальные AppStore scopes, ChatScreenRouteParams, ChatOpenLease, activate/show/
disappear. Global handle — явно fake boundary. Старые raw методы в fake были
функциональны на RED: падения вызваны неправильным поведением, не отсутствием API.
JSON-итог содержит SHA-256 страницы, исходных/исполненных методов и sourceStable.

| Этап | Результат |
|---|---|
| RED до изменения страницы | 1 PASS / 36 FAIL, exit 1, sourceStable=true |
| Первый GREEN того же набора | 37 PASS / 0 FAIL, exit 0 |
| Расширенный набор до дополнительных lifecycle-сценариев | 42 PASS / 0 FAIL, exit 0 |
| Второй RED: reentrant setup/disappear + retained listened-state | 42 PASS / 3 FAIL, exit 1 |
| GREEN после второго RED | 45 PASS / 0 FAIL, exit 0 |
| Третий RED, найденный независимым review: old-row repaint после B | 45 PASS / 2 FAIL, exit 1 |
| Итоговый GREEN | 47 PASS / 0 FAIL, exit 0, sourceStable=true |
| `--mutant=unguarded-handle` | 21 FAIL, exit 1, 1 реально изменённый исполняемый участок |
| `--mutant=lost-unsubscribe` | 6 FAIL, exit 1, 1 участок |
| `--mutant=stale-zero-row` | 2 FAIL, exit 1, 1 участок |

RED SHA-256 страницы: `530921498a162e09cc15cd803248a47da01d5769e2fb7babb709dab94f59018c`.
Первый GREEN SHA-256: `0f36223bbb6a57f1e229db0cd8a02608a0d597dd577330bf678ed0819676993b`.
Итоговый GREEN SHA-256: `0810cf63c5276d99b23cddf5a379ce4d8c5e148a1c139a294b982673f3b45d56`.

Независимый read-only reviewer нашёл P2 old-row repaint. Оба сценария лично
воспроизведены RED и включены в итоговые 47 GREEN; reviewer повторил их после
исправления: same-chat notifications `['1', '2']`, different-chat `['1']`, 2/2 PASS.
Review не вносил изменений и не запускал builds/device.

Соседние регрессии проверены локально:
- `node scripts/test-chat-lifecycle-account-scope.cjs`: 106/106, exit 0, sourceStable=true.
- `node scripts/test-chat-draft-account-scope.cjs`: 32/32, exit 0, sourceStable=true.
- `node scripts/test-chat-jump-ownership.cjs`: 21/21, exit 0, 17 source hashes stable.
- `node --check scripts/test-chat-media-page-ownership.cjs`: exit 0.
- `git diff --check -- entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`: exit 0
  (только предупреждение Git о последующей нормализации LF → CRLF).

## Что это не доказывает

- Fake Global не доказывает корректность реального filtering, account invalidation,
  AVSession, root mini-player или auto-advance: actual Global+Controller+Store —
  отдельная проверка parent worker. Проверен page-side контракт без вызова stop.
- В прочитанном промежуточном draft Global первый publishForPage вызывал
  retireAccount, очищавший уже установленные page handlers. Риск передан parent;
  правок Global здесь нет, это не вывод о финальном состоянии parent patch.
- Финальная ArkTS compile и device/runtime/UI acceptance здесь не выполнялись
  по явному ограничению задачи. Финальная compile остаётся у parent.

## Переиспользуемое правило

Срок жизни playback шире срока жизни страницы. Страница владеет capability и
своей подпиской, но не глобальным player. Проверять отдельно: устаревшие команды,
поздние callbacks, identity cleanup и возврат retained route; одних id сообщения
или chatId недостаточно для установления владельца.

## Дополнение: actual page + Global + AppStore + controller integration

Отдельное test-only поручение после page-среза. Добавлен
`scripts/test-chat-media-account-integration.cjs`; в существующий page-тест добавлены
только exports `methodSource`, `entry`, `pageSourceHash` для повторного использования
полных извлечённых методов. Production, Global/account fixtures и AppStore в этом
поручении не редактировались. Этот раздел расширяет прежнюю границу проверки выше,
но не превращает host-сценарии в device acceptance.

### Реальная и подменённая части

Использован именно `fixture(undefined, true, false)` из
`scripts/test-global-media-ownership.cjs`: настоящий Global и настоящий
MediaPlaybackController, **без предварительного account bind**. Actual AppStore,
его scopes/invalidation, ChatScreenRouteParams, ChatOpenLease и полные методы
activate/show/disappear приходят из существующей lifecycle-фикстуры. Media-методы
страницы повторно извлекаются из текущего production-файла; SHA-256 проверяется.

Полный путь начинается с настоящего setup страницы. Первый publishNowPlayingMeta
делает первое реальное связывание аккаунта; затем handle.toggle вызывает настоящий
controller, который открывает mock FD, готовит mock AVPlayer и обрабатывает его
stateChange/timeUpdate. Результат проверяется и в page row state/notifications,
и в настоящем `mediaPlaybackUIState`, и на player/FD границе. Global wrappers —
только call-through наблюдатели, без замены аргументов/receiver/результатов.
Используются `load`/`flush` из указанной Global-фикстуры. Seed/playReal/private
metadata helpers не используются для старта треков.

Подменены **AVPlayer, file I/O, AVSession, background APIs, timers, native/TDLib
transport, adjacent-audio use case/network, ArkUI navigation/lifecycle delivery,
timeline row rendering, localization/FileUri**. Поэтому это не «только SDK mocks»
для всего приложения: структура page timeline задана fixtures, а network fallback
проверяется до границы use case. Production-механизмы владения не подменены.
`harmonyos_docs` дополнительно запрошен по `"AVPlayer" "stateChange" "released"`
(EN, Media Kit): stateChange/AVPlayerState подтверждают используемые границы состояний.

### Результат и границы доказательства

`node scripts/test-chat-media-account-integration.cjs`: **20/20 PASS**, exit 0,
sourceStable=true. Это исходный GREEN текущего parent patch, не выдуманный RED
production-кода. Последующая команда с `--negative-controls` сохранила 20/20 GREEN
и отклонила четыре точечные мутации actual Global **только в памяти**:

| Мутация | Ожидаемых behavioral FAIL |
|---|---:|
| first-bind-handler: retireAccount без сохранения нового page owner | 8/20 |
| crosschat-same-id: убрать stop при смене chat owner | 1/20 |
| unscoped-unsubscribe: убрать subscription identity check | 3/20 |
| no-account-retirement: убрать retirement из scope observer | 3/20 |

Каждая мутация меняет ровно один source site; проверены engagement, конкретный
упавший сценарий и отсутствие parser/harness ошибок вместо behavioral failure.
Это дополнительные negative-control прогоны, не ещё 80 независимых acceptance tests.

Покрыты: first bind/row progress, voice/audio seek/pause/resume/completion,
same-chat stale cleanup, different-chat same-ID zero snapshot и новый player при
совпадающем path, fallback auto-advance чужого чата, возврат route/repaint,
root playback/AVSession после disappear, три синхронных store reset/revoke пути,
retained A после B, runtime replacement без revoke, pending native play при reset,
старые system controls после account switch и reentrant initial snapshot.
В конце каждого кейса дополнительно проверяются SDK violation ledger, release
всех mock players и ровно одно закрытие каждого приобретённого mock FD.

Хеши проверенного production-среза:
- Page: `0810cf63c5276d99b23cddf5a379ce4d8c5e148a1c139a294b982673f3b45d56`.
- Global: `afcf9d659d0486b66b51190ad856bdcae96aa3c3da7b4d81786978cf33d63d15`.
- Controller: `496a9ddd8252dc775f434072014e1ff5e415524dbe0f24039841d1f0b64c9e92`.
- AppStore: `cd598b4d56b08c99697599effb8915f04ad1e43ca558c53d4729530a8b1d261c`.

Предыдущий draft-риск потери handlers при первом bind **не воспроизвёлся на этом
Global**: начальный setup→publish→toggle прошёл с живой page-подпиской; его возврат
in-memory мутацией детектируется. Это подтверждение конкретного integration-сценария,
не полное ревью AVSession queue/retry/failure. ArkTS builds, эмулятор и commits не запускались.

### Проверка самого harness после независимого review

Reviewer нашёл незавершённый cleanup вне watchdog. Дефект лично воспроизведён
in-memory подменой **SDK** release на никогда не завершающийся Promise:
`exit=0, mainFinished=false, releaseEntered=1`, без итогового JSON. Production
файлы не менялись. Исправлен только новый тест: watchdog охватывает setup/body/
cleanup, повторный cleanup тоже ограничен; beforeExit ставит exit 1 при незавершённом main.

- `node scripts/test-chat-media-account-integration.cjs --harness-stalled-cleanup`:
  **19 PASS / 1 ожидаемый HARNESS_TIMEOUT, exit 1**, полный итоговый JSON,
  `stalledReleaseCalls=1`, sourceStable=true. Это контроль harness, не дефект production.
- Отдельная in-memory подмена main на pending Promise без активных handles:
  **exit 1**, `HARNESS_ERROR: integration run did not finish`.
- После исправления: основной набор снова **20/20**, четыре production mutation
  controls снова **8/1/3/3 FAIL**, exit 0, sourceStable=true.
- Existing page-only suite после добавления exports: **47/47**, exit 0.

### Повторная проверка Global с metadata-intent generation guard

Проверен новый Global SHA-256
`80e201d1433ac95b84f9863a0adc9ef338d1dec415f8ad41cc6e9afb128f4fdb`.
External handle API не изменился. Page/Controller/AppStore остались с указанными
выше hash; production в этом test-only продолжении не редактировался.

Старые 20 integration-кейсов сразу прошли **20/20**, sourceStable=true.
Прежний negative-control anchor `retireAccount(owner.accountStore)` отсутствовал:
его проверка дала exit 1 с `0 !== 1`. Это явно **устаревший test anchor**, не
production regression. Мутация обновлена на существующую проверку сохранения
текущего page owner в retireAccount.

Добавлены три actual-page integration-кейса:
1. Initial account bind: синхронный snapshot→page repaint инициирует второй тап
   того же handle; остаются новый title/id и только новый mock FD, старый intent не стартует.
2. Cross-chat stop: та же reentry при переключении чата не заменяет новый intent
   старым toggle; старый player освобождён.
3. Ранний actual AppStore invalidation observer создаёт новый scope и actual route B
   до retirement A; поздний observer A не снимает регистрацию B, а B затем получает
   настоящий playback snapshot.

Итог: `node scripts/test-chat-media-account-integration.cjs --negative-controls`
— **23/23 PASS**, exit 0, sourceStable=true. Мутации actual Global только в памяти:
first-bind-handler **10/23 FAIL**, crosschat-same-id **1/23**, unscoped-unsubscribe
**3/23**, no-account-retirement **4/23**, stale-page-intent **2/23**.
Последняя мутация убирает intent/playbackGeneration gate из toggleForPage и
падает именно на двух новых repaint-reentry сценариях; external API не подменён.
Исходный source остаётся неизменным, каждое изменение anchor проверено на один site.
