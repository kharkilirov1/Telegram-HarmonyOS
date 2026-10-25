# TgReactionPicker — паспорт атома

Статус: **S3d** (горизонтальный ряд доступных реакций над меню действий сообщения). Дата: 2026-10-25.
Источник данных: `chat.available_reactions` → `availableReactionKeys(chat)` в `AppState`.
Контракт TDLib: `chatAvailableReactionsAll` / `chatAvailableReactionsSome` (`td_api.tl:3181-3184`),
`updateChatAvailableReactions` (`td_api.tl:9613`).

## Входы

| Параметр | Тип | Смысл |
|---|---|---|
| `keys` | `string[]` | ключи чипов в порядке показа; уже обрезаны до `MAX_PICKER_REACTION_KEYS` |
| `onReactionPress` | `(key) => void` | тап по пилюле; нажатие отдаёт ключ, индекс наружу не уходит |

Атом не знает про store и не решает, можно ли ставить реакцию: список уже отфильтрован моделью
`chatAllowsReactions(chat)`.

## Состояния

| Состояние | Ожидание |
|---|---|
| `keys` пуст | атом не рендерится (попап просто без ряда) |
| чат разрешает всё / чат неизвестен | 12 дефолтных реакций iOS (`ChatEntityKeyboardInputNode.swift:231`) |
| `chatAvailableReactionsSome` | только серверный список, порядок сохранён |
| больше 12 | модель обрезает до `MAX_PICKER_REACTION_KEYS`, ряд скроллится |
| кастомный эмодзи | нейтральный глиф `REACTION_CUSTOM_EMOJI_FALLBACK` (emoji-слой — D16) |
| узкий экран | горизонтальный `Scroll`, скроллбар скрыт |

## Интеграция

`TgChatTimelineRow` (long-press) → `bindPopup` → `TgChatMessageActionsPopup` → `TgReactionPicker`.
Тап: `popup → bindings.handleMessageActionReaction(key) → session → ChatMessagePopupCoordinator`
(закрывает меню, затем `ChatReactionController.toggle` — оптимистичный снимок и откат из S3c).

## Токены

| Что | Токен |
|---|---|
| высота полосы | `REACTION_PICKER_HEIGHT` |
| размер пилюли | `REACTION_PICKER_PILL_SIZE` |
| глиф | `REACTION_PICKER_GLYPH_SIZE` |
| боковые отступы | `REACTION_PICKER_PADDING_H` |
| фон/радиус/зазор | `REACTION_CHIP_BG` / `REACTION_CHIP_RADIUS` / `REACTION_CHIP_GAP` |

## Не сделано (долг)

- Список «недавние/популярные» из `getMessageAvailableReactions` (`availableReactions.top_reactions`
  / `recent_reactions`) — S3d заявляет только быстрый ряд из `available_reactions`.
- Поиск реакции и выбор кастомного эмодзи из паков.
- `are_tags` / реакции-теги (Saved Messages) — отдельный срез.

## iOS-референс

`submodules/TelegramUI/Components/ChatEntityKeyboardInputNode/Sources/ChatEntityKeyboardInputNode.swift`
(дефолтный ряд), `ChatMessageReactionsFooterContentNode` (геометрия пилюль).
