# Petrelgram и Telegram-HarmonyOS: сравнительный code review

Дата: 2026-10-01. Обзор по фактическим локальным checkout, с проверкой ключевых UI→TDLib цепочек и ограниченными безопасными host-проверками.

## 1. Результат и происхождение сравниваемого кода

Petrelgram полезен как отдельный референс развитого HarmonyOS Telegram-клиента: у него шире связанный набор функций, тематические stores, настоящая отправка albums, folders/topics/settings/calls. Текущий Telegram-HarmonyOS имеет более явную границу domain state и более строгие guards владения аккаунтом/TDLib-клиентом. Ни число функций, ни наличие архитектурных слоёв не доказывают runtime-превосходство. У обоих остаются крупные страницы и существенные непроверенные native/lifecycle границы.

| Проект | Фактический checkout | Ветка / SHA / состояние |
|---|---|---|
| Telegram-HarmonyOS | `C:\Users\Kharki\Desktop\Telegram-HarmonyOS` | `dev@faf66b3e066afccdbbfa36442eb9122073f509b2` **плюс 265 исходных modified/untracked файлов**, зафиксированных SHA-256. Это текущий local working tree, а не опубликованный GitHub HEAD. |
| Petrelgram | `C:\Refs\Telegram\Petrelgram` | `main@a5e1ec763b08d549630a58f9efe96677bb3245de`, clean shallow clone `--depth 1`; commit `2026-09-30T16:08:27+08:00`. |

Petrelgram cloned from `https://github.com/miramira8295/Petrelgram.git`, без recursive submodules и без исполнения hooks. Telegram-HarmonyOS уже существовал; повторный clone не создавался. Его ветка, HEAD, staged state и исходные пользовательские файлы сохранены. Внешнее дерево находится вне основного Git; нет submodule, junction или сборочной зависимости.

**Правило ссылок:** все `Pxx` ведут на публичный код Petrelgram, закреплённый на SHA выше. Все `Txx` относятся к **локальному рабочему дереву Telegram-HarmonyOS**; статус конкретного файла указан в таблице evidence. Для dirty/untracked файлов намеренно нет GitHub-ссылки на текущую версию: опубликованный commit может содержать другой код и другую нумерацию. Это правило относится к каждому выводу о вашем проекте ниже, включая функциональную матрицу.

Прочитаны глобальные и проектные AGENTS, актуальные memory/architecture/decision/reference документы. В `.agents/skills` проекта каталога нет; существующие `.agents` относятся к завершённому review июля, а не к этой задаче. Secrets, credentials, session stores и локальная `.codex` не открывались. `harmonyos_docs` недоступен; платформенный runtime здесь не заверяется. Самостоятельный обзор дополнен тремя независимыми статическими обзорами; ключевые выводы сверены с исходниками.

## 2. Архитектура, состояние и потоки данных

| Область | Petrelgram, pinned main | Telegram-HarmonyOS, local working tree |
|---|---|---|
| Сборка runtime | `tdkit/Globals.ets:133` создаёт client/auth и тематические users/chats/files/folders/calls stores. | `app/bootstrap/AppCoreRuntime.ets:95` связывает transport, normalizer, serial AppStore и side effects. |
| Входящие данные | Native JSON → `TdClient` → handlers по `@type` → mutable feature store с заменой отдельных entries → subscribers/data source/page state. | Gateway → dispatcher → `core/events/EventNormalizer.ets:36` → domain events/reducers → `core/store/AppStore.ets:116` → `AppStoreBridge.ets:205` / page subscriptions → V2 UI/VO. |
| Исходящий action | Страницы/store формируют raw `TdRequest`; transport сохраняет `TdError.code/message`. | Typed command/use case → `TdGatewayPort` → adapter → `CommandSerializer` → gateway; одна основная точка проверки wire format. |
| Аккаунты | Account slots, отдельные directories, serial switch и session epoch (`Globals.ets:430`, `:507`). Но transport не отзывает старый client capability полностью. | Captured gateway generation, account scope, page/route/operation tokens, route-owned `ChatOpenLease`. Это изоляция активного runtime/recovery; сопоставимый UI account-slot registry в изученных путях не найден. |
| UI контракт | Публично заявлен ориентир Telegram Android; фактически есть отдельные product surfaces, включая Music Center. | Принятый контракт — Telegram iOS runtime/source, atom→demo→integration и `tg_ui`, токены, HDS shell. |

Это различие моделей, а не основание заменять ваш core на Petrelgram stores. Полезнее переносить узкие поведения и тестовые сценарии через существующие DTO/use cases. Источники: `Petrelgram/tdkit/Globals.ets:133–191`; локальные `AppCoreRuntime.ets:95`, `TdGatewayAdapter.ets:53`, `AppStore.ets:116`, `AppStoreBridge.ets:205`.

**Размеры не равны оценке качества.** Измерены физические строки, включая comments/blank lines, без локальных credential-файлов и vendored native code:

| Метрика | Petrelgram | Telegram-HarmonyOS local |
|---|---:|---:|
| Production `.ets` | 741 файлов / 175304 строки | 313 файлов / 73021 строка |
| Главная chat page | 9274 | 5730 |
| MessageStore / AppStore | MessageStore 6524 | AppStore 305 |
| Зарегистрированные host ETS test modules, без List | 347 | 0 |
| Зарегистрированные ohosTest modules, без List | 3 | 66 |
| SDK-free CJS host suites, обнаружены, не все запускались | 0 | 62 |

Большая `MessageStore` Petrelgram объединяет history, media, edits, reactions и прочее; в вашем проекте это распределено между use cases/controllers/reducers. В обоих chat page остаётся много coordination. Petrelgram уже извлекает `ComposerSession`, `SearchSession`, `SelectionSession` и scroll/session helpers; ваш проект — typed controllers. Нельзя считать весь scope одинаковым или выбирать победителя по строкам.

У Petrelgram полезен конкретный performance-паттерн: dirty chat IDs, один snapshot на list key, trailing throttle без бесконечного переноса flush [P20], cached ordered IDs (`ChatStore.ets:286`). У вашего проекта есть selective cloning, generation filtering и time-budgeted drain, но клонирование chat containers (`core/utils/stateClone.ets:70`, `:101`) и преобразования JSON тоже стоят работы. Worker bridge в Petrelgram **выключен** [P01]. FPS, память, latency и поведение при update storm не измерялись.

## 3. TDLib, native lifecycle и безопасность

Официальный TDLib JSON contract: `td_receive` общий для client IDs, envelopes содержат `@client_id`, ответы коррелируются через `@extra`; client освобождается после закрытия. `int32/int53` передаются числами, `int64` — строками. Поэтому обычный `JSON.parse` сам по себе не доказывает потерю TDLib int64. `close → ok`, timeout или остановка receive thread не заменяют подтверждение `authorizationStateClosed`. [TDLib JSON API](https://core.telegram.org/tdlib/docs/td__json__client_8h.html).

| Приоритет и тип вывода | Наблюдение и доказательство | Практическая граница вывода |
|---|---|---|
| P1, Petrelgram: доказанный разрыв retirement contract | `closeDatabase` успешно завершает ожидание при timeout/error [P06,P07]; `Globals.stopRuntime` затем dispose/tdDestroy [P08]; native забывает ID [P12]. | При незавершённом старом client исчезает его owner. Поздние old envelopes могут попасть в новый receiver. Реальная гонка на устройстве не воспроизведена. |
| P1, Petrelgram: доказанный отсутствующий stale-client gate | `dispose()` очищает pending/handlers [P04], но последующий `send()` вызывает bridge [P03]; native отправляет через текущий глобальный ID [P10]. | Retained callback со старым TdClient после switch способен использовать новый ID. Достижимость конкретного пользовательского action и смешение данных в runtime не проверены. |
| P1, Petrelgram: условный cross-account envelope риск | Новый client опять создаёт `req_N` [P02], а `deliverParsed` не фильтрует `@client_id` [P05]; `td_receive` глобальный [P09]. | Если old client выдаёт delayed ответ с совпавшим extra или update после timeout, новый client может его принять. Это статический сценарий, не подтверждённый exploit. |
| Сильная сторона вашего current dirty кода | Adapter проверяет identity/generation до/после await [T01]; gateway удерживает retirement до Closed [T02], проверяет top-level client ID [T03] и batch generation [T04]. | Это реальная защита прочитанного command path. Она не доказывает правильность каждого raw-native caller или env teardown установленного SDK. |
| P2, native stop | Petrelgram join синхронен [P11], poll ждёт до 0.5s [P09]. У вашего current dirty bridge join выполняет async work [T05], restart блокируется при Stopping. | Возможная UI задержка Petrelgram; ANR/время не измерены. Более строгий barrier вашего проекта также требует SDK/device acceptance. |
| P2, ваш current dirty delivery: доказанный error-path loss | Callback удаляет batch [T07] до conversion; failure создания строки возвращает управление [T08]. | Если эта ветка сработает, batch уже потерян. Allocation/conversion failure на устройстве не наблюдался; нужен recovery/resync contract, а не безусловный replay после partial JS processing. |
| P2, оба: backpressure риск | TSFN queue size 0 [P13,T09]; owning native deque и `TdGateway.ets:823` queue не имеют общего byte/high-water budget. | Порция 50 объектов и 8ms drain ограничивают работу за тик, а не суммарный рост памяти. Freeze/OOM здесь не доказаны. |
| P2, ваш current dirty adapter: доказанная потеря ошибок | Catch заменяет classified AppError на CONNECTION_FAILED [T10]; GatewayError создаёт NETWORK/code0/retryable=true [T11]. | AUTH/403 либо RATE_LIMIT теряют kind/code/retryability на пути в use case. Это прямой семантический дефект; конкретный неверный UX/retry не воспроизводился. |
| P2, ваш current dirty auth logging: подтверждён неполный redaction | LoginController скрывает checkCode text, но adapter ранее логирует public detail [T12], checkPassword также печатает message [T13]. | Настоящий code/password в логах не наблюдался. Утечка условна: backend/native error должен echo credential. Локальные секреты не читались. |

**Что ещё неизвестно.** В обоих изученных TDLib-мостах не найден env cleanup hook. Petrelgram освобождает string после TSFN non-ok [P14]; безопасность владения при неоднозначном enqueue failure зависит от конкретного SDK. У вашего bridge payload отделён от TSFN: owning queue плюс nullptr wakeups и retry; null-env guard предшествует чтению context [T06]. Это полезные защиты, но env/opaque-handle teardown и реальный enqueue-failure contract остаются непроверенными. Здесь не заявляются double-free, native crash или подтверждённая утечка credentials. [OpenHarmony NAPI reference](https://github.com/openharmony/docs/blob/master/en/application-dev/reference/native-lib/napi.md).

JSON у Petrelgram проще: стандартный parser и верхние object keys. Ваш lazy `TdObject` даёт дополнительную семантику и raw JSON expansion. В current dirty `getTopLevelInt64String` при отсутствии верхнего поля fallback-ится в generic accessor [T14], который может взять одноимённое вложенное поле. Это статический дефект strict/top-level API; конкретный сбой caller не установлен. Проверенный gateway identity использует обычный top-level parsed object и не опирается на этот fallback. Обе реализации в изученном calls pagination используют opaque `offset:string`; наличие number для chat/message int53 не является дефектом.

Отдельная изоляция observer errors заслуживает внимания: Petrelgram `ChatStore.flushNotify` не изолирует исключение каждого subscriber [P21]. У вашего AppStore listener isolation есть, но processing error в dispatch queue логируется и returned Promise становится успешным (`AppStore.ets:116–162`). Эти ветви могут скрыть неполную доставку; фактические исключения тут не воспроизводились.

## 4. Реальная полнота функций UI

«Есть» ниже означает найденную связанную source-цепочку UI→controller/store/use case→TDLib/native. Это **не** подтверждённый успешный device-сеанс. Для всех Telegram-HarmonyOS ячеек источник — local working tree, не remote HEAD.

| Сценарий | Petrelgram pinned | Telegram-HarmonyOS local |
|---|---|---|
| Chat list и основные actions | Archive/mute/read/pin, folder-specific list. `pages/chatlist/ChatRow.ets:522 → store/ChatActions.ets:141`. | Реальные pin/archive/mute/read-unread: `ui/pages/chatlist/ChatListPage.ets:983`, `:994`, `:1086`. All/Unread/Personal — локальные фильтры. |
| Reply/edit/forward/delete/pin | Связаны, включая caption/media edit. `MessageStore.ets:1772`, `ForwardDirect.ets:31`. | Связаны; отдельные edit/delete/forward controllers и свежие permissions/operation guards. `ChatEditMessageController.ets:63 → domain/usecases/editMessage.ets:155`. |
| Отправка media | Настоящий photo/video album [P15], GIF вынесен из album; `ChatPage.ets:7090` вызывает sendMedia. | Picker, voice, GIF/sticker связаны. Несколько вложений идут отдельно [T15]. Отображение received albums уже есть — это не album send parity. |
| Reactions/polls/scheduled/translation | Есть request paths: `MessageStore.ets:2012`, `:2090`, `:1836`; `services/TranslationService.ets:277`. | Сопоставимые связанные sender/vote/translate/scheduling flows в изученном main ETS не найдены. DTO scheduling field сам по себе не даёт scheduled composer. |
| Search | In-chat и global message/media search: `pages/search/GlobalSearchPage.ets:766`, `pages/chat/SearchSession.ets:193`. | In-chat search реальный (`ChatSearchController.ets:129`), server search пользователей есть в compose (`searchComposeUsers.ets:130`). Chatlist header фильтрует loaded list (`ChatListPage.ets:657`); сопоставимый global message/media search не найден. |
| Server folders | Create/edit/delete/reorder/include/exclude и invite flows: [P16], `FolderEditPage.ets:275`, `ChatFoldersPage.ets:226`. | Settings folder row без action (`SettingsPage.ets:226`); server folder CRUD не найден. Локальные фильтры не являются folders. |
| Forum topics | List/thread navigation и управление: `ForumTopicsPage.ets:152`, `:198`, `:299`. | Найден isForum creation flag, но не связанный topics list/history/manage scenario. |
| Stories | Достижим photo-post (`MyProfilePage.ets:1711 → :1109`). Viewer существует, но обычный UI caller не найден; chatlist launch намеренно отсутствует [P18], profile grids без click. Полный viewer flow не засчитывается. | Active stories загружаются (`loadActiveStories.ets:37`) и preview передаётся (`ChatListPage.ets:1518`); story callbacks не подключены и defaults noop [T17]. Полный viewer/post flow не подтверждён. |
| Calls/live | Profile call buttons → CallSession.createCall [P19] → реальный NativeCallMedia (`Globals.ets:162`). Live/group native paths тоже связаны. Quality соединения не проверена. | История All/Missed и pagination реальны (`CallsPage.ets:380 → loadCalls.ets:73`); create/accept/signaling UI path не найден. Не полноценный call client. |
| Downloads/playback/storage | Download Center pause/resume/cache cleanup: `DownloadCenterPage.ets:435 → DownloadCenterStore.ets:230`; `StorageApi.ets:199`. | Есть media/file pipeline, gallery и общий AVSession/player с account invalidation (`GlobalMediaPlayback.ets:207`, `:330`); Storage settings row без action. |
| Settings/privacy/devices | Реальные notification scopes [P17], privacy rules (`PrivacyApi.ets:124`), proxy (`ProxyPage.ets:867`), sessions/storage pages. | Большинство rows — shell без callbacks [T16]; Recent Calls action есть (`SettingsPage.ets:215`). |
| Localization | Base Chinese + 19 locale catalogs и in-app language selection (`LanguagePage.ets:114`). | Base/ru_RU/zh_CN resources; Language row без picker/action. Системная локализация не равна in-app language selection. |

Сильная сторона Petrelgram — ширина именно связанных поведения/API paths. Сильная сторона вашего проекта — существующая `tg_ui` композиция и выраженные account/route/operation boundaries. Stories показывают ограниченность README/filename анализа: наличие viewer файла не доказывает достижимый пользовательский сценарий.

## 5. Качество проверок и воспроизводимость сборки

После чтения скриптов выполнены только безопасные проверки без изменения исходников и без native/device:

| Проверка этой сессии | Результат | Что она не доказывает |
|---|---|---|
| Petrelgram `node scripts/i18n-check.mjs` | Exit0, `I18N CHECK: PASS`; 3217 strings,75 plurals,19 locales,4201 refs,724 guarded ETS. | Качество перевода, dynamic keys, UI layout, runtime resource resolution. Missing translations и 120 unreferenced keys в этом gate сами по себе не failing. |
| Telegram `node scripts/test-command-serializer-escaping.cjs` | Exit0;198 passed/0 failed;32 Hypium bodies через host,106 mock native send seam calls. | Реальный TDLib/native транспорт, compiler/device execution. |
| Telegram `node scripts/test-host-test-runner.cjs` | Exit0; discovery/empty/failure/signal/spawn/serial continuation/CI path PASS. | Успех всех 62 suites или удалённого CI. |
| Статическая регистрация ETS tests | Petrel347 host +3 ohos modules; Telegram66 ohos modules. Все найденные modules имеют import и call в List. | Исполнение, число успешных cases и assertions. Raw count `it(`3385/804 — только текстовая метрика, не coverage. |

Petrelgram `run-local-tests.sh` не доверяет одному BUILD SUCCESSFUL: проверяет assertion failures, test_result и нижний case count [P23]. Это полезный паттерн. Но clone не содержит `libtdjson.so`, `libtgcalls_ohos.so`, libvpx и rlottie; CMake требует их [P24]. README описывает первые две библиотеки, actual CMake дополнительно требует codec/render dependencies. Полная build/test gate **не запускалась**, бинарники/пакеты не скачивались, credentials/signing не создавались. Versioned prebuilt fetch использует release assets без проверяемого здесь checksum manifest; соответствие binaries source commit неизвестно.

У вашего local tree `.github/workflows/smoke.yml:27` содержит SDK-free host gate, а Harmony build job условен. Runner, часть тестов и bootstrap сейчас untracked относительно HEAD: local PASS нельзя распространять на чистый checkout/remote CI. Существующие сообщения в STATUS о прежних builds не считались новой проверкой этой сессии.

У обоих target SDK `26.0.0`; compatible SDK у Petrelgram `6.0.0(20)`, у вашего проекта `6.1.0(23)`. Petrelgram native ABI profile — arm64-v8a. Эти значения взяты из конкретных build profiles, но ABI/device compatibility не проверялась сборкой.

Найден статический пробел Petrelgram i18n gate: `MIGRATED` не включает `pages/music`, где17 ETS files [P22]. Текущая проверка PASS не доказывает запрет новых Chinese UI literals там. Текущий плохой UI текст не обнаружен; это gap проверки, а не подтверждённая ошибка перевода.

## 6. Лицензия и пределы заимствования

Корневой Petrelgram LICENSE — Apache-2.0. При будущем распространении заимствованного исходного кода нужно учитывать §4: license copy, сохранение применимых notices и обозначение изменённых файлов; §6 отдельно ограничивает использование trademarks. [Pinned LICENSE](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/LICENSE#L90).

Root LICENSE не является лицензией всего native supply chain. В source registry tgcalls указан LGPL-3.0 [P25]; tg_owt/WebRTC, codecs/renderers и зависимости требуют отдельных notices/условий. TDLib upstream содержит Boost Software License1.0. [TDLib license](https://raw.githubusercontent.com/tdlib/td/master/LICENSE_1_0.txt), [tgcalls license](https://raw.githubusercontent.com/TelegramMessenger/tgcalls/master/LICENSE).

`UTYA_DUCK_NOTICE.txt:1–8` указывает источник TGS mascot; это provenance, не разрешение копировать все assets. В вашем root не найден LICENSE, хотя `entry/oh-package.json5:7` содержит MIT: это metadata, а не полный audit прав приложения/TDLib/vendor components. В этой задаче только изучение: сторонний runtime-код, assets и бинарники в приложение не копировались. Анализ лицензий — инвентаризация видимых условий; заключение о пригодности конкретного будущего distributable не делалось.

## 7. Девять полезных паттернов для дальнейшего изучения

Оценки — предварительные человеко-дни для одного разработчика, включая адаптацию к существующим AppStore/use cases/tg_ui и focused tests; полноценная device acceptance и новые native зависимости не включены. Это рекомендации, а не уже выполненные улучшения или новый утверждённый roadmap. Открытые native/reliability gates вашего проекта сохраняют приоритет.

| Приоритет | Конкретный паттерн / источник | Оценка | Минимальная проверяемая цель |
|---|---|---:|---|
| P1 | Album sender: `MessageStore.ets:2363–2410` [P15], GIF split, единые caption/reply | 3–5 | Typed sendMessageAlbum use case; смешанные photo/video и GIF, failure/retry, stale account; получатель получает media_album_id. |
| P1 | Resource gate: `i18n-check.mjs`, placeholder shape, orphan refs, literal guard | 1–3 | Адаптировать checker к своим resource catalogs; negative controls missing key/placeholder; автоматически обнаруживать новые directories, включая music. |
| P1 | Targeted publication: dirty IDs + snapshot per list key + non-starving throttle [P20] | 3–5 | Изучить применение через selectors/bridge, не второй store; benchmark large list/update burst и сохранение entry identity. |
| P1 | Notification scopes: read→edit→commit/rollback, `NotificationApi.ets:41` [P17] | 3–5 | Private/Groups/Channels, loading/error/retry, rollback; сохранить existing chat-level mute semantics. |
| P1 | Serialized folder mutations: `FolderApi.ets:149`, include/exclude/reorder [P16] | 6–10 | Basic server CRUD и update reconciliation; local filters не подменяют server folders. Invite links отдельным срезом. |
| P2 | Global message/media search: opaque cursor и stale-query ownership, `GlobalSearchPage.ets:727,766,842` | 5–8 | Query replacement/pagination/retry и переход в message; сохранить работающий in-chat/compose search. |
| P2 | Forum/topic scoping: `ForumTopicsPage.ets:152,198,299`, `MessageStore.ets:383` | 8–12 | Начать list/navigation; явно scope history/search/send/draft/reply по thread/topic, затем permissions/manage. |
| P2 | Session helper decomposition: Composer/Search/Selection/HeaderIdentity/Membership | 3–6 на узкий срез | Выделить один behavior slice из своей page с единым route/account owner; wiring и behavioural negative controls. Не копировать 9K page целиком. |
| P2 | Download policy: pause/resume/retry/cache registry, `DownloadCenterStore.ets:230,329,399` | 4–7 | Узкий service/use case на существующий file pipeline; отмена/stale account/background limits; затем UI и device witness. |

Отдельно, до расширения функций, вашему current dirty коду полезны focused проверки error classification [T10,T11], delivery recovery [T07,T08], auth error redaction [T12,T13] и native queue/env teardown. Это исправление собственных границ, а не перенос Petrelgram реализации; в этой задаче оно не выполнялось.

**Не стоит переносить напрямую:** Android-oriented shell/dock/glass и message bubbles вместо iOS contract; global client/timeout retirement из Petrelgram; raw string-owning TSFN failure policy без SDK proof; disabled Worker как якобы готовую оптимизацию; orphan StoryViewer; весь Music Center. Calls/live/tgcalls/screen sharing — отдельный native subsystem с audio/video/network/background lifecycle и LGPL/source obligations, не быстрый перенос нескольких ArkTS страниц. Assets тоже требуют отдельного разрешения.

## 8. Таблица ключевых evidence snippets

Ниже фактические короткие source snippets, считанные из checkout, и точные path:line. `P` — clean pinned Petrelgram; `T` — текущий локальный Telegram-HarmonyOS. `M` означает modified относительно HEAD, `?` untracked, `clean` означает только этот файл, а не весь проект. `…` в комментарии таблицы обозначает изученный диапазон, не воспроизведённый runtime. Отсутствие guard проверено по полному указанному методу, а не одной строке.

| ID | Источник / состояние | Path:line и ссылка | Фактическая строка | Что проверяет |
|---|---|---|---|---|
| P01 | Petrelgram / clean pinned | [entry/src/main/ets/tdkit/Globals.ets:113](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/tdkit/Globals.ets#L113) | `const TD_WORKER_BRIDGE_ENABLED: boolean = false;` | Optional Worker выключен |
| P02 | Petrelgram / clean pinned | [entry/src/main/ets/tdkit/TdClient.ets:73](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/tdkit/TdClient.ets#L73) | ``const extra = `req_${this.extraSeq}`;`` | req_N без account generation |
| P03 | Petrelgram / clean pinned | [entry/src/main/ets/tdkit/TdClient.ets:87](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/tdkit/TdClient.ets#L87) | `this.bridge.send(JSON.stringify(requestObj));` | send вызывает bridge |
| P04 | Petrelgram / clean pinned | [entry/src/main/ets/tdkit/TdClient.ets:167](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/tdkit/TdClient.ets#L167) | `dispose(): void {` | dispose: проверены 167–174, disposed gate отсутствует |
| P05 | Petrelgram / clean pinned | [entry/src/main/ets/tdkit/TdClient.ets:190](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/tdkit/TdClient.ets#L190) | `const extra = obj['@extra'] as string \| undefined;` | deliverParsed: проверены 189–225, client_id filter отсутствует |
| P06 | Petrelgram / clean pinned | [entry/src/main/ets/tdkit/AuthService.ets:345](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/tdkit/AuthService.ets#L345) | `logW('AuthService.closeDatabase timed out; recreating TDLib client');` | close timeout: complete() на 346, лимит 5000 на 347 |
| P07 | Petrelgram / clean pinned | [entry/src/main/ets/tdkit/AuthService.ets:351](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/tdkit/AuthService.ets#L351) | `complete();` | close rejection завершает ожидание |
| P08 | Petrelgram / clean pinned | [entry/src/main/ets/tdkit/Globals.ets:377](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/tdkit/Globals.ets#L377) | `testNapi.tdDestroy();` | stopRuntime вызывает native destroy после dispose |
| P09 | Petrelgram / clean pinned | [entry/src/main/cpp/napi_init.cpp:302](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/cpp/napi_init.cpp#L302) | `const char *result = td_receive(0.5);` | Глобальный receive, poll timeout |
| P10 | Petrelgram / clean pinned | [entry/src/main/cpp/napi_init.cpp:375](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/cpp/napi_init.cpp#L375) | `td_send(g_clientId, request);` | Native send использует текущий глобальный ID |
| P11 | Petrelgram / clean pinned | [entry/src/main/cpp/napi_init.cpp:402](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/cpp/napi_init.cpp#L402) | `g_receiveThread.join();` | Синхронный join в TdDestroy |
| P12 | Petrelgram / clean pinned | [entry/src/main/cpp/napi_init.cpp:409](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/cpp/napi_init.cpp#L409) | `g_clientId = 0;` | TdDestroy забывает ID |
| P13 | Petrelgram / clean pinned | [entry/src/main/cpp/napi_init.cpp:331](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/cpp/napi_init.cpp#L331) | `napi_create_threadsafe_function(env, args[0], nullptr, resourceName, 0, 1, nullptr, nullptr,` | TSFN queue size 0 |
| P14 | Petrelgram / clean pinned | [entry/src/main/cpp/napi_init.cpp:307](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/cpp/napi_init.cpp#L307) | `delete copy;` | Delete payload при non-ok enqueue status |
| T01 | Telegram / local working tree (M) | [entry/src/main/ets/infra/td/adapter/TdGatewayAdapter.ets:35](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/infra/td/adapter/TdGatewayAdapter.ets:35) | `this.clientGeneration === this.gateway.getClientGeneration();` | Captured generation gate; identity проверка на 34 |
| T02 | Telegram / local working tree (M) | [entry/src/main/ets/infra/td/gateway/TdGateway.ets:595](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/infra/td/gateway/TdGateway.ets:595) | `if (!this.destroyClosedObserved) {` | Без Closed shutdown отвергается на 598–599 |
| T03 | Telegram / local working tree (M) | [entry/src/main/ets/infra/td/gateway/TdGateway.ets:789](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/infra/td/gateway/TdGateway.ets:789) | `Array.isArray(obj) \|\| obj['@client_id'] !== this.clientId) return false;` | Top-level client_id filter |
| T04 | Telegram / local working tree (M) | [entry/src/main/ets/infra/td/gateway/TdGateway.ets:914](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/infra/td/gateway/TdGateway.ets:914) | `if (generation !== this.clientGeneration && !this.isClosedEnvelope(obj)) return;` | Batch generation и исключение Closed |
| T05 | Telegram / local working tree (M) | [entry/src/main/cpp/tdlib_napi.cpp:465](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/cpp/tdlib_napi.cpp:465) | `if (stop->thread.joinable()) stop->thread.join();` | Join в ExecuteStop async work |
| T06 | Telegram / local working tree (M) | [entry/src/main/cpp/tdlib_napi.cpp:239](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/cpp/tdlib_napi.cpp:239) | `if (env == nullptr \|\| js_callback == nullptr \|\| context == nullptr) return;` | Null-env guard до dereference context |
| T07 | Telegram / local working tree (M) | [entry/src/main/cpp/tdlib_napi.cpp:247](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/cpp/tdlib_napi.cpp:247) | `delivery->batches.pop_front();` | Batch удаляется до conversion |
| T08 | Telegram / local working tree (M) | [entry/src/main/cpp/tdlib_napi.cpp:253](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/cpp/tdlib_napi.cpp:253) | `if (napi_create_string_utf8(env, batch.c_str(), batch.length(), &argv[0]) != napi_ok) {` | Conversion failure returns на 255 |
| T09 | Telegram / local working tree (M) | [entry/src/main/cpp/tdlib_napi.cpp:350](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/cpp/tdlib_napi.cpp:350) | `0, 1, context.get(), FinalizeDelivery, context.get(),` | TSFN queue size 0 |
| T10 | Telegram / local working tree (M) | [entry/src/main/ets/infra/td/adapter/TdGatewayAdapter.ets:93](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/infra/td/adapter/TdGatewayAdapter.ets:93) | `GatewayErrorCode.CONNECTION_FAILED,` | Adapter заменяет классификацию ошибок |
| T11 | Telegram / local working tree (clean) | [entry/src/main/ets/domain/ports/TdGatewayPort.ets:47](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/domain/ports/TdGatewayPort.ets:47) | `super(AppErrorKind.NETWORK, message, technicalMessage, 0, true);` | GatewayError: NETWORK, code0, retryable=true |
| T12 | Telegram / local working tree (M) | [entry/src/main/ets/infra/td/adapter/TdGatewayAdapter.ets:90](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/infra/td/adapter/TdGatewayAdapter.ets:90) | `hilog.error(DOMAIN, TAG, 'Command %{public}s failed: %{public}s (tdlib: %{public}s code: %{public}d)',` | Public error detail на 90–91 |
| T13 | Telegram / local working tree (M) | [entry/src/main/ets/ui/controllers/LoginController.ets:280](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/controllers/LoginController.ets:280) | `hilog.error(DOMAIN, TAG, 'checkPassword failed: %{public}s', err.message);` | Password error message логируется public |
| T14 | Telegram / local working tree (M) | [entry/src/main/ets/models/td/common/index.ets:144](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/models/td/common/index.ets:144) | `return this.getInt64String(prop);` | Top-level getter fallback к generic accessor |
| P15 | Petrelgram / clean pinned | [entry/src/main/ets/store/MessageStore.ets:2387](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/store/MessageStore.ets#L2387) | `'@type': items.length > 1 ? 'sendMessageAlbum' : 'sendMessage'` | Настоящий album request для нескольких media |
| T15 | Telegram / local working tree (M) | [entry/src/main/ets/ui/pages/chat/ChatComposerController.ets:333](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/ChatComposerController.ets:333) | `await useCase.execute(params);` | Цикл 315–333: отдельный use case на вложение |
| P16 | Petrelgram / clean pinned | [entry/src/main/ets/store/FolderApi.ets:141](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/store/FolderApi.ets#L141) | `const request: TdRequest = { '@type': folder.id === 0 ? 'createChatFolder' : 'editChatFolder' };` | Create/edit server folders |
| P17 | Petrelgram / clean pinned | [entry/src/main/ets/store/NotificationApi.ets:52](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/store/NotificationApi.ets#L52) | `const request: TdRequest = { '@type': 'setScopeNotificationSettings' };` | Server notification scopes |
| T16 | Telegram / local working tree (M) | [entry/src/main/ets/ui/pages/settings/SettingsPage.ets:247](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/settings/SettingsPage.ets:247) | `title: localized($r('app.string.settings_notifications_sounds').id, 'Notifications and Sounds'),` | Проверены 246–252: row без onRowClick |
| T17 | Telegram / local working tree (clean) | [entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets:45](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets:45) | `@Event onStoryPress: () => void = (): void => {};` | Story action default noop |
| P18 | Petrelgram / clean pinned | [entry/src/main/ets/pages/chatlist/MainTabBody.ets:734](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/pages/chatlist/MainTabBody.ets#L734) | `// StoryViewerPage are kept, but nothing on the chat list launches them.` | Нет chatlist launch story viewer |
| P19 | Petrelgram / clean pinned | [entry/src/main/ets/services/CallSession.ets:104](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/services/CallSession.ets#L104) | `const req: TdRequest = { '@type': 'createCall' };` | createCall в реальном service |
| P20 | Petrelgram / clean pinned | [entry/src/main/ets/store/ChatStore.ets:1373](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/store/ChatStore.ets#L1373) | `this.dirtyChatIds.add(chatId);` | Dirty chat IDs для targeted publication |
| P21 | Petrelgram / clean pinned | [entry/src/main/ets/store/ChatStore.ets:1423](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/store/ChatStore.ets#L1423) | `s.listener(snapshot);` | Observer fanout без per-listener isolation |
| P22 | Petrelgram / clean pinned | [scripts/i18n-config.mjs:80](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/scripts/i18n-config.mjs#L80) | ``return MIGRATED.some((dir) => posix === dir \|\| posix.startsWith(`${dir}/`));`` | Guard зависит от ручного MIGRATED |
| P23 | Petrelgram / clean pinned | [scripts/run-local-tests.sh:33](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/scripts/run-local-tests.sh#L33) | `MIN_TESTS="${MIN_TESTS:-2459}"` | Нижняя граница числа выполненных cases |
| P24 | Petrelgram / clean pinned | [entry/src/main/cpp/CMakeLists.txt:43](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/cpp/CMakeLists.txt#L43) | `"缺 libvpx：先跑 bash scripts/build-libvpx-ohos.sh（产物不进版本库）")` | Clean clone не содержит обязательный libvpx |
| P25 | Petrelgram / clean pinned | [scripts/tgcalls/README.md:59](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/scripts/tgcalls/README.md#L59) | `Licensing: tgcalls is LGPL-3.0; tg_owt/WebRTC and their bundled dependencies` | Native LGPL boundary |

Дополнительные публичные источники функциональной и архитектурной матрицы:

| Область | Дополнительный pinned public source |
|---|---|
| Petrelgram source | [entry/src/main/ets/tdkit/Globals.ets:133](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/tdkit/Globals.ets#L133) |
| Petrelgram source | [entry/src/main/ets/tdkit/Globals.ets:430](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/tdkit/Globals.ets#L430) |
| Petrelgram source | [entry/src/main/ets/pages/chatlist/ChatRow.ets:522](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/pages/chatlist/ChatRow.ets#L522) |
| Petrelgram source | [entry/src/main/ets/store/ChatActions.ets:141](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/store/ChatActions.ets#L141) |
| Petrelgram source | [entry/src/main/ets/store/MessageStore.ets:1772](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/store/MessageStore.ets#L1772) |
| Petrelgram source | [entry/src/main/ets/store/ForwardDirect.ets:31](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/store/ForwardDirect.ets#L31) |
| Petrelgram source | [entry/src/main/ets/store/MessageStore.ets:2012](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/store/MessageStore.ets#L2012) |
| Petrelgram source | [entry/src/main/ets/store/MessageStore.ets:2090](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/store/MessageStore.ets#L2090) |
| Petrelgram source | [entry/src/main/ets/services/TranslationService.ets:277](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/services/TranslationService.ets#L277) |
| Petrelgram source | [entry/src/main/ets/pages/search/GlobalSearchPage.ets:766](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/pages/search/GlobalSearchPage.ets#L766) |
| Petrelgram source | [entry/src/main/ets/pages/chat/SearchSession.ets:193](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/pages/chat/SearchSession.ets#L193) |
| Petrelgram source | [entry/src/main/ets/pages/chat/ForumTopicsPage.ets:152](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/pages/chat/ForumTopicsPage.ets#L152) |
| Petrelgram source | [entry/src/main/ets/pages/main/MyProfilePage.ets:1109](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/pages/main/MyProfilePage.ets#L1109) |
| Petrelgram source | [entry/src/main/ets/pages/main/DownloadCenterPage.ets:435](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/pages/main/DownloadCenterPage.ets#L435) |
| Petrelgram source | [entry/src/main/ets/store/DownloadCenterStore.ets:230](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/store/DownloadCenterStore.ets#L230) |
| Petrelgram source | [entry/src/main/ets/store/PrivacyApi.ets:124](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/store/PrivacyApi.ets#L124) |
| Petrelgram source | [entry/src/main/ets/pages/main/LanguagePage.ets:114](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/pages/main/LanguagePage.ets#L114) |
| Petrelgram source | [entry/src/main/ets/store/ChatStore.ets:286](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/entry/src/main/ets/store/ChatStore.ets#L286) |

## 9. Локальный результат и ограничения

Petrelgram добавлен в принятый `REFERENCES.md` с origin, canonical path, branch, SHA, фактической структурой, лицензиями и ссылкой на этот отчёт. `STATUS.md`, `TASKS/TODO.md`, `TASKS/LESSONS.md` обновлены короткими reference-only записями; прежние runtime outcomes не переписаны. Этот отчёт: `docs/reviews/2026-10-01-petrelgram-comparison.md`; supporting evidence: `docs/reviews/2026-10-01-petrelgram-evidence.json`.

Проверены существование cited paths/lines, registry markdown row, local report links, git diff/status и Git eligibility документов. Все исходные пользовательские файлы вне четырёх намеренно дополненных документов совпадают с baseline SHA-256; для этих четырёх отдельно проверено, что удаление наших точных вставок и восстановление даты даёт исходные bytes. HEAD/ветка/index сохранены; Petrelgram остаётся clean. Runtime/build/dependency manifests не менялись. Commit/push/PR/merge не выполнялись.

Оставшиеся ограничения сравнения: нет fresh builds обоих checkout, full test execution, packaged `.so` audit, current device/UI/iOS witnesses, performance benchmarks и воспроизведения conditional native/account races. Сеть/доступ клонирование не блокировали; отсутствующие Petrelgram build inputs и недоступный harmonyos_docs не обходились.
