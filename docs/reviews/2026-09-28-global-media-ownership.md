# Global media playback ownership — 2026-09-28

## Результат и граница доказательства

Исправлены воспроизведённые гонки global playback: поздние search/download/cover
не получают право запускать трек или менять metadata после `stop()`/нового
`setNowPlaying()`. Поздний `stop()` не отменяет background нового владельца;
context-wide background start/stop выполняются последовательно.

**Host witness: 41/41 PASS, 14/14 in-memory negative controls выявлены, exit 0.**
Тот же финальный harness с исходным Global из HEAD: **12/41 PASS, 29 FAIL, exit 1**.
Это не device/runtime acceptance и не account-wide/session isolation.

Изменены только:

- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/GlobalMediaPlayback.ets`
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-global-media-ownership.cjs`
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-global-media-ownership.md`

Controller, page/API callers, root docs и отдельный integration harness parent
этим worker не изменялись. Публичные сигнатуры Global сохранены.

## Grounding

Прочитаны STATUS/TODO/DECISIONS/ARCHITECTURE/REFERENCES и активный execution route:
надёжность перед визуальной полировкой. Архитектура AppStore/TDLib не менялась.

- `harmonyos_docs` queried: `"startBackgroundRunning" "stopBackgroundRunning"`,
  `"stopBackgroundRunning" "Promise"`, `"AVPlayer" "play" "Promise<void>"`,
  `"AVPlayer" "prepared" "stateChange"`.
  Официальный Background Tasks Kit описывает `stopBackgroundRunning(context)` как
  отмену **всех continuous tasks текущей UIAbility**; Promise API не принимает
  playback-owner. Поэтому проверка generation после уже отправленного stop не
  защищает новый native start — нужна сериализация этих SDK-вызовов.
- `C:/Refs/Telegram/HarmonyOS-Codelabs/Media/AudioPlayer/entry/src/main/ets/common/utils/BackgroundTaskUtil.ets`:
  WantAgent → AUDIO_PLAYBACK start, context-wide stop. Пример не является доказательством отсутствия гонок.
- `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/SharedMediaPlayer.swift:203-235`:
  playlist updates доставляются на main queue; при смене playback data предыдущий
  item останавливается/отсоединяется перед созданием нового. Использовано как
  behavioral reference, без заявления visual parity или переноса iOS architecture.
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/generate/scheme/td_api.tl:12408-12421`:
  `downloadFile(... synchronous:true)` отвечает после завершения/ошибки/отмены;
  `false` возвращает текущее состояние, дальнейшее завершение идёт через updates.
  Проверен также `searchChatMessages` на строке 10595 и фактические
  `findAdjacentAudio`, `downloadAudioSync`, `requestThumbDownload` в
  `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/domain/usecases/searchChatMessages.ets:239-298`.

## Изменение

- `playbackGeneration`: новый `setNowPlaying` и начало `stop` синхронно отменяют
  право прежних продолжений. Message ID не подходит для ownership: `'0'`,
  одинаковые IDs и ABA воспроизведены.
- `adjacentRequestId`: последнее adjacent-намерение побеждает, даже если старый
  поиск завершается раньше нового. Проверки после find/download/toggle и перед
  итоговым успехом; устаревшая операция возвращает `false`, не применяет speed.
- Cover привязан к generation и file ID, а не к ещё прежнему UI message ID.
  Актуальная обложка переживает штатный initial-zero → active snapshot.
- Background разделён на desired-state и подтверждённое завершением SDK состояние.
  Одна Promise-очередь сериализует native effects; queued reconciliations coalesced.
  После `getWantAgent` желание проверяется снова. Ошибка не отравляет очередь.
- Explicit stop ставит cleanup **до** ожидания controller release. `finally`
  повторно запрашивает cleanup только для всё ещё текущего владельца.
- Linger имеет generation + отдельный cancellation token. Новая metadata отменяет
  ещё не отправленный linger-stop, но получает собственный ограниченный grace
  period. Завершённый linger не даёт metadata-only публикации запустить background.

## RED → GREEN

Первая проверка до production edits: **8/28 PASS, 20 FAIL**, exit 1.
Baseline SHA-256: `898917fad4f2d2e498f23ba763264ae5ad0d3ce2343eafa9f37b89fa85ac1632`.
В частности: stale find начинал download (`1 !== 0`), stale download возвращал
`true !== false`, cover A затирал B, native stop пересекался с pending start.

Независимое read-only ревью выявило дополнительное окно pending background start
→ stop/release pending → новая metadata без успешного play. До второго исправления
оно и ещё два linger-сценария дали **37/40 PASS**, exit 1. После исправления
отдельный regression-check metadata-only после завершённого linger дал
**40/41 PASS**, exit 1; затем исправлен без расширения write scope.

После исправления controller в parent прежние три integration assertions были
повторно проверены: **38/41 PASS**, exit 1 (`'10'/'11' !== '0'`). Это устаревший
test contract: controller публикует текущий prepared-трек **до** `play()`, а не
скрывает его до завершения Promise. Исправлены только harness/report, production
Global остался byte-for-byte frozen. Теперь проверяются реально наблюдаемый initial
zero, видимый prepared ID с `hasActive=true`/`isPlaying=false`, SDK `playing` event
до resolve Promise и неизменность released state после позднего resolve. Повторная
проверка дала **41/41 + 14/14 controls**, без удаления/добавления cases или mutations.

Финальные команды из корня репозитория:

```powershell
node C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-global-media-ownership.cjs --baseline-head
# Global media ownership: 12/41 PASS; exit 1 (ожидаемый RED)

node C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-global-media-ownership.cjs
# Global media ownership: 41/41 PASS
# Harness deadline control: dangling Promise rejected (real keepalive timer)
# In-memory negative controls: 14/14 rejected
# exit 0
```

Финальный Global SHA-256:
`187c105a3b81dc664e8b792b4da19fc3b4176442497ef4cb8cc7aea47654c35f`.
Controller, прочитанный только для финальных integration cases:
`496a9ddd8252dc775f434072014e1ff5e415524dbe0f24039841d1f0b64c9e92`.
Оба финальных прогона (current Global и baseline HEAD Global) использовали именно
этот controller; исходный Global baseline hash не изменился:
`898917fad4f2d2e498f23ba763264ae5ad0d3ce2343eafa9f37b89fa85ac1632`.
HEAD Global с нормализованными LF совпал по hash с исходником первого RED.
`git diff --check` для production-файла: exit 0, только предупреждение LF/CRLF.

### Negative controls — только in memory

| Отключённая защита | Behavioral FAIL из 41 |
|---|---:|
| generation нового setNowPlaying | 7 |
| generation stop | 6 |
| ordering adjacent requests | 1 |
| post-find guard | 2 |
| post-download guard | 3 |
| cover ownership | 4 |
| post-toggle guard | 3 |
| late-stop guard | 2 |
| сериализация background effects | 5 |
| post-WantAgent guard | 1 |
| весь linger owner guard | 2 |
| same-generation timer token | 1 |
| немедленная постановка stop cleanup | 2 |
| отмена queued linger новым startup | 1 |

Для каждой mutation проверяются ровно одно заменённое место, падение конкретного
ожидаемого теста и класс `ERR_ASSERTION`, а не syntax/load error или timeout.
Исходник на диске сравнивается с прочитанными до запуска bytes — mutation его не меняет.

## Что именно выполняет harness

Node 24.12.0 загружает **фактический Global ETS body**: удаляются imports,
типы, ArkUI decorators; production control flow не переписывается.
37 unit-сценариев используют управляемый controller collaborator, 4 integration
сценария загружают также **фактический MediaPlaybackController ETS body**.
SDK, сеть, файловые дескрипторы и platform timers замоканы; ресурсов устройства нет.
Integration cases записывают фактические snapshots через page listener: initial
`'0'` → visible prepared current ID с `isPlaying=false` → SDK playing event.
Prepared ownership публикуется до `play()` resolve; SDK state/event и Promise
settlement независимы. Проверены актуальная cover во время prepared, stop уже
играющего трека при pending play Promise, замена prepared adjacent новым треком и
join старого release. В fake SDK state-version не позволяет позднему play Promise
перезаписать более новое состояние, в частности `released`; released проверяется
и до, и после позднего resolve. Mock SDK violations записываются отдельно, чтобы
production catch не скрыл ошибку тестового контракта.

Каждый test имеет реальный 1500 ms deadline/keepalive. Отдельный known-negative
тест подаёт никогда не завершающийся Promise и подтверждает rejection по deadline.
Platform linger timers доставляются вручную: тест same-generation cancelled callback
— defensive stress-case, не доказательство такой доставки после clearTimeout на SDK.

## Открытые границы и пропуски

- **Account-wide auth/session isolation НЕ интегрирована.** Snapshot не содержит
  chat/account identity; page handlers остаются global, их регистрация/снятие не
  имеют page lease. Auth reset не подключён к этой generation. Это следующий gate.
- Сторонние прямые `controllerRef()` вызовы без согласованного `setNowPlaying`/`stop`
  не становятся автоматически global ownership boundaries. Page callers не менялись.
- Сеть не отменяется: устаревшие результаты игнорируются. Не добавлялся глобальный
  `cancelDownloadFile`, который мог бы затронуть других потребителей того же файла.
- SDK background операции могут зависнуть или отвергнуть cleanup. Очередь сохраняет
  последнее подтверждённое состояние и может повторить действие по следующему
  intent/tick/finally; гарантированного autonomous retry budget нет. При отсутствии
  следующих событий после ошибки stop cleanup не гарантирован. Другие владельцы
  continuous tasks той же UIAbility этой локальной очередью не управляются.
- Создание/уничтожение AVSession и порядок фактического применения уже отправленных
  SDK metadata/state запросов не проверены. Покрыто недопущение **новых** side effects
  от поздних find/download/cover продолжений, не все OS/AVSession lifecycle гонки.
- **Hvigor main/ohosTest и broad smoke worker не запускал**: serial final builds
  выполняет parent. Его промежуточные результаты здесь не выдаются за проверку
  финального hash. Host stripping не заменяет ArkTS compilation.
- Эмулятор, аккаунты, сообщения, микрофон, secrets, commits/push не затрагивались.
  Device audio, Control Center, background-kill и визуальное соответствие iOS
  остаются непроверенными.

## Повторно используемый вывод

Generation guards нужны до каждого нового async side effect, но не отменяют уже
отправленный context-wide native stop. Для такого SDK необходима последовательная
очередь; desired cleanup следует ставить при отмене, а не только в позднем finally.
Тестировать надо и неуспешный новый startup без active snapshot, иначе happy-path
нового playback скрывает потерянный cleanup старой операции.
