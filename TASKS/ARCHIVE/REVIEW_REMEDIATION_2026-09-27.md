# Исправления после сравнительного аудита — 2026-09-27

## Граница
Основание: `docs/reviews/2026-09-27-github-comparison.md`; пользователь поручил действовать по результатам аудита. Текущий этап — надёжность. Существующие незакоммиченные изменения сохраняются. Без commit/push, аккаунтных действий, установки HAP и изменения системных настроек.

## Первый проверяемый срез
1. Создание групп/каналов: принимать корректные отрицательные IDs, отвергать невалидные ответы; удалить OTP из логов. Независимый агент, отдельные use cases/controller/tests.
2. История: generation ownership запросов; jump не теряется при загрузке; запоздалый ответ не меняет новое окно. Независимый агент, только history use case/tests.
3. Основной агент: mark-read из списка действительно читает сообщения, а не только снимает ручной unread; существующий build bootstrap перестаёт игнорироваться; behavioral suites включаются в CI.
4. Личный повтор focused suites, независимая проверка изменений, общий host regression, последовательные main/ohosTest сборки. Обновить рабочие документы и итоговый отчёт.

## Уточнения после независимого review
- Проверки поймали дополнительные границы того же среза: null/unknown и unsent last message нельзя объявлять прочитанными по одному Ok; явный отказ предпочтительнее ложного успеха. Добавлены RED→GREEN cases.
- History ownership требуется не только use case, но и UI jump continuation/отложенному scroll; late aroundUnread correction должна заменять, а не объединять разорванные окна. Исправления делегированы с непересекающимися write scopes.
- Новый CI job выявил скрытую зависимость host media suite от ignored Hypium. Исправляется тестовая boundary, suite не исключается и native acceptance не заявляется.
- Выполненные до этих уточнений 43 host / 38 PS и main/ohosTest сборки — промежуточные. Финальный результат принимается только после повторной проверки изменённых файлов.

## Ожидаемый свидетель до правок
- Acceptance tests на старом коде FAIL по заявленному дефекту, после минимального изменения PASS; синтетические данные и настоящие production-функции.
- Mark-read: getChat с exact ID → viewMessages последнего сообщения с force_read=true → снятие manual unread; пустой чат без фиктивного message ID. Ошибки не объявляются успехом.
- Build bootstrap: проверка Git eligibility обязательного локального импорта FAIL до изменения ignore, PASS после. Это не доказательство полной clean-clone сборки.
- CI runner: обнаруживает все `scripts/test-*.cjs`, ненулевой exit любого child сохраняется; пустая коллекция считается ошибкой. CI в GitHub без публикации не запускался.
- Forced ArkTS сборки и неизменность проверенных файлов после них; compile не заменяет device/UI acceptance.

## Не закрывается этим срезом
Native open_count/bridge, все media/account/forward transport риски, полная iOS parity, реальное устройство и публикация. Не расширять срез без конкретной регрессии.

## Завершённый результат среза
После исправлений independent-review findings:44/44CJS,38/38PS+Bash,44/44CJS с anchored запретом installed dependencies; forced serial main/ohosTest PASS,397 source/resource hashes неизменны. Creation50, OTP11, history33, jump21, mark-read32 cases PASS. Три legacy fixtures исправлены без ослабления ожиданий. Подробности и ограничения: `docs/reviews/2026-09-27-remediation.md`. Общий проект/релиз не объявлены завершёнными; HEAD/staging не менялись, HDC [Empty].
