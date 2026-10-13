# R04 — ChatVoiceRecordingController: operation/resource ownership

Дата: 2026-09-28. Статус: узкий production fix и behavioral regression готовы;
старый private-field fixture исправлен после расширения write scope координирующим агентом.
Focused permission/send suite: 53/53; ownership: 22/22; 8/8 negative controls отвергнуты.
Повторный общий host-прогон: 45/45 suites PASS, native R19 suite намеренно исключён.
Build, device и hardware acceptance **не выполнялись**.

## Граница работы и исходное состояние

- Репозиторий: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS`, HEAD
  `faf66b3e066afccdbbfa36442eb9122073f509b2`, существующий dirty tree.
- Исходный controller уже содержал незакоммиченный `getSendMediaUseCase(mediaKind?: string)`
  и оба вызова `getSendMediaUseCase('voice')`. Они сохранены, не являются новым R04 fix.
- Исторические `TASKS/CODE_REVIEW_2026-09-26.md` и
  `scripts/review/2026-09-26/media_races.cjs` прочитаны через локальный remote-tracking ref
  `origin/codex/architecture-hardening-plan-2026-09-26`
  (`621e8d3811e252ddc4525395be7d827aea22dd85`), без fetch.
  Исторический exit 0 означает воспроизведённый BUG, а не acceptance.
  Весь исторический probe не запускался: он захватывает playback/download вне задачи.
- Page, playback, bridge/`tdlib_napi.cpp`, общие STATUS/TODO/LESSONS/CI не редактировались
  этим срезом. Работа родителя R19 не дублировалась; native-suite исключён из общего прогона.
  Коммитов, устройств, аккаунтов и Telegram network не было.

## Grounding

Прочитаны AGENTS, STATUS, TODO, DECISIONS, ARCHITECTURE, REFERENCES, активный маршрут
AGENT_EXECUTION_PLAN и релевантные lessons (включая 142/143: historical probes,
production-path host tests и negative controls).

`harmonyos_docs` отсутствует среди выставленных инструментов этой сессии, но его
настроенный сервер доступен. Реальный MCP `initialize` / `tools/call` выполнен через
stdio, Python MCP client и
`C:/Users/Kharki/Desktop/harmonyos-rag/mcp_server_win.py`.

Запросы `search_harmonyos_docs`, `language=en`:

- `AVRecorder AND release AND prepare`;
- `"AVRecorder" AND "release" AND "fd" NOT "OH_AVRecorder"`;
- `"AVRecorder" AND "prepare" AND "idle" NOT "OH_AVRecorder"`.

Через `get_harmonyos_document` дополнительно прочитаны:

- `743d323e78ad7ef0`, **AVRecorderState 9+**,
  source `application-dev/reference/apis-media-kit/arkts-apis-media-t.md`:
  prepare из idle/stopped, start из prepared, stop из started/paused,
  release из любого состояния кроме released; error допускает release.
- `f806c379d69e7c32`, **Complete Sample Code**,
  source `application-dev/media/media/using-avrecorder-for-recording.md`:
  образец ожидает release, затем закрывает FD.

Локальный внешний reference также прочитан:
`C:/Refs/Telegram/HarmonyOS-Codelabs/Media/AVRecorder_Audio/entry/src/main/ets/services/RecorderService.ets`.
Из него не копировалась cleanup-логика; lifecycle grounding выше взят из MCP docs.
UI/Telegram behavior не менялись; iOS visual witness к этому resource-срезу не заявляется.

## Исправление

1. `VoiceRecordingResources` объединяет recorder, file, path и shared release promise.
   До успешного start + актуального operation/lifecycle guard этот объект принадлежит
   только локальному `beginAsync`, а не общему полю контроллера.
2. После create проверяется актуальность **до prepare**; после prepare/start — снова.
   `finally` освобождает неопубликованный набор и при устаревании, и при исключении.
   Cleanup не выполняется конкурентно с ещё ожидаемым prepare/start того же recorder.
3. Cleanup работает только с переданным набором. Recorder и FD захватываются до await,
   close следует за stop/release; повторные cancel/dispose/send ждут один release promise.
   Старый cleanup больше не останавливает общий timer нового B.
4. Failure cleanup ожидается до публикации error/idle; reset не стирает ресурсы,
   которые нужны незавершённому cleanup. Поздние completion/error не обновляют новый UI.
5. Имя файла содержит timestamp + module-level `voiceOutputSequence`: successive operations
   и два разных controller из одного загруженного модуля в одну миллисекунду не используют
   один output path. Успешно отправленный файл сохраняется, как раньше.

## RED → GREEN: фактически выполнено

Node `v24.12.0`. Новый script исполняет актуальный controller целиком и реальную
`TgVoiceRecordingPolicy.ets`, удаляя только imports/типовую разметку. Вызовы идут через
`begin`, `cancel`, `dispose`, `lock`, `finishAndSend`; private methods не подменяются.

До production edits создан первоначальный набор из 15 сценариев:

```text
node --disable-warning=ExperimentalWarning scripts/test-voice-recording-ownership.cjs
BEFORE: voice ownership: 7 passed, 8 failed; exit 1
AFTER:  voice ownership: 15 passed, 0 failed; exit 0
```

После первого расширения coverage и проверки, что production catch не скрывает assertions
fake SDK, тот же сохранённый исходный controller повторно исполнялся **только в памяти**.
Его hash проверен перед запуском, рабочий файл не откатывался:

```text
21-case harness + BEFORE controller: voice ownership: 10 passed, 11 failed; exit 1
21-case harness + first fix:         voice ownership: 21 passed, 0 failed; exit 0
```

После замечания parent отдельно воспроизведён конфликт двух controller. В одной
загрузке production-модуля созданы два реальных экземпляра с общими SDK/filesystem,
filesDir и неизменным clock; оба находятся в первой операции. При локальном token suffix
cancel A удаляет path B: `A cleanup deleted B path across controllers`.

```text
timestamp + controller token: voice ownership: 21 passed, 1 failed; exit 1
timestamp + module sequence:  voice ownership: 22 passed, 0 failed; exit 0
```

Это дополнительный лично наблюдённый RED → GREEN, а не вывод из name/source check.
После cancel A проверяются path/FD/timer B и его последующий release через public dispose.

### Точные наблюдения двух основных сценариев

FD A = 1, FD B = 2. Clock начинается с 100000; перед B увеличен на 1,
чтобы ownership race не смешивался с отдельной проверкой path collision.

| Наблюдение | BEFORE | AFTER |
|---|---|---|
| Late create A после cancel A / started B: закрытые FD | `[1,2]` | `[1]` |
| Удалённые paths | A и B | только A |
| `prepare` у позднего A | `fd://2` — FD B | не вызывается |
| release A / release B до dispose B | `1 / 0` | `1 / 0` |
| Живые timers B после late A | `0` | `1` |
| release B после последующего dispose | `0` — B потерян | `1` |
| Prepare failure, release ещё pending: UI | `idle` | `preparing` |
| Prepare failure, release завершён: закрытые FD | `[]` | `[1]` |
| Prepare failure, release завершён: удалённые paths | `[]` | `[A]` |
| Prepare failure, release завершён: оставшиеся paths | `[A]` | `[]` |

Начальный RED содержал `late A closed B FD` и
`every acquired FD closed once: actual [], expected [1]`.
Дополнительный coverage: cancel в prepare/start, late failures, dispose в create/release,
permission cancellation, lifecycle invalidation, repeated cleanup, queued lock/send,
short recording, successful send и stale send completion. Проверяются FD/path,
recorder release counts, timer, UI events, отсутствие stale toast/send.

### Negative controls

```text
node --disable-warning=ExperimentalWarning scripts/test-voice-recording-ownership.cjs --negative-controls
voice ownership: 22 passed, 0 failed
negative controls: 8 rejected, 0 survived (in memory only)
exit 0
```

Каждая точечная мутация обязана попасть ровно в один anchor и получить ожидаемый FAIL:
удаление post-create guard; чтение текущего bundle вместо captured FD;
потеря FD; обнуление path до release; stop общего timer из stale cleanup;
удаление release join; удаление unique suffix из имени файла; возврат к controller-local
token вместо module sequence (два экземпляра снова конфликтуют).
На диск мутации не пишутся. Нормальный oracle нового script: exit 0 = исправное поведение.

## Соседние проверки и разрешённое расширение scope

До адаптации fixture выполнен существующий host runner,
**кроме** `test-native-bridge.cjs` (родитель R19):

```text
node -e "const r=require('./scripts/run-host-tests.cjs'); process.exitCode=r.runSuites(r.discoverSuites().filter(f=>f!=='test-native-bridge.cjs'));"
{"suites":45,"passed":44,"failed":1}
exit 1
```

Единственный failing suite: `scripts/test-edit-only-send-guard.cjs`, **51 PASS / 2 FAIL**:

- `channel permitted voice: actual voice controller reaches sendMediaMessage`;
- `private permitted voice: actual voice controller reaches sendMediaMessage`.

Оба ожидали `['sendMediaMessage']`, получили `[]`. Причина локализована:
`prepareVoice()` (строки 157–160) вручную заполняет удалённое private-поле `outputPath`,
а fixture подменяет `beginAsync` и `releaseRecorder`. Это не реальная startup-ветка.
Диагностическая замена **только в памяти**
`outputPath: '/fixture/voice.m4a'` → `resources: { outputPath: '/fixture/voice.m4a' }`
дала **53 PASS / 0 FAIL, exit 0**, включая оба permitted voice sends.
На этом этапе это было подтверждение причины, **не** исправление файла и не GREEN
всего рабочего дерева. Ниже — последующая разрешённая адаптация и свежие результаты.

Затем пользователь явно разрешил расширить write scope только на
`C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-edit-only-send-guard.cjs`
и потребовал **реальный public setup**, а не инъекцию нового private bundle.
Внесённая правка отличается от временной диагностической подстановки выше:

- Удалены подмены `beginAsync`/`releaseRecorder` и `Object.assign` в private recorder state.
- `prepareVoice()` вызывает actual page `handleVoiceRecordStart()` → public `begin()`;
  fake заменяет только permission, AVRecorder, file I/O, clock/timers. Проверяются
  реальный prepare со своим FD, start, published UI recording; clock продвигается на 1500ms.
- Actual page `handleVoiceRecordSend()` → public `finishAndSend()` → stop/release/close →
  настоящий SendMediaMessageUseCase и fake gateway. Ожидание `['sendMediaMessage']`
  для channel/private и mediaKind='voice' сохранено; добавлены path и lifecycle trace checks.
- Captured-send guard теперь стартует разрешённую запись, затем через store revoke +
  actual `setEditMode` переводит страницу в edit-only перед поздним callback.
  Revocation during release задерживает настоящий SDK `release()` fake promise,
  а не приватный cleanup контроллера. Expected sends=[] сохранён в обоих случаях.
- SDK assertion failures учитываются отдельно от production catch; timer leaks запрещены.

Лично выполнено на финальном controller:

```text
node --disable-warning=ExperimentalWarning scripts/test-edit-only-send-guard.cjs
53 passed, 0 failed; exit 0
node --disable-warning=ExperimentalWarning scripts/test-voice-recording-ownership.cjs --negative-controls
22 passed, 0 failed; 8 negative controls rejected; exit 0
```

Дополнительные in-memory negative probes для адаптированного permission suite:
public `begin` превращён в no-op → **49 PASS / 4 FAIL, exit 1**;
fresh `host.getSendMediaUseCase('voice')` заменён прямым cached use case →
**51 PASS / 2 FAIL, exit 1**, именно edit-only captured send и revocation during release.
Expected sends/guards не ослаблены; обе мутации на диск не писались.

После окончательных правок лично повторён тот же общий host runner с исключением
`test-native-bridge.cjs` (R19): `{"suites":45,"passed":45,"failed":0}`, **exit 0**.
Ранее сообщённые parent 46-suite/38PS/Bash результаты не прибавляются к личным проверкам.

Дополнительно:

- `powershell -ExecutionPolicy Bypass -File scripts/test-ios-native-liquid-composer.ps1`:
  `Full iOS native-liquid composer source contract passed.`, exit 0.
- `powershell -ExecutionPolicy Bypass -File scripts/smoke-ui-phase0.ps1`:
  `tg_ui shell smoke checks passed.`, exit 0.
- `git diff --check` для production controller: exit 0.
- Независимый read-only reviewer сообщил no findings в узком R04. Дополнительные
  reviewer-only probes не включены в приведённые выше лично воспроизведённые числа.

## Ограничения fake SDK и открытые gates

- Это executable host/control-flow witness, не ArkTS type-check, Hypium или hardware acceptance.
  Ни main/ohosTest build, ни emulator/device не запускались; сборку родителя не затрагивали.
- Fake SDK контролирует promise settlement, state/FD legality и stop→release→close порядок,
  но не моделирует реальную конкуренцию микрофона, native callbacks, codec/muxer flush,
  файлы ОС, permission dialog или реальные ошибки/зависания SDK.
- Если create/prepare/start никогда не settle, локальный startup bundle остаётся ждать:
  timeout/forced native cancellation этот фикс не вводит. Не заявляется прекращение
  физического захвата микрофона на устройстве или успешный B при native contention.
- Поведение при реальном stop/release/close/unlink rejection остаётся best-effort logging;
  гарантия физического освобождения при ошибке SDK не доказана.
- Send fake не проверяет upload/TDLib acknowledgement. Отмена уже dispatched send и
  lifetime переданного в TDLib файла — отдельный контракт, здесь не исправлялся.
- Path uniqueness проверена для successive operations и двух живых controller из одного
  загруженного модуля. Разные процессы/изолированные module contexts и process restart
  не проверены. **Account-wide media safety не заявляется.**

## Изменённые файлы и fingerprints

Этот срез с разрешённым расширением пишет только:

1. `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/ChatVoiceRecordingController.ets`
2. `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-voice-recording-ownership.cjs` (новый)
3. `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-recording-ownership.md` (новый)
4. `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-edit-only-send-guard.cjs`
   (существовавший untracked файл; после явного разрешения пользователя)

Новый ohosTest не добавлялся. SHA-256:

```text
Controller BEFORE: 0f247e6bce3d0e17e7fe129495c125a0eefa4b51cfdf7927900edb7317165b79
First fix:         af36b9f909fcd9a478f266368e4b4d3a634095c6a8696bda53cfed44c9f93324
Controller FINAL:  5483f0e0f5c0164d51bb68f35218c7539e1085b71d37f35997865e52e31dddbd
New host script:   362ae293756d69a1bad99ade28b4699320c9dd98f98a52926abd197a1f8bfced
Fixture BEFORE:    f94b734beaabcae54091712503e40bbab99a25ef5d03930f6e916d4c13823b34
Fixture AFTER:     457daaeab1347b544a35c9d0294932163ab9a94c9481fa33112f1c2307a6791a
Duration policy:   7d1fa3c2eb7b09efd21b1d46192c636261fee27b33d486c0d20ccfb90198f5c7 (не менялась)
```

Controller hashes относятся к LF-normalized source и совпали с file hashes этой сессии.
Существующий diff относительно HEAD включает прежние dirty изменения; не откатывать
controller целиком через Git ради rollback этого среза.
