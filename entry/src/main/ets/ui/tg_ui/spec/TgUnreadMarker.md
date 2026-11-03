# TgUnreadMarker — паспорт атома

Статус: **S5a (C6)** — разделитель непрочитанного в истории чата. Дата: 2026-11-04.
Живёт в `atoms/TgDateSeparator.ets` рядом с датой (общая centered-геометрия истории).

## Входы

| Параметр | Тип | Смысл |
|---|---|---|
| `text` | `string` | подпись, по умолчанию «Unread messages» (ресурс `chat_unread_messages`) |
| `containerWidth` | `number` | ширина таймлайна для кап-расчёта |
| `maxWidthRatio` | `number` | доля ширины под плашку; iOS-бар занимает всю ширину (1.0) |

## Состояния

| Состояние | Ожидание |
|---|---|
| чат с непрочитанными | одна плашка перед первым входящим новее `last_read_inbox_message_id` |
| `unreadCount = 0` и нет sticky-границы | плашки нет (`unreadEntryIndex = -1`) |
| граница `'0'` | валидна: непрочитано с первого входящего |
| исходящие | пропускаются при поиске границы |
| sticky-граница (чат прочитан, но вход был с непрочитанными) | плашка остаётся до пересборки таймлайна |
| длинный текст | ellipsis, одна строка |

## Геометрия (сверено с iOS `ChatUnreadItem.swift:142-176`)

| Что | Токен | iOS |
|---|---|---|
| высота плашки | `UNREAD_MARKER_HEIGHT` = 25 | `backgroundSize.height 25` |
| радиус | `UNREAD_MARKER_RADIUS` = 0 | бар во всю ширину, не капсула |
| отступ сверху | `UNREAD_MARKER_MARGIN_TOP` = 6 | `insets.top 6.0 (+ header height)` |
| отступ снизу | `UNREAD_MARKER_MARGIN_BOTTOM` = 5 | `insets.bottom 5.0` |
| ширина | `UNREAD_MARKER_MAX_WIDTH_RATIO` = 1.0 | `params.width` |
| шрифт | 13 / Regular / lineHeight 16 | `titleFont` |

Отступ сверху у iOS добавляет высоту дейт-заголовка, когда дата стоит снизу; наш VO ставит дату
отдельной записью выше, поэтому плашка наследует `UNREAD_MARKER_MARGIN_TOP` без добавки.

## Интеграция

`buildChatTimeline` (`ChatTimelineVO.ets`) создаёт запись `kind='unread'` перед первым непрочитанным
входящим и сбрасывает sender-group, затем `TgChatTimelineViewport` рендерит `TgUnreadMarker`.
Текст — ресурс `chat_unread_messages` (base/ru_RU/zh_CN); это отдельная строка от `unread` из
фильтра чатов.

## Не сделано

- Device witness: положение плашки при входе в чат со скроллом к непрочитанному не снято
  (host-контракт `test-unread-divider.cjs` покрывает модель и геометрию, не пиксели).
