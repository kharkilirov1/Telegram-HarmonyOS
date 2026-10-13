# Отправка фотоальбомов — 2026-10-01

Из существующего native photo picker выбор 2–10 фотографий отправляется одним `sendMessageAlbum`. Раньше каждый элемент отправлялся отдельным `sendMessage`. Порядок выбора сохранён; plain-text caption находится у первого элемента, reply относится ко всему альбому. Один файл использует прежнюю одиночную отправку. Получение и отображение фотоальбомов используют существующий timeline/gallery pipeline.

## Реализация

`ChatComposerController` передаёт photo batch в небольшой `ChatPhotoAlbumController`. Новый typed command, serializer и `SendMediaAlbumUseCase` используют захваченный route/account gateway через существующий media use case. Фото сначала полностью копируются в app-owned staging; после каждого await проверяются operation/lifecycle/chat, identity use case, photo permission и revision входных данных. Коллизии staging filenames устраняет общий монотонный sequence. При известной ошибке до dispatch собственные копии удаляются; после dispatch они сохраняются для TDLib upload.

Принятый результат должен быть `TdObject messages` с ровно N ненулевыми `message`, соответствующим chat и уникальными положительными safe-int53 ID. Нативные pending message ID также положительные; int64 `media_album_id` — другой контракт. `total_count` не используется. Это принятие к отправке, а не подтверждение доставки.

Неоднозначный ответ оставляет caption, reply и выбор фото. Автоматического повторения или fallback на отдельные сообщения нет. Следующий обычный Send для уже submitted selection требует native Cancel/Send again; это распространяется и на успешный ответ, если новый draft или отозванное permission оставили прежний выбор видимым. После нового input revision успешная старая операция не очищает новый ввод. Новый узкий operational revision не меняет 112 observed backing fields; существующие284 delegates сохранены, добавлен один getter (всего285).

## Нативные дефекты, выявленные проверкой

Первый настоящий SDK run был RED:112/111/1. Пустой `Button.color` отклонял native `showDialog`; это соответствует [ParseButtons](https://github.com/openharmony/arkui_ace_engine/blob/master/interfaces/napi/kits/promptaction/prompt_action.cpp) и [NapiStringToString](https://github.com/openharmony/arkui_ace_engine/blob/master/interfaces/napi/kits/utils/napi_utils.cpp), где нулевая длина строки не принимается. После замены цветовым Resource API24 показывал чёрный Done на тёмном фоне — отдельный подтверждённый screenshot defect. Отдельный native diagnostic подтвердил cross-HAP ID mismatch: mounted getColorSync(ID) —9001001; полный Resource —base#ff0088cc; getColorByNameSync(telegram_blue) —правильный dark#ff3390ec. Окончательный код использует имена ресурсов рядом с существующими токенами и ResourceManager текущего mounted context, затем передаёт unsigned ARGB string. Native screenshot теперь показывает читаемые themed buttons.

SDK screenshot сохраняется в filesDir собственного test module. Проверка отсутствия текста ждёт окончания dismiss animation не более5секунд и затем строго отвергает оставшиеся элементы; best-effort finally cleanup сохраняет исходную ошибку. Эти исправления синхронизации не заменяют presence/absence assertions заглушками.

## Проверки

| Gate | Результат |
|---|---|
| Actual-source album domain/serializer + native callback bodies в host |57/57 PASS (49 SDK cases +8 host-only)|
| Actual-source controller/Composer/Context ownership |23/23 PASS|
| Decomposition payload/receiver/revision integration |22/22 PASS,285 delegates/98 binding probes|
| Общий host runner |65/65 PASS|
| PS и Bash UI smoke |PASS|
| Forced serial main и ohosTest HAP |PASS, без установки зависимостей|
| SDK focused SendMediaAlbum/PhotoAlbumDialog/ChatTimelineVO |112/112 PASS,0 ignored|
| Полный SDK run |856/856 PASS,0 ignored|
| Независимый Astra review |57/23/22 PASS; семь поведенческих mutants отвергнуты; native pixels/runtime проверены отдельно|

SDK witness выполнен на существующем API24 emulator в отдельном credential-free bundle `com.telegram.harmonyos.chatrefactor20261001`. Одновременно установлены main/test HAP; byte hashes, compiled ABC markers и18 соответствующих candidate source hashes закреплены в [evidence](2026-10-01-photo-album-evidence.json). Оригинальный bundle пользователя не переустанавливался. Native UI использует настоящий mounted UIContext и настоящий системный диалог; file preparation и send acceptance — deterministic fixtures с zero gateway/single-send calls.

## Референсы и границы

Все восемь установленных refs проверены: current/old iOS, Android, Nekogram, HarmonyOS examples/codelabs, ArkGram metadata и Petrelgram. Точные URL/branch/SHA, licensing и file:line основания перечислены в [reference audit](2026-10-01-photo-album-references.md). iOS остаётся главным behavioral/UI ориентиром: grouping по умолчанию, ordered selection, caption-first, album batch10. iOS picker допускает100 выбранных элементов; текущий HarmonyOS picker ограничен10 — это явная граница этого законченного photo-only slice. Petrelgram `main@a5e1ec763b08d549630a58f9efe96677bb3245de` остаётся внешним reference в `C:\Refs\Telegram\Petrelgram`: Apache-2.0 root, отдельные native/asset notices; его InputFile wrapper несовместим с нашей pinned TDLib schema и не перенесён.

Не обещаны mixed/video albums, custom ordered preview/reorder, HD/spoiler/paid/schedule, animated/live-photo conversion и caption entity editor parity. Текущий установленный iOS picker runtime witness недоступен, поэтому shipped visual parity не заявляется. `harmonyos_docs` MCP недоступен: использованы public SDK contracts, первичные исходники и закреплённые HarmonyOS refs. Никакие сторонние runtime-код/assets/scripts не копировались и не подключались.

Реальная отправка Telegram/доставка и настоящий picker/file-provider flow не запускались: это требует отдельной авторизованной проверки с аккаунтом. Существующие pending-message updates/reducers остаются владельцами отправки и timeline; UI не создаёт фиктивные confirmed messages.

Локальная установка выполняется с SHA guards по всем1004 public baseline files, отдельными before backups и exact changed-path manifest. Index/HEAD сохраняются; прежние dirty changes вне feature delta не затрагиваются. Commit/push/PR/merge не выполняются. Независимый финальный отчёт: [Astra](2026-10-01-photo-album-astra-review.md).

Следующий продуктовый приоритет — ordered photo selection preview с удалением/перестановкой перед отправкой, по текущему iOS witness и source. Mixed photo/video требует сначала typed receive/render/gallery contract.
