# R02 / R21 — создание чатов и приватность OTP, 2026-09-27

**Результат:** исправлены отказ на отрицательных chat ID и передача OTP-материала в логи `LoginController.checkCode()`. Подтверждено host acceptance; не device/build acceptance.

## Изменения

- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/domain/usecases/createBasicGroupChat.ets` — строгий top-level тип ответа и ненулевой safe-integer signed `chat_id`; частичные ошибки участников, результат hydration/fallback и количество команд сохранены.
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/domain/usecases/createChannelChat.ets` — строгие signed chat ID, тип канала, boolean `is_channel`, положительный safe-integer `supergroup_id`; возвращается настоящий `ChatDto` с точными ID.
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/controllers/LoginController.ets` — только два участка `checkCode()`: статические сообщения вместо OTP-prefix/length и raw exception (исключение может повторять OTP). Ни public, ни private аргументов с секретом нет. Команда и success/error mapping не изменены.
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-chat-creation.cjs` — новый самостоятельный acceptance, 50 сценариев.
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-auth-code-privacy.cjs` — новый самостоятельный acceptance, 11 сценариев.
- Этот отчёт: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-27-chat-creation-auth-privacy-fix.md`.

## RED → GREEN, лично выполнено

Node v24.12.0; оба новых теста выполнены до production-правок, затем те же тесты без изменения ожиданий после правок.

```text
node --disable-warning=ExperimentalWarning C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-chat-creation.cjs
RED, exit 1:
FAIL group preserves exact signed ID -7001, hydrates once and keeps partial failures
Error: Group creation failed
FAIL channel preserves exact signed ID -1000000008100 and sends create only once
Error: Channel creation failed
27/50 PASS; 23 FAIL (production chat creation, host fixtures only)

GREEN, exit 0:
50/50 PASS; 0 FAIL (production chat creation, host fixtures only)

node --disable-warning=ExperimentalWarning C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-auth-code-privacy.cjs
RED, exit 1:
FAIL numeric submit preserves success/payload and logs no credential material
AssertionError [ERR_ASSERTION]: credential prefix must never enter any log sink
FAIL invalid echoed OTP: failure result preserved without logging error/OTP
AssertionError [ERR_ASSERTION]: submitted credential must never enter any log sink
0/11 PASS; 11 FAIL (production login submit, synthetic-only)

GREEN, exit 0:
11/11 PASS; 0 FAIL (production login submit, synthetic-only)

node --disable-warning=ExperimentalWarning C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-login-recovery.cjs
33/33 PASS; 0 FAIL (actual source, host fixtures only)
exit 0
```

Оба новых scripts: `node --check` PASS. Scoped `git diff --check`: exit 0; Git предупреждает о будущем LF→CRLF, whitespace errors нет.

Тесты исполняют текущие production ETS через Node TypeScript stripping: настоящие use cases, `TdObject`, DTO/accessors и command factories; не копии алгоритмов. Подменены только gateway и platform log sink. Privacy-тест вызывает настоящий `LoginController.getInstance().checkCode()`, используемый `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/login/CodeInputPage.ets:190`, проверяет точный payload и raw log arguments **до** public/private masking. Все входы синтетические.

Покрытие: отрицательные group/channel IDs (включая большое точное значение), положительный compatibility control, zero/missing/null/boolean/fraction/unsafe/string/nested/nonfinite malformed responses, ошибочные типы, частичные ошибки участников, пять hydration failures с сохранением committed identity, один create без автоматического повтора, исходное исключение gateway, success/failure result classes. OTP: числа/leading zero/короткий ввод/word/phrase, invalid/expired/flood/network/unknown ошибки, включая echo синтетического OTP.

## Grounding

- Прочитаны AGENTS/STATUS/DECISIONS/REFERENCES, active roadmap и architecture. TDLib: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/generate/scheme/td_api.tl:3189,3206,10110,11775,11785` — `chat.id:int53`, `createdBasicGroupChat.chat_id:int53`, `checkAuthenticationCode code:string`, разные create response shapes.
- iOS references: `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramCore/Sources/TelegramEngine/Peers/CreateGroup.swift` и `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramCore/Sources/TelegramEngine/Peers/ChannelCreation.swift`: создание, committed identity, отдельная обработка missing invitees/hydration; MTProto IDs не подменяют TDLib ID contract.
- Выполнен `harmonyos_docs` query `"hilog" "format" "private"`: official Performance Analysis Kit, `hilog.info`/`hilog.warn`. Маскирование не является удалением аргумента; здесь данные вовсе не передаются логгеру. Поиск `Number.isSafeInteger` в MCP не дал результата; compile-совместимость этим поиском не подтверждена.
- Historical probes прочитаны через `git show origin/codex/architecture-hardening-plan-2026-09-26:...`; не использованы как acceptance (их exit 0 подтверждал старый баг).

## Границы / передача основному агенту

- DevEco/hvigor, HAP install, live auth, commits/push не выполнялись. Общие test lists, STATUS/TODO/LESSONS и чужие suites не изменялись. Новые tests не зарегистрированы в общем runner.
- В `LoginController.ets` уже были чужие dirty изменения account-adapter/logout; они сохранены. В parser используется уже существующий dirty-tree API `getTopLevel*Strict` из `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/models/td/common/index.ets`; этот файл не изменялся данным срезом.
- Host stripping не заменяет ArkTS compilation/native TDLib/device runtime. Основному агенту остаётся проверить общий diff и выполнить управляемую им последовательную сборку.
- Область privacy witness — `checkCode()` и его прямой logging. Другие auth methods/native logs и отображение текста UNKNOWN-ошибки не аудированы этим тестом; общий security-clean статус не заявляется.
- Без перестройки общего `TdObject`: legacy coercion не менялся глобально; strict validation добавлена только на границе двух create responses.

