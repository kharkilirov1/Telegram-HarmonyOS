# TgReactionsFooter — паспорт атома

Статус: **S3b** (read-only подвал реакций). Строка матрицы D10. Дата: 2026-10-25.
Данные: `Message.reactions` → `ChatTimelineVO` (pack) → примитивы строки → атом.

## Входы (primitives only)

| Параметр | Тип | Смысл |
|---|---|---|
| `emojis` | `string[]` | глифы видимых чипов в порядке, который задал VO (chosen → count → key) |
| `counts` | `number[]` | счётчик каждого видимого чипа |
| `chosenFlags` | `boolean[]` | своя реакция (акцентный тинт) |
| `hiddenCount` | `number` | чипы сверх лимита 6 → бейдж `+N` |

Атом не принимает объекты страницы (`ChatTimelineVO`) и не имеет `@Event`: постановка реакции —
S3c, пикер — S3d. Отсутствие события — намеренное: мёртвая проводка запрещена (`SLICE_PROTOCOL` §9).

## Состояния

| Состояние | Ожидание |
|---|---|
| нет реакций | атом не рендерится (вызов пропускается в бабле) |
| одна своя | один чип, акцентный фон и акцентный счётчик |
| несколько чужих | порядок задан VO; фон нейтральный |
| переполнение | до 6 чипов + `+N` (N = hiddenCount) |
| кастомный эмодзи | глиф `REACTION_CUSTOM_EMOJI_FALLBACK`, пока нет emoji-слоя (D16) |
| узкий бабл | `Flex(wrap: Wrap)`, чипы переносятся строками |

## Геометрия и токены

| Что | Токен | Значение (iOS-референс) |
|---|---|---|
| высота чипа | `REACTION_CHIP_HEIGHT` | 30 (pill 50×30 в `ReactionRowPackingTests`) |
| радиус | `REACTION_CHIP_RADIUS` | 15 |
| боковой отступ | `REACTION_CHIP_PADDING_H` | 8 |
| зазор | `REACTION_CHIP_GAP` | 6 (`ChatMessageReactionsFooterContentNode.itemSpacing`) |
| счётчик | `REACTION_CHIP_COUNT_SIZE` / `_WEIGHT` | 13 / Medium |
| глиф | `REACTION_CHIP_EMOJI_SIZE` | 14 |
| отступ от контента | `REACTION_FOOTER_TOP_GAP` | 4 |
| фон / фон своей | `REACTION_CHIP_BG` / `REACTION_CHIP_BG_CHOSEN` | `color.json` (light + dark) |
| текст / текст своей | `REACTION_CHIP_TEXT` / `REACTION_CHIP_TEXT_CHOSEN` | `color.json` |

Магических чисел в атоме нет: всё через `TgUiTokens`.

## Интеграция

`TgChatTimelineRow` → `TgMessageRouter` → `TgTextBubbleV3` → `TgReactionsFooter`.
Пока подключено к текстовому баблу (основной поток сообщений). Медиа-баблы получают подвал
отдельным шагом S3b.1 — это записано долгом, пока строка D10 остаётся `partial`.

## iOS-референс

`submodules/TelegramUI/Components/Chat/ChatMessageReactionsFooterContentNode/Sources/ChatMessageReactionsFooterContentNode.swift`
(раскладка, `itemSpacing = 6`, чипы внутри бабла) и
`ChatMessageDateAndStatusNode/Tests/ReactionRowPackingTests.swift` (pill 50×30, до 6 в ряду).
