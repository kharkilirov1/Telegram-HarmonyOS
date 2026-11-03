# TgSelectionPanel — паспорт молекулы

Статус: **S5b (C9)** — панель выделения сообщений, заменяет композер, пока выбраны сообщения.
Дата: 2026-11-04. iOS-эталон: `ChatMessageSelectionInputPanelNode.swift`.

## Входы

| Параметр | Тип | Смысл |
|---|---|---|
| `title` | `string` | готовый заголовок со счётчиком («N selected», ресурс `selection_count`) |
| `canCopy` / `canForward` / `canDelete` | `boolean` | доступность действия для текущего выбора |
| `onClose` | `() => void` | выход из режима выделения |
| `onCopy` / `onForward` / `onDelete` | `() => void` | действия над выбранными сообщениями |

## Состояния

| Состояние | Ожидание |
|---|---|
| одно сообщение | «1 selected», действия доступны |
| несколько | «N selected», счётчик обновляется из `selectedMessageIds` |
| нет текста в выборе | Copy недоступен (`canCopy=false`) |
| выбор пуст | панель не рендерится: страница показывает композер |
| закрытие (X) | выход из режима, композер возвращается |

## Токены

| Что | Токен |
|---|---|
| высота | `SELECTION_PANEL_HEIGHT` = 52 |
| фон | `SELECTION_PANEL_BG` |
| шрифт действий | `SELECTION_PANEL_ACTION_TEXT_SIZE` / `_WEIGHT` |
| паддинги действий | `SELECTION_PANEL_ACTION_PADDING_H` |
| иконка закрытия | `SELECTION_PANEL_CLOSE_ICON_SIZE` |

## Отклонения от iOS (долг)

- Действия — текстовые кнопки Copy/Forward/Delete; в iOS это иконки (в наборе ресурсов нет
  copy-глифа, поэтому иконочный ряд был бы неполным). Визуальный witness не снят.
- Нет кнопки «Info» и меню «Ещё» — за рамками первого среза.

## Интеграция

`TgChatScreenPage`: при `timeline.selectionActive` вместо `TgChatComposerDock` рендерится
`TgSelectionPanel`; действия уходят в session → `ChatMessagePopupCoordinator`
(copy/forward/delete/clear), модель выбора — `selectedMessageIds` в `ChatTimelineViewState`.
