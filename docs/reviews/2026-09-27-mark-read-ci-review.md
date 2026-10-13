# Независимое ревью mark-read / CI — 2026-09-27

Исходный read-only аудит: **3 actionable findings**, единственная запись — этот отчёт. Затем пользователь отдельно разрешил узкую remediation P1: изменены только host-script и этот отчёт. **P1 исправлен**, проверка ниже. Оба P2 и их номера строк сохранены как исходный snapshot; их дальнейшие исправления выполняет основная задача, здесь они не перепроверялись. Параллельные creation/login/history-изменения не оценивались.

## P1 — Новый host job не воспроизводится без локального Hypium

Место: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/.github/workflows/smoke.yml:40-41`.

Job выполняет checkout → Node → все suites, но не подготавливает зависимости. Реально обнаруживаемый runner-ом `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-chat-media-download-controller.cjs:35-39,76` читает `entry/oh_modules/@ohos/hypium/src/main/module/mock/MockKit.js`; loader НЕ заменяет этот участок injected boundary. Каталог игнорируется (`.gitignore:34`), tracked-файлов Hypium нет. На чистом checkout suite завершится `ENOENT`, а обязательный job — ошибкой.

Личный witness: установленный Hypium → **25/25, exit 0**; тот же настоящий suite с read-only перехватом чтения только отсутствующего в clean checkout `entry/oh_modules` → **exit 2**, `HARNESS_ERROR ... ENOENT ... mock/MockKit.js`. Файлы не удалялись. Исправление: обеспечить pinned SDK-free host-зависимость/fixture в checkout либо её воспроизводимую установку до запуска; не скрывать suite исключением.

### Разрешённая remediation P1 — выполнена

В `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-chat-media-download-controller.cjs:33-105` загрузка установленного Hypium заменена собственным явным host test double: только own-method replacement, `when(any).afterAction` и восстановление исходной функции. Неизвестные matcher/метод, ненастроенный вызов и неподдерживаемое число аргументов приводят к assertion failure. Argument identity, `this`, возвращаемый Promise и однократный вызов action проверяются отдельно. Реальные production methods и все исходные `.ets` test bodies продолжают исполняться; новый helper-файл не понадобился. SDK-код не скачивался и не копировался.

Лично повторённые witnesses на Node 24.12.0:

- **До правки:** обычный запуск 25/25, exit 0; запрет любого чтения из `oh_modules` — RED `ENOENT ... MockKit.js`, exit 2.
- **После правки:** тот же запрет чтения — GREEN **25/25, exit 0**; обычный запуск также 25/25. Сохранена проверка cleanup при намеренно брошенном assertion и пропущенном afterEach. Физические каталоги не переименовывались/удалялись.
- **Null controls, только in-memory mutations:** потеря action return и no-op восстановления отдельно обнаруживаются self-check, exit 2. Подавление только dispatch проходит self-check, но приводит к **16 FAIL / 9 PASS, exit 1** в исходных проверках — assertions не стали permissive.
- **Общий runner после этой правки:** 43 suites / **41 PASS / 2 FAIL**, exit 1. `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-chat-history-generation.cjs`: `initial preserves empty top-up exhaustion`, `initial preserves no-progress top-up exhaustion` (`true !== false`). `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-chat-lifecycle-account-scope.cjs`: три Wave18 correction/boundary сценария, 103/106. Оба среза вне write scope; здесь не исправлялись и не исследовались дальше.

SHA-256 изменённого host-script: `6f8e0a360a0a19768f5b0a542fd7a24582564979f095cceb8145c3755053546e`. Production, workflow, native test suite и SDK не изменены. hvigor не запускался; выполнение Ubuntu/GitHub Actions по-прежнему не заявляется.

## P2 — Неизвестный last_message ошибочно принимается за пустой чат

Место: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/domain/usecases/toggleChatUnread.ets:51-52` (успешное завершение: 62-63).

TDLib допускает `last_message=null`, когда сообщение **неизвестно**, а не только когда чат пуст: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/generate/scheme/td_api.tl:3157`, [официальный контракт chat](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1chat.html). При положительном `unread_count` текущая ветка отправляет только getChat → toggle(false), не продвигает inbox boundary, но возвращает успех.

Личный host witness через loader нового suite: `unread_count=4, last_message=null` → Promise resolved, `sends=getChat,toggleChatIsMarkedAsUnread`; дополнительная проверка наличия read-запроса **RED, exit 1**. Исправление: отличать подтверждённо пустой/read inbox от неизвестной границы; получить пригодную границу либо явно завершить операцию ошибкой, не объявляя прочтение успешным. Добавить этот случай рядом с empty-chat тестом.

## P2 — Последнее pending-сообщение не является read boundary

Место: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/domain/usecases/toggleChatUnread.ets:59-60`.

Положительный safe integer и правильный chat_id не исключают pending-исходящее. TDLib пропускает `is_yet_unsent()` при выборе `max_message_id`: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/MessagesManager.cpp:16134-16136,16202`; при нулевой границе `read_dialog_inbox` ничего не делает (16322-16324), хотя viewMessages возвращает Ok (16314-16319). Последнее сообщение чата берётся без такого фильтра (16722); то же исключение есть в [upstream TDLib](https://raw.githubusercontent.com/tdlib/td/master/td/telegram/MessagesManager.cpp).

Личный host witness: `last_message.id=1048577`, `sending_state=messageSendingStatePending`, `unread_count=4` → успешные getChat → viewMessages([1048577], force_read=true) → toggle(false). Проверка пригодности переданной границы **RED, exit 1**. Значение имеет корректный TYPE_YET_UNSENT=1: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/MessageId.h:32,111-113`, `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/MessageId.cpp:115-123`. Исправление: до viewMessages учитывать sending_state и получать последнее пригодное сообщение либо явно отклонять действие; добавить pending/failed-send regression case. Нативное выполнение TDLib не заявляется: факт отправленного запроса проверен host-тестом, отсутствие read-эффекта обосновано исходником TDLib.

## Проверено без новых findings

- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-chat-list-mark-read.cjs`: **27/27**, exit 0. Реальные TdObject, factories и serializer; строгая проверка top-level type/identity/Ok работает в покрытых сценариях. force_read=true присутствует и в итоговом JSON.
- Дополнительная композиция настоящих use case + serializer + `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/infra/td/adapter/TdGatewayAdapter.ets`: **3/3**, exit 0. Нормальный путь отправляет три запроса; смена client generation во время getChat или viewMessages отклоняет continuation без следующего native send. Adapter проверяет generation до и после await (53-55,78-85); отсутствие отдельного scope в use case само по себе здесь НЕ дефект.
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-host-test-runner.cjs` и `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-build-bootstrap.cjs`: exit 0. Исключение `.gitignore` действительно открывает существующий compat-bootstrap для Git; сам bootstrap не исполнялся. [setup-node@v7](https://github.com/actions/setup-node) существует; выбранный input отключения cache поддерживается.
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/smoke-ui-phase0.sh`: полный Windows Git Bash запуск и `bash -n` — exit 0; `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-smoke-hex-check.cjs`: **5 cases PASS**, exit 0. Используется фактический grep; canonical route strings сверены с существующим PowerShell-контрактом. Нового дефекта в этих изменениях не найдено.

## Ограничения

- Общий `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/run-host-tests.cjs`: **43 suites / 42 PASS / 1 FAIL**, exit 1. Ошибка `test-unread-count-routing.cjs:294`, `actual loadAroundMessage resets the old window ...`, `true !== false` относится к параллельно изменяемому history-срезу и НЕ включена в findings этого ревью.
- Node **24.12.0**, Windows + Git Bash. Ubuntu/GitHub Actions фактически не запускались; clean-checkout отсутствие Hypium воспроизведено на файловой границе, не физическим clone. hvigor, эмулятор, аккаунт и сеть TDLib не запускались.
- Grounding: harmonyos_docs Async/Await; локальные TDLib schema/C++; Android-reference `C:/Refs/Telegram/telegram-android/TMessagesProj/src/main/java/org/telegram/ui/DialogsActivity.java:9320-9321`; официальные источники по ссылкам выше. Десять файлов review-scope повторно проверены по SHA-256: во время focused probes не менялись.
