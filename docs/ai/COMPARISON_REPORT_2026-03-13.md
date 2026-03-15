# Сравнительный анализ: Telegram-HarmonyOS vs iOS/Android

Дата: 2026-03-13

---

## 1. TAB BAR

### 1.1 Форма и позиционирование

| Параметр | iOS Telegram | Android Telegram | Наша реализация | Дельта |
|---|---|---|---|---|
| Тип | Floating glass capsule (`GlassBackgroundView`) | **Нет bottom tab bar** — боковое drawer-меню (hamburger) | Floating glass island capsule | Соответствует iOS. Android использует совершенно другой паттерн |
| cornerRadius | `height * 0.5` (полная капсула) | N/A | `999` (полная капсула) | Совпадает с iOS |
| Позиция | Floating снизу, поверх контента | N/A (drawer слева) | Stack overlay снизу (`barHeight(0)`) | Совпадает с iOS |
| Скрытие при навигации | Да, при открытии чата | N/A | Да (`chatScreenVisible` guard) | Совпадает с iOS |

### 1.2 Размеры

| Параметр | iOS Telegram | Наша реализация | Дельта |
|---|---|---|---|
| Высота (horizontal) | 34pt | 56vp | **Наш на 65% выше.** iOS использует 34pt в горизонтальном режиме, 49pt+bottomInset в вертикальном (старый стиль). Новый `TabBarComponent` использует высоту передаваемую снаружи |
| Высота (vertical) | 49pt + bottomInset | 56vp (без bottomInset внутри) | Наш близок к 49pt, но bottomInset добавляется через margin, а не внутри капсулы |
| Ширина | `params.size.width` (почти вся ширина, минус 48+8 при поиске) | `min(screenWidth * 0.8, 328vp)` | **Разница**: iOS растягивает на всю ширину. Наш ограничивает до 80% или 328vp — это Android-inspired стиль |
| Иконка | Нативный размер image (~25-30pt), animated sticker 51pt | 23vp | Близко |
| Текст | `Font.medium(10.0)` (vertical), `Font.regular(13.0)` (horizontal) | 10vp, FontWeight.Medium | **Совпадает** с iOS vertical mode |
| Badge шрифт | `Font.regular(13.0)` | 13vp, FontWeight.Medium | Близко, но iOS Regular vs наш Medium |

### 1.3 Анимация выделенного таба

| Параметр | iOS Telegram | Наша реализация | Дельта |
|---|---|---|---|
| Тип highlight | Смена `tintColor` + animated sticker (Lottie) | Pill background + scale animation (0.6 -> 1.0) | **Значительная разница**: iOS не имеет pill/capsule highlight. iOS использует цветовую смену иконки + Lottie-анимацию иконки. Наш pill-эффект — кастомный, не из iOS |
| Анимация | `.easeInOut(duration: 0.25)` для alpha transition | `320ms EaseOut` для scale + opacity | Наша анимация длиннее (320ms vs 250ms) |
| Lottie иконки | Да (`animationName`, `AnimatedStickerNodeLocalFileSource`) | Нет | **Отсутствует** — iOS использует анимированные Lottie-иконки при выборе таба |

### 1.4 Badge

| Параметр | iOS Telegram | Наша реализация | Дельта |
|---|---|---|---|
| Позиция | Верхний правый угол иконки (`badgeContainerNode`) | `position({ right: 0, top: 0 })` с offset | Близко |
| Фон | `badgeBackgroundColor` + stroke 1pt | `COLOR_UNREAD_BG` | Совпадает |
| Stroke | 1pt `badgeStrokeColor` | Нет stroke | **Отсутствует** — iOS имеет белый stroke вокруг badge |

### 1.5 Количество и порядок табов

| Параметр | iOS Telegram | Android Telegram | Наша реализация | Дельта |
|---|---|---|---|---|
| Кол-во | 4+ (динамически, контроллеры передаются извне) | 0 (drawer sidebar) | 4 (фиксированные) | Концептуально совпадает с iOS |
| Порядок | Contacts, Calls, Chats, Settings (типичный) | Drawer: New Group, Contacts, Calls, People, Saved, Settings | Contacts, Calls, Chats, Settings | **Совпадает с iOS** |

### 1.6 Safe Area

| Параметр | iOS Telegram | Наша реализация | Дельта |
|---|---|---|---|
| Bottom inset | `bottomInset` добавляется к высоте: `49pt + bottomInset` | `margin({ bottom: bottomInset || 10vp })` + `expandSafeArea` | Аналогичный подход, но iOS включает inset внутри bar height, наш — через margin |

---

## 2. PROFILE SCREEN

### 2.1 Header (аватар, имя, статус)

| Параметр | iOS Telegram (`PeerInfoHeaderNode`) | Android (`ProfileActivity`) | Наша реализация | Дельта |
|---|---|---|---|---|
| Аватар | Большой, с parallax pull-down эффектом, свайп для gallery. `PeerInfoAvatarListNode` — полноэкранный при pull | `AvatarImageView` с pull-down expand | `TgAvatar` 100vp, статичный | **Значительная разница**: iOS/Android имеют интерактивный pull-down аватар с parallax, у нас — статичный круг |
| Имя | Крупный bold текст | Крупный текст в collapsed header | 22vp Bold, max 2 строки | Близко |
| Статус | Под именем, зеленый для online | Под именем | `FONT_PREVIEW_SIZE`, синий для online | **Различие**: iOS — зеленый для online, у нас — `COLOR_ICON_PRIMARY` (синий). Должен быть зеленый |

### 2.2 Action Buttons

| Параметр | iOS Telegram | Android Telegram | Наша реализация | Дельта |
|---|---|---|---|---|
| Кнопки | Message, Call, Video Call, Search, Mute, More, AddMember, Leave, Stop, AddContact | Write (FAB), Call, Video Call | **Отсутствуют полностью** | **Критический пробел**: iOS показывает ряд круглых кнопок под именем (Message, Call, Video, Search, Mute, More). Android использует FAB-кнопку. У нас нет ни одной action button |
| Стиль кнопок iOS | Круглые иконки в ряд, с подписями, tinted `accentColor` | Material FAB (writeButton) + overflow menu | — | — |

### 2.3 Info-секции

| Параметр | iOS Telegram | Android Telegram | Наша реализация | Дельта |
|---|---|---|---|---|
| Phone | `PeerInfoScreenLabeledValueItem`, copyable, tappable | `phoneRow` в RecyclerView | `buildInfoRow('phone', ...)`, copyable | Близко, но iOS имеет tap-to-call |
| Username | С дополнительными usernames (`additionalUsernames`), copyable | `usernameRow` | `buildInfoRow('username', ...)` | **Пробел**: нет поддержки множественных usernames |
| Bio | Multiline, с entities (ссылки, mentions), context menu, `textBehavior: .multiLine(maxLines: 100)` | `bioRow` | `buildInfoRow('bio', ...)` max 5 строк | **Пробел**: нет rich text entities в bio, ограничение в 5 строк |
| Notes | Персональные заметки (`PeerInfo_Notes`) | — | Отсутствует | **Пробел** |
| Birthday | `PeerInfoScreenBirthdatePickerItem` | — | Отсутствует | **Пробел** |
| Personal Channel | `case personalChannel` секция | — | Отсутствует | **Пробел** |
| Business Hours | `PeerInfoScreenBusinessHoursItem` | — | Отсутствует | **Пробел** |
| Group Location | `case groupLocation` | — | Отсутствует | **Пробел** |

### 2.4 Секция уведомлений

| Параметр | iOS Telegram | Android Telegram | Наша реализация | Дельта |
|---|---|---|---|---|
| Notifications toggle | В `peerSettings` секции | `notificationsRow` | `buildSwitchRow('Notifications', !isMuted)` | **Визуально совпадает**, но не функционален (toggle не привязан к TDLib action) |

### 2.5 Shared Media

| Параметр | iOS Telegram | Android Telegram | Наша реализация | Дельта |
|---|---|---|---|---|
| Реализация | Полноценный `SharedMediaLayout` с табами (Media, Files, Links, Music, Voice, GIFs, Stories, Gifts) | `SharedMediaLayout` с табами + scroll integration | Список disclosure rows (Media, Files, Links, Voice) — только UI, не функционален | **Критический пробел**: iOS/Android имеют inline shared media с grid/list + tab strip. У нас — заглушки |
| Интеграция scroll | Nested scrolling: profile scroll -> shared media scroll (seamless transition) | Аналогично, `NestedScrollingParent` | Нет | **Пробел**: нет nested scroll integration |

### 2.6 Members (группы)

| Параметр | iOS Telegram | Android Telegram | Наша реализация | Дельта |
|---|---|---|---|---|
| Members | `peerMembers` секция, inline список участников + search | Inline member list | Disclosure row "Members" + "Administrators" (только счетчик) | **Пробел**: нет inline списка участников |

---

## 3. НАВИГАЦИЯ

### 3.1 Chat List Header

| Параметр | iOS Telegram | Android Telegram | Наша реализация | Дельта |
|---|---|---|---|---|
| Заголовок | "Chats" centered, bold | Drawer hamburger + "Telegram" | "Chats" centered bold (`TgChatListNavigationBar`) | Совпадает с iOS |
| Edit кнопка | Слева ("Edit") | Нет (Android: hamburger) | Слева ("Edit") | Совпадает с iOS |
| Compose кнопка | Справа (pen icon) | FAB внизу справа | Справа (pen icon) | Совпадает с iOS |
| Поиск | Inline search bar под заголовком | Expandable search в ActionBar | Inline Search под заголовком | Совпадает с iOS |
| Glass blur | `GlassBackgroundView` с specular gradient | Нет | Glass blur + specular overlay | Совпадает с iOS |

### 3.2 Filter Tabs

| Параметр | iOS Telegram | Android Telegram | Наша реализация | Дельта |
|---|---|---|---|---|
| Реализация | `TabBarChatListFilterController` — свайп между фильтрами, интеграция с tab bar | Horizontal scroll tabs в ActionBar | `TgFilterBar` — glass capsule bar с animated highlight | Визуально кастомный, функционально базовый |
| Фильтры | All Chats + пользовательские папки | Аналогично | All, Unread, Groups, Channels (hardcoded) | **Пробел**: нет пользовательских папок из TDLib |

### 3.3 Переходы между экранами

| Параметр | iOS Telegram | Android Telegram | Наша реализация | Дельта |
|---|---|---|---|---|
| Chat -> Profile | Push с interactive back gesture, parallax avatar transition | Push, collapsible header | NavPathStack push (стандартный ArkUI transition) | Базовый, но функциональный |
| List -> Chat | Push с custom transition | Push с animation | NavPathStack push | Аналогично |
| Tab switching | Instant, no animation, independent stacks | Drawer slide | `animationDuration(0)`, independent NavPathStacks | **Совпадает с iOS** (мгновенное переключение + независимые стеки) |

---

## 4. СВОДКА ПРИОРИТЕТНЫХ РАСХОЖДЕНИЙ

### Критические (влияют на core UX):
1. **Profile: отсутствуют action buttons** (Message, Call, Video, Search, Mute, More)
2. **Profile: статичный аватар** — нет pull-down parallax / gallery swipe
3. **Shared Media: заглушки** — нет реального контента, нет grid/list view
4. **Tab Bar: pill highlight — наш кастом** — iOS не использует pill, а Lottie-анимации иконок

### Важные (заметны пользователю):
5. **Profile: online статус зеленый** (iOS) vs синий (наш)
6. **Profile: bio без rich text** (entities, ссылки, mentions)
7. **Badge: нет white stroke** как в iOS
8. **Filter tabs: hardcoded** — нет папок из TDLib
9. **Profile: notifications toggle не функционален**

### Косметические:
10. Tab bar ширина: iOS — full width, наш — 80% max 328vp (стилистический выбор)
11. Tab bar высота 56vp vs iOS 34-49pt (стилистический выбор для Android-like feel)
12. Отсутствуют: birthday, personal channel, notes, business hours, group location в profile

---

## 5. РЕКОМЕНДАЦИИ ПО ПРИОРИТЕТУ

1. **P10: Profile Action Buttons** — добавить ряд кнопок (Message, Call, Video, Mute, More) под именем
2. **P11: Profile Online Color** — изменить online цвет на зеленый
3. **P12: Badge Stroke** — добавить white stroke вокруг badge в tab bar
4. **P13: Shared Media Grid** — реализовать базовый media grid с данными из TDLib
5. **P14: Pull-down Avatar** — интерактивный expand аватара в profile
6. **P15: Bio Rich Text** — поддержка entities в bio
