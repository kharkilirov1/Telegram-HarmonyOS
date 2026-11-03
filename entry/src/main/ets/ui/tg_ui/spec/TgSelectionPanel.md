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

## Геометрия и токены (сверено с iOS)

iOS: `ChatInputPanelNode.defaultHeight` = 40, кнопки — круги 40×40 со стеклянным фоном
(`ChatMessageSelectionInputPanelNode.swift:581-597`), раскладка по ширине панели, нажатие
подсвечивается (`HighlightTrackingButton`) — у нас это нативный press-effect `Button`.

| Что | Токен | iOS |
|---|---|---|
| высота панели | `SELECTION_PANEL_HEIGHT` = 40 | `defaultHeight` = 40 |
| кнопка | `SELECTION_PANEL_BUTTON_SIZE` = 40 | `buttonSize` 40×40 |
| иконка кнопки | `SELECTION_PANEL_BUTTON_ICON_SIZE` = 20 | `image.size` в круге 40 |
| фон кнопки + блюр | `SELECTION_PANEL_BUTTON_BG` + `TgGlassPolicy.composerBlurStyle()` | GlassBackgroundView |
| глиф Copy | `SELECTION_PANEL_COPY_GLYPH` = ⧉ | иконка ассета (у нас нет) |
| счётчик | `SELECTION_PANEL_TEXT_SIZE` / `_WEIGHT` (SemiBold) | заголовок навбара iOS |

Материал: панель и кнопки — стекло (`backdropBlur` + тинт, LESSON 121), а не плоская заливка;
иерархия читается за счёт прозрачности, контент чата просвечивает под панелью. |

## Отклонения от iOS (долг)

- Copy — глиф вместо ассета: в наборе ресурсов нет copy-иконки. Остальные три — реальные иконки в
  тех же кругах. Визуальный witness не снят; press-состояние опирается на нативный эффект `Button`.
- Нет кнопки «Info» и меню «Ещё» — за рамками первого среза.

## Интеграция

`TgChatScreenPage`: при `timeline.selectionActive` вместо `TgChatComposerDock` рендерится
`TgSelectionPanel`; действия уходят в session → `ChatMessagePopupCoordinator`
(copy/forward/delete/clear), модель выбора — `selectedMessageIds` в `ChatTimelineViewState`.
