# Исправления после ревью — 27 сентября 2026

## Итог

**Выполнен первый проверенный срез исправлений, а не только очередной аудит.** Исправлены создание групп/каналов, гонки загрузки истории и перехода к сообщению, действие «Прочитано», утечка части OTP в лог. Добавлен единый запуск behavioral tests для CI; устранены две причины ложной уверенности в локальных проверках.

Финальная проверка основным агентом: **44/44 CJS suites, 38/38 PowerShell-проверок и Bash smoke — PASS. Обе принудительные ArkTS-сборки — PASS.** Это не означает готовность всего клиента к релизу: runtime на устройстве, оставшиеся native/account/media риски и публикация не закрыты.

Основание: [сравнение с GitHub](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-27-github-comparison.md). Оно остаётся историческим снимком **до** этих исправлений.

## Что изменено в приложении

| Область | Исправление | Лично повторённый witness |
|---|---|---|
| Создание группы и канала | Корректные отрицательные TDLib chat IDs больше не превращают успешное создание в ошибку. Строгая проверка ответа; fallback уже созданной группы и частичные ошибки приглашения сохранены. | **50/50**; те же тесты на исходном коде в памяти: **23 FAIL** |
| OTP | В `checkCode()` не логируются введённый код, его префикс, длина или raw error, способный повторить секрет. Payload авторизации сохранён. | **11/11**; исходный код: **11 FAIL**; login recovery **33/33** |
| Окно истории | Jump не теряется из-за занятого initial-запроса. Устаревшие responses, queued dispatch и finally не меняют новое окно/курсоры/loading. Поздний aroundUnread заменяет разорванный fallback-диапазон. Пустой/no-progress top-up больше не открывает исчерпанную пагинацию повторно. | **33/33**; исходный history: **25 FAIL** |
| Переход/подсветка сообщения | Отдельный token каждого jump защищает UI completion и отложенный scroll, включая A→B→A. Новый jump к уже отображаемому B при незавершённом A отзывает старое history-окно, а не только UI target. | **21/21**; исходный page method с новым history: **14 FAIL** |
| «Прочитано» из списка | Получает актуальный chat и отправляет `viewMessages` последнего пригодного сообщения с `force_read=true`, затем снимает manual-unread. Проверяет exact ID и строгий Ok. | **32/32**; первый RED: **24 FAIL**, дополнительное независимое review: ещё **5 RED → GREEN** |

**Ограничение mark-read:** при неизвестной границе и ненулевом unread, pending/failed/scheduled last message операция теперь явно отклоняется, а не выдаёт ложный успех. Автоматический поиск более раннего пригодного сообщения этим срезом не реализован. Пустой/уже прочитанный inbox с `unread_count=0` позволяет снять только ручную отметку.

Production-файлы:
- [createBasicGroupChat](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/domain/usecases/createBasicGroupChat.ets)
- [createChannelChat](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/domain/usecases/createChannelChat.ets)
- [loadChatHistory](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/domain/usecases/loadChatHistory.ets)
- [toggleChatUnread](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/domain/usecases/toggleChatUnread.ets)
- [LoginController](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/controllers/LoginController.ets)
- [TgChatScreenPage — только jump-участок этого среза](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets)

## Проверки и CI

- Добавлен [единый runner](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/run-host-tests.cjs): находит все `test-*.cjs`, запускает последовательно; пустой набор, ненулевой exit, signal/spawn failure не становятся PASS.
- В [workflow](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/.github/workflows/smoke.yml) добавлен безусловный host job на Node 24. Опциональная Harmony-сборка зависит от static и host jobs. **Запуск на GitHub не выполнялся:** изменения не опубликованы. Возможности setup-node и cache input сверены с [официальным README](https://github.com/actions/setup-node).
- Найден скрытый импорт Hypium из ignored `oh_modules` в media host-suite. Заменён на узкую, явно обозначенную host mock boundary с проверками return/аргументов/call count/restoration. Настоящие controller и native test bodies сохранены; это **не выполнение Hypium на устройстве**.
- Все **44 suites** повторно прошли с принудительным запретом чтения из `oh_modules` и `node_modules`. В каждом child контрольный read действительно отклонялся; иных чтений этих каталогов не было. Это проверка SDK-free host dependencies, **не физический clean clone**.
- [Bash smoke](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/smoke-ui-phase0.sh) приведён к существующему owner-bound route contract вместо устаревшего global unread snapshot.
- Исправлен color guard: `{3,8}` ошибочно использовался с basic grep. Контрольный `#abc` сначала не обнаруживался, теперь обнаруживается; пять positive/negative случаев проходят.
- Три старых тестовых участка адаптированы к реальной интеграции: history witness наблюдает gateway, не подменяет `execute`; lifecycle loader получает настоящий reset event; channel source-contract проверяет строгие TDLib type/is_channel guards. Ожидания поведения не ослаблены.
- Обязательный локальный [build bootstrap](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tools/hvigor/hvigor-ohos-plugin-compat.ts) перестал игнорироваться Git благодаря узкому исключению в [.gitignore](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/.gitignore). Он **виден как untracked**, не закоммичен. Отдельный guard сначала падал, затем прошёл. Полная воспроизводимость HAP из чистого clone пока не доказана.

## Финальная верификация после всех production-правок

| Проверка | Результат |
|---|---|
| Все host suites через новый runner | **44/44**, exit 0 |
| Те же suites без доступа к installed dependencies | **44/44**, все 44 контрольных запрета сработали |
| PowerShell test scripts + UI smoke | **38/38**, exit 0 |
| Bash UI smoke | exit 0 |
| Lifecycle/account/late-first | **106/106** |
| Unread routing | **43/43**, 0 swallowed errors |
| Main `assembleHap --no-incremental --no-daemon` | exit 0; CompileArkTS **15.933 s**, BUILD SUCCESSFUL **24.546 s** |
| Затем ohosTest, теми же forced flags | exit 0; OhosTestCompileArkTS **8.757 s**, BUILD SUCCESSFUL **17.398 s** |
| SHA-256 исходников/тестов/resources до и после | **397/397 неизменны** |
| `git diff --check` | exit 0 |

Сборки **unsigned**. Предупреждения о проверке NAPI declarations, потенциальных исключениях/permission API и previewer ICU data остаются; отсутствие ошибок компиляции не закрывает эти вопросы.

Старые промежуточные зелёные сборки не использованы как финальное доказательство: после замечаний независимого review обе сборки повторены. Обычные и negative-control host-прогоны выполнялись на синтетических данных, без Telegram-аккаунта и сетевых операций TDLib. Наборы пересекаются — число cases не суммируется в «уникальные тесты».

Подробные результаты, список изменённых файлов, hash manifest, build output и команды: [машиночитаемые доказательства](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-27-remediation-evidence.json).

## Как использованы субагенты

Три субагента работали в непересекающихся участках. Независимая проверка нашла не только формальные замечания, но и воспроизводимые границы: неизвестный/pending last message, скрытый Hypium, late unread range, UI jump ownership и top-up exhaustion. Исправления приняты только после личного повторного запуска основным агентом.

Локальные отчёты:
- [Создание чатов и OTP](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-27-chat-creation-auth-privacy-fix.md)
- [История и generation ownership](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-27-chat-history-generation-fix.md)
- [Независимое review истории и исправление jump](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-27-history-independent-review.md)
- [Review mark-read/CI и устранение Hypium dependency](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-27-mark-read-ci-review.md)

В этих промежуточных отчётах сохранены RED и прежние номера строк; актуальная интеграционная сводка — этот файл.

## Что сознательно не объявлено завершённым

1. **Устройство/эмулятор:** свежий `hdc list targets` — **[Empty]**. Нового запуска приложения, HAP install, реального создания чата/логина и визуальной проверки не было.
2. **Релиз:** native open_count/bridge, полная межаккаунтная изоляция media, неизвестный transport outcome forward и остальные открытые группы исходного аудита не закрыты.
3. **GitHub:** HEAD остался `faf66b3`, staging пуст. Никаких commit/push/deploy; прежние локальные изменения не сбрасывались. Новые tests/bootstrap/runner должны входить в будущий проверенный patchset, а не потеряться при публикации.
4. **UI parity:** правки защищают поведение, но не доказывают совпадение рендера с текущим Telegram iOS.

**Оценка:** приоритет выбран правильно — устранены реальные ошибки и усилена воспроизводимость проверок до дальнейшей визуальной полировки. Следующий технический рубеж — оставшиеся native/account/media риски и затем проверка пользовательских сценариев на авторизованном устройстве; не косметическое расширение проекта.

