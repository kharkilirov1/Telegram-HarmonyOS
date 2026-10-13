# Wave10 — запуск эмулятора и локализация системного сбоя

**Итог: эмулятор запущен и проверен. HDC shell доступен временно, но рабочего UI нет: SceneBoard получает LIFECYCLE_TIMEOUT, перезапускается четыре раза, затем ОС вызывает kernel panic. Telegram в диагностический профиль не устанавливался. Первопричина торможения ОС пока не доказана; device/visual acceptance проекта не закрыта.**

Все пути ниже относительно `C:/Users/Kharki/Desktop/Telegram-HarmonyOS`, если не указано иначе. Полная цель reliability → существующий UI → функции/UI → публикационная готовность остаётся активной.

## Что реально сделано

- Проверен уже работавший `Pura API24` (PID 31600, старт 00:54:04 UTC+05): его guest уже завершился panic в 01:04:28. Это не запуск Wave9. Wrapper остановлен штатным CLI, отсутствие PID проверено; userdata сохранены.
- Создан отдельный профиль `Codex API24 capture 20260906` под `.codex/emulator-smoke/`, не поверх пользовательского профиля: HarmonyOS 6.1.1(24), system build `6.1.0.125(SP9DEVC00E120R4P11)`, 4 vCPU, 4096 MiB RAM, 6 GiB storage. Использован обычный `coldboot`, без `reset`, без `-noWindow`; следующие запуски сохраняли данные этого профиля.
- На выделенном HDC target `127.0.0.1:10023` проверены реальные команды shell/date/processes, снят и прочитан screenshot, получены системные fault reports и два системных ELF-файла для символизации.
- Вспомогательный диагностический скрипт ограничивает время каждого HDC client. Он не останавливает общий HDC server и не меняет конфигурацию гостя. После panic остановлены только соответствующие emulator wrappers; их отсутствие проверено. Итоговый `hdc list targets`: `[Empty]`.
- Нет установки HAP, сброса профилей/аккаунтов, driver/security/pagefile изменений, реальных sends, commit/push/deploy/publication.

## Свежая временная шкала

В таблице host time UTC+05. В guest fault reports время CST UTC+08 — на три часа больше.

| Boot | Wrapper PID / начало | Реальный witness | Свежий terminal marker |
|---|---|---|---|
| 1 | 41712 / 02:24:44 | shell 02:26:44; чёрный screenshot; полный sysfreeze восстановлен в boot2 | SceneBoard exits 4times 02:30:14; panic 02:30:31 |
| 2 | 26028 / 02:43:18 | shell 02:46:09; SceneBoard PID 2329; полный fault получен 02:46:10 | SceneBoard exits 4times 02:46:22; panic 02:46:44 |
| 3 | 22444 / 02:54:30 | shell, ELF downloads, три текущих partial sysfreeze с PID 1829/2457/2671 | SceneBoard exits 4times 02:57:56; panic 02:58:20 |

Первый монитор boot2 ошибочно принял старый panic из повторно открытого log за новый по свежему mtime. Это ошибка диагностики, не дополнительный boot или panic. Монитор исправлен: сверяет timestamp каждой строки с началом запуска. Работа с тем же живым PID продолжена без лишнего перезапуска.

## Что показывают fault reports

Полный файл: `.codex/ui-audit/2026-09-06/wave10/sysfreeze-first-full.log`, 120212 bytes, SceneBoard 2.1.0.71, PID 3745. Причина — `com.ohos.sceneboard.MainAbility load timeout` / `LIFECYCLE_TIMEOUT`.

- Строки 81–90: main thread в `do_relocs → reloc_all → dlopen_impl → NativeModuleManager → ArkNativeEngine::RequireNapi`. Имена скрытых функций восстановлены из `.gnu_debugdata` загруженного ELF, а не угаданы по соседнему exported symbol.
- GNU Build ID musl `68fb7e82ebc144b704e40412fdcab7aa` совпадает с fault. `0x88cdd = do_relocs+1725`, `0x7ab3a = reloc_all+650`, `0x82d88 = dlopen_impl+6024`. Результат в `musl-resolved-pcs.json`. Исходный ELF не переписывался; XZ распакован только в памяти Python standard library.
- В более поздней выборке этого fault (строки 659–662) main thread имеет state D, без полученного стека. Это не доказательство конкретной причины I/O ожидания.
- В boot3 main-thread samples другие: PID 1829 ждёт синхронный `BundleMgrProxy::GetBundleInfoForSelf`, PID 2457 — `ScreenSessionManagerProxy::RegisterClientDeathListener`, PID 2671 исполняет `nontrivial_free → __libc_free → libark_jsruntime`. Поэтому нельзя объявлять NAPI relocation единственной причиной всех тайм-аутов.
- Guest snapshot (строки 539–541): MemTotal 4025348 kB, MemFree 2475736 kB, MemAvailable 3082232 kB. Host preflight: 12.56 GiB свободной RAM. В старом Pura boot были low-memory warnings, но текущие данные не доказывают RAM exhaustion как причину этих запусков.

**Доказано:** сбой системного startup до установки приложения. **Не доказано:** конкретный дефект GPU/драйвера, неисправный образ, режим аппаратной виртуализации, одна зависшая библиотека или выигрыш от увеличения RAM. Длительность проверки подписи system.img не равна измерению дисковой пропускной способности. Предупреждение readelf об ELF note тоже не доказывает повреждение образа.

## Достоверность capture и исправления инструмента

Новые файлы: `scripts/capture-emulator-scene-fault.ps1`, `scripts/test-emulator-capture.ps1`.

- Реальная готовность shell требует отдельной точной строки `WAVE10_READY`, а не exit 0 / Connect OK.
- Panic относится к текущему запуску только по timestamp строки, не по mtime файла.
- PID берётся из реального process row или AppDfr key, не из grep command; число валидируется перед формированием команды.
- HDC иногда возвращает `[Fail] Device not found or connected` с exit 0. Исправленный collector принимает fault только с фактическим HiviewDFX header; ошибки отделены в `faultReadError` и не затирают уже полученный fault.
- Последний фикс сделан **после boot3**, проверен host-тестами, но не новым boot. В сохранённом boot3 JSONL исторический счётчик `faultCount=8` неверен как число полученных файлов: фактически 7 разных успешных partial payloads (4 старых + 3 текущих), затем 6 неудачных чтений. Raw не переписан под исправленный скрипт.
- `-logZip` сообщил collection failure при exit 0 — архив не получен; сохранены реальные individual logs. HDC file recv использовал native Windows destination path. Для hilog использован `-x`, без несовместимого `-z`.

## Проверки и границы результата

Focused helpers: **14/14 PASS**. До добавления fault predicate тест завершился exit 1 (`Missing actual helper: Test-FaultCapture`); in-memory возврат старого условия exit0 + nonempty stdout даёт воспроизводимый exit 1: `HDC exit zero with failure text is not a fault`. Мутация не записывалась в проект.

Свежая полная PowerShell/source-contract regression: **38/38 PASS** (37 `test-*.ps1` + `smoke-ui-phase0.ps1`), общий runner exit 0. Production ArkTS в Wave10 не менялся: проверены SHA256 всех 48 изменённых/новых `.ets` из Wave9 — совпадают, дополнительных dirty `.ets` нет. Compile/build и CJS результаты Wave9 остаются историческими, не выдаются за новые Wave10 запуски. Host-regression, hashes и окончательный diff-check записаны в соседнем `2026-09-06-reliability-wave10-evidence.json`.

Свежий `.codex/ui-audit/2026-09-06/wave10/boot.jpeg` (1320×2856, 60055 bytes) лично просмотрен: полностью чёрный. Это OS failure witness, не UI acceptance Telegram. Device runner, signing/install, navigation/media/permission E2E и visual parity не подтверждены.

## Параллельная работа по проекту

Субагент Gibbs выполнил read-only аудит ordinary megagroup/booster contract и закрыт. Основной агент повторно прочитал `tdlib/td/telegram/DialogParticipant.cpp:456–490`, `ChatManager.cpp:8477–8496,8743–8745` и iOS input-panel reference. Подтверждено: booster снимает default restrictions, но не индивидуальные; creator/admin имеют отдельный bypass. Отсутствующий FullInfo в AppStore нельзя приравнять к отсутствующему внутреннему TDLib cache.

Прямой probe текущего selector даёт RED: при концептуально известном boost 3/3 и индивидуально разрешённом text, запрещённом photo ожидается composer/restricted, фактически restricted/restricted. Ограничение probe: selector ещё не имеет booster snapshot input; это свидетель отсутствующей policy, не end-to-end тест будущего FullInfo flow. Production-исправление в Wave10 не делалось.

Следующий source-срез: typed `my_boost_count`/`unrestrict_boost_count`, exact scoped FullInfo hydration + live updates + per-kind policy, с отдельными unknown/cache/membership cases. Системную диагностику продолжать только с новым различающим измерением (например, CPU/storage/IPC latency в раннем boot или поддерживаемой конфигурацией по official emulator docs), не повторять одинаковый coldboot и не отключать watchdog/security наугад.

## Grounding

`harmonyos_docs` доступен: запросы `faultlogger AND hdc` и `LIFECYCLE_TIMEOUT` дали official fault retrieval / Performance Analysis Kit lifecycle classification. Они не устанавливают root cause этого guest. CPL HTTP health отказал в соединении; использован прямой read уже известных исходников и локальных логов, без выдачи retrieval chunks за проверенный код. External iOS source: `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/ChatInterfaceStateInputPanels.swift:234–255`.

Доказательства сохранены локально в `.codex/ui-audit/2026-09-06/wave10/`. Диагностические профили и прежние пользовательские данные сохранены. Глобальные prompts/memories не менялись.
