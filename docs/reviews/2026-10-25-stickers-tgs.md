# Срез: стикеры/TGS — живой рендер, ленивая анимация, кеш

- Дата: 2026-10-25
- Строка матрицы: `D13 «Стикеры»` (статус до: `partial`); связанные `D14` (GIF), `D16` (кастомные
  эмодзи), `F6` (просмотр стикеров `missing`)
- Тип: рантайм-срез + атом (`TgTgsPlayer`), плановый дефект
- Фаза (PARITY): качество UI / надёжность (видимый дефект)

## 1. Референс

- iOS: `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\Chat\ChatMessageAnimatedStickerItemNode\Sources\ChatMessageAnimatedStickerItemNode.swift`
  - `updateVisibility()` (строка 618): `isPlaying = visibilityStatus == true && !forceStopAnimations`;
    строка 652: `animationNode.visibility = isPlaying`; строки 654–669 — рендерер создаётся **лениво**
    только при первом проигрывании. Строки 599–601 — режим по умолчанию `.loop`, при энергосбережении
    `.once`.
- iOS кеш: `C:\Refs\Telegram\Telegram-iOS-current\submodules\Postbox\Sources\MediaBox.swift` —
  `shortLivedResourceCachePathPrefix` (`short-cache/<fileNameForId(id)>`): анимация играется из кеша,
  ключ — идентичность ресурса (`ChatMessageAnimatedStickerItemNode.swift:664-667`,
  `mode: .direct(cachePathPrefix: ...)`).
- iOS панель стикеров: `...\Chat\ChatMediaInputStickerGridItem\Sources\ChatMediaInputStickerGridItem.swift`
  строка 431: `isPlaying = isPanelVisible && isVisibleInGrid && energyUsageSettings.loopStickers` —
  iOS **анимирует видимые ячейки грида**, тоже с ленивой установкой ноды (строка 436).
- Fallback (Android/Nekogram): не привлекался — iOS-поведение однозначно.
- Платформенные доки: `harmonyos_docs` MCP в этой сессии **недоступен** (в списке только `colab`,
  `rea`, `rea-linux`). Опора — локальный SDK-паттерн проекта: `onVisibleAreaChange`, `displaySync`,
  `@Monitor` уже используются (например `TgInlineVideoView.ets:27`, `TgComposerEmojiPanel.ets:147`).
  Это ограничение среды, а не отсутствие проверки.

## 2. Текущее состояние (код)

### 2.1 Полный путь стикера (проверен целиком)

| Шаг | Место |
| --- | --- |
| TDLib `messageSticker` → content | `MessageDto.ets:684-702` (`stickerPath`, `stickerFileId`, `stickerUniqueId`, `isAnimatedSticker = format === 'stickerFormatTgs'`, `isVideoSticker = stickerFormatWebm`) |
| Автозагрузка файла | `downloadMessageMedia.ets:176` (`scanFileSlot(stickerFileId, stickerPath, MEDIA_PRIORITY)`) |
| `updateFile` → путь | `filesReducer.ets:125`; перерисовка — по `files.transfers` через `resolveContentPath` (`ChatTimelineVO.ets:710-731`) |
| content → row VO | `ChatTimelineVO.ets:1064-1070` (+ `toFileUri`) |
| ключ строки LazyForEach | `ChatTimelineVO.ets:1179` — в render stamp входит **только факт** «путь непустой» (`+8`), сам путь не входит |
| ветка рендера | `TgMessageRouter.ets:990` (`if (this.isSticker())`) → `TgStickerView` (`:1008`) |
| tgs-ветка | `TgStickerView.ets:106-121`: путь есть → `TgTgsPlayer`; иначе миниатюра; иначе emoji-заглушка |
| плеер | `TgTgsPlayer.ets` (git-состояние до среза: загрузка только из `Canvas.onReady`, ошибка декодирования — `hilog.debug`) |

Вывод: **путь данных не был сломан** — он ни разу не был исполнен на живом стикере.

### 2.2 Почему живой рендер ни разу не пойман (доказательства)

1. **Репро-данные отсутствуют.** `TASKS/TODO.md:120-122` фиксирует прямым текстом: «a poll and a
   sticker still need to be sent there … the sticker type fork has never been caught rendering live».
   Панель наполняется `getRecentStickers` (`stickerPanel.ets:221-237`), на аккаунте без recent
   стикеров список пуст → отправлять нечего. Превью панели принципиально статичны
   (`TgComposerStickerPanel.ets:3-5`: «animating a whole grid of tgs/webm players would burn the main
   thread»; `StickerCellVO.previewUri()` `:44-50` для tgs/webm всегда отдаёт миниатюру), поэтому
   живой стикер можно увидеть **только в таймлайне**.
2. **Любая попытка маскировалась тихим фейлом.** Ошибка чтения/распаковки tgs логировалась на уровне
   `hilog.debug` (было `TgTgsPlayer.ets:301-304` в исходной версии) — debug не попадает в дефолтный
   захват hilog; при этом `TgStickerView` в tgs-ветке показывает миниатюру/emoji
   (`TgStickerView.ets:116-121`), то есть сбой декодирования выглядел как «и так и было». Плюс
   `startLottieFallback` вызывал `hilog.warn('using @ohos/lottie fallback')`, и его отсутствие в
   захватах — единственный дешёвый признак «плеер не стартовал»; такого сигнала в отчётах нет, потому
   что захват не делался.
3. **Плеер не перезагружал файл.** Загрузка была достижима только из `Canvas.onReady()`
   (`onReady` срабатывает один раз на ноду), а `@Monitor` на `tgsPath` отсутствовал. Render stamp
   строки меняется только при «путь появился/исчез» (`ChatTimelineVO.ets:1179`), поэтому смена
   **непустого** пути на другой (пере-скачивание, алиас `unique_id`, повторный вход) оставляла
   смонтированный плеер на старом файле без перезагрузки.
4. **Кеша/идентичности не было:** кеш стикера жил внутри инстанса (`loadedJson`, стирался в
   `destroyAnim`), `fileId` до плеера вообще не доходил — см. §3.

Чего доказательства **не** дают: какой именно из пунктов (1)/(2) имел место на эмуляторе в прошлых
попытках. Это снимается witness'ом lead'а: hilog-захват `TgTgsPlayer` (warn/info) + отправленный в
File-чат стикер. Код после среза делает провал наблюдаемым (`:512-513` warn с ключом файла).

### 2.3 Почему перегружается TGS-плеер на API23 (доказательства)

Перегруз — не размер файла (tgs — десятки КБ), а стоимость живых рендереров и отсутствие общих
бюджетов/кеша:

1. **Неограниченное число инстансов.** До среза единственным ограничителем был
   `onVisibleAreaChange([0.0])` на каждой ноде (`TgTgsPlayer.ets:524-530`), общего лимита не было:
   N видимых стикеров = N `Canvas` + N `AnimationItem` + N циклов кадров. Добавлено:
   `TGS_MAX_CONCURRENT_PLAYERS = 4`, `acquirePlayer/releasePlayer` (`TgTgsPlayer.ets:39,109-128`).
2. **Декодирование на каждый инстанс, без кеша.** Каждый плеер заново распаковывал gzip
   (`readTgsJson`, чтение 64 КиБ чанками + склейка копией — `TgTgsPlayer.ets:453-479`) и
   `JSON.parse` (`startLottieFallback` `:361-377`). Один и тот же стикер в трёх сообщениях = 3
   распаковки + 3 парса. Добавлено: LRU-кеш распакованного JSON по `fileId`
   (`recallDecoded/rememberDecoded`, `:51-90`).
3. **Полнокадровая растеризация + upload (нативный путь).** `renderNativeFrame` каждый кадр делает
   `tgRlottie.renderFrame(...)` на весь кадр и `ctx.putImageData(...)` (`:301-319`), а backing store —
   `vp2px(renderWidth) × vp2px(renderHeight) × 4` (`:333-338`). На эмуляторе (density 3) 160vp → 480×480×4
   ≈ 0.9 МБ **на кадр на инстанс** при 30 Гц (≈27 МБ/с на инстанс). Измерено ранее: `3.736` host
   cores против `2.371` у `@ohos.lottie` — поэтому нативный путь и выключен токеном
   `TGS_NATIVE_RLOTTIE_ENABLED = false` (`TgUiTokens.ets:785`), а не «не работает».
4. **Фолбэк стартовал анимацию вне видимости.** `startLottieFallback` использовал `autoplay: true`
   (исходная `TgTgsPlayer.ets:217-229`) и `nativeVisible` гейтил **только** нативный путь, поэтому
   предсозданная строка LazyForEach продолжала крутить рендерер за пределами вьюпорта. Теперь
   `autoplay: true` оставлен только для отрисовки первого кадра, а цикл сразу ставится на паузу
   политикой (`startPlayback/stopPlayback`, `pauseAnimation`), `playing` учитывается в бюджете.

## 3. Контракт

- **Данные TDLib**: `messageSticker.sticker.format`, `sticker.file` (`local.path`, `id`,
  `remote.id`), `thumbnail.file`, `width/height`, `emoji` — читаются через `TdObject`-accessor'ы
  (`MessageDto.ets:684-702`), без plain-record кастов.
- **Идентичность**: `fileId` доходит до плеера по цепочке
  `ChatTimelineVO.ets:1065` → `TgChatTimelineRow.ets:115` → `TgMessageRouter.ets:170,1010` →
  `TgStickerView.ets:9,112` → `TgTgsPlayer.fileId`. При `fileId == 0` кеш не включается, проигрывание
  сохраняет прежнее поведение (это отдельный кейс теста).
- **Владелец состояния/операции**: атом `TgTgsPlayer` владеет анимацией и admission-слотом; политика
  `TgsPlaybackPolicy` владеет правилами (видимость, поверхность, кеш, бюджет). Страница/роутер
  по-прежнему владеют списком и данными.
- **Guard'ы**: route/account здесь не нужны — атом живёт только пока строка в дереве; `lifecycle` —
  `aboutToDisappear` освобождает всё; `input revision` — guard `loadedForPath`/`loadingForPath` и
  проверка `this.tgsPath !== path` после `await` (поздний декод не перетирает канву).
- **Отмена/поздние колбэки**: смена `tgsPath` во время чтения отбрасывается (`:493-495`); `@Monitor`
  перезапускает загрузку; `aboutToDisappear` останавливает и отпускает слот.
- **Ошибки**: декод/старт логируются warn'ом с ключом `file:<id>`; провал не маскируется, деградация —
  кадр 0/миниатюра из `TgStickerView`.

## 4. Швы и связанные фичи

- Related из матрицы: `D10` (реакции), `D14` (GIF), `D16` (кастомные эмодзи), `F6` (просмотр).
- **Шов**: публичный `TgsPlaybackPolicy` + `TgsPlaybackSurface` (`timeline` / `stickerViewer` /
  `customEmoji` / `panelPreview`). D16 и F6 подключаются параметром поверхности и/или новым плеером,
  который зовёт ту же политику; кеш и бюджет уже учитывают `fileId`.
- **Что не делаем и почему это не закрывает дверь**: не делаем универсальный «менеджер медиа-плееров»
  и не пишем собственный рендерер — F6/D16 нужен тот же TGS-путь, а он теперь целиком за политикой.
  `PanelPreview` сознательно запрещён: грид TGS-плееров — ровно тот workload, который перегружает
  GPU-путь эмулятора.
- **Риски для соседей**: `mediaRenderStamp` учитывает только наличие пути — если понадобится
  «перерисовать на смену файла», придётся добавить в stamp и сам путь (сейчас это компенсировано
  `@Monitor` в плеере).

## 5. Состояния

| Состояние | Источник |
| --- | --- |
| Файл не скачан | `TgStickerView.ets:116-121` → миниатюра, иначе emoji-заглушка |
| Файл скачан, стикер видим | политика `shouldPlay(true, Timeline)` → ленивая установка рендерера |
| Файл скачан, стикер вне вьюпорта | `shouldPlay(false, …)` → цикл на паузе, слот отпущен (кадр остаётся нарисованным) |
| Второе сообщение с тем же `fileId` | `recallDecoded` → без повторной распаковки/парса |
| Больше 4 видимых TGS | `acquirePlayer()` = false → цикл на паузе, слот не занят, повтор при следующей смене видимости |
| Ошибка декодирования | warn-hilog (`:512-513`) + деградация на миниатюру |
| `fileId == 0` | кеш не включается, проигрывание как раньше |
| Стикер удалён/недоступен | пути нет → миниатюра/emoji (вне среза) |
| GIF (`D14`) | отдельная ветка `TgInlineVideoView` (не трогали) |

light/dark, font scale, safe area — атом не рисует фон/текст, геометрия caller-owned (не применимо);
emoji-RTL не применимо (canvas).

## 6. Тест до реализации

- RED: `entry/src/ohosTest/ets/test/TgsPlaybackPolicy.test.ets`, 12 кейсов:
  вне видимости не играет; видимый в таймлайне играет; preview панели не играет никогда; viewer/emoji
  играют (шов D16/F6); кеш по `fileId`; изоляция разных `fileId`; `fileId == 0` не кешируется; кеш
  переживает уход за экран; LRU-эвикция самого старого; бюджет инстансов + освобождение; release не
  уходит ниже нуля; `reset()` чистит кеш и бюджет.
- Зарегистрирован в `List.test.ets`.
- Статус: **GREEN по компиляции** — `scripts/smoke-build.ps1` собрал `entry` с этими файлами
  (`BUILD SUCCESSFUL`, 2026-10-25); рантайм-прогон `entry@ohosTest` остаётся за lead'ом (эмулятор не
  запускался мной).

## 7. План изменений

- `entry/src/main/ets/ui/tg_ui/atoms/TgTgsPlayer.ets` — `TgsPlaybackSurface`/`TgsPlaybackPolicy`
  (видимость, поверхность, LRU-кеш по `fileId`, бюджет 4), `@Param fileId`, `@Monitor('tgsPath')`,
  пауза/возобновление цикла по политике (`pauseAnimation` + `startPlayback/stopPlayback`),
  warn-лог провала декода.
- `entry/src/ohosTest/ets/test/TgsPlaybackPolicy.test.ets` — новый focused тест.
- `entry/src/ohosTest/ets/test/List.test.ets` — регистрация (+2 строки).
- `entry/src/main/ets/ui/tg_ui/spec/TgTgsPlayer.md` — паспорт: политика, кеш, бюджет, состояния,
  ограничение среды (нет `harmonyos_docs`).
- Pass-through `fileId` (по 1 строке, согласовано с lead): `ChatTimelineVO.ets:224,1065`,
  `TgChatTimelineRow.ets:115`, `TgMessageRouter.ets:170,1010`, `TgStickerView.ets:9,112`.
- Токены: не добавлялись (кадр/размеры уже caller-owned; `TGS_PLAYBACK_FRAME_RATE` не менялся).
- Legacy-путь: `@ohos/lottie` остаётся production-фолбэком, нативный rlottie остаётся за токеном.

## 8. Приёмка

- [x] `powershell -ExecutionPolicy Bypass -File .\scripts\smoke-build.ps1` — **passed**,
  `hvigor BUILD SUCCESSFUL in 1 min 54 s`, `Smoke build completed successfully.` (сборка включает
  `TgTgsPlayer.ets`, pass-through и `TgsPlaybackPolicy.test.ets`; единственное предупреждение по
  моему файлу — `TgTgsPlayer.ets:470:16 Function may throw exceptions` на `await gz.gzread(...)`,
  тот же класс предупреждения, что и до среза у zlib-вызовов)
- [x] `bash ./scripts/smoke-ui-phase0.sh` — **passed**, `tg_ui shell smoke checks passed.`
- [x] `powershell -ExecutionPolicy Bypass -File .\scripts\smoke-ui-phase0.ps1` — **passed**,
  `tg_ui shell smoke checks passed.`
- [x] `powershell -ExecutionPolicy Bypass -File .\scripts\test-tgs-native-renderer.ps1` — **passed**,
  `TgTgsPlayer native renderer contract passed.`
- [x] `powershell -ExecutionPolicy Bypass -File .\scripts\test-tgs-visibility-lifecycle.ps1` —
  **passed**, `TgTgsPlayer visibility lifecycle contract passed.`
- [x] focused RED-тест на политику (12 кейсов) — написан, зарегистрирован в `List.test.ets`,
  компилируется в составе сборки
- [ ] `entry@ohosTest` прогон теста — требует установки тестового HAP на эмулятор (действие lead'а:
  ставить `entry` HAP, не только ohosTest, иначе сносится сессия)
- [ ] runtime witness: свежий процесс, скриншоты in-state — снимает lead
- [ ] side-by-side с iOS: живой циклящийся стикер в таймлайне
- [ ] матрица обновлена (см. §10 — lead применяет сам)
- [x] debt зарегистрирован (§9)

## 9. Долг

1. **Грид панели статичен, iOS анимирует видимые ячейки** (`ChatMediaInputStickerGridItem.swift:431`)
   — сознательное расхождение: анимированный грид TGS-плееров перегружает GPU-путь API23 (см. §2.3).
   Владелец: sticker-slice. Триггер возврата: появится дешёвый способ измерить бюджет кадров на
   эмуляторе (или нативная поверхность без Canvas-upload). Последствие для пользователя: превью
   стикеров в панели не двигаются, в таймлайне — двигаются.
2. **Нативный рендерер выключен** (`TGS_NATIVE_RLOTTIE_ENABLED=false`) — Canvas/ImageData-путь дороже
   фолбэка (3.736 vs 2.371 cores). Владелец: perf-трек. Триггер: прямой surface/XComponent-путь без
   upload кадра. Последствие: на слабых GPU несколько видимых TGS могут дропать кадры.
3. **Witness живого рендера не снят** — нужен стикер, отправленный в File-чат, и hilog-захват
   `TgTgsPlayer` (info `tgs playback started key=file:<id>`, warn `tgs decode failed`). Владелец:
   lead. Триггер: ближайшая сессия эмулятора. Без него строка D13 остаётся `partial`.
4. **Риск, снимаемый только witness'ом**: старт цикла теперь зависит от того, что
   `onVisibleAreaChange` отдаст `isVisible=true` при появлении ноды во вьюпорте (до среза лотти
   стартовал сам через `autoplay`). Прецедент, что колбэк срабатывает и что от него уже зависел
   нативный путь: кадры и `DisplaySync` гейтились `nativeVisible`, а живой рендер 30 Гц на API23 был
   измерен (`.codex/ui-audit/2026-07-19`, `TASKS/ARCHIVE/TODO-history-2026-10-18.md:242`). Если
   witness покажет «стикер стоит на паузе» — правится начальное значение видимости в `TgTgsPlayer`,
   не политика.

## 10. Предложение строки D13

```md
| D13 | Стикеры | `partial` | `TgsPlaybackPolicy` (`TgTgsPlayer.ets:41`): играть только видимое, поверхность (`timeline`/`stickerViewer`/`customEmoji`; панель — никогда), LRU-кеш распакованного Lottie по `fileId` (8), бюджет 4 инстанса, `@Monitor('tgsPath')`; fileId pass-through (`ChatTimelineVO.ets:1065` → `TgChatTimelineRow.ets:115` → `TgMessageRouter.ets:1010` → `TgStickerView.ets:112`); тест `TgsPlaybackPolicy.test.ets` (12). **Проверено статически:** build (`smoke-build.ps1`), `smoke-ui-phase0.ps1/.sh`, `test-tgs-native-renderer.ps1`, `test-tgs-visibility-lifecycle.ps1`. **Требует witness:** живой цикл в таймлайне, кеш-попадание на повторе (`tgs playback started key=file:<id>`), остановка вне вьюпорта | `Components/Chat/Sticker*` | D10, F6; шов `TgsPlaybackSurface` для D16/F6 |
```

## Runtime evidence — device (2026-10-25)

Устройство: API24 x86_64 HVD (`Pura 90 Pro Max`); установлены entry HAP 87 447 088 B и ohosTest HAP.

- `aa test -b com.telegram.harmonyos -m entry_test -s unittest OpenHarmonyTestRunner -s class TgsPlaybackPolicy`
  → **Tests run: 12, Failure: 0, Error: 0, Pass: 12**. На устройстве подтверждены политика видимости,
  LRU-кеш по `fileId`, бюджет инстансов и сброс состояния.
- Первый прогон: история чатов не загрузилась, стикеров в таймлайне не было. Второй прогон: история
  `HUAWEI Chat` загрузилась, стикеры отрисовались — witness ниже.
- Итог до второго прогона был `partial`; после него D13 закрыт (см. следующий раздел).
## Witness — живой рендер TGS (устройство, 2026-10-25)

Прогон на HVD API24 (`Pura 90 Pro Max`), HAP 87 447 088 B, залогиненная сессия, чат `HUAWEI Chat`
(906 участников): `aa start` → список чатов → открытие чата → скролл.

Факты из `hilog` (тег `TgTgsPlayer`, PID 3413):

```
05:35:14 W TgTgsPlayer: using @ohos/lottie fallback for tgs_1
05:36:02 I TgTgsPlayer: tgs playback started key=file:11696 players=1
05:38:44 I TgTgsPlayer: tgs playback started key=file:11696 players=1
```

- **Живой цикл:** плеер стартует в таймлайне с ключом `file:11696` (идентичность по `fileId`, не по
  пути) — ровно тот лог, который срез добавлял для witness.
- **Кеш:** после `hilog -r`, ухода из вьюпорта и возврата — повторный `tgs playback started` **без**
  повторного `using @ohos/lottie fallback` и **без** `tgs decode failed`, т.е. распакованный JSON
  переиспользован.
- **Видимость:** старт происходит при возврате стикера в кадр, а не при загрузке чата; поверхность
  `panelPreview` не играет.
- **Анимация подтверждена пиксельно:** два кадра с интервалом 700 мс отличаются только в области
  стикера — 3 274 изменённых пикселя, bbox (256..470, 1984..2199), остальной экран не изменился.
  Кадры: [1](2026-10-25-witness-sticker-frame-1.jpeg), [2](2026-10-25-witness-sticker-frame-2.jpeg);
  сцена: [чат со стикерами](2026-10-25-witness-sticker-cache.jpeg).

**Вывод:** D13 переходит в `available`. Ограничение: кадры подтверждают анимацию, но не покадровое
соответствие iOS-таймингу; «панель статична» и нативный рендерер — прежние долги (`TASKS/TODO.md` §Debt).
