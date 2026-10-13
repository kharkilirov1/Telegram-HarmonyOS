# Media account/page ownership — итог среза 2026-09-28

**Изоляция медиаплеера между account scopes и страницами реализована и проверена на source/host/compile уровне.** Финальный прогон: **53/53 host suites, 38 PowerShell checks, Bash smoke и обе forced serial HAP builds — PASS**. Два дефекта независимого ревью воспроизведены, исправлены и повторно проверены. Новая сборка в эмулятор не устанавливалась; device acceptance и полная production parity ещё не достигнуты.

## Что изменено

1. **AppStore:** одноразовый синхронный `subscribeScopeInvalidation`. Отзыв account scope немедленно прекращает владение playback, не дожидаясь очереди уведомлений UI. Exceptions, unsubscribe и вложенная invalidation не теряют observers новой эпохи. Использованы уже существующие точки shutdown/recovery/failure в AppCoreRuntime; зависимости core от UI не добавлены.
2. **Страница чата:** вместо raw global controller — `MediaPlaybackPageHandle`, связанный с account, chat, route и lifecycle. Старый cleanup не снимает новую подписку; одинаковые message IDs разных чатов не смешиваются. При возврате перерисовывается и старая строка. Обычный уход со страницы не останавливает global audio.
3. **Global playback:** reset очищает audio/metadata/search capability и отзывает старые handles. Новый чат с теми же ID/path получает новый player, а не переключает старый. Публикация metadata и следующий toggle принадлежат конкретному generation: синхронный callback не позволяет старому вызову отобрать управление у более нового.
4. **AVSession:** create/activate/destroy выполняются последовательно между аккаунтами. Pending session старого аккаунта освобождается, stale system commands проверяют revision/identity. Повторный attach не создаёт дубликат; временная ошибка create/activate допускает повтор на следующем playback intent. Поздняя activation получает текущие metadata, а не прошлый snapshot.

Основные production-файлы:
- [AppStore.ets](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/core/store/AppStore.ets)
- [GlobalMediaPlayback.ets](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/GlobalMediaPlayback.ets)
- [TgChatScreenPage.ets](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets)

Добавлены четыре suites: `test-app-store-invalidation.cjs`, `test-media-account-ownership.cjs`, `test-chat-media-page-ownership.cjs`, `test-chat-media-account-integration.cjs`. Обновлены fixtures в `test-global-media-ownership.cjs` и `test-media-playback-integration.cjs`. Все находятся в `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/`.

## Наблюдавшиеся ошибки и изменение результата

- После исправления отсутствующего import в host fixture: **12/18 PASS**, шесть behavioral FAIL. Терялись handler при первом bind/смене аккаунта; cross-chat same ID переключал старый звук; не было требуемого AVSession teardown/ownership. После production fix — **18/18**.
- Расширение на transient AVSession failures: **29/31 → 31/31**. Сессия теперь повторно создаётся на следующем намерении пользователя, не только при смене аккаунта.
- Reset внутри zero-snapshot callback: **31/32 → 32/32**; старое название больше не публикуется после отзыва scope.
- Независимый reviewer нашёл два P2: более новый same-handle intent перезаписывался внешним вызовом; ранняя подписка B удалялась поздним cleanup A. Родитель добавил также outer-toggle варианты: **32/37 → 37/37**. Все пять исходных reviewer probes лично повторены: **5/5**, exit 0. Reviewer отдельно повторил их и восемь outer-toggle вариантов; F1/F2 закрыты.
- Широкий runner сначала выявил **52/53**: mutation старого operation-only теста ломала новую account-инициализацию fixture вместо нужного пути. Исправлена только граница setup этого unit fixture; actual account integration по-прежнему выполняет настоящую привязку. Финально **53/53**. Parser/TypeError/timeout не считаются успешно обнаруженной продуктовой регрессией.

## Финальные проверки

Команды выполнялись из `C:/Users/Kharki/Desktop/Telegram-HarmonyOS` на Node `v24.12.0`.

| Проверка | Результат |
|---|---|
| `node scripts/test-media-account-ownership.cjs` | **37/37**, **19/19** source mutation controls обнаружены, exit 0 |
| `node scripts/test-app-store-invalidation.cjs --negative-controls` | **23/23**, **13/13** controls, exit 0 |
| `node scripts/test-chat-media-page-ownership.cjs` | **47/47**, sourceStable=true, exit 0 |
| Три page mutations: unguarded-handle / lost-unsubscribe / stale-zero-row | Ожидаемые **21 / 6 / 2 FAIL**, каждый exit 1 |
| `node scripts/test-chat-media-account-integration.cjs --negative-controls` | **23/23**, пять controls дают **10 / 1 / 3 / 4 / 2 FAIL**, итоговый exit 0 |
| `node scripts/test-global-media-ownership.cjs` | **41/41 + 14/14 controls**, exit 0 |
| `node scripts/test-media-playback-integration.cjs` | **4/4**, exit 0 |
| `node scripts/run-host-tests.cjs` | **53 suites: 53 passed, 0 failed**, exit 0 |
| Все `scripts/test-*.ps1` + `scripts/smoke-ui-phase0.ps1` | **38/38**, exit 0 |
| Git Bash `scripts/smoke-ui-phase0.sh` | exit 0 |
| Forced `assembleHap`, `module=entry@default` | **BUILD SUCCESSFUL**, exit 0 |
| Forced `assembleHap`, затем `module=entry@ohosTest` | **BUILD SUCCESSFUL**, exit 0 |
| `git -c core.whitespace=cr-at-eol diff --check` | exit 0 |

Сборки запускались последовательно с `--no-incremental --no-daemon`; команды и output сохранены в evidence JSON. ArkTS warnings о native declarations, потенциально бросающих SDK вызовах и MICROPHONE остаются; **без warning сборка не заявляется**. Signing пропущен из-за отсутствующей signing configuration.

Перед финальным host прогоном зафиксированы **775 hashes** файлов под `entry/src` и `scripts` (`*.png`, `*.jpg`, `*.mp4`, `*.hap`, `*.log` исключены); после прогона расхождений нет. Production sources не менялись между финальными сборками и этим прогоном; после build менялись только два test fixtures, затем повторно проверены. Хеширование не заменяет тесты и не доказывает полный clean-checkout build.

Финальные HAP SHA256:
- main: `dda26a67ba9c1801380d3215514a1dff64950daf8ef909884537c3e285d3ee95`;
- ohosTest: `8705e04a4a7ab16df02bade3a295b3e8a0c3818b32d5c6ed7acb7dfb15c5b75a`.

В main `modules.abc` найдены `subscribeScopeInvalidation`, `MediaPlaybackPageHandle`, `isAvSessionRequestCurrent`, `mediaPlaybackUnsubscribe`, `playbackIntent`: новый путь действительно вошёл в HAP. В test HAP присутствует AppStore observer; отсутствие UI/media классов там ожидаемо и не выдаётся за runtime coverage.

## Граница доказательства

- Host tests исполняют настоящие методы page/lifecycle, AppStore, Global и playback controller; отдельные случаи также настоящие AppCoreRuntime shutdown/recovery/failure. SDK, файловые/сетевые зависимости, ArkUI delivery и AVSession service заменены управляемыми doubles. Это **не** воспроизведение аудио/системной карточки на устройстве.
- Store и page suites по отдельности недостаточны: поэтому отдельно проверена actual page → Global → controller → snapshot цепочка и восстановление строки при навигации.
- Rejected `destroy()` подтверждает запрет старых команд и продолжение JS queue, но **не** освобождение native session. Постоянные ошибки/зависания SDK и фоновые ограничения ОС остаются device-гейтами.
- Свежий HDC read-only осмотр: `127.0.0.1:5555`, старый процесс Telegram **3020**, STIME **15:01:55** по часам устройства; shell-наблюдение **16:41:36**. Новые HAP не установлены, сохранённые данные и авторизация не тронуты. Реальные сообщения и запись голоса не выполнялись.
- Ветка `dev`, HEAD `faf66b3e066afccdbbfa36442eb9122073f509b2`; index пуст. Предыдущие dirty/untracked изменения сохранены; commits/push не выполнялись. Не использовать общий diff от HEAD как безопасный откат только этого среза: он включает прежнюю работу.

## Источники и дальнейшая граница

Platform grounding: `harmonyos_docs`, AVSession `destroy(): Promise<void>` / `activate()`; локальный iOS reference [MediaManager.swift](C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/MediaManager.swift), account/player identity и stop/detach. Это ориентиры ownership, не свидетельство визуальной или системной iOS parity.

- [Машинные результаты и hashes](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-media-account-evidence.json)
- [Независимое ревью и воспроизводимые probes](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-media-account-independent-review.md)
- [Page + actual integration](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-media-page-ownership.md)
- [AppStore observer](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-store-invalidation.md)

Полная цель проекта остаётся активной. Следующие открытые участки надёжности: native enqueue/async stop/open_count, unknown forward outcome; затем clean-checkout и device/UI gates нового HAP. Согласованный маршрут «надёжность → имеющийся UI → функции/UI → публикационная готовность» не заменён более узкой целью.
