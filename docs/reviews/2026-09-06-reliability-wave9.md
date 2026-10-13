# Reliability Wave9 — basic-group media permissions

2026-09-06. **Срез подтверждён source + host execution + двумя forced CompileArkTS. Runtime/visual acceptance не получена; проект не готов к публикации.**

## Результат

- Все девять default send bits проходят initial chat → DTO → live normalizer → reducer → clone/partial update. Individual restrictions пересекаются с defaults по конкретному типу; active basic-group creator/admin сохраняют bypass, inactive/left/banned не получают отправку.
- Media-only basic group больше не закрывает composer из-за запрета текста. Caption отправляется с разрешённым media, не отдельным запрещённым text message.
- Actual page getters и composer/voice/forward callbacks проверяют конкретный тип. Media batch повторно проверяет именно свой тип после await: разрешённый document не позволяет продолжить отозванную photo batch.
- Неизвестные defaults получают отдельный bounded `getChat` после `getBasicGroup`; malformed response показывает retry. Live snapshot не заменяется поздним hydrate; unrelated title update не теряет hydrate. Account-scoped store и generation guards сохранены.
- UI имеет явный `@Local composerAllowedKinds` и отдельные `@Param sendEnabled/voiceEnabled`, category/photo/video flags. Недоступный текст не превращает Send в microphone. Recent media затемняется и не выбирается при запрете.
- Native picker ограничен допустимыми типами; video-only открывает video picker. Результаты проверяются по chat/lifecycle/generation и текущим правам; старый picker не заменяет новый attachment.
- Forward проверяет cached source content kinds до/после comment с захваченными IDs, даже после очистки preview. Unknown source разрешается только если разрешены все возможные send kinds.

## Основание решений

Лично перечитан `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramCore/Sources/ApiUtils/TelegramGroup.swift:14–42`: sendSomething — любая разрешённая категория, creator/admin exception. Это source reference, не визуальный witness текущего iOS.

Локальная TDLib schema: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/generate/scheme/td_api.tl:924` (девять send bits) и `:10283` (getChat chat_id:int53 → Chat). HarmonyOS MCP ответил на `"@Param" AND "one-way"`: V2 primitive @Param read-only; для изменений child используются события. Picker lookup вернул deprecated Core File Kit enum и ссылку на предпочтительный photoAccessHelper: новая реализация остаётся на уже используемом photoAccessHelper, не мигрирует на deprecated picker API.

Ориентация по ранее прочитанным CPL/project docs и текущим исходникам. Повторный идентичный CPL timeout не запускался. Независимого subagent review именно Wave9 нет: ранее достигнутый quota blocker не выдаётся за успешное ревью.

## Проверка изменений

Harness: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-basic-group-media.cjs`. Исполняются настоящие normalizer/reducer/scoped store, extracted page methods, controllers/use cases, scalar atom handlers и шесть native test bodies через host adapter. Transport/native pickers/file I/O — fixtures; реальные сообщения не отправлялись.

Контролируемые RED → GREEN: hydration 31/3, picker 36/6, invalid empty-kind file preparation 50/1, reactive snapshot 51/1 → **52/0**. Первый вариант harness имел отсутствующий ChatDto dependency в AppEvent loader: его ошибки **не** засчитаны production-дефектами; dependency исправлена, число normalized events проверяется явно.

| In-memory mutation | PASS | FAIL | Замены |
|---|---:|---:|---:|
| transport | 16 | 36 | 1 |
| selection | 26 | 26 | 1 |
| dispatch | 33 | 19 | 1 |
| batch | 51 | 1 | 1 |
| hydration | 51 | 1 | 1 |
| picker | 50 | 2 | 1 |
| voice | 51 | 1 | 3 |

Каждый mutant завершился exit 1; production-файлы при mutation не менялись. Voice source загружается в три отдельных scalar probes, поэтому три применения.

Финальные проверки после последних production-правок:
- **52/52 focused**, включая **6 native bodies через host adapter**, не device Hypium.
- **26/26 CJS**, **37/37 PowerShell + UI smoke**, review witness **8/8**, syntax **27/27**, `git diff --check` exit 0.
- main `CompileArkTS`: **1 min 7 s 645 ms**; `assembleHap`: **1 min 38 s 218 ms**, exit 0.
- `OhosTestCompileArkTS`: **31 s 932 ms**; `assembleHap`: **1 min 3 s 430 ms**, exit 0.
- Forced flags: `--no-incremental --no-daemon`. **48 modified/new .ets SHA256 совпали до и после финальных двух сборок.** Более ранний build до последних правок не засчитан финальным witness.
- Соседние fixtures получили реальные default snapshots и новые module dependencies; прежние allowed/denied expectations сохранены. Gallery source-contract уточнён под photo/video permission choice и подтверждён functional picker cases.

Детали и hashes: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-06-reliability-wave9-evidence.json`.

## Эмулятор

Свежий `hdc list targets`: **[Empty]**. В этой волне emulator boot и HAP install не выполнялись; device suites и UI не проверялись. Предыдущий отчёт Wave6 фиксирует SceneBoard exits → kernel panic даже у чистого API24 до установки проекта; это прежнее свидетельство, не новый boot сегодня. Повторять тот же boot без новой диагностической точки не стал. Установки, аккаунты и профили не удалялись.

## Оставшиеся ограничения

1. **Ordinary supergroup/megagroup + booster/full-info policy ещё не реализована этой волной.** Нельзя переносить basic-group AND механически.
2. Capability transport девяти категорий не добавляет отсутствующие audio/music/videoNote/poll/checklist UI и send features. Реальный media serializer здесь ограничен photo/video/document/voice; неизвестный kind не превращается в document.
3. Gallery при одновременно разрешённых photo/video сохраняет прежний photo-first picker; video доступно через recent grid, а video-only picker теперь корректен. Mixed media batch и полная iOS gallery parity не заявлены.
4. Forward при неполных cached source metadata и частичных правах может быть консервативно недоступен. Автоматическая hydration source metadata, can_be_forwarded eligibility и неоднозначный transport failure остаются отдельными задачами.
5. Basic-group migration/DeleteChat CTA, полная edit eligibility, OS crash root cause, native/device execution и визуальная приёмка открыты.
6. Внешних публикаций, commits/push, deploy или реальных sends нет. Полный маршрут надёжность → существующий UI → функции/UI → публикационная готовность остаётся активным.

## Изменённые production-файлы

- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/core/model/AppState.ets`
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/core/model/dto/ChatDto.ets`
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/core/events/normalizers/ChatNormalizer.ets`
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/core/reducers/chatsReducer.ets`
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/core/utils/stateClone.ets`
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/domain/usecases/loadChatAccess.ets`
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/ChatAccessController.ets`
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/ChatInputPanelPolicy.ets`
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/ChatComposerController.ets`
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/ChatMessageActionsController.ets`
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/ChatVoiceRecordingController.ets`
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/tg_ui/atoms/TgComposerInput.ets`
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/tg_ui/atoms/TgAttachmentSheet.ets`

Новый native suite: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/ohosTest/ets/test/BasicGroupMedia.test.ets`, зарегистрирован в List; BasicGroupAccess fixtures синхронизированы. Документы STATUS/TODO/LESSONS, access/production plans и два component passports обновлены. Глобальные prompts/memories не менялись.
