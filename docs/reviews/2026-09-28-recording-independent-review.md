# R04 — независимое review после implementation

Дата: 2026-09-28. **Новых blockers в проверенном recorder ownership slice не найдено.**
Контрпримеров к изоляции ресурсов A/B и false-green по проверенным guards не воспроизведено.
Это вывод source review и host probes, не подтверждение работы SDK/микрофона на устройстве.

## Scope и проверенные ветки

Прочитаны финальный controller, оба запрошенных test scripts, worker report
`C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-recording-ownership.md`
и узкие page callbacks/accessor. Worker claims не приняты за собственную проверку.

В `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/ChatVoiceRecordingController.ets`:

- **149–190:** startup bundle локален до успешного актуального `start`; после create/prepare/start проверяется operation + lifecycle/chat. Неопубликованный A освобождается через `finally`, не через текущие поля B.
- **21–22, 155:** module-level sequence разделяет output paths двух экземпляров при одинаковом clock; это не controller-local token.
- **127–135, 259–268, 312–366:** dispose захватывает bundle до reset; stop/release single-flight, FD захвачен до await, close после release settlement. Повторный cleanup не трогает timer/FD/path нового B.
- **212–257, 369–382:** после cleanup повторно проверяются актуальность и `getSendMediaUseCase('voice')`; revoke не отправляет файл и приводит к удалению. Happy send закрывает FD, передаёт собственный path, сохраняет файл и обновляет UI только актуального operation.

В `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-edit-only-send-guard.cjs` проверены **52–118, 219–227, 302–334, 403–423**: startup действительно идёт через page callback → public begin → actual controller, без инъекции private bundle/подмены cleanup. Реальный send use case доходит до fake gateway; нарушения SDK assertions сохраняются вне production catch. Новый ownership harness также проверяет swallowed assertions (**37–49, 355–359**).

## Лично воспроизведённые evidence

Node **v24.12.0**; HEAD `faf66b3e066afccdbbfa36442eb9122073f509b2`, существующий dirty tree.
Команды выполнялись из `C:/Users/Kharki/Desktop/Telegram-HarmonyOS`:

```text
node --disable-warning=ExperimentalWarning scripts/test-voice-recording-ownership.cjs --negative-controls
voice ownership: 22 passed, 0 failed
negative controls: 8 rejected, 0 survived (in memory only)
exit 0

node --disable-warning=ExperimentalWarning scripts/test-edit-only-send-guard.cjs
53 passed, 0 failed
exit 0
```

**Дополнительно 10/10 reviewer probes, exit 0**, только в памяти. Harness загружен через `Module._compile` с заменой финального main-вызова на экспорт fixture; production controller не подменялся:

- Шесть interleavings: `dispose` во время create/prepare/start A → B при том же clock → поздний resolve/reject A. Закрыт только FD A, path/FD/timer/UI B сохранены, stale toast отсутствует; dispose B завершает cleanup.
- Два controller, общие filesystem/clock/module: cancel pending-create A → late A при pending-create B → успешный B. A не удаляет B path.
- Отзыв send rights во время pending stop: sends=0, FD закрыт, path удалён, UI idle.
- Recorder уже в `error`: cancel вызывает release без stop и очищает FD/path.
- Двойной finishAndSend при pending release: один release, один send, файл после успеха сохранён.

**Отдельно перепроверены два negative controls адаптированного permission fixture** — изменения только загруженного source в памяти:

```text
public begin -> no-op:                    49 passed, 4 failed; exit 1
fresh voice accessor -> cached use case: 51 passed, 2 failed; exit 1
```

Первый ломает оба happy voice sends и два сценария revoke/edit-only. Второй ломает именно captured voice-send и revoke during release. Следовательно, эти проверки не зеленеют за счёт отсутствующего startup или неиспользуемого permission guard.

## Grounding и ограничения вывода

- Выполнен `harmonyos_docs.search_harmonyos_docs`: `AVRecorder release error reset`, en; прочитан `get_harmonyos_document(743d323e78ad7ef0)`, **AVRecorderState 9+**, source `application-dev/reference/apis-media-kit/arkts-apis-media-t.md`. Документ допускает release из любого состояния, кроме released, включая error. Прочитан локальный reference `C:/Refs/Telegram/HarmonyOS-Codelabs/Media/AVRecorder_Audio/entry/src/main/ets/services/RecorderService.ets`.
- Здесь проверены завершающиеся promises и ownership/control flow. Never-settling SDK calls, физическая конкуренция микрофона и native error callbacks не покрыты. Stop/release/close/unlink failures остаются best-effort logging; физическое освобождение при таких ошибках не доказано. Это известные границы worker report, не новые подтверждённые regressions.
- Уникальность path подтверждена в одном загруженном module context, не между процессами/restarts. Проверен вызов send, не upload/TDLib acknowledgement или lifetime файла после dispatch.
- Builds, emulator/device, микрофон, Telegram network, общий media/account/project аудит и commits не выполнялись. Результаты параллельных HAP builds родителя сюда не включены.

## Неизменность проверенных файлов

SHA-256 совпали до и после проверок:

```text
ChatVoiceRecordingController.ets   5483f0e0f5c0164d51bb68f35218c7539e1085b71d37f35997865e52e31dddbd
test-voice-recording-ownership.cjs  362ae293756d69a1bad99ade28b4699320c9dd98f98a52926abd197a1f8bfced
test-edit-only-send-guard.cjs       457daaeab1347b544a35c9d0294932163ab9a94c9481fa33112f1c2307a6791a
```

Единственная запись reviewer — этот файл. Production/tests и prior dirty changes не редактировались и не откатывались.
