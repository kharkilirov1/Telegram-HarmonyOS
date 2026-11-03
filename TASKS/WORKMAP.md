# WORKMAP — карта работ на сейчас

Живёт только «сейчас»: 1–3 активных среза и ближайший backlog. Каждый срез — по
`TASKS/SLICE_PROTOCOL.md`; вход — строка `TASKS/CAPABILITY_MATRIX.md`. Перегенерируется после
каждого закрытого среза. Долг — в `TASKS/TODO.md` (§Debt).

**Обновлено:** 2026-11-03 (S3d.1)

## Закрыто в этой волне

| # | Срез | Строка | Результат |
|---|---|---|---|
| M0 | Верификация 9 `unverified` | B6, C10, D20, D24, D29, E1, H4, J5, J7 | `unverified` = 0; матрица 105 строк с доказательствами |
| S1 | Typing indicator | C2 | TTL 8 s, откат по дедлайну, группа — имя, приватный — текст, точки; **чает witness** (нужен второй аккаунт) |
| S1.1 | Тексты и TTL списка | C2/B12 | «печатает…» в ресурсах, один TTL в шапке и списке; harness починен, host 96/96 |
| S2 | Стикеры/TGS | D13 | политика видимости, кеш по `fileId`, бюджет 4, `@Monitor`; witness снят на устройстве, D13 → `available` |
| S3 | Reactions | D10 | дизайн-документ `docs/specs/2026-10-25-reactions-design.md`, код не писался |
| S4 | Мёртвые контролы | B3, E1, H4 | профильный Toggle → `SetChatMuteCommand`; строка «Data and Storage» удалена; мёртвая проводка `attachmentMenuLabels` удалена; DTO `TdAutoDownloadSettings` удалены; guard `test-dead-controls.cjs` |
| S3a | Reactions — данные | D10 | модель чипов + парсер TDLib + события/reducer + VO + `test-reactions-model.cjs`; D10 → `partial` |
| S3b | Reactions — подвал (текст) | D10 | атом `TgReactionsFooter` + токены/цвета + spec/demo + интеграция в текстовый бабл + `test-reactions-footer.cjs` |
| S3c | Reactions — постановка | D10 | команда + сериализатор + use case + `ChatReactionController` (optimistic/откат, guard) + тап по чипу + `test-reactions-send.cjs` |
| S3d | Reactions — пикер (быстрый ряд) | D10 | `available_reactions` в `ChatDto`/`Chat` + `availableReactionKeys`/`chatAllowsReactions` + атом `TgReactionPicker` + spec/demo + ряд в попапе действий + `test-reactions-availability.cjs`/`-picker` |
| S3d.1 | Reactions — пикер (per-message) | D10 | `getMessageAvailableReactions` + команда/сериализатор/use case + слияние `pickerReactionKeys` (top→recent→popular, кап 12, fallback на чат) + фенс устаревших ответов + `test-reactions-picker-data.cjs` |
| S3b.1 | Reactions — подвал в медиа | D10 | подвал рисует роутер под медиа-баблами (фото/видео/альбом/кружок/документ/аудио/голос/контакт/локация/опрос), стикер — долг из-за фиксированной высоты + `test-reactions-media-footer.cjs` |
| S5a | Непрочитанный разделитель (верификация C6) | C6 | строка была `missing`: код (`firstUnreadIncomingIndex`, `kind='unread'`, sticky, сброс sender-group) уже был, но без тестов; добавлены паспорт `TgUnreadMarker` (iOS-геометрия 25/0/6/5), ресурс `chat_unread_messages` (base/ru/zh вместо «Unread») + `test-unread-divider.cjs`; C6 → `partial` |
| S5b | Панель выделения сообщений (C9) | C9 | `selectionActive`/`selectedMessageIds` + пункт «Select» + удаление многих через `requestMany` + панель `TgSelectionPanel` (spec/demo/токены) вместо композера + чек-индикатор и блокировка тапов в строке + `test-selection-mode.cjs`; C9 → `partial` |
| S6a | Избранное — представление (D7) | D7 | `isSavedMessagesChat` + заголовок «Saved Messages» в списке и шапке + аватар-закладка (`TgAvatar.symbolIcon`) + флаг в diff + `test-saved-messages.cjs`; D7 → `partial` |

## Следующие срезы (в порядке)

1. **S6b. Избранное — точки входа (D7).** Строка в настройках → открыть чат (вынести open-chat транзакцию из `ChatListPage`), создание чата при отсутствии (`createPrivateChat` с `my_id`).
2. **S7. Папки чатов (B7)** — крупный срез списка, делать после стабилизации списка.
3. **C9-долг.** Иконки панели, подсветка выбранных баблов, формулировка диалога удаления для N сообщений, device-witness.

## Требуют внешних условий (не начинать)

- **Witness D10:** поставить/снять реакцию на живом аккаунте (эмулятор + чат с сообщениями);
  до этого S3a–S3d.1 и S3b.1 проверены host-контрактами, не устройством.
- **Witness C2:** второй аккаунт/устройство, которое начнёт печатать.
- **Witness D13:** стабильный запуск эмулятора + стикер в доступном чате; логи
  `tgs playback started key=file:<id>`.
- Push (AGC), подпись (сертификат), VoIP/секретные чаты (заморожены).

## Не в этой карте

- `@ReusableV2`/perf — после измерений, отдельным решением.
- Полный аудит оставшихся `partial`-строк — по мере приближения к их экранам.
