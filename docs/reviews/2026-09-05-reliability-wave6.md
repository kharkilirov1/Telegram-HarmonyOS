# Reliability wave6 — forward ownership и запуск эмуляторов

Дата: 2026-09-05. Ветка `dev`, исходный baseline ревью `faf66b3`; накопленные незакоммиченные изменения сохранены.

## Результат

Исправлены воспроизведённые гонки отправки/пересылки: устаревший forward не начинает следующий запрос после отзыва доступа или смены контекста, старый callback не снимает busy новой операции, failed send не восстанавливает старый аккаунт/черновик поверх нового состояния. Focused witness: **51/51 PASS**; main и ohosTest принудительно пересобраны.

По просьбе пользователя выполнены обычные запуски двух существующих эмуляторов и нового изолированного экземпляра. Во всех трёх гостевая ОС дошла до **`SceneBoard exits4times` → kernel panic**. Чистый экземпляр кратковременно дал рабочий HDC shell и настоящий screenshot, но экран чёрный; проект в него не устанавливался. **Проверка приложения на устройстве не выполнена**, причина системного падения не установлена. Запущенные нами процессы остановлены; существующие профили и сессии не удалялись.

## Что воспроизведено и изменено

Первый actual-source harness: **8 PASS / 34 FAIL**, 42 случая. После основной правки и расширения матрицы отдельный случай «failed text становится caption нового attachment» дал **50 PASS / 1 FAIL**; добавленный guard устранил его.

- `ChatMessageActionsController`: повторная проверка владения и актуальных capabilities перед deferred dispatch и после awaited comment. Непустой обязательный comment не пропускается молча при отсутствии text capability. Успешно отправленный comment не восстанавливается для повторной отправки при ошибке forward.
- `TgChatScreenPage`: единый `sendingMessageOperation` для forward/text/media, инвалидация через `setSendingMessage` при старте/reset; `hasActiveChatState` использует захваченный account-scoped store.
- `ChatComposerController`: владение через page token, а не отдельный controller-local counter. Failed text восстанавливается только в актуальном чате без edit, forward, attachment или нового draft.
- Cleanup зависит от владельца operation/lifecycle/chat, а не от permission-gated use-case getter. Отзыв права не оставляет busy навсегда; старое завершение не отменяет новую операцию.

Production-файлы находятся в `entry/src/main/ets/ui/pages/chat/`. Добавлены `scripts/test-forward-send-ownership.cjs` и `entry/src/ohosTest/ets/test/ForwardSendOwnership.test.ets`; suite зарегистрирован в `List.test.ets`. Два соседних harness (`test-edit-only-send-guard.cjs`, `test-send-cleanup-ownership.cjs`) подключают новые actual page helpers и инициализируют token; expectations не ослаблены.

### Границы тестов

CJS загружает реальный controller/use-case/scoped-store код и извлечённые actual page methods; gateway, file I/O и presentation заменены явными fixtures. В 51 проверку входят 6 реальных native test bodies через Hypium host adapter. Это **не запуск Hypium на HarmonyOS**. Native suite скомпилирован; его typed host отдельно от интеграционной проверки actual page.

Проверены revoke/edit/chat/lifecycle/reset до dispatch и после comment; success/failure, retry без дублирования comment, смена draft/attachment, все forward↔text/media takeover-направления, остановка старого batch, межаккаунтное восстановление буфера. Тесты не отправляют реальные сообщения.

| In-memory mutation | PASS / FAIL | Exit | Изменений действительно применено |
|---|---:|---:|---:|
| `no-dispatch-guards` | 34 / 17 | 1 | 2 |
| `permission-cleanup` | 25 / 26 | 1 | 1 |
| `shared-owner` | 39 / 12 | 1 | 2 |
| `account-restore` | 45 / 6 | 1 | 2 |

Mutations изменяют загруженные строки, не исходники на диске. Падения подтверждают участие нужных guards, а не прохождение тестов по fallback.

## Верификация после последних source-изменений

- Все **23 CJS scripts**: exit 0; соседние edit-only **51/51**, cleanup **52/52**, group payload **115/115**.
- **36 PowerShell scripts + UI smoke = 37/37**; review-witness **8/8**; `node --check` **24/24**; `git diff --check`: exit 0.
- `assembleHap --no-incremental --no-daemon`, последовательно `entry@default` и `entry@ohosTest`: оба exit 0.
- Main `CompileArkTS`: **1 min 57 s 61 ms**, build **3 min 47 s 606 ms**. OhosTestCompileArkTS: **32 s 813 ms**, build **54 s 517 ms**.
- **41 изменённый/новый `.ets` SHA256** совпадает до/после сборки и при итоговом перечитывании. После сборки source не менялся.
- Сборки имеют warnings, включая `icudtl.dat missing`; signingConfigs отсутствует, HAP unsigned. Успешная компиляция не доказывает installation/runtime/visual acceptance.

Машиночитаемые счётчики, результаты и hashes: `docs/reviews/2026-09-05-reliability-wave6-evidence.json`.

## Эмулятор: выполненные проверки

HDC client/server **3.2.0e / 3.2.0e**. Использован штатный `Emulator.exe` из DevEco, обычный boot без `-noWindow`; процессы запускались с Windows `WindowStyle Hidden`. Новый образ не скачивался. Времена старта — host UTC+5, ошибки — timestamps локальных emulator logs.

| Экземпляр | Старт / PID | Наблюдение |
|---|---|---|
| Существующий Pura API24 | 23:14:21 / 16872 | Guest boot, затем SceneBoard failure 23:17:27.361, panic 23:17:45.852; успешного shell нет |
| Существующий Pura X Vie, API26 Beta1 | 23:21:19 / 17392 | Проверка system image продолжалась 221601 ms; listener 5555 принадлежал процессу. TCP Connect OK не подтвердился shell. SceneBoard failure 23:27:08.586, panic 23:27:31.791 |
| Новый `Codex API24 clean 20260905` | 23:37:21 / 30500 | Shell sentinel 23:39:36, настоящий screenshot; затем SceneBoard failure 23:42:55.092, panic 23:43:13.482 |

Изолированный экземпляр создан штатным CLI из установленного `HarmonyOS 6.1.1(24)`: memory 4 GiB, storage 6 GiB, coldboot, hotBoot false. Расположение: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/.codex/emulator-smoke/Codex API24 clean 20260905`. Он сохранён для диагностики; custom-root instance не перечисляется обычным default `-list`. Existing image/userdata не сбрасывались.

В чистом guest реально сработали remote `date`, `ps`, просмотр faultlogger и `snapshot_display`. Screenshot получен через `hdc file recv`: `.codex/ui-audit/2026-09-05/wave6/clean-boot.jpeg`, **60055 bytes, 1320×2856, визуально полностью чёрный**. SHA256 записан в evidence JSON. Guest clock `Sun Sep 6 02:40:19 CST 2026` согласуется с host UTC+5 по часовому поясу.

Для API26 screenshot CLI напечатал success, но файла не было; `Emulator.log` сообщил `Emulator display is not ready.` Это не visual witness. `snapshot_display` принимает `.jpeg`, а `-h` означает height; ошибочные попытки с `.png` не считаются capture.

После panic все три собственных процесса остановлены штатным CLI и отсутствие PID проверено. HDC оставляет адреса 10001/5555 со статусом **Offline**, это не доступные устройства. HDC server не перезапускался. **Никакой HAP не установлен, native tests не исполнены, пользовательские account-действия не выполнялись.**

### Вывод и предел диагностики

Такое же системное падение воспроизводится в новом профиле **до установки проекта**. Значит, его нельзя объяснить только Telegram-HarmonyOS или только старым userdata. Причина внутри host/emulator/shared image/platform пока не локализована. Наблюдения GPU и SceneBoard AVC/QOS не доказывают виновника; драйверы, SELinux, pagefile и signing не менялись. Старый `Commit charge is not enough!` не описывает эти три boot, дошедшие до guest.

Новый запуск имеет смысл с новым диагностическим планом: использовать короткое Connected-окно чистого экземпляра для focused SceneBoard/system fault capture. Не повторять boot вслепую и не удалять профили ради предположения.

## Grounding и дальнейшая работа

- `harmonyos_docs`: Monitor Application Scenarios и JsUnit User Guide; инструкция `aa test -b ... -m ... -s unittest OpenHarmonyTestRunner -s class ...` найдена, но не исполнена на Offline guest.
- После предыдущего CPL timeout использовано точное локальное чтение source; confidence retrieval не подменяет код.
- Прочитан iOS `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/Chat/ChatControllerLoadDisplayNode.swift:2061–2088`: selection IDs сортируются, forward options/resetCurrent обрабатываются отдельно. Это source reference, не доказательство текущей App Store реализации и не прямой аналог Harmony ownership fix.
- Локальный `tdlib/td/generate/scheme/td_api.tl:10873–10881` требует strictly increasing IDs, максимум 100 и can_be_forwarded. Полнота этих проверок у клиента требует отдельного аудита; этот срез её не заявляет.
- Следующий source-срез: effective group/per-media policy, default send bits, admin/creator/booster exceptions, unknown group hydration и соответствующие action guards. Wave5 сохраняет payload, но ещё не реализует всю policy.

Полная цель остаётся открыта: надёжность → имеющийся UI → функции/UI → публикационная готовность. Device acceptance, iOS visual parity и сравнительная надёжность **не доказаны**.
