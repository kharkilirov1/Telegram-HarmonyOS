# Ревью Telegram-HarmonyOS — 2026-09-05

**Итог: 6 воспроизведённых дефектов runtime-логики, из них 2 приоритета P1. Свежие сборки приложения и ohosTest проходят, но этого недостаточно для production quality.**

База: `dev@faf66b3`, исходно чистое рабочее дерево. Production-код не исправлялся. Проверки выполнены в этой сессии, а не перенесены из старых отчётов. Ревью выборочное по критическим путям, не построчная проверка всего TDLib и всех экранов.

## Основные находки

### R1 · P1 — Асинхронная гидратация меняет порядок TDLib updates и теряет редактирование

**Место:** [AppCoreRuntime.ets:174–194](../../entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets#L174-L194), дополнительный `await` — строки 202–219.

Подписчик запускает `handleUpdate()` без последовательной очереди. Перед нормализацией нового сообщения выполняется гидратация отправителя. У следующего `updateMessageContent` дополнительного ожидания нет. Даже уже закешированный отправитель не спасает: вложенный `await` в строке 219 меняет порядок продолжений.

**Воспроизведение на текущих исходниках:** синхронно доставить `updateNewMessage(original)` и затем `updateMessageContent(edited)`. Реальные `AppCoreRuntime`, `LoadChatHistoryUseCase`, `AppStore` и `messagesReducer` дали:

```text
expected order: updateNewMessage -> updateMessageContent; text=edited
actual order:   updateMessageContent -> updateNewMessage; text=original
```

Причина потери: [messagesReducer.ets:426–439](../../entry/src/main/ets/core/reducers/messagesReducer.ets#L426-L439) пропускает изменение, если сообщение ещё не существует. Последующий `newMessage` сохраняет первоначальный текст. Это нарушает явное требование порядка в [td_json_client.h:29–31](../../tdlib/td/telegram/td_json_client.h#L29-L31).

**Что исправлять:** сериализовать входной pipeline либо применять updates в исходном порядке, а гидратацию делать отдельно без задержки доставки. Добавить regression через `AppCoreRuntime`, а не только последовательный вызов normalizer/reducer из теста. Ближайшая suite: `EventPipeline.test.ets`.

### R2 · P1 — После успешного logOut повторная авторизация использует закрытый TDLib client

**Место:** [TdGateway.ets:458–475](../../entry/src/main/ets/infra/td/gateway/TdGateway.ets#L458-L475), guard `initialize()` — строки 138–141.

`authorizationStateClosed` просто транслируется подписчикам. Gateway сохраняет `state=ready` и прежний `clientId`, поэтому повторный `initialize()` ничего не делает. [AuthSideEffect.ets:142–148](../../entry/src/main/ets/core/sideeffects/AuthSideEffect.ets#L142-L148) сбрасывает флаги, но не создаёт новый клиент.

**Достижимый путь:** возврат с экрана кода на ввод телефона вызывает `LoginController.logout()` через `LoginRouter.forceBackToPhone()`; комментарии ошибочно обещают `waitPhoneNumber` после logout. Локальный [td_api.tl:188–190](../../tdlib/td/generate/scheme/td_api.tl#L188-L190) требует новый экземпляр после `Closed`; [logOut:10166–10167](../../tdlib/td/generate/scheme/td_api.tl#L10166-L10167) закрывает текущий экземпляр.

**Witness:** fixture `Closed` прошла через реальные gateway/dispatcher; после повторного initialize: `state=ready`, `createdClients=1`, ожидалось `2`. Это проверка реакции на terminal state, не выполнение реального logout. Ответ `500` от сервера в этой сессии не запрашивался.

**Что исправлять:** явный lifecycle закрытия/пересоздания клиента и согласованное переподключение pipeline, pending requests и side effects. Добавить тест `Closed -> initialize -> новый clientId` в `TdGateway.test.ets` и сценарий возврата из auth-code screen. Не подменять lifecycle локальным переключением UI.

### R3 · P2 — Завершение загрузки стирает chatId цитируемого сообщения

**Место:** [filesReducer.ets:165–185](../../entry/src/main/ets/core/reducers/filesReducer.ets#L165-L185).

`cloneMessageWithContent()` переносит `replyToMessageId`, но пропускает `replyToChatId`. Новый `Message` получает значение `0` из конструктора. В результате скачивание фотографии или другого медиа в сообщении с cross-chat reply меняет адрес цитаты, хотя событие относится только к файлу.

**Witness:** matching `fileDownloaded` установил `photoPath`, но превратил `replyToChatId: 202 -> 0`. Отрицательный контроль с чужим `fileId` сохранил `202`. В [ChatTimelineVO.ets:495–525](../../entry/src/main/ets/ui/pages/chat/ChatTimelineVO.ets#L495-L525) нулевой chatId направляет lookup в текущий чат: сниппет/автор/thumbnail теряются либо относятся к другому сообщению с совпавшим id.

**Что исправлять:** сохранять `replyToChatId` и проверять все семантические поля `Message` при частичных file updates. Ближайшие suites: `FilePipeline.test.ets`, `ChatTimelineVO.test.ets`.

### R4 · P2 — Обычный cloneChat снимает локальное ограничение отправки

**Место:** [stateClone.ets:130–166](../../entry/src/main/ets/core/utils/stateClone.ets#L130-L166).

Ручное копирование не включает новый `canSendBasicMessages`; конструктор `Chat` возвращает `true`. Вызовы, не связанные с правами, например [chatReadInbox:332–340](../../entry/src/main/ets/core/reducers/chatsReducer.ets#L332-L340), превращают restricted-группу в разрешённую для composer. `deriveChatBottomBar()` использует именно это поле.

**Witness:** `cloneChat({canSendBasicMessages:false})` вернул `true`; контроль сохранения `id/title` прошёл. Это UI/state-дефект, не обход серверных прав Telegram: сервер всё ещё может отклонить отправку.

**Что исправлять:** дополнить clone и regression `chatReadInbox`/`chatUpdated`/avatar update для запрещённой отправки. Тест «all Chat fields» в `StateClone.test.ets` должен проверять и новые поля.

### R5 · P2 — Ошибка отменённого download ломает новую попытку того же файла

**Место:** [ChatMediaDownloadController.ets:59–65](../../entry/src/main/ets/ui/pages/chat/ChatMediaDownloadController.ets#L59-L65), строки 91–97 и 101–124.

Ответ привязан только к `fileId` в Set. После отмены и повторного запроса этот id снова присутствует, поэтому поздний reject старого Promise помечает новую попытку как failed и удаляет её из pending. Дополнительно `token !== lifecycleToken` сравнивает две неизменяемые копии одного аргумента, а не текущий lifecycle страницы.

**Witness:** `request(77) -> cancel(77) -> request(77) -> reject первого request` дал `{pending:false, failed:true}` вместо `{pending:true, failed:false}`. Реальный controller исполнен; gateway заменён управляемыми Promise, ни один download не отправлен в Telegram.

**Что исправлять:** идентификатор/поколение каждой попытки, инвалидируемый на cancel/clear, и проверка актуальности в обоих completion handlers. Для lifecycle — getter либо состояние самого controller, не сравнение захваченного аргумента с ним же.

### R6 · P2 — Автор канала не получает composer; членство подменено позицией в списке

**Место:** [TgChatScreenPage.ets:1815–1825](../../entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets#L1815-L1825).

Любой `chat.type === 'channel'` безусловно получает Join/Mute/Unmute, после чего dispatcher возвращается. Владельцы и администраторы с правом публикации не выделены; модель `Chat` не несёт актуальный статус текущего участника. Это касается и собственного канала, созданного через Compose.

**Witness pure dispatcher:** канал с ненулевой позицией и разрешённой отправкой получил `mute`, не `none` (composer). Это не визуальный прогон владельцем реального канала; доказано безусловное ветвление текущего кода. В iOS-reference `ChatInterfaceStateInputPanels.swift:351–366` Subscriber-панель выбирается с проверкой `hasPermission(.sendSomething)` и `isMember`.

Связанный source-level edge case: `order/archiveOrder` в строке 1819 не доказывают подписку. [td_api.tl:3159](../../tdlib/td/generate/scheme/td_api.tl#L3159) прямо разделяет позицию и принадлежность списку; external MTProxy/PSA chats описаны в строках 3094–3108. У неподписанного промотируемого канала может исчезнуть Join. Отдельный device-сценарий этого edge case не запускался.

**Что исправлять:** гидратировать реальный `supergroup.status`, posting rights и membership, затем выбирать панель по этой матрице. `chat.permissions` по TDLib описывает права неадминистраторов, а не все права текущего пользователя. Не исправлять это ещё одной эвристикой на `order`.

## Проверка сборки и тестов

| Проверка в этой сессии | Результат |
|---|---|
| `assembleHap --mode module -p product=default -p buildMode=debug --no-incremental --no-daemon` | PASS; `Finished :entry:default@CompileArkTS`, 36.908 s; весь build 51.478 s |
| `assembleHap --mode module -p product=default -p module=entry@ohosTest -p buildMode=debug --no-incremental --no-daemon` | PASS; `OhosTestCompileArkTS`, 11.705 s; весь build 25.568 s |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/smoke-ui-phase0.ps1` | PASS; `tg_ui shell smoke checks passed.` |
| 33 дополнительных `scripts/test-*.ps1` | 27 PASS / 6 FAIL, подробности ниже |
| Новый source-harness, Node 24.12.0 | 2 контрольных PASS / 6 regression FAIL; exit 1; HARNESS_ERROR отсутствует |
| `hdc list targets` | `[Empty]`: device/emulator runtime не проверялся |

Сначала также прошла incremental-сборка, но `CompileArkTS` там был `UP-TO-DATE`. В таблице выше приведён последующий принудительный compile, а не старый cache hit. Обе HAP-сборки unsigned: hvigor сообщил `No signingConfigs profile is configured`. Сборка ohosTest **не равна выполнению** его suites; 53 файла в test-каталоге не объявляются прошедшими тестами. HAP на устройство не устанавливался, пользовательская сессия не затрагивалась.

### Шесть красных source-contract scripts

Все шесть падений воспроизведены. Ниже указано первое упавшее утверждение каждого скрипта; последующие assertions скрипта после throw не исполнялись.

| Скрипт:строка проверки | Сообщение / причина |
|---|---|
| `test-chatlist-topbar.ps1:17` | `FAIL: API23 adaptive blur fallback`; ищет старый `.backgroundBlurStyle(...)`, live atom использует `.backdropBlur(...)` |
| `test-forward-picker-polish.ps1:29` | То же устаревшее ожидание blur API |
| `test-profile-navigation-bar.ps1:13` | То же устаревшее ожидание blur API |
| `test-ios-native-liquid-composer.ps1:65` | `Native-liquid composer contract missing: .backgroundBlurStyle(`; composer уже использует backdropBlur |
| `test-grouped-photo-album.ps1:37` | Ищет `if (mode === 'download')`; актуальный atom и policy используют `downloadAndOpen`, то есть загрузку с немедленным открытием gallery |
| `test-scroll-fab-unread.ps1:20` | Ищет `UNREAD_BADGE_COMPACT_THOUSAND` прямо в atom; atom делегирует `formatTelegramCompactCount()` |

Это подтверждённая рассинхронизация проверок с текущими реализациями, **не шесть доказанных визуальных регрессий**. Например, удалять текущий backdropBlur ради старого теста было бы неверно. Source-smoke стоит оставить для архитектурных границ, а семантику тестировать поведением.

Три дополнительных scripts — `test-chat-split-navigation.ps1`, `test-root-tab-bar-geometry.ps1`, `test-root-tab-unread-badge.ps1` — создают/удаляют временные host-fixtures и не вошли в этот read-only пакет из 33. Их прохождение здесь не заявляется.

## Как воспроизвести шесть находок

Из корня проекта, без SDK, аккаунта и сети:

```powershell
node --disable-warning=ExperimentalWarning docs/reviews/2026-09-05-review-witness.cjs
```

Нужен Node.js 24+ с `node:module.stripTypeScriptTypes`. [Скрипт](2026-09-05-review-witness.cjs) читает текущие 16 исходных файлов, снимает типы и import/export wiring в памяти, не исправляет тела методов и выводит SHA-256 каждого исходника. Platform/native зависимости подменены; pure panel method извлекается отдельно от ArkUI renderer. Normalizer в R1 — fixture mapper, зато очередь AppStore и messagesReducer настоящие. Начальные state/TDLib ответы синтетические. Это **host source-harness**, не ArkUI UI-test и не живая TDLib-сессия.

Ожидаемый baseline на `faf66b3`: `passed=2, failed=6`, exit `1`. После будущих исправлений соответствующие regression assertions должны стать зелёными; менять ожидаемые значения на текущие сломанные запрещено. Ошибка загрузки/компиляции самого harness даёт `HARNESS_ERROR` и exit `2`, а не маскируется под дефект продукта.

## Архитектурная оценка и границы

Реально прослежены два пути: `UI -> UseCase -> AppCommand -> TdGatewayAdapter -> TDLib` и `TDLib -> dispatcher -> normalizer -> AppStore -> bridge -> UI`. Разделение портов, normalizers, reducers и UI позволяет делать узкие исправления; общий rewrite не требуется. Основной риск — не недостаток слоёв, а несохранённые инварианты на их границах: порядок событий, terminal lifecycle, полнота ручного clone и идентичность асинхронной попытки.

Ориентация выполнена по `STATUS.md`, активным разделам `TASKS/TODO.md`, `DECISIONS.md`, `ARCHITECTURE.md`, `REFERENCES.md`; CPL scan ранее дал карту 1854 исходников, включая TDLib. `cpl_context` в этой сессии завершился timeout через 300 s, использован прямой source fallback. `harmonyos_docs` ответил на запрос UIAbility/onDestroy. Локально прочитаны TDLib schema/header и iOS input-panel dispatcher/reply-info component из reference registry; references не обновлялись. Новых runtime screenshots iOS/HarmonyOS не получено: визуальную fidelity не оцениваю как проверенную.

Два субагента независимо исследовали gateway/runtime и Compose/bottom-panel. В итог попали находки, сверенные основным агентом с исходниками; все шесть основных defects воспроизведены им в сохранённом harness. Подозрение на неработающие file-id aliases отклонено: `ChatTimelineVO.resolveContentPath` использует transfers/aliases как реальный fallback; отсутствие прямой записи content path само по себе не доказывает дефект.

**Рекомендуемый порядок исправлений:** R1/R2 -> R3/R4/R5 -> матрица прав/членства R6 -> синхронизация source-smoke -> запуск focused ohosTest и свежие runtime witnesses. Изменения серверных прав, logout, отправка сообщений и публикация при ревью не выполнялись.

## Изменённые файлы аудита

- Этот отчёт и `2026-09-05-review-witness.cjs` — воспроизводимый результат ревью.
- `STATUS.md`, `TASKS/TODO.md`, `TASKS/LESSONS.md` — короткие ссылки и стабильные результаты согласно AGENTS.md.
- `entry/src/**`, старые scripts, настройки и reference repositories не изменены. Build создал только обычные generated artifacts. Commit/push не выполнялись.
