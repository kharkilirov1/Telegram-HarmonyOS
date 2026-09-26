# План укрепления архитектуры Telegram-HarmonyOS

Tracking issue: [#198](https://github.com/kharkilirov1/Telegram-HarmonyOS/issues/198).

Дата: 2026-09-26. База анализа: `dev`, `2d2f68391e259fa83e4c3e09f38841cc08c235d1`.

Статус: предложен план реализации. После расширенного ревью добавлены B1–B4 и [23 группы находок](CODE_REVIEW_2026-09-26.md). PR содержит документы и host-репродукторы известных дефектов; runtime не исправлен, этапы ниже не выполнены. Историческая заморозка в [STATUS.md](../STATUS.md) сохраняется; текущий запрос пользователя разрешает подготовить план, tracking issue и PR. Каждый этап реализации предлагается отдельным небольшим PR в `dev`. Это датированное дополнение к [каноническому release roadmap](AGENT_EXECUTION_PLAN.md); архивные `docs/ai/*`, принятые `DECISIONS.md` и merge `dev→main` этот PR не пересматривает.

## 1. Цель и границы

Сохранить существующие UI-компоненты, use cases, reducers и TDLib. Первоначальные четыре области:

1. Управление жизнью сессии, повторным входом и восстановлением после ошибок.
2. Владение native-потоком, callback и очередями.
3. Корректное преобразование JSON TDLib в данные приложения, включая точные int64.
4. Проверяемость поведения и разделение обязанностей экрана чата.

Расширенное ревью добавило обязательные области: целостность DTO/state pipeline (B1), корректность пользовательских mutations и черновиков (B2), владение media-операциями (B3), безопасные логи и стоимость production-проверок (B4). Конкретные условия, locations и доказательства — в [CODE_REVIEW_2026-09-26.md](CODE_REVIEW_2026-09-26.md).

Первый полезный результат: выход/отмена входа и повторная инициализация не оставляют приложение с закрытым клиентом или устаревшим адаптером. Следующий: задержанные события не пересекают границу сессии, поля JSON читаются на правильном уровне, перегрузка имеет определённое поведение.

Изменение дизайна, новые функции Telegram, переход на другой UI-фреймворк, мультиаккаунт и полная перепись приложения в этот план не входят. Базовая модель — один активный клиент приложения и один получатель общего потока `td_receive` в процессе.

## 2. Основания и степень подтверждения

| Наблюдение | Где | Подтверждение и ограничение |
|---|---|---|
| После `authorizationStateClosed` сбрасываются флаги, но новый клиент не создаётся; gateway остаётся `ready` | [AuthSideEffect](../entry/src/main/ets/core/sideeffects/AuthSideEffect.ets), [LoginController](../entry/src/main/ets/ui/controllers/LoginController.ets), [TdGateway](../entry/src/main/ets/infra/td/gateway/TdGateway.ets) | Проверены исходники и обработчик в host-стенде с fake TDLib. Реальный `logOut` закрывает экземпляр; нужен новый клиент. При отказе `logOut` нельзя считать выход успешным |
| `LoginController` сохраняет прежний adapter/gateway после reset runtime | [LoginController](../entry/src/main/ets/ui/controllers/LoginController.ets), [TdGatewayAdapter](../entry/src/main/ets/infra/td/adapter/TdGatewayAdapter.ets), [AppCoreRuntime](../entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets) | В host-стенде новый gateway был `ready`, а отправка через прежний контроллер завершилась ошибкой до native send |
| После таймаута `close` callback старого запуска может доставить update новому gateway | [TdGateway](../entry/src/main/ets/infra/td/gateway/TdGateway.ets), [MainThreadDispatcher](../entry/src/main/ets/infra/threading/MainThreadDispatcher.ets), [AppCoreRuntime](../entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets) | Управляемый replay задержанного callback: client 2 попал в gateway client 3. Это условный сценарий при timeout/restart; он не доказывает нарушение FIFO после успешного получения финального `Closed` |
| Regex-getter читает вложенное поле вместо верхнего | [TdObject](../entry/src/main/ets/models/td/common/index.ets) | На исходном модуле `getNumber('id')` для `{"nested":{"id":7},"id":42}` вернул `7`; для `{"nested":{"id":7}}` тоже вернул `7` |
| Native-мост игнорирует статусы TSFN, не освобождает payload при `env == nullptr`, имеет неограниченную очередь и синхронный `join` | [tdlib_napi.cpp](../entry/src/main/cpp/tdlib_napi.cpp), [napi_init.cpp](../entry/src/main/cpp/napi_init.cpp) | Host C++ harness подтвердил Running без TSFN, env-null payload leak и stop около 3,4 с на управляемом потоке. Поведение конкретного SDK teardown и нагрузка требуют native/device tests |
| CI не запускает поведенческие тесты; HarmonyOS build включается отдельно | [smoke.yml](../.github/workflows/smoke.yml), [smoke-ui-phase0.sh](../scripts/smoke-ui-phase0.sh) | Проверен workflow: обязательны документы и статические UI-контракты. Сборка тестового HAP сама по себе не означает выполнение тестов |

Уровень P0 по этим данным не установлен. Ошибки входа/перезапуска рассматриваются как кандидаты P1 с указанными условиями. Архитектурные улучшения не получают аварийный приоритет только из-за размера файла.

Host-проверка ArkTS после удаления типов проверяет исполняемую логику, но не заменяет компилятор ArkTS, N-API runtime и запуск на устройстве. В текущем окружении не было HarmonyOS SDK и prebuilt TDLib; HAP не собирался. Исходный submodule TDLib закреплён на `cb863c1600082404428f1a84e407b866b9d412a8`, но соответствие локальных prebuilt-библиотек этому SHA пока не проверено.

Не считать подтверждёнными сбоями текущего приложения:

- Одновременный `Receive()` и background receive: экспорт существует, вызовов обычного `receive()` в ArkTS не найдено.
- Конкурентный `Start/Stop` из разных JS-env: использования TDLib из Worker в текущем приложении не найдено. Native API всё равно должен явно ограничивать владельца.
- Дедлок из-за заполнения нынешней TSFN-очереди: `max_queue_size = 0` не ждёт свободного места. Ограничение очереди требует одновременно изменить протокол остановки.
- Переполнение только из-за `str_len + 1`: при корректной длине и нулевом терминаторе это не установленная ошибка C++17.

## 3. Целевая организация

Названия новых типов ниже рабочие. Нужны явное владение и небольшие интерфейсы; отдельный DI-фреймворк не требуется.

| Компонент | Ответственность | Граница |
|---|---|---|
| `AppCoreRuntime` | Собрать зависимости приложения, подключить store и UI-bridge | Не распределяет перезапуск по независимым singleton-reset |
| `SessionCoordinator` | Состояние сессии, generation, создание и завершение gateway, намерение restart/stop/logout | Единственное место, решающее, нужен ли новый клиент |
| `TdGateway` | Request/response correlation, timeout, доставка допустимых updates | Проверяет generation и `@client_id`; не ищет актуальный gateway через глобальный singleton в старом callback |
| Native transport port | Один receiver, TSFN, владение env и payload, асинхронная остановка | Передаёт ошибки запуска/остановки; не объявляет запуск успешным до готовности ресурсов |
| `TdJsonCodec` + DTO adapters | Разбор, типы полей, точные ID, проверка входных данных | Одна согласованная граница для native batch и domain-моделей |
| Контроллеры чата | Отдельные обязанности timeline, composer, media, lifecycle | Получают зависимости и освобождают свои подписки/таймеры |

### Инварианты сессии

- Транспортная готовность и авторизация пользователя — разные состояния. `ready` gateway не равно `authorizationStateReady`.
- Lifecycle: `idle → starting → running → stopping → idle`; ошибки запуска/остановки дают определённое состояние `failed`, без второго получателя поверх незавершённого первого.
- Одновременные вызовы `start()` разделяют одну операцию; повторный `stop()` возвращает promise уже начатой остановки. Запуск во время остановки ждёт её завершения либо возвращает документированную ошибку.
- При начале stop прекращаются новые пользовательские команды и побочные эффекты. Ответ на `close` и финальный `Closed` того же клиента продолжают приниматься до завершения graceful shutdown или timeout. Нельзя отключить весь callback до завершения этого ожидания.
- После завершения/таймаута старого запуска его generation недействителен. Любой поздний callback, timer, retry или response проверяет принадлежность сессии до воздействия на новую.
- Все pending requests завершаются ровно один раз. Correlation key содержит generation; старый timeout не удаляет новый запрос.
- Intent `logout-and-restart` создаёт новый клиент только после подтверждения освобождения старого. Intent `shutdown` не запускает новый клиент после `Closed`. Timeout без подтверждённого закрытия не разрешает немедленно открыть вторую TDLib на той же БД.
- Контроллеры создаются вместе с сессией либо используют стабильный session-provider. Асинхронная команда сохраняет исходную generation; её retry не переключается незаметно на нового пользователя.

## 4. Этапы и небольшие PR

Порядок после расширенного ревью: A0 (build bootstrap и проверки) → первые P1 из A1/B1/B3 → оставшиеся A2/A3/B1/B2/B3/B4 → A4 → A5. Локальные исправления отрицательных chat ID, sending_state и recorder ownership не ждут полного архитектурного рефакторинга. A3 и независимые B-срезы можно готовить параллельно после A0; переключение gateway на codec согласуется с A1/A2. A4 начинается после исправления поведения и стабилизации API. По одному изменению поведения на PR; UI-полиш и SDK-upgrade не смешивать. Native/device-проверки входят в приёмку соответствующих PR; A5 повторяет общую матрицу, а не откладывает платформенную проверку до конца. При недоступном стенде affected PR остаётся с явно незавершённой runtime-приёмкой.

### A0. Воспроизводимые проверки и исходная точка

**PR:** `test: establish architecture regression harness`.

- Восстановить отсутствующий `tools/hvigor/hvigor-ohos-plugin-compat`, импортируемый корневым `hvigorfile.ts`, либо заменить штатным bootstrap; подтвердить build чистого checkout (R05).
- Исправить BRE/ERE-проверку hex в Bash smoke и доказать её отрицательным fixture (R23).
- Закрепить базовый commit, фактические SDK/API/NDK, ABI, TDLib version/SHA и контрольную сумму prebuilt. `SONAME` в CMake не считать доказательством версии бинарника.
- Добавить host-runner для чистой логики, fake transport, управляемые часы и задержанные callbacks. В [audit artifacts](../scripts/review/2026-09-26/README.md) уже сохранены исполнимые воспроизведения; они утверждают наличие дефектов. Перенести fixtures в suite ожидаемого корректного поведения вместе с fixes, не подключать audit runner как release gate.
- Сохранить JSON fixtures с повторяющимися вложенными ключами, экранированием и большими ID. Использовать синтетические данные, без переписок и авторизационных секретов.
- В CI выполнять поведенческие host-тесты. Существующий UI smoke оставить дополнительной проверкой; утверждение о наличии строки в коде не заменяет assertion результата.
- Добавлять тест ожидаемого исправленного поведения вместе с соответствующим фиксирующим PR: зафиксировать, что он падает на базе и проходит после изменения. Не оставлять красную default-ветку или бессрочно отключённые регрессии.

**Готово, когда:** чистая среда запускает проверки одной документированной командой; есть контроль, что намеренное нарушение проверяемого поведения делает suite красным; отчёт различает host tests, ArkTS compile и device tests.

### A1. Согласованное владение сессией и восстановление входа

**PR 1:** `refactor: make session ownership explicit` — coordinator, transport port, injected/captured зависимости вместо позднего поиска singleton; адаптер совместимости для существующих use cases.

**PR 2:** `fix: restart closed clients and reject stale session work` — logout/Closed, generation, client filtering через корректное чтение верхнего уровня, обновление LoginController и правил повторного запуска.

Основные файлы: `AppCoreRuntime.ets`, `TdGateway.ets`, `TdGatewayAdapter.ets`, `MainThreadDispatcher.ets`, `AuthSideEffect.ets`, `LoginController.ets`, `LoginRouter.ets`, `EntryAbility.ets`.

- Отдельно определить отмену pre-auth входа и полноценный logout. Не приравнивать `logOut` к `auth.cancelCode`; ошибка logout не означает успешный серверный сброс.
- Во время закрытия сохранять доступность служебных ответов и `Closed`, не отдавая старые UI-эффекты новой сессии.
- Guard generation действует и на вход callback, и на уже поставленную ArkTS-очередь. Проверять `@client_id` до маршрутизации элемента. Не использовать для envelope небезопасные regex-getters; минимальный корректный reader envelope входит в этот PR, полный codec мигрирует в A3.
- Сбрасывать либо переустанавливать все session-scoped зависимости. Не чинить только singleton gateway, оставляя controller/use case со старой ссылкой.
- Не создавать новый singleton из shutdown-кода. Возможность безопасно перезапустить runtime проверять отдельно от завершения процесса.

**Готово, когда:** нормальный close, отказ close, timeout, два stop, start во время stop и logout/relogin имеют проверенные исходы; новый send использует новый клиент; old callback/request/timer не изменяет новую сессию; shutdown не запускает повторный вход.

### A2. Native-мост: ресурсы, остановка и управляемая перегрузка

**PR 1:** `fix: enforce native transport ownership and error handling`.

- Явно закрепить один env-владелец process-wide receiver. Вызов из другого env возвращает ошибку, не меняя callback действующего владельца.
- Убрать доступность конкурирующего sync `receive` либо отклонять его при работающем loop под общей синхронизацией. Простая отдельная проверка atomic перед чтением не устраняет гонку.
- Проверять N-API статусы; при ошибке создания TSFN/потока откатывать частичную инициализацию и сообщать ошибку ArkTS. Перехватывать C++-исключения на границе N-API.
- Определить владение payload: до успешного enqueue — producer; после — callback. RAII освобождает payload при неуспехе и при невозможности вызвать JS. Ветка `napi_closing` завершает использование TSFN согласно контракту установленной версии OpenHarmony.
- Зарегистрировать cleanup на уничтожение env; согласовать stop, cleanup и TSFN finalizer. После завершения cleanup поток не обращается к уничтоженному env/TSFN.

**PR 2:** `fix: stop receive loop asynchronously and bound ingress`.

- Сделать stop асинхронным для ArkTS; атомарно закреплять принадлежность `std::thread` одной операции join. `Stopped` публикуется после завершения согласованной операции остановки.
- Проверять stop внутри набора batch и предусмотреть пробуждение ожидающего producer. Определить deadline остановки; timeout переводит transport в явное failed-состояние, а не в ложный успех.
- Ограничить совокупный ingress: native pending bytes/items + очередь ArkTS. Лимит только TSFN не помогает, если callback немедленно переносит всё в безразмерный `pendingBatchQueue`.
- Перед изменением размеров очередей измерить backlog и задержки. Предлагаемый механизм: лимит in-flight batches/bytes, acknowledgement после обработки ArkTS и освобождение ожидания при stop. Конкретные лимиты выбрать по измеренному профилю, а не произвольной константой.
- Сохранить порядок updates. Requests и authorization updates не терять молча. При достижении жёсткого лимита/oversized payload — явная ошибка transport с описанным восстановлением; coalescing допустим только для отдельных доказанно заменяемых событий.
- Ранний выход из receive loop и отказ transport должны дойти до coordinator и завершить pending requests. Ограничение bridge-очереди не заявлять как ограничение всей памяти TDLib.

**Готово, когда:** fault tests проверяют create failure, rejected enqueue, closing TSFN, env cleanup и thread-start failure; stop не блокирует JS; native handles/payloads освобождаются; заданный медленный consumer не приводит к бесконечному росту bridge backlog и не нарушает порядок. На поддерживаемом host-стенде применить sanitizers для сценариев владения памятью.

### A3. Корректный JSON-контракт от native batch до DTO

**PR 1:** `fix: introduce lossless TDLib JSON codec` — типы, fixtures и codec за существующим интерфейсом.

**PR 2:** `refactor: route TDLib batches through the codec` — заменить gateway parse/stringify и последовательно мигрировать getters/DTO, затем удалить ненужные regex helpers.

Основные файлы: `models/td/common/index.ets`, `TdGateway.ets`, `tdAccessors.ets`, DTO parsers, normalizers, `CommandSerializer.ets`.

- Разбирать объект структурно; отсутствующее верхнее поле не искать во вложенных объектах. Отдельно проверить fallback `getTopLevelInt64String`, который сейчас возвращается к общему getter.
- Сохранять различие отсутствующего значения, `null`, `false`, нуля и пустой строки. Domain-defaults назначать в DTO, а ошибки/неизвестные варианты сохранять явно.
- До выбора реализации проверить совместимость с используемым ArkTS. Предпочесть поддерживаемый lossless parser; если требуется адаптер поверх сырого JSON, он обязан учитывать грамматику строк/чисел и иметь самостоятельные conformance-тесты.
- Точные ID вне безопасного диапазона JS Number сохранять строкой или другим точным представлением на всём пути. Для внешнего TDLib wire-format учитывать типы из схемы; не превращать все числа в строки без разбора.
- Устранить раннюю потерю точности: текущий `JSON.parse(batchJson)` → `JSON.stringify(obj)` происходит до `TdObject`. Исправление одного `getInt64String` не восстанавливает уже округлённое число.
- Разрешённые по схеме quoted int64 сохранять точно. Для unquoted больших чисел явно проверять lossless поведение и обработку недопустимого типа. Не объявлять все реальные TDLib ID потерянными без проверки wire fixtures.
- Correlation `@extra`, `@client_id`, вложенные `@type`, Unicode, escaped quotes/backslashes, массивы и неверный JSON входят в проверку. Проверить границы ±int64, `2^53−1`, `2^53`, `2^53+1` и независимость результата от порядка вызовов getters/кэша. Не логировать сырые пользовательские payloads при parse errors.

**Готово, когда:** пример `{"nested":{"id":7},"id":42}` даёт `42`; отсутствие верхнего `id` не даёт `7`; число `9007199254740993` сохраняется точно там, где контракт допускает такой ID; batch → DTO → command сохраняет значения; неправильный payload даёт наблюдаемую ошибку без повреждения store. Нагрузка сравнивается на одном наборе fixtures до/после.

### A4. Разделение экрана чата по обязанностям

**PR:** отдельный небольшой PR на каждый перенос: timeline/history → composer/panels → screen lifecycle/subscriptions.

Стартовая точка: `TgChatScreenPage.ets` — 5331 строка на базовом commit. Размер служит сигналом для изучения, а не критерием успешности рефакторинга.

- Сначала составить карту состояния и зависимостей экрана. Уже есть `ChatComposerController`, `ChatSearchController`, `ChatMessageActionsController`, `ChatMediaDownloadController`, `ChatVoiceRecordingController`, `VoicePlaybackController` и `ReplyHydrationCoordinator`; расширять их ответственность только там, где она совпадает, не создавать дубли.
- Оставить экрану композицию ArkUI, параметры навигации и связывание UI с контроллерами. Выделять оставшуюся логику состояния и async-операций с явным attach/detach.
- Для каждого таймера, listener и async continuation указать владельца и способ отмены. Не переносить сложность в глобальный singleton.
- Сохранять ownership `@Local`, identity элементов списка, текущие геометрию, прокрутку, клавиатуру, draft flush, reply, media и навигацию; не менять визуальное поведение в PR извлечения.

**Готово, когда:** каждую выделенную логику можно проверить без создания ArkUI-экрана; повторное открытие чата не умножает подписки; подтверждены scroll anchor, pagination, draft/reply и media cleanup; контрольные скриншоты до/после не показывают непреднамеренных изменений.

### A5. Проверка целой цепочки и критерии выпуска

**PR:** `ci: enforce session and transport regression gates` плюс итоговый отчёт о проверках.

- Host behavioral suite работает с A0 и расширяется каждым PR. Зафиксировать обязательные release gates: ArkTS compile, HAP build, выполнение device-сценариев и проверка lifecycle native-моста.
- Сборка `ohosTest` и выполнение тестов — разные результаты; отчёт содержит команду, число запущенных/пройденных тестов, commit, SDK и TDLib artifact identity.
- Использовать существующий self-hosted HarmonyOS runner либо подготовленный локальный стенд. Недоступность стенда обозначать «не проверено», а не зелёным результатом. Включение branch protection выполняется отдельно при готовности runner и прав доступа.
- Проверить cold start, pre-auth Back, отказ logout, успешный logout/relogin, reset во время pending request, timeout close, медленный JS-consumer, повторное открытие чата и фон/возврат.
- Повторить сценарии B1–B4 на устройстве: creation без повторной mutation, offline/failed send и history reload, jump при pagination, read/mentions, draft/edit/partial media retry, cancel/retry recorder, playback stop во время create/Next.
- Отдельно проверить ARM64 device product: текущий глобальный `x86_64` ABI не переопределяется release-конфигурацией. Решить и документировать границу регистрации нового аккаунта (`waitRegistration` сейчас отменяется).
- Сравнить p95/p99 длительность обработки batch/JS slices, stop latency, peak backlog bytes/items и память после прогрева серии restart. Пороговые значения согласовать по baseline A0 и ограничениям устройства до признания этапа выполненным.

**Готово, когда:** пройдена матрица ниже; нет необъяснённого монотонного роста session-owned ресурсов в 100 restart-циклах host-стенда и 20 циклах на устройстве; сценарии без сети/с отказами заканчиваются определённым состоянием; в отчёте явно перечислены оставшиеся ограничения.

## 5. Матрица обязательных регрессий

| Сценарий | Ожидаемый результат | Проверка |
|---|---|---|
| start дважды; start во время stop; stop дважды | Один receiver, одна операция завершения, определённый итог | Host + native harness; device smoke |
| Успешный logout/relogin | Старый клиент закрыт, новый создан, отправка идёт через новый adapter | Fake TDLib + device |
| Ошибка logout / отмена pre-auth | UI не объявляет серверный сброс успешным без подтверждения | Host + device |
| `Closed` раньше ответа `close` | Закрытие распознано, нет ложного дополнительного ожидания | Host |
| `close` timeout и поздний update/response | Старый generation не воздействует на новый; БД не открывается конкурентно | Host + native/device |
| Отказ создания TSFN/потока | Start отклонён, нет `ready`, ресурсы освобождены | Native fault harness |
| Enqueue failure / teardown env | Нет утечки payload, повторного обращения к уничтоженному handle | Native harness + device |
| Медленный consumer и stop при заполненной очереди | Backlog ограничен, stop завершается, ошибки доставки видимы | Host/native stress + device |
| Вложенные одинаковые ключи, отсутствующее верхнее поле | Читается только текущий объект | Codec tests |
| Quoted/unquoted int64 и batch round-trip | Точные значения или явный отказ по контракту; нет молчаливого округления | Codec + gateway integration |
| Неверный JSON, null, Unicode, escape sequences | Предсказуемая обработка, store остаётся целым | Codec fixtures |
| Открыть/закрыть чат 20 раз | Нет дублирующихся listeners; draft, scroll и media корректны | Host controllers + device |

## 6. Миграция, откат и порядок приёмки

1. В каждом PR: проблема, изменение поведения, воспроизведение до фикса, проверки после, ограничения и способ отката.
2. Публичный domain port сохранять через адаптер совместимости, пока все потребители не переведены. Все изменения сигнатуры `stopReceiveLoop` проводить вместе с C++, `.d.ts` и ArkTS callers.
3. Миграция не меняет формат TDLib БД. Проверки реального logout удаляют локальные данные по контракту TDLib и требуют отдельной тестовой сессии; обычный shutdown проверять через `close`.
4. Откат — revert одного этапа к проверенному baseline вместе с зависимыми адаптерами/тестами. Не включать старый и новый receive loop одновременно. При откате codec/session fix явно возвращается известный дефект; такой rollback не считается готовностью к выпуску.
5. UI-извлечение можно остановить после любого принятого среза. Критерий — понятное владение, меньшая связанность и сохранённое поведение; целевого числа файлов/строк нет.
6. Tracking issue остаётся открытым после merge документа. Закрытие — после A0–A5 и B1–B4 или явно согласованного сокращения объёма с указанием оставшихся задач.

## 7. Чеклист tracking issue

- [ ] A0: воспроизводимый baseline и выполняемые host-проверки.
- [ ] A1: session owner, logout/restart, отсутствие устаревших зависимостей и событий.
- [ ] A2: native lifecycle, ошибки, async stop, ограниченный ingress.
- [ ] A3: структурный codec и точные ID на всём пути.
- [ ] A4: постепенное выделение обязанностей экрана чата.
- [ ] A5: device-регрессии, замеры и обязательные критерии выпуска.
- [ ] B1: контракты DTO, маршрутизация событий, history и команды чатов.
- [ ] B2: draft/edit ownership, подтверждённый прогресс отправки, caption command.
- [ ] B3: владение recording/playback/download операциями.
- [ ] B4: credential logging и стоимость production invariants.

## 8. Контракты внешних API

- [TDLib logOut](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1log_out.html): закрывает экземпляр после выхода.
- [TDLib authorizationStateClosed](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1authorization_state_closed.html): финальное состояние; для дальнейшей работы нужен новый клиент.
- [TDLib JSON interface](https://core.telegram.org/tdlib/docs/td__json__client_8h.html): один одновременный получатель `td_receive`.
- [OpenHarmony N-API data types](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/napi/napi-data-types-interfaces.md): TSFN modes; точные lifetime/cleanup-гарантии дополнительно сверяются с SDK проекта в A0/A2.


## 9. Дополнение по широкому ревью: B1–B4

Это обязательные срезы стабилизации до структурного A4, а не повод переписать все слои. ID Rxx отсылают к [отчёту](CODE_REVIEW_2026-09-26.md). Один B-этап может содержать несколько небольших PR по самостоятельным причинам ошибок.

### B1. Контракты данных, состояния и команд чатов

**Первыми:** R02 (отрицательные ID) и R03 (sending_state). Остальные: R08–R13. JSON R06/R07 входит в A3; минимальные локальные исправления не должны ждать полной миграции codec.

- Различать chat/user/message/file IDs на границах и в fixtures; server success сохранять до локальной hydration/navigation, retry не повторяет уже committed создание.
- Согласовать full DTO и partial updates: sending state/error, mentions, reply origin и остальные поддерживаемые поля. Не терять метаданные в ручных clones.
- Сделать routing supported events исчерпывающим и проверять через настоящий `appReducer`. Не добавлять второй event bus.
- Различать неизвестную chat position и подтверждённое отсутствие в списке.
- Ввести generation окна истории, общую для primary/older/newer; reset происходит только при принятой новой операции. Поздний ответ не меняет текущее окно и cursors.
- «Прочитано» обрабатывает actual unread и manual unread по разным TDLib контрактам.

**Приёмка:** negative group/channel creation признаётся успешным; pending/failed переживают history reload; aggregate 150 не заменяется partial sum 2; reset реально проходит root reducer; removed chat исчезает; jump не смешивает разорванные окна; download сохраняет cross-chat reply; snapshot mention count совпадает с partial update; mark-read отправляет нужные команды и выбирает актуальный read target даже при загруженном старом окне после jump.

### B2. Composer, edit и подтверждённый прогресс отправки

**Находки:** R14–R16.

- Ввести snapshot/revision операции composer и отдельный edit buffer. Завершение/ошибка Promise изменяет только собственную версию; новый текст, entities, reply и вложения сохраняются.
- Track accepted media items: retry повторяет только оставшийся хвост и не дублирует caption/reply. Различать локальный preparation failure и неоднозначный transport timeout.
- Typed edit target выбирает text или caption command; failed edit сохраняет ввод и даёт понятное состояние UI.

**Приёмка:** новый draft переживает завершение media send и ошибку forwarding; edit/cancel восстанавливает прежний draft; A accepted/B failed/retry даёт A,B без второго A; caption редактируется правильной командой, включая entities и сетевой отказ. Не блокировать весь composer только ради обхода гонки без оценки UX.

### B3. Владение ресурсами media-операции

**Первая задача:** R04 recorder; затем R17/R18 playback/download.

- Recorder/FD/temp path принадлежат отдельной операции; её cleanup использует captured resources. Результат create проверяется до записи в shared поля. Cancel/failed prepare завершают cleanup до повторного запуска.
- Playback intent generation проходит player create/prepare, playlist search и file download. Stop инвалидирует все continuations, включая Next; каждый проигрыватель/FD освобождает его owner.
- Download request identity задаётся отдельно для каждого file и меняется при retry; membership pending-set недостаточна для принятия ответа.
- Общий helper вводить только если исправления демонстрируют одинаковый контракт; UI lifecycle token не заменяет идентичность отдельных операций.

**Приёмка:** begin A/cancel/begin B/late A не трогает B; после failed prepare и dispose нет потерянных FD/output; два быстрых play не оставляют orphan player; Stop во время create/Next не возобновляет звук; старый download reject не меняет новый retry. Host races обязательны, recorder/player также проверяются на устройстве.

### B4. Логи и стоимость production-проверок

**Находки:** R21/R22; CI gaps решаются в A0/A5.

- Убрать символы auth code из public logs; синтетические секреты не появляются даже частично в captured logger. Ошибки API тоже проверять на безопасное содержимое.
- Передавать AppStore явный build debug flag. Production invariants должны иметь определённую локальную стоимость; полный обход оставить диагностическим инструментом.
- Измерить реальную основную message map, а не только отдельный LRU. Ввести ограничение/выгрузку с учётом текущего timeline, reply hydration и scroll anchor; не выбрасывать данные вслепую.

**Приёмка:** logger fixtures не содержат секретных фрагментов; progress update не запускает debug scan всей истории в production; на устройстве проверены time slices, backlog и память на согласованном объёме истории. Host 0,7 с не используется как device performance budget.
