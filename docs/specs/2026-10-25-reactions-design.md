# Reactions — проектирование среза (S3)

Дата: 2026-10-25. Строка матрицы: **D10** (`missing`). Тип: фича, вертикаль «реакции на сообщение».
Статус: дизайн принят; **S3a, S3b и S3c реализованы 2026-10-25; S3d — быстрый ряд из `available_reactions` с дефолтом iOS**; S3b.1 (медиа-баблы), S3d.1 (recent/popular, кастомные эмодзи), теги и witness на живом аккаунте впереди.

## 1. Что делает iOS (эталон)

Референсные файлы (пути от `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI`):

- `Components/Chat/ChatMessageReactionsFooterContentNode/Sources/ChatMessageReactionsFooterContentNode.swift`
  — подвал бабла: ряды реакций, раскладка, переполнение, «+N».
- `Components/Chat/TopMessageReactions/Sources/TopMessageReactions.swift` — реакции на закреплённом.
- `Components/ContextControllerImpl/Sources/ReactionPreviewView.swift` — превью реакции в контекст-меню.
- `Components/Settings/QuickReactionSetupController/` — быстрые реакции, доступные в чате.
- `Components/Chat/ChatMessageDateAndStatusNode/Tests/ReactionRowPackingTests.swift` — тест раскладки
  (полезен как образец для нашего VO-теста).

Поведение: реакция ставится тапом по чипу или через меню; повторный тап снимает; чипы сортируются
по числу (своя реакция — отдельным состоянием); переполнение сворачивается; в каналах возможны
платные реакции (у нас вне scope).

## 2. Контракт TDLib (наш pinned submodule)

`tdlib/td/generate/scheme/td_api.tl`:

| Что | Строка | Форма |
|---|---|---|
| поставить/снять | 11643 | `setMessageReactions chat_id:int53 message_id:int53 reaction_types:vector<ReactionType> is_big:Bool = Ok` |
| полное обновление | 10249 | `updateMessageReactions chat_id message_id date reactions:vector<messageReaction>` |
| одно изменение | 10242 | `updateMessageReaction chat_id message_id actor_id date old_reaction_types new_reaction_types` |
| данные сообщения | 2670 | `messageInteractionInfo … reactions:messageReactions` |
| сводка | 2663 | `messageReactions reactions:vector<messageReaction> are_tags:Bool …` |
| чип | 2656 | `messageReaction type total_count is_chosen used_sender_id recent_sender_ids` |
| типы | 2599/2597 | `reactionTypeCustomEmoji custom_emoji_id`, `reactionTypeEmoji emoji` |
| доступные в чате | 3255/9613 | `chat.available_reactions`, `updateChatAvailableReactions` |
| варианты | — | `chatAvailableReactionsAll` / `chatAvailableReactionsSome` (и `none` в новых версиях) |
| активные эмодзи | — | `updateActiveEmojiReactions emojis` |

Решение по API: `is_big` всегда `false` на первом шаге (платные/большие реакции — отдельно).
Снятие — отправить пустой `reaction_types`.

## 3. Текущее состояние кода

- В `entry/src/main/ets` **нет** обработки `interaction_info` / `reactions` (проверено grep:
  `interactionInfo|interaction_info|availableReactions|sendReaction` → 0 совпадений).
- Значит, нужен полный путь: normalizer → DTO → timeline VO → бабл; команда — AppCommand →
  CommandSerializer → TdGateway.
- `TgBubbleLayout.ets` раскладывает бабл, `ChatTimelineVO.ets` — данные строки; `AppCommand.ets`
  содержит команды, `CommandSerializer.ets` — их сериализацию.

## 4. Шов (что оставить открытым)

1. **VO чипа**: `ReactionChipVO { key, emoji | customEmojiId, count, chosen }` и
   `ReactionsVO { chips, totalCount, availableInChat }` — владелец `ChatTimelineVO`.
   Через него пойдут: подвал бабла, реакции на закреплённом (C4/TopMessageReactions), счётчик
   непрочитанных реакций в списке чатов (`unread_reaction_count`).
2. **Команда** `SetMessageReactionsCommand` с типизированным payload — через неё же пойдут
   «быстрая реакция» и контекст-меню (`ReactionPreviewView`).
3. **Доступность**: `available_reactions` из chat DTO — общий источник и для пикера (S3d), и для
   скрытия подвала, если реакции выключены.
4. **Оптимистичность**: отдельный слой не вводим; используем существующий паттерн pending/ack
   (как в send), чтобы откат при ошибке был единым механизмом.

## 5. Состояния (матрица для spec)

| Состояние | Ожидание |
|---|---|
| нет реакций | подвал не рендерится |
| одна своя | чип active, count 1 |
| несколько чужих | сортировка по count desc, стабильная при равенстве |
| переполнение | видимые N чипов + «+N» (порог — из iOS-констант) |
| реакции выключены в чате | подвал и пикер скрыты |
| кастомный эмодзи | рендер как emoji-слой (пока — fallback на текст) |
| сообщение удалено/не загружено | обновление игнорируется, без краша |
| повторный быстрый тап | одно сетевое действие; состояние по ack |

## 6. Разбиение на срезы (порядок реализации)

1. **S3a. Данные (без UI).** Normalizer + DTO + VO + тесты: `updateMessageReactions` → чипы;
   `updateMessageReaction` → инкрементальное обновление; сортировка/переполнение — чистая функция.
2. **S3b. Подвал бабла (read-only).** Рендер `ReactionsVO` в `TgBubbleLayout`/бабл, состояния из §5.
3. **S3c. Постановка реакции.** `setMessageReactions` + optimistic + откат по ошибке; тест на
   повторный тап и на удалённое сообщение.
4. **S3d. Пикер.** Меню доступных реакций из `available_reactions` + быстрые реакции; iOS
   `ReactionPreviewView` как визуальный эталон.

## 7. Тесты и witness

- Host: сериализация команды (форма `setMessageReactions`), сортировка/переполнение чипов
  (по образцу `ReactionRowPackingTests`), инкрементальное обновление.
- On-device: `ChatReactionsVO.test.ets`.
- Runtime witness: поставить/снять реакцию на эмуляторе (нужен аккаунт — сейчас `blocked` на
  внешнем аккаунте; до этого — witness на мок-событиях + скриншот с seeded VO).

## 8. Риски

- Обновления приходят и для неоткрытых чатов — не держать реакции в состоянии экрана.
- Реакции меняют высоту бабла: пересчёт layout и scroll-anchor, иначе прыжок списка.
- `updateMessageReaction` может прийти раньше полного сообщения.
- Кастомные эмодзи требуют отдельного emoji-слоя (D16) — не тащить в S3a.

## 9. Definition of Done (для каждого подсреза)

См. `TASKS/SLICE_PROTOCOL.md` §8. Обязательное дополнение: строка D10 в матрице обновляется только
после witness; до этого — `partial` с указанием, что именно проверено.
