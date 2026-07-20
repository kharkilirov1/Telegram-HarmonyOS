# ARKGRAM_REFERENCE — карта подсматривания в конкурента

> Мост-заметка для новых сессий. Составлена после декомпиляции и сравнительного
> анализа **ArkGram v1.0.1** (другой неофициальный Telegram-клиент для HarmonyOS,
> `com.matheusrv.arkgram`, vendor mrvapps). Используется как **референс реализаций
> на ArkTS/ArkUI** — то, чего не дают iOS/Android-референсы.

## ⚠️ Дисклеймер (обязательно к соблюдению)
- **Не копировать код 1:1.** Это чужая интеллектуальная собственность + декомпилят
  искажён (не скомпилируется). Учиться **подходам, структуре, числам** — реализовывать
  по-своему через свои `tg_ui`-токены/atoms.
- ArkGram собран в **debug** без обфускации — поэтому и декомпилировался. Наш Redux/
  тесты/слои так дёшево из бинарника не вытащить (это в нашу пользу).

## Где лежит (абсолютные пути, доступны из любой сессии)
```
C:\Refs\Telegram\ArkGram-RE\out\ArkGram-project\entry\src\main\ets\   ← причёсанные .ets по путям
C:\Refs\Telegram\ArkGram-RE\out\ArkGram-project\_reference\ArkGram_native_full.ts  ← полный нативный ArkTS (чище синтаксис)
C:\Refs\Telegram\ArkGram-RE\out\ArkGram-project\_reference\modules.disasm.pa        ← офиц. дизасм (эталон сверки)
C:\Refs\Telegram\ArkGram-RE\out\ArkGram-project\README.md             ← пределы + шпаргалка артефактов
```

## Карта: что где смотреть

| Нужно | Файл в ArkGram-project | Что брать (не код — подход/числа) |
|---|---|---|
| Топ-бар чата | `view/ChatHeader.ets` | Row 100%×**60**, padding 10, title **16/Bold**, статус **12px** синим `#2AABEE`; layoutWeight(1) на Column |
| Строка чат-листа | `view/ChatRow.ets` | Row padding {l16,r16,t10,b10}, Stack аватар+бейдж, Column layoutWeight(1), long-press Menu |
| Баблы (все типы) | `view/ChatMessageItem.ets` (**монолит 8K строк**) | как в одном классе; у нас лучше — atomic. Брать только структуру/числа |
| Форма/группировка баблов | `utils/ChatBubbleLayout.ets` | consecutive-группировка сообщений одного отправителя |
| Композер/инпут | `view/ChatInputArea.ets` (самый насыщенный) | компоновка панелей ввода |
| Загрузка истории | `controller/MessageManager.ets` | `getChatHistory` (offset/limit/from_message_id), колбэки по `@extra` |
| TGS-стикеры (анимация) | `utils/TgsPlayer.ets`, `utils/MediaStickerPlayer.ets`, `utils/TgsCacheManager.ets` | как проигрывают/кешируют анимированные стикеры |
| Прокси (полная система) | `proxy/*` (8 файлов) | ProxyManager, ProxyLinkParser, ProxyTypes |
| Медиа-вьюер | `view/MediaViewer.ets`, `view/MediaViewerCoordinator.ets` | галерея/зум |
| Push | `controller/PushManager.ets`, `utils/NotificationHelper.ets`, `extensionability/ArkGramPushExtension.ets` | HMS token → свой relay `https://arkgram.eu/register` → `deviceToken` в TDLib; inline reply из шторки (WantAgent action `com.arkgram.action.INLINE_REPLY`) |
| Иерархия уведомлений | `settingsUI/notifications/NotificationHandler.ets` | 3 уровня: scope → category → exception (как Telegram Desktop) |
| Сессии/QR | `settingsUI/devices/DeviceHandler.ets` | getActiveSessions/terminateSession/confirmQrCode; session id парсятся regex'ом из JSON-строки |
| Адаптив (фолды/планшет) | `settingsUI/adaptive/` (11 файлов) | FoldLayoutSpec/TripleFold/WideFold, `LargeScreenMainTabBar` (2897 строк), split-view панели |
| Роутинг TDLib-апдейтов | `controller/TdClient.ets` → `TdDispatcher.ets` → `TelegramParsers.ets` (1166) | receive-loop → парс по `@type` → синглтон `TelegramState` + AppStorage; без очереди/Redux |

### Фичи, которых у нас пока нет (полный обход декомпилята 2026-07-08; всего 159 .ets)
- **Push:** `PushManager` (HMS→relay), `ArkGramPushExtension`, `NotificationHelper` (inline reply)
- **Реакции:** `sendReaction`/`getAvailableReactions` в TelegramController (у нас нет совсем)
- **Комментарии/треды:** `pages/CommentThread.ets` (5145 строк) + семейство `send*InThread`
- **Отправка опросов:** `sendPoll`/`votePoll` (у нас только рендер `TgPollBubble`)
- **Папки чатов + архив:** `settingsUI/chatfolders/`, `ChatListManager` (`ARCHIVE_FOLDER_ID = 0x2000000`)
- **Privacy-настройки:** `settingsUI/privacy/` (11 файлов, все `userPrivacySetting*` правила)
- **2FA-настройки:** `pages/TwoStepVerification.ets` (2286 строк) — setPassword/recovery email
- **Хранилище:** `getStorageStatistics`/`optimizeStorage` + `StoragePieChart`
- **Прочее:** AutoDelete, темы/обои, PowerSave, BlockedUsers, EditProfile, LanguageSettings,
  `MentionManager` (@-автокомплит), глобальный поиск + `searchPublicChats`, отправка альбомов,
  адаптив под фолды/планшеты (`settingsUI/adaptive/`)

## Архитектурный контекст (ArkGram vs наш) — сжато
- **ArkGram:** простой MVC. Состояние в синглтонах-менеджерах (`TelegramState`,
  `ChatListManager`), **96 прямых `TdClient.send` в 14 файлах**, **0 тестов**,
  ~261 ручной флаг состояния, ~71 `setTimeout`, God-objects. API 26.
- **Цепочка апдейтов ArkGram:** native receive-loop → `TdClient.onEvent` → `TdDispatcher`
  (парс по `@type`) → `TelegramParsers` → мутация `TelegramState`/AppStorage → UI.
  Без очереди и Promise (ошибки приходят отдельным update `@type:error`); optimistic
  updates — сообщение в UI сразу, синк потом. Фасад — `TelegramController` (1896 строк,
  ~50 методов).
- **TDLib-инициализация ArkGram:** `use_secret_chats: 1` + случайный
  `database_encryption_key` с первого запуска (`AuthManager.ets:23-25`).
- **Наш:** Clean Arch + Redux (AppStore/reducers/selectors/usecases/ports),
  406 it()-кейсов в 18 сьютах (grep 2026-07-08), EventNormalizer, serial-dispatch. API 23 (D14).

## Где брать у него ПРОСТОТУ (главный урок)
Его `loadChatHistory` = **~15 строк**, наш `LoadChatHistoryUseCase` = **~700**. Он принял
баги (гонки смены чата, короткие батчи, «Unknown»-отправители) ради скорости и покрыл
больше фич. **Урок:** не везде нужны 700 строк. Критичное (история, авторизация,
отправка) — наша строгость оправдана; некритичное (экраны настроек, статика, редкие
типы баблов) — можно его лаконичностью, иначе «медленный старт» станет хроническим.

## Где НЕ подсматривать качество (мы уже сильнее)
- **Rich-text в баблах:** у нас движок `TgTextBodyV3` (`splitRichSpans`, пересечения
  entities, тесты) — у него 48 inline `Span.create` в монолите.
- **Время в баббле:** у нас `measure`/`timeWidth` (точный угол) — у него наивный inline
  `Span` без измерения.
- **Гонки загрузки истории:** у нас `generation`+`isLatestBucketRequest` — у него **0
  защиты** (быстрое переключение чатов → чужой ответ может мелькнуть).

## Переносимые UI-паттерны (из его кода, общие для ArkUI)
1. `layoutWeight(1)` — растяжение (flex), основа адаптивности Telegram-UI.
2. Все цвета из объекта темы (`theme.textColor/accentColor/listColor`) — у нас это `TgUiTokens`.
3. `Stack` — наложение (аватар + онлайн-точка/бейдж).
4. `If.create()` — условный рендер (аватар есть/нет, обычный/поиск-режим).
5. props-down / callback-up + `@StorageLink` для сквозного состояния.

## Как читать декомпилят (шпаргалка)
`Row.create()`=контейнер · `.width/.height/.padding`=стиль · `layoutWeight`=растяжение ·
`_fnN`=анонимная лямбда · `func_main_0`=тех-инициализатор модуля · `vNN`/`arg0`=локалки
(имена утеряны) · `ldlexvar`/`ldobjbyvalue`=промежуточные байткод-операции.

## Пределы
Не компилируется, локальные переменные безымянные (`vNN`), комментарии/типы утеряны.
Только для чтения/изучения. Полный конвейер декомпиляции — в `C:\Refs\Telegram\ArkGram-RE\`.
