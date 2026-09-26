# Ревью Telegram-HarmonyOS — 2026-09-26

База production-кода: `dev@2d2f68391e259fa83e4c3e09f38841cc08c235d1`. Tracking: [issue #198](https://github.com/kharkilirov1/Telegram-HarmonyOS/issues/198), [PR #199](https://github.com/kharkilirov1/Telegram-HarmonyOS/pull/199). Реализация исправлений — отдельные PR по [обновлённому плану](ARCHITECTURE_HARDENING_PLAN_2026-09-26.md).

## Вывод

Проект стоит стабилизировать на существующей архитектуре. Разделение на transport, normalizers, DTO, store/reducers, use cases и контроллеры уже позволяет воспроизводить ошибки без запуска всего приложения. Полная перепись по результатам этого ревью не обоснована.

Однако исходного плана, сосредоточенного на TDLib lifecycle и JSON, недостаточно. Найдены ошибки пользовательских операций, потери полей при преобразовании состояния, гонки медиа и пробелы в проверках сборки. Основная проблема — неполные контракты между существующими слоями и неявное владение асинхронной работой. Перемещение методов из большого экрана само по себе эти ошибки не исправит.

Ниже **23 группы находок**, включая ранее разобранные session/JSON/native проблемы. Группировка по месту исправления, а не по числу failing assertions. **P0 не установлен.** P1 означает высокий приоритет до релиза затронутого сценария; P2 — плановое исправление подтверждённого поведения. Это приоритеты ревью, без production-телеметрии о частоте сбоев. Ограничения продукта и неподтверждённые риски вынесены отдельно.

## Метод и границы проверки

- Проведён широкий обзор репозитория, затем предметная проверка основных цепочек. Это не утверждение, что каждая строка всех файлов проверена или все баги найдены.
- В production примерно 298 ETS-файлов; в `ohosTest` найдено 52 файла `*.test.ets`. Количество файлов не является оценкой покрытия.
- **Host:** исполнялись реальные ETS-модули после удаления imports/types через Node 24 `stripTypeScriptTypes`; внешние зависимости, таймеры и ответы подменялись управляемыми mocks. Для races задавался порядок завершения Promise. ArkUI-страницы сопоставлялись с реальными call sites; их rendering lifecycle здесь не исполнялся.
- **Native host:** неизменённый `tdlib_napi.cpp` компилировался с минимальными N-API/TDLib/Hilog заглушками. Это доказательство control flow и владения, а не соответствия ABI или реального teardown OpenHarmony.
- **Статика:** проверены маршруты событий, потребители полей, конфигурация сборки, CI, логи и части платформенных wrappers.
- HarmonyOS SDK, HAP build, Hypium execution, устройство/эмулятор, реальный Telegram и измерения FPS/ANR в этом срезе **не использовались**. Исторические device-результаты в STATUS не перепроверялись.
- Репродукторы сохранены в [scripts/review/2026-09-26](../scripts/review/2026-09-26/README.md). Их успешный exit подтверждает наличие известных дефектов на базе, **не** исправленность приложения. Их нельзя использовать как зелёный release gate.

| Область | Что проверено | Ограничение |
|---|---|---|
| TDLib lifecycle | Gateway, adapter, dispatcher, runtime, auth side effects, native receive | Fake transport и native mocks; реальные env/TSFN semantics требуют SDK |
| Данные | TdObject, DTO Message/Chat/User/Story, normalizers, accessors, serializers | Выборочные fixtures; не полный корпус всех TDLib типов |
| Состояние и use cases | Root/leaf reducers, store, clones, invariants, history, создание чатов, read actions | Управляемые ответы; серверные mutations не выполнялись |
| UI | Composer/actions/search, login, draft/edit/send, основные navigation guards | Нет визуального, accessibility или полного ArkUI lifecycle прогона |
| Медиа | Recording/playback/download controllers, gallery, file pipeline, TGS wrapper | SDK media API mocked; native rlottie просмотрен статически |
| Build/CI/privacy | Hvigor/CMake/profiles, smoke, test execution, credential logging | Не pentest, не аудит всей git history, не анализ бинарных зависимостей |

## Высокий приоритет

### R01 · P1 · Сессия не имеет согласованного завершения и повторного запуска

**Где:** [AuthSideEffect.ets](../entry/src/main/ets/core/sideeffects/AuthSideEffect.ets), строки 142–148; [LoginController.ets](../entry/src/main/ets/ui/controllers/LoginController.ets), 210–216; [AppCoreRuntime.ets](../entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets), 82–85; [TdGateway.ets](../entry/src/main/ets/infra/td/gateway/TdGateway.ets), initialize/destroy и `handleUpdateOnMainThread`.

**Проверено:** после `logOut → Closed` сбрасываются auth-флаги, но новый client не создаётся и gateway остаётся `ready`. После reset singleton `LoginController` сохраняет прежний adapter: новый gateway готов, а отправка номера через старый контроллер падает до native send. При timeout закрытия и последующем restart старый callback client 2 доставляет update в gateway client 3 через общий dispatcher.

**Последствие:** повторный вход/восстановление может остаться на закрытом клиенте либо получить устаревшие события. Последний сценарий условный: нужен timeout/restart и задержанная работа. Он не доказывает нарушение FIFO после нормального финального `Closed`.

**Исправление/приёмка:** единый владелец сессии, generation/client filtering и согласованное обновление зависимостей. Служебные `close`/`Closed` принимать до завершения graceful stop; timeout не разрешает открыть второй клиент на той же БД без подтверждения освобождения. Repro: `check_gateway.cjs`.

### R02 · P1 · Успешное создание группы и канала возвращается как ошибка

**Где:** [createBasicGroupChat.ets](../entry/src/main/ets/domain/usecases/createBasicGroupChat.ets), 68–70; [createChannelChat.ets](../entry/src/main/ets/domain/usecases/createChannelChat.ets), 32–34.

Проверка `chatId <= 0` отвергает нормальные отрицательные chat ID групп/каналов. Host с реальными parser/DTO/use cases отклонил `-7001` и `-1000000008100` после успешного ответа создания. Серверная операция уже выполнена, но UI получает failure; повтор способен создать дубликат. Тестовые положительные ID скрывают ошибку. Отрицательные значения подтверждаются также [DialogId.cpp закреплённого TDLib](https://github.com/tdlib/td/blob/cb863c1600082404428f1a84e407b866b9d412a8/td/telegram/DialogId.cpp).

**Исправление/приёмка:** различать chat ID и user ID, принимать допустимые отрицательные chat ID; проверять ноль/нечисловое значение и контракт типа. Тестировать реалистичные server-success ответы, сохранение committed result и retry после локальной ошибки. Repro: `state_usecases.cjs`.

### R03 · P1 · Неотправленные сообщения могут отображаться отправленными

**Где:** [MessageDto.ets](../entry/src/main/ets/core/model/dto/MessageDto.ets), 181, 480–484; [messagesReducer.ets](../entry/src/main/ets/core/reducers/messagesReducer.ets), 196–203; [ChatTimelineVO.ets](../entry/src/main/ets/ui/pages/chat/ChatTimelineVO.ets), 594–610.

DTO полного message не читает `sending_state`. И pending, и failed payload дали `isPending=false`; reducer выставляет `sendStatus='none'`, а outgoing VO выбирает `Sent`. Особенно существенно восстановление failed-сообщений из history: отдельный `updateMessageSendFailed` способен исправить текущую сессию, но не заменяет восстановление snapshot.

**Исправление/приёмка:** переносить явные pending/failed/sent и данные ошибки через DTO → state → VO. Проверить offline send, последующий failure и повторную загрузку history. [Контракт TDLib message](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1message.html). Repro: `data_parsing.cjs`; downstream подтверждён исходниками.

### R04 · P1 · Отменённое создание recorder вмешивается в следующую запись

**Где:** [ChatVoiceRecordingController.ets](../entry/src/main/ets/ui/pages/chat/ChatVoiceRecordingController.ets), 145–160, 330–343; действия доступны из `TgChatScreenPage`, 3136–3151.

Последовательность: begin A с задержанным `createAVRecorder` → cancel A → begin B, запись запущена → завершение create A. Результат A присваивается общему `this.recorder` до проверки token. Cleanup A закрывает/удаляет output B и теряет ссылку на работающий B; последующий dispose его не освобождает. Отдельно `failAndReset()` запускает async cleanup и сразу стирает FD/path, из-за чего ошибка prepare оставляет ресурсы без владельца.

**Исправление/приёмка:** ресурсы recorder/FD/path принадлежат конкретной операции; устаревший результат освобождается до публикации в controller. Cleanup работает с захваченными ресурсами и завершается до нового idle. Host доказал потерю владения; продолжение захвата микрофона на реальном устройстве не проверено. Repro: `media_races.cjs`.

### R05 · P1 · В чистом checkout отсутствует обязательный модуль сборки

**Где:** [hvigorfile.ts](../hvigorfile.ts), 1.

Корневой script импортирует `./tools/hvigor/hvigor-ohos-plugin-compat`; этого файла/каталога нет в Git. В README не описана его генерация. Установка SDK и TDLib сама по себе не разрешит этот локальный импорт. Вывод по import и git tree; полный Hvigor build здесь не запускался.

**Исправление/приёмка:** восстановить обязательный bootstrap либо штатный импорт; проверить документированный build из чистого checkout без файлов авторской машины. Одновременно согласовать README min API 22 с профилем min 23/target 26.

## Данные, состояние и команды

### R06 · P2 · JSON reader меняет смысл корректного JSON

**Где:** [models/td/common/index.ets](../entry/src/main/ets/models/td/common/index.ets), `getNumber`, 387–392, `unescapeJsonString`, 802–809.

Три воспроизводимых класса одной границы парсинга: вложенный `id=7` читается вместо корневого `id=42` и даже вместо отсутствующего корневого поля; буквальный шестисимвольный текст `\u0041` становится `A`, а `C:\temp` получает табуляцию; координаты `1e-7,-1e-7` превращаются в `1,-1`, поскольку numeric regex не включает exponent. Gateway сам может получить экспоненциальную запись при stringify маленького double.

**Последствие:** неправильные поля, изменённый отображаемый/копируемый текст и entity offsets, неверная геопозиция. **Исправление/приёмка:** структурный reader с полным JSON string/number contract; fixtures вложенности, Unicode/escapes и exponent. Отдельный риск A3: ранний gateway parse/stringify округляет unsafe unquoted integers; это не утверждение о потере всех реальных TDLib ID, quoted int64 нужно проверять отдельно. Repro: `data_parsing.cjs`.

### R07 · P2 · Управляющие символы делают отправляемый JSON невалидным

**Где:** [CommandSerializer.ets](../entry/src/main/ets/infra/td/serialization/CommandSerializer.ets), 751–757; [TdObject](../entry/src/main/ets/models/td/common/index.ets), 815–821.

Путь `createSendMessageCommand → serializeCommand → TdObject.toJSON` не экранирует весь диапазон U+0000–001F. Вставленные U+0000/U+0008/U+000C/U+001B дали `Bad control character in string literal`. Валидация длины такой ввод пропускает. Конкретный native error/timeout не измерялся.

**Исправление/приёмка:** общий encoder строк, например `JSON.stringify` для строкового значения; проверить полный диапазон control characters. Это не требует преобразовывать int64-bearing объект целиком в Number. Repro: `data_parsing.cjs`.

### R08 · P2 · Root reducer теряет два реализованных события

**Где:** [reducers/index.ets](../entry/src/main/ets/core/reducers/index.ets), 25–38.

Нет маршрутов `chatListUnreadMessageCountChanged` и `chatMessagesReset`. Normalized aggregate 150 через настоящий AppStore оставляет `mainUnreadMessageCount=-1`; badge использует сумму загруженных чатов и показывает 2. Reset сохраняет прежние сообщения, хотя leaf reducer удаляет их. Jump соединяет старый и новый участки истории.

**Исправление/приёмка:** добавить маршруты и исчерпывающую проверку supported events через production root reducer. Тест leaf reducer не покрывает эту интеграцию. Repro: `state_repro.cjs`.

### R09 · P2 · Чат с известной нулевой позицией остаётся в основном списке

**Где:** [chatsReducer.ets](../entry/src/main/ets/core/reducers/chatsReducer.ets), 86–95, 109–115.

`order='0', archiveOrder='0'` попадает в `noOrder` и обратно в `orderedChatIds`. Это смешивает placeholder без загруженной позиции с авторитетным отсутствием в списках. После `DeleteChatHistory(removeFromChatList=true)` позиционные updates не убирают строку; repro `100 → 0` сохраняет chat 7.

**Исправление/приёмка:** различать неизвестную позицию и известное отсутствие; нулевая подтверждённая позиция исключает чат из соответствующего списка. Repro: `state_repro.cjs`.

### R10 · P2 · Jump не инвалидирует запросы предыдущего окна истории

**Где:** [loadChatHistory.ets](../entry/src/main/ets/domain/usecases/loadChatHistory.ets), 575–585, 623–627, 648–657.

Reset вызывается до резервирования `primary`: при занятом bucket новый jump возвращает false без target request, уже запросив очистку. Старый `older/newer` из других buckets остаётся актуальным: после jump `[90,100,110]` поздний результат `[950,960,970]` присоединяет несвязанный диапазон и двигает newest cursor 110 → 970. Этот дефект остаётся после исправления R08; сценарий отдельно проверен управляемым store adapter.

**Исправление/приёмка:** generation всего окна чата, инвалидация всех buckets при принятом jump, согласованный reset; stale result не меняет сообщения и cursors. Repro: `state_usecases.cjs`.

### R11 · P2 · «Прочитано» снимает только ручную отметку unread

**Где:** [toggleChatUnread.ets](../entry/src/main/ets/domain/usecases/toggleChatUnread.ets), 42–44; [ChatListPage.ets](../entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets), 1086–1087.

Меню выбирает markAsRead при реальном `unreadCount > 0`, а use case отправляет только `toggleChatIsMarkedAsUnread(false)`. Эта команда меняет ручную отметку, не чтение сообщений; `viewMessages` отсутствует. Repro подтверждает состав отправленных команд, а не серверный read receipt.

**Исправление/приёмка:** реализовать/переиспользовать viewMessages с явно выбранным актуальным read target и снять manual mark; проверить actual unread, manual unread и загруженное старое окно после jump. Контракты: [toggle](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1toggle_chat_is_marked_as_unread.html), [viewMessages](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1view_messages.html). Repro: `state_usecases.cjs`.

### R12 · P2 · Обновление файла теряет chat ID ответа

**Где:** [filesReducer.ets](../entry/src/main/ets/core/reducers/filesReducer.ets), 165–184, 381–383; [ChatTimelineVO.ets](../entry/src/main/ets/ui/pages/chat/ChatTimelineVO.ets), 495–508.

Ручной `cloneMessageWithContent` сохраняет `replyToMessageId`, но пропускает `replyToChatId`. Photo download превратил reply `(-10055,22)` в `(0,22)`. VO теперь ищет сообщение в текущем чате: превью пропадает либо выбирается другое сообщение с тем же ID.

**Исправление/приёмка:** сохранять все поля при обновлении content, свести расходящиеся clones к одной проверяемой операции. Fixture cross-chat reply должен переживать file progress/completion. Repro: `state_repro.cjs`.

### R13 · P2 · Полный chat snapshot теряет непрочитанные упоминания

**Где:** [ChatDto.ets](../entry/src/main/ets/core/model/dto/ChatDto.ets), 40, 119–121.

`unread_mention_count:7` становится DTO `unreadMentionCount:0`, попадает в store и скрывает indicator. Частичный `updateChatUnreadMentionCount` обрабатывается, поэтому ошибка проявляется на cold/full load до следующего изменения; full refresh может обнулить известное значение.

**Исправление/приёмка:** заполнять счётчик в snapshot parser; проверить одинаковый итог snapshot и последовательности partial updates. Repro: `data_parsing.cjs`.

## Пользовательские операции и медиа

### R14 · P2 · Composer не сохраняет принадлежность черновика операции

**Где:** [ChatComposerController.ets](../entry/src/main/ets/ui/pages/chat/ChatComposerController.ets), 262–271; [ChatMessageActionsController.ets](../entry/src/main/ets/ui/pages/chat/ChatMessageActionsController.ets), 283–292, 355–368, 392–398; [TgChatScreenPage.ets](../entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets), 623–650, 4089–4109, 5026–5031.

Три сценария потери ввода: успешная отложенная media send очищает уже новый text/reply/attachment; неудачная отправка комментария forward восстанавливает старый комментарий поверх нового текста; вход в Edit и Cancel уничтожает существовавший draft без snapshot. Затем persistDraft может сохранить пустоту. Input во время send не запрещён.

**Исправление/приёмка:** отдельный edit buffer и snapshot/revision composer operation; cleanup/rollback касается только захваченной версии. Новый пользовательский ввод не стирается и не перезаписывается результатом старого Promise. Repro: `ui_composer_repro.cjs`, реальные controllers и извлечённые методы страницы Edit/Cancel; остальные зависимости состояния страницы подменены host.

### R15 · P2 · Retry нескольких вложений повторяет уже принятые файлы

**Где:** [ChatComposerController.ets](../entry/src/main/ets/ui/pages/chat/ChatComposerController.ets), 253, 276–282, 294–320.

Отправка A успешна, подготовка/отправка B падает; catch оставляет исходный список. Повтор отправляет A ещё раз. Repro принятых отправок: `[A,A,B]`.

**Исправление/приёмка:** сохранять подтверждённый прогресс операции и retry только неотправленного хвоста, включая принадлежность caption/reply. При неоднозначном network timeout не объявлять mutation неисполненной без согласованного протокола. Repro: `ui_composer_repro.cjs`.

### R16 · P2 · Edit caption вызывает editMessageText

**Где:** [ChatMessageActionsController.ets](../entry/src/main/ets/ui/pages/chat/ChatMessageActionsController.ets), 216–222, 248–249, 311–331; [editMessage.ets](../entry/src/main/ets/domain/usecases/editMessage.ets), 44.

Меню разрешает редактировать caption фото/видео/документа, но теряет тип edit target. Controller и use case в host отправили `editMessageText` для photo. Для caption предназначен [editMessageCaption](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1edit_message_caption.html). Edit buffer очищается до результата, а ошибка только логируется.

**Исправление/приёмка:** сохранять тип цели, caption entities и буфер до подтверждения; отдельная caption command. Проверить text и media edits, отказ сети и восстановление ввода. Repro: `ui_composer_repro.cjs`.

### R17 · P2 · Playback переживает Stop и допускает два player

**Где:** [VoicePlaybackController.ets](../entry/src/main/ets/ui/pages/chat/VoicePlaybackController.ets), 210–244; [GlobalMediaPlayback.ets](../entry/src/main/ets/ui/pages/chat/GlobalMediaPlayback.ets), 397–410.

Два play могут пройти release до завершения создания: затем играют оба AVPlayer, но owner хранит только последний player/FD. Stop во время create не мешает позднему результату начать playback. На уровне playlist задержанный Next search/download также запускает трек после stop.

**Исправление/приёмка:** generation пользовательского playback intent через все await и playlist; operation-owned cleanup; stop инвалидирует создание и поиск следующего трека. Repro: `media_races.cjs`; реальные SDK audio effects не проверены.

### R18 · P2 · Ответ отменённого download ломает новый retry

**Где:** [ChatMediaDownloadController.ets](../entry/src/main/ets/ui/pages/chat/ChatMediaDownloadController.ets), 59–64, 91–97.

Token сравнивается с неизменённым аргументом, из которого скопирован. Request → cancel → retry того же file: старый reject видит membership нового pending, удаляет его и выставляет failed; новый direct completion затем игнорируется.

**Исправление/приёмка:** per-file request identity, инвалидируемая cancel/clear; проверка в success и error. Repro: `media_races.cjs`.

## Native, приватность и проверяемость

### R19 · P2 · Ошибки native callback скрываются, payload имеет неполный cleanup

**Где:** [tdlib_napi.cpp](../entry/src/main/cpp/tdlib_napi.cpp), 211–222, 257–266, 292–295.

Fault injection отказа TSFN create оставляет loop `Running` с null callback: ответы вычитываются из TDLib, но ни один не передаётся в JS. ETS после возврата считает gateway ready. `CallJs(env=nullptr, data)` возвращается без удаления payload; host tracker подтвердил отсутствие delete. Результат enqueue также игнорируется.

**Исправление/приёмка:** проверять N-API status, rollback startup, явное владение payload до/после enqueue, освобождение на env-null и failure. Для `napi_closing` сверить lifetime-контракт версии SDK. Частота реальных allocation/teardown failures не установлена. Repro: `native/run.sh`; это не LSan/device результат.

### R20 · P2 · Stop receiver синхронно блокирует вызывающий JS-поток

**Где:** [tdlib_napi.cpp](../entry/src/main/cpp/tdlib_napi.cpp), 271, 279–285, 332–337.

`join()` выполняется внутри NAPI. Если ответ приходит после установки Stopping, batch продолжает до 49 ожиданий по 50 мс без проверки состояния после первого poll до 1 секунды. Host stream дал примерно 3,4 секунды внутри Stop. После нормального TDLib close типичный хвост короче; сценарий длительного ожидания предполагает продолжающийся поток ответов и не задаёт максимальную задержку устройства.

**Исправление/приёмка:** проверять stop внутри drain, завершать join асинхронно с согласованной сигнатурой ArkTS. Это **не** queue-full deadlock: текущая TSFN очередь имеет max size 0. Неограниченный backlog остаётся риском для отдельного stress test; ограничивать его нужно совместно с протоколом stop. Repro: `native/run.sh`.

### R21 · P2 · Часть одноразового кода попадает в публичный лог

**Где:** [LoginController.ets](../entry/src/main/ets/ui/controllers/LoginController.ets), 247–248.

`substring(0,2) + '***'` передаётся в `%{public}s` вместе с длиной. На синтетическом `12345` logger получил `12***,5`. Это раскрытие части секрета, а не установленный захват аккаунта; внешняя доступность логов не исследовалась.

**Исправление/приёмка:** логировать событие и безопасный correlation ID, не символы OTP/пароля. Тест capture logger на синтетических secret fixtures. Repro: `auth_logging.cjs`.

### R22 · P2 · Production выполняет полные debug-invariants на progress updates

**Где:** [AppCoreRuntime.ets](../entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets), 58; [AppStore.ets](../entry/src/main/ets/core/store/AppStore.ets), 26, 88–89; [assertInvariants.ets](../entry/src/main/ets/core/invariants/assertInvariants.ets), обходы messages.

`new AppStore(appReducer)` наследует `devMode=true`. На каждом dispatch проверяется вся накопленная история, в том числе при file progress. Host: 30 000 messages и 100 events → 9 000 000 посещений сообщений, около 0,7 с суммарно на этой машине. Это не прогноз FPS/ANR. Основная message map не имеет показанного ограничения; отдельный `MessageLruCache` не управляет её вставками.

**Исправление/приёмка:** явный build debug flag, локальные production checks и политика выгрузки основной истории; замерить dispatcher/store/VO и память на устройстве до выбора лимитов. Repro: `state_perf.cjs`.

### R23 · P2 · Smoke даёт ложную уверенность, а CI не исполняет поведенческие тесты

**Где:** [smoke-ui-phase0.sh](../scripts/smoke-ui-phase0.sh), 20, 33; [smoke.yml](../.github/workflows/smoke.yml), 23–30; [smoke-build.ps1](../scripts/smoke-build.ps1), 64–74.

HEX_PATTERN содержит ERE `{3,8}`, но запускается BRE `grep -n`: `.fontColor('#FF0000')` не обнаруживается; `grep -nE` обнаруживает. Обязательный CI проверяет документы/исходный текст; HarmonyOS build условный. Даже сборка HAP не означает исполнение Hypium. Поэтому зелёный smoke совместим и с отсутствующим build bootstrap, и с R08.

**Исправление/приёмка:** поправить matcher с отрицательным fixture; выполнять тесты поведения и production root integration в CI; отдельно показывать compile, build и device execution. Проверить, что намеренно внесённая регрессия делает соответствующий gate красным.

## Ограничения продукта и дальнейшие проверки

- **Регистрация нового номера:** `LoginRouter.ets:236–255` отправляет `waitRegistration` в logout/возврат к номеру. `RegistrationPage` существует, но не подключена. Это явный временный fallback, не доказанная регрессия. Если продукт обещает регистрацию — её блокер; иначе документировать «только существующие аккаунты». Email auth states дополнительно не нормализуются, но не утверждается, что они доходят до этой logout-ветки.
- **Device release ABI:** `entry/build-profile.json5:7–12` оставляет `x86_64`; release block не добавляет ARM64. Подходит текущему emulator-профилю, но одного переключения release недостаточно для native device build. Нужны раздельные products/ABI gate и проверка HAP.
- **UI visibility:** код скрытого chat может продолжать read callbacks; без воспроизведения реального NavDestination lifecycle это оставлено гипотезой, не включено в 23 группы.
- **Native concurrency:** экспортированный sync Receive и multi-env Start/Stop требуют контрактов; вызовов sync receive и TDLib Worker в текущем ArkTS не найдено. Их нельзя объявлять доказанными P0 текущего приложения.
- **rlottie wrapper:** проверены bounds/typed-array alignment/shared ownership; нового подтверждённого дефекта не найдено. Это не гарантия отсутствия ошибок в движке или бинарной поставке.
- **Custom emoji:** parser теряет часть метаданных, но UI spec допускает fallback для unsupported entity types; не включено как подтверждённый регресс.
- **Безопасность:** проверка логов не заменяет аудит storage, URI permissions, cryptography, зависимостей и всей истории секретов. Недоказанные сценарии RCE/утечки БД здесь не заявляются.

## Что это меняет в архитектурном плане

1. Сначала воспроизводимый build и тесты границ, затем session correctness и локальные исправления P1. Декомпозиция экрана не должна задерживать R02/R03/R04.
2. Codec — единая структурная граница с полным string/number contract. DTO snapshot и partial updates должны давать согласованное состояние; root reducer обязан маршрутизировать весь supported event set.
3. Async ownership нужен не только TDLib-сессии: history window, composer operation, recorder, playback и per-file download имеют собственные идентичности/поколения. Один глобальный lifecycle token этого не обеспечивает.
4. Пользовательская mutation различает «сервер принял», «локально обработано», «пользователь уже начал следующую операцию». Retry/rollback не повторяет подтверждённое действие и не стирает новый ввод.
5. Общие механизмы извлекать после двух-трёх конкретных исправлений, когда виден одинаковый контракт. Не добавлять универсальный coordinator/DI/event bus ради формы.

В [план](ARCHITECTURE_HARDENING_PLAN_2026-09-26.md) добавлены B1–B4 с этими задачами и критериями приёмки. A4 (структурное разделение UI) выполняется после исправлений поведения. Этот PR содержит обзор и репродукторы, **не runtime fixes**.
