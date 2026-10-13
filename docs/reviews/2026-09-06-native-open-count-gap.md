# Wave17: logical lease не доказывает native open-count safety

Дата: 2026-09-06. **Physical native `open_count` gate: OPEN.**
Это bounded source-review и процедура следующего среза, не реализация,
не native/runtime witness и не завершение общей цели. Текущий helper и его
тесты в этом doc-only срезе заморожены.

## Подтверждённые исходниками границы

- [td_api.tl:11713–11718](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/generate/scheme/td_api.tl#L11713): схема задаёт ответ `Ok` для `openChat` и `closeChat`; ответ не содержит acquisition token или сведений о фактическом increment/decrement.
- [Requests.cpp:3360–3367](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/Requests.cpp#L3360): external requests вызывают `MessagesManager::open_dialog/close_dialog(DialogId)`.
- [MessagesManager.cpp:15926–15943](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/MessagesManager.cpp#L15926): существующий dialog получает `Status::OK()` после вызова `Dialog*` overload.
- [MessagesManager.cpp:16407–16419](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/MessagesManager.cpp#L16407): отсутствие Read access или насыщение счётчика возвращает управление **до** `open_count++`.
- [MessagesManager.cpp:16521–16527](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/MessagesManager.cpp#L16521): любой close уменьшает ненулевой счётчик; проверки владельца нет, при нуле close ничего не уменьшает.

Поиск `open_dialog`/`close_dialog` по всем `*.cpp`/`*.h` локального TDLib,
включая ссылки на символы без `(`, не выявил других callers этого счётчика:
только Requests и forwarding между overloads. Все найденные обращения
`MessagesManager` к `open_count`, кроме инициализации и указанных `++/--`, —
чтения. Это утверждение о checkout, не об установленном native binary.

## Контрпример: модель по исходникам, не исполненный native тест

Предусловия: один TDLib client/dialog, начальный count=0, A и B — разные страницы.

| Шаг | Read access | API / действие | Native count в модели |
|---|---|---|---:|
| A acquire | нет | `openChat` → `Ok`, increment пропущен | 0 |
| B acquire | восстановлен | `openChat` → `Ok`, increment выполнен | 1 |
| A release, B ещё активна | есть | `closeChat` уменьшает общий счётчик | **0** |
| B release | есть | `closeChat`, уже ноль | 0 |

Один close на каждый acknowledged open всё равно может закрыть другой live
holder. [ChatOpenLease.ets:25–98](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/domain/usecases/ChatOpenLease.ets#L25)
гарантирует logical acknowledged-call ownership, single attempt, release-once
и captured gateway, **не** принадлежность или точность native decrement.
Parent может независимо воспроизвести эту counter-model; её исполнение здесь
не заявляется. Compile и зелёные logical-lease tests этот native gate не закрывают.

## Следующий concrete slice: coordination contract, пока не принят/не реализован

Кандидат: канонический **client/session group identity + chatId**, общий для
всех holders и всех app-origin open/close этого dialog.

1. Регистрировать holder до dispatch; отдельно учитывать pending acquisitions.
2. На release снимать logical holder, откладывая положенные acknowledged closes.
3. Drain начинать только при нуле live holders и завершённых acquisitions.
4. Сериализовать drain с новыми acquisitions: старые closes не должны пересекать новый open epoch.
5. Явно определить uncertainty: rejected/timeout Promise не доказывает завершение native операции. Без подтверждённого ordering/fence нельзя объявлять drain безопасно завершённым; unknown close не replay.

Не сводить все opens группы к одному: после A/noRead новый B/open может быть
первым реальным increment. Не обещать точный balance даже при отложенном drain:
unknown outcomes и неохваченные callers остаются ограничениями.

`accountStore` сам по себе не канонический session key:
[AppStore.ets:49–69](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/core/store/AppStore.ets#L49)
создаёт разные scope views и меняет generation при сохранении root identity.
Identity произвольного gateway wrapper тоже не контракт:
[TdGatewayAdapter.ets:144–152](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/infra/td/adapter/TdGatewayAdapter.ets#L144)
позволяет пересоздание adapter. Каноническую identity и её lifetime нужно
оговорить отдельно, не угадывать внутри текущего helper.

Минимальный следующий witness: контрпример выше; coordinator сохраняет count=1
после A release до ухода B; затем drain→0. Дополнительно: late ack после release,
новый C во время drain, unknown open/close, смена client/session и isolation chatId.
Это проверки предложенной модели, не замена native/runtime acceptance.

## Альтернатива: обоснованный visible-session lifetime

Выбор route lifetime против visible-session lifetime должен ответить: обязана ли
скрытая, но retained страница сохранять opened-chat активности? Нельзя просто
приравнять потерю global navigation owner к уничтожению underlying page.

- iOS: сопоставить shipped runtime поведение push/back/profile/modal с локальными [ChatController.swift:252,7491,8047](C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/ChatController.swift#L7491). Captured `AccountContext` и lifecycle hooks — ориентиры, не доказательство TDLib counter policy.
- HarmonyOS: `harmonyos_docs` → **Example 8: Using NavDestination Lifecycle Callbacks** различает `onShown/onHidden` и appear/disappear hooks; docs также описывают modal linkage с shown/hidden. Выбранный lifetime требует проверки реальной callback последовательности на целевом SDK, включая overlays, retained routes и возврат.
- Критерий принятия: явный владелец visible session, отсутствие повторных acquisitions от duplicate callbacks и отсутствие stale close после нового open. Сам перенос release в `onHidden` не устраняет uncertainty или гонку передачи ownership.

Retrieval: CPL local HTTP `/retrieve` завершился по таймауту 2 с; fallback —
точный поиск и чтение исходников. `harmonyos_docs` запрос lifecycle выполнен.
Никаких code edits, builds, devices, account действий или новых гарантий native
count в этом срезе нет. **Gate остаётся OPEN.**
