# Island Player Suite — полоса-контролы, AVSession+фон, морф-карточка

Дата: 2026-07-22. Статус: дизайн утверждён пользователем в диалоге (порядок v1→v2→v3).
Полный spec-review-луп пропущен сознательно: CLAUDE.md проекта — «specs опциональны»;
дизайн зафиксирован здесь, исполнение — проектными срезами с E2E-витнессами.

## Контекст

Остров-мини-плеер (HDS miniBar слот) уже играет войсы/аудио app-глобально через
`GlobalMediaPlayback` (единственный AVPlayer; `mediaPlaybackUIState` зеркалит
hasActive/isPlaying/progress/title/subtitle/chatId/messageId/contentType).
Пользовательское решение: тап по телу полосы для войса — прыжок к сообщению;
для музыки — полноценный плеер; собрать нативный системный слой вместе с нашим.

## v1 — полоса по паттерну нативной Музыки + войс-jump

- `TgRootMiniPlayer`: для `contentType==='audio'` добавить кнопку `⏭` между
  текстом и `✕`; тело полосы кликабельно.
- Тап тела: voice → `PendingJumpSignal.set(chatId, messageId)` + открыть чат
  (существующий вход из чат-листа); audio → временно тот же прыжок (до v3).
- Глобальный «следующий трек» в `GlobalMediaPlayback`:
  `searchChatMessages(chatId, filter=searchMessagesFilterAudio, from=current, limit=1)`
  через TdGateway → скачивание при нужде → openAndStart. Он же чинит
  auto-advance вне чата (сейчас `pageCompleted` живёт только со страницей).
- Витнесс: остров с музыкой показывает ⏭; тап войса из root прыгает к сообщению.

## v2 — AVSession + фоновое воспроизведение

- `@ohos.multimedia.avsession`: одна сессия на приложение, владелец —
  `GlobalMediaPlayback`; на каждом снапшоте — `setAVMetadata`
  (assetId=messageId, title, artist=performer/отправитель, duration) и
  `setAVPlaybackState`; обложка позже (v3 парсит thumb).
- Команды из системы: play/pause/stop/playNext (+seek) → те же методы wrapper.
- Фон: `@ohos.resourceschedule.backgroundTaskManager` continuous task
  `AUDIO_PLAYBACK` на время активного плейбека + `backgroundModes:
  ["audioPlayback"]` в module.json5.
- Витнесс: свернуть приложение — музыка продолжает играть; шторка/локскрин
  показывают трек и управляют им.

## v3 — морф-карточка полноценного плеера

- Тап по телу полосы с музыкой: капсула острова анимированно вырастает в
  карточку (оверлей над нижней третью экрана, HDS-материал): обложка
  (`album_cover_thumbnail` → допарсить в TdMessageParser + модель TdAudioNote),
  тайтл/исполнитель, сик-бар (AVPlayer.seek), ⏮/▶⏸/⏭, скорость 1x/1.5x/2x
  (setSpeed), ✕. Тап вне карточки — сворачивание обратно в полосу.
- Войс-тап остаётся прыжком; карточка только для audio.
- Витнесс: скрин карточки, сик двигает позицию, скорость слышимо меняется
  (позиционный витнесс по прогрессу), сворачивание корректно возвращает полосу.

## Риски

- searchChatMessages filter: проверить поддержку фильтра в сериализаторе,
  дополнить при нужде (мелко).
- AVSession на эмуляторе: шторка эмулятора может не показывать медиа-карточку —
  тогда витнесс через hilog команд + поведение фона.
- Морф-анимация: сначала простой animateTo высоты/ширины оверлея; геометрия
  идёт от bounds полосы (без geometryTransition в первой итерации).
