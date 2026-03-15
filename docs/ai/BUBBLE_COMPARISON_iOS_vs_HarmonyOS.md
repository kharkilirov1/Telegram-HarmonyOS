# Сравнительный анализ: система пузырей сообщений iOS Telegram vs HarmonyOS

## 1. Форма пузыря (radius, tail, incoming/outgoing)

### iOS Telegram
- **Настраиваемый radius**: `PresentationChatBubbleCorners` с `mainRadius` (по умолчанию ~17pt) и `auxiliaryRadius` для merged-углов.
- **4 независимых угла**: `topLeftRadius`, `topRightRadius`, `bottomLeftRadius`, `bottomRightRadius` — вычисляются отдельно по `MessageBubbleImageNeighbors` (top/bottom/both/none/extracted).
- **Tail (хвостик)**: рисуется через CGPath (addLine/addCurve) на стороне incoming (слева) или outgoing (справа). Tail появляется только когда сообщение НЕ merged снизу с тем же отправителем. `drawTail = true` для `.none` и `.both`, `false` для `.top`/`.bottom`/`.side`/`.extracted`.
- **Adaptive corners**: merged-сообщения получают `minCornerRadius` на стороне стыка, остальные — `maxCornerRadius`.
- **Bubble image**: 9-patch растровая генерация (UIImage), не borderRadius.

### Наша реализация
- **Фиксированный borderRadius**: 17vp для всех углов (`BUBBLE_RADIUS_INCOMING = BUBBLE_RADIUS_OUTGOING = 17`).
- **Tail отсутствует** — нет хвостика. Только скругленный прямоугольник.
- **Нет adaptive corners** — при grouping радиусы не уменьшаются.

### Разница
| Аспект | iOS | Наш |
|--------|-----|-----|
| Tail/хвостик | Да, CGPath | Нет |
| Adaptive radius | minRadius (6pt) на merged-стороне | Фиксированный 17vp |
| Bubble rendering | 9-patch UIImage | borderRadius CSS-like |
| Corner config | Пользователь настраивает | Захардкожено |

---

## 2. Цвета (incoming bg, outgoing bg)

### iOS Telegram
- Тематизируемые через `theme.chat.message.incoming/outgoing.bubble`.
- Default light: incoming `#FFFFFF` (или чуть серый), outgoing — зеленоватый `#E1FEC6`.
- Поддержка wallpaper-зависимых цветов (`withWallpaper`/`withoutWallpaper`), gradient bubble fills, shadow.

### Наша реализация
- `chat_bubble_incoming` и `chat_bubble_outgoing` из `color.json`.
- Одноцветные заливки, без gradient, shadow, wallpaper-адаптации.

### Разница
Нет gradient fills, shadow, и wallpaper-зависимой адаптации.

---

## 3. Типографика внутри пузырей

### iOS Telegram
- `messageFont` — системный, по умолчанию ~17pt (настраиваемый через fontSize settings).
- Отдельные шрифты: `messageBoldFont`, `messageItalicFont`, `messageBoldItalicFont`, `messageFixedFont`, `messageBlockQuoteFont`.
- Rich text через `stringWithAppliedEntities()` — bold, italic, code, links, mentions, hashtags.
- `primaryTextColor`, `linkTextColor` из темы.

### Наша реализация
- `MSG_TEXT_SIZE = 17`, `MSG_TEXT_WEIGHT = FontWeight.Regular`, `MSG_TEXT_LINE_HEIGHT = 22`.
- Один `Text()` компонент — **нет rich text rendering** (bold/italic/code внутри текста).
- `TgMessageTextKind` enum (Plain/Link/Mention/Hashtag) — только весь текст одного типа, нет смешанного форматирования.
- Emoji-only: 40vp.

### Разница
| Аспект | iOS | Наш |
|--------|-----|-----|
| Rich text | Полный (bold/italic/code/link inline) | Нет — plain text only |
| Font size | Настраиваемый | Фиксированный 17vp |
| Block quotes | Да | Нет |
| Code blocks | Да (syntax highlight) | Нет |

---

## 4. Meta placement (время + checkmarks)

### iOS Telegram
- `ChatMessageDateAndStatusNode` с 6 типов размещения:
  - `BubbleIncoming` / `BubbleOutgoing` — внутри пузыря, BottomEnd.
  - `ImageIncoming` / `ImageOutgoing` — плавающее поверх медиа с полупрозрачным фоном.
  - `FreeIncoming` / `FreeOutgoing` — для стикеров, без фона.
- Checkmarks: clock (pending), single check (sent), double check (read).
- Reactions рендерятся рядом с meta.

### Наша реализация
- `TgMessageMeta` — единый компонент с `timeText` + `sendStatus` (None/Sending/Sent/Read/Failed).
- В текстовых: Stack BottomEnd overlay (поверх текста, внутри пузыря).
- В медиа: отдельный Row под контентом.
- В стикерах: Row под стикером.
- **Нет floating overlay на медиа** — meta всегда в отдельной строке.

### Разница
| Аспект | iOS | Наш |
|--------|-----|-----|
| Overlay на фото/видео | Да (полупрозрачный bg) | Нет — meta ниже медиа |
| Типы размещения | 6 вариантов | 3 варианта (text/media/sticker) |
| Reactions в meta | Да | Нет |

---

## 5. Sender name в группах

### iOS Telegram
- Цвет из `peer.nameColor` — серверная палитра `PeerNameColors` (до 8+ цветов, dark/light варианты).
- Показывается только когда `!mergedTop.merged && incoming && isGroupOrChannel`.
- Кликабельное имя (переход в профиль).

### Наша реализация
- `senderName` + `senderColorHex` — цвет через hex-строку.
- 13vp, FontWeight.Medium.
- `showSenderName` проп.
- **Не кликабельное**.

### Разница
Близко к iOS. Отсутствует кликабельность и серверная палитра nameColor (мы используем hex-строку).

---

## 6. Reply snippet

### iOS Telegram
- Вертикальная цветная полоска (2-3pt) + автор + превью текста.
- Автор окрашен в nameColor отправителя ответа.
- Превью может содержать media thumbnail (фото/видео/стикер).
- Кликабельный (скролл к оригиналу).
- Quote mode — расширенный preview с большим количеством строк.

### Наша реализация
- `TgReplySnippet` — полоска 2vp + автор (13vp) + превью (13vp).
- Поддержка `isQuote` с другими maxLines (2/5 vs 1/1).
- **Нет media thumbnail** в reply.
- **Не кликабельный**.

### Разница
Нет thumbnail и навигации к оригиналу.

---

## 7. Типы контента: iOS vs наш

### iOS Telegram (~30+ content nodes)
Action, AttachedContent, BirthdaySuggestion, Call, CommentFooter, Contact, EventLogPrevious (3 variants), FactCheck, File, Game, Gift, GiftOffer, Giveaway, InstantVideo, Invoice, JoinedChannel, Map, Media (photo/video), Poll, RestrictedContent, Sticker, AnimatedSticker, Text, WebPage (link preview), PaidStars, StoryMention, и др.

### Наша реализация (8 content types)
- text, photo, video, animation, videoNote, document, audio, voice, sticker
- Через `TgMessageRouter` маршрутизация в 5 атомов: `TgMessageBubbleBase`, `TgPhotoBubble`, `TgVideoBubble`, `TgDocumentRow`, `TgVoiceBubble`, `TgStickerView`.

### Разница
| iOS | Наш | Статус |
|-----|-----|--------|
| Text | text | Есть (без rich text) |
| Photo/Video | photo, video, animation, videoNote | Есть |
| File | document, audio | Есть |
| Voice | voice | Есть |
| Sticker | sticker | Есть |
| Contact | - | Нет |
| Location/Map | - | Нет |
| Poll | - | Нет |
| Game | - | Нет |
| Invoice | - | Нет |
| WebPage (link preview) | - | Нет |
| Gift/Giveaway | - | Нет |
| Call | - | Нет (есть TgCallRow в списке) |

---

## 8. Spacing между сообщениями

### iOS Telegram
- `defaultSpacing = 2.0 + UIScreenPixel` (~2.33pt) — разные отправители.
- `mergedSpacing = 0.0` — тот же отправитель (merged).
- `edgeInset = 3.0`.
- `mergedTop/mergedBottom: ChatMessageMerge` — определяет, сливать ли сообщение с соседним.

### Наша реализация
- Spacing управляется на уровне `ChatTimelineDataSource` / List, конкретные значения не токенизированы в `TgUiTokens`.
- Нет системы merged top/bottom для адаптации радиусов.

### Разница
Нет формальной merge-системы. Spacing не дифференцирован по same/different sender.

---

## 9. Date separator

### iOS
- `ChatMessageDateHeaderNode` — центрированная капсула с датой.
- Полупрозрачный фон поверх wallpaper.

### Наша реализация
- Есть: `DATE_SEPARATOR_*` токены — капсула 13vp, Medium, radius 12, padding 10H/4V.
- `date_separator_bg` (полупрозрачный) + `text_on_overlay`.

### Разница
Функционально совпадает. Визуально близко к iOS.

---

## 10. Interactions

### iOS Telegram
- **Long press**: контекстное меню (reply, copy, forward, delete, pin, react).
- **Double tap**: quick react (heart).
- **Swipe to reply**: `ChatSwipeToReplyRecognizer` — свайп влево = reply.
- **Tap on links/mentions**: навигация.
- **Tap на media**: fullscreen viewer.
- **Tap на forward header**: переход к источнику.
- **tapActionAtPoint**: детальная система hit-testing по content nodes.

### Наша реализация
- **Нет** long press menu.
- **Нет** double tap.
- **Нет** swipe to reply.
- **Нет** tap navigation (links, mentions, media fullscreen).

### Разница
Взаимодействия полностью отсутствуют. Это крупнейший функциональный gap.

---

## 11. Selection mode

### iOS: `selectionState` — мультивыбор сообщений с checkmark circles слева.
### Наш: Не реализован.

---

## 12. Forwarded message header

### iOS: `ChatMessageForwardInfoNode` — "Forwarded from [Name]" с кликабельным именем. Цветная полоска.
### Наш: Не реализован.

---

## 13. Link previews

### iOS: `ChatMessageAttachedContentNode` / `ChatMessageWebpageBubbleContentNode` — полноценный preview (title, description, image, site name, favicon).
### Наш: Не реализован.

---

## 14. Reactions

### iOS: Полноценная система — кнопки реакций под пузырём, inline в meta, animation при добавлении.
### Наш: Не реализован.

---

## Сводка приоритетов по сближению с iOS

| # | Фича | Сложность | Влияние на UX |
|---|-------|-----------|---------------|
| 1 | Rich text rendering (bold/italic/code/link inline) | Высокая | Критическое |
| 2 | Bubble tail (хвостик) | Средняя | Высокое (визуал) |
| 3 | Adaptive corners (merge system) | Средняя | Высокое (визуал) |
| 4 | Meta overlay на медиа (полупрозрачный фон) | Низкая | Среднее |
| 5 | Swipe to reply | Средняя | Высокое (UX) |
| 6 | Long press context menu | Средняя | Высокое (UX) |
| 7 | Link preview content node | Высокая | Среднее |
| 8 | Forward header | Низкая | Среднее |
| 9 | Reply snippet tap navigation | Низкая | Среднее |
| 10 | Contact/Location/Poll content nodes | Средняя | Среднее |
| 11 | Reactions | Высокая | Среднее |
| 12 | Selection mode | Средняя | Низкое |
| 13 | Gradient bubble fills / wallpaper adaptation | Средняя | Низкое |
| 14 | Sender name click navigation | Низкая | Низкое |
