# Сравнение Chat Top Bar и Composer: iOS vs HarmonyOS

Дата анализа: 2026-03-13

---

## 1. CHAT TOP BAR

### 1.1 Layout

| Аспект | iOS Telegram | Наша реализация | Разница |
|--------|-------------|-----------------|---------|
| Общая структура | Стандартный UINavigationBar: [back+count] — [titleView center] — [search/info] | Capsule-based: [backCapsule] — [titleCapsule center] — [avatarCapsule] | Наш дизайн — три отдельных glass capsule. iOS — стандартный nav bar с custom titleView |
| Back button | Системная стрелка назад + unread badge count ("< 3") | Круглая glass-капсула с иконкой back | iOS показывает счётчик непрочитанных рядом с кнопкой back — у нас нет |
| Правая сторона | UIBarButtonItem: search, openChatInfo (аватар или иконка info) | Круглая glass-капсула с аватаром | iOS: кнопка поиска + отдельная кнопка info/avatar. У нас только avatar capsule |
| Title position | Центрированный titleView внутри стандартного nav bar | Title capsule с FlexAlign.Center внутри Row | Визуально похоже |
| Avatar в title | НЕТ аватара в title area. Аватар — в правом nav button (openChatInfo) | Аватар в отдельной правой capsule | Схоже по расположению |

### 1.2 Glass/Blur

| Аспект | iOS | Наша реализация | Разница |
|--------|-----|-----------------|---------|
| Title view bg | `GlassBackgroundView` — отдельный glass view внутри title view | `backgroundBlurStyle(BlurStyle.Thin)` + `CHAT_TOP_BAR_CAPSULE_BG` | Оба используют glass/blur. iOS имеет GlassBackgroundView с возможным fallback |
| Nav bar bg | Стандартный UINavigationBar blur (на уровне системы) | Прозрачный bg на Column, blur на каждой capsule отдельно | iOS blur — единая полоса, у нас — три отдельных blur-капсулы |
| Specular overlay | Нет данных о specular в iOS reference | `buildGlassSpecular()` — линейный градиент поверх capsule | Наш эксклюзив |

### 1.3 Title Content

| Аспект | iOS | Наша реализация | Разница |
|--------|-----|-----------------|---------|
| Name | Peer display name, customTitle support, "Saved Messages", "My Notes", "Replies" | `this.title` из chat.title | iOS обрабатывает Saved Messages, Replies, Notes, Anonymous — у нас просто chat.title |
| Online status | Subtitle: "online" (зелёный), "last seen recently/week/month/long time ago" | `formatUserStatus()`: те же статусы | Покрыто |
| Member count | `onlineMemberCount: (total: Int32?, recent: Int32?)` — "N members, M online" | Нет | **ОТСУТСТВУЕТ** для групп/каналов |
| Typing | Развёрнутая система: typingText, recordingVoice, recordingVideo, uploadingFile, uploadingPhoto, playingGame, choosingSticker, speakingInGroupCall; в группах — "User typing...", "User and User typing...", "User and N others typing..." | `typing...` — одна строка | **ЗНАЧИТЕЛЬНО УПРОЩЕНО**: нет типа активности, нет имён в группах |
| Network state | "Connecting...", "Updating...", "Waiting for network..." заменяет subtitle | Нет | **ОТСУТСТВУЕТ** |
| Badge/Icons | lock (secret chat), mute, verified, premium, emojiStatus, scam, fake | Нет | **ОТСУТСТВУЕТ**: никаких badge/иконок рядом с именем |

### 1.4 Interaction

| Аспект | iOS | Наша реализация | Разница |
|--------|-----|-----------------|---------|
| Tap title | `pressed` callback -> открывает profile/info | `onTitlePress` -> `openProfile()` | Покрыто |
| Long press title | `longPressed` callback (special actions) | Нет | **ОТСУТСТВУЕТ** |
| Tap avatar | Через nav button action `openChatInfo(expandAvatar: true)` — раскрывает аватар на весь экран | `onAvatarPress` -> `openProfile()` | iOS при tap на аватар раскрывает его fullscreen, у нас — просто переход в профиль |
| Search button | Отдельная кнопка search в правой части nav bar | Нет | **ОТСУТСТВУЕТ** в top bar чата |

### 1.5 Фичи iOS отсутствующие у нас

1. **Unread count badge на кнопке back** — показывает сколько непрочитанных чатов
2. **Кнопка поиска** в top bar (search messages in chat)
3. **Verified/premium/scam/fake badges** рядом с именем
4. **Lock icon** для secret chats
5. **Mute icon** рядом с именем
6. **Network state** overlay (Connecting/Updating/Waiting)
7. **Развёрнутые typing indicators** (тип активности + имена)
8. **Member count** для групп/каналов
9. **Long press** на title
10. **Animated transitions** при смене subtitle (typing появляется с анимацией)
11. **Saved Messages / My Notes / Replies** — специальные названия
12. **Reply thread header** с количеством комментариев

---

## 2. COMPOSER (Text Input Panel)

### 2.1 Layout

| Аспект | iOS | Наша реализация | Разница |
|--------|-----|-----------------|---------|
| Общая структура | Сложная multi-layer панель: accessoryPanel (reply/edit/forward) сверху, затем textInputContainer + buttons | Единая glass capsule: [attach] [textArea] [emoji] [send/mic] | iOS значительно сложнее |
| Attach button | Левый край, transition animation при появлении текста | Левый край, статичный | Нет анимации transition |
| Text field | Custom `ChatInputTextView` с rich text support (attributed string), inline emoji, mention highlights | Стандартный ArkUI `TextArea` с plain text | **КРИТИЧЕСКАЯ РАЗНИЦА**: iOS поддерживает rich text, mentions, форматирование |
| Emoji button | Переключатель emoji keyboard <-> text keyboard с анимацией | Статичная иконка emoji (не функциональна) | **ОТСУТСТВУЕТ**: нет emoji picker, нет анимации переключения |
| Send/Mic button | Два отдельных узла: `sendButton` + `micButton` с animated transition; mic имеет press-and-hold для voice recording, slide-to-cancel | Условная иконка send/mic в одной кнопке | **ЗНАЧИТЕЛЬНО УПРОЩЕНО**: нет voice recording, нет анимации перехода |
| Кнопка "Schedule" | Отдельная кнопка для scheduled messages | Нет | **ОТСУТСТВУЕТ** |
| Slow mode | `ChatTextInputSlowmodePlaceholderNode` — таймер обратного отсчёта | Нет | **ОТСУТСТВУЕТ** |

### 2.2 Text Field Behavior

| Аспект | iOS | Наша реализация | Разница |
|--------|-----|-----------------|---------|
| Placeholder | Локализованный "Message" с разными вариациями (silent message, schedule, etc.) | `placeholder: 'Message'` | iOS имеет контекстные placeholder |
| Max lines | Автоматический рост, ограничен высотой экрана; `maxHeight` рассчитывается от metrics | `COMPOSER_MAX_LINES` из tokens | Покрыто базово |
| Auto-grow | `updateHeight()` с анимацией изменения высоты, плавный transition | TextArea auto-grow встроенный | iOS анимирует изменение высоты, у нас — нативный auto-grow без custom анимации |
| Rich text | Поддержка bold, italic, monospace, spoiler, link; inline entity highlights | Plain text only | **КРИТИЧЕСКАЯ РАЗНИЦА** |
| Mentions | @username autocomplete с popup, inline highlight | Нет | **ОТСУТСТВУЕТ** |
| Hashtag autocomplete | #hashtag поиск + autocomplete | Нет | **ОТСУТСТВУЕТ** |
| Bot commands | /command autocomplete | Нет | **ОТСУТСТВУЕТ** |
| Text formatting menu | Long press -> format bar (bold, italic, mono, link, spoiler) | Нет | **ОТСУТСТВУЕТ** |

### 2.3 Button Transitions

| Аспект | iOS | Наша реализация | Разница |
|--------|-----|-----------------|---------|
| Send <-> Mic | Animated crossfade/scale transition, `sendButtonRadialStatusNode` для progress | Conditional icon swap без анимации | **ОТСУТСТВУЕТ** анимация |
| Mic press-hold | Long press -> voice recording mode; показывает waveform, timer, slide-to-cancel | Нет | **ПОЛНОСТЬЮ ОТСУТСТВУЕТ** |
| Video message | Long press mic -> switch to video recording circle | Нет | **ПОЛНОСТЬЮ ОТСУТСТВУЕТ** |
| Send button states | Normal, highlighted, disabled; with haptic feedback | canSend() boolean, background color change | Базовый |
| Attach button hide | При наборе текста attach button может скрываться с анимацией | Всегда видна | Нет анимации |

### 2.4 Attachment Menu

| Аспект | iOS | Наша реализация | Разница |
|--------|-----|-----------------|---------|
| Menu type | `ChatControllerOpenAttachmentMenu` — action sheet / bottom sheet с: Photo/Video, File, Location, Contact, Poll, Quick Photo | Нет (иконка attach не функциональна) | **ПОЛНОСТЬЮ ОТСУТСТВУЕТ** |
| Camera | Inline camera preview в attachment menu | Нет | **ОТСУТСТВУЕТ** |
| Media picker | Галерея с multi-select, crop, edit | Нет | **ОТСУТСТВУЕТ** |
| File picker | Document browser | Нет | **ОТСУТСТВУЕТ** |

### 2.5 Reply/Edit Bar

| Аспект | iOS | Наша реализация | Разница |
|--------|-----|-----------------|---------|
| Reply bar | `accessoryPanelNode` над composer: показывает reply preview с автором, текстом, thumbnail; animated appear/dismiss | `TgReplySnippet` внутри composer Column, glass capsule | Базовая реализация есть |
| Edit mode | То же место — показывает "Edit Message" + original content | Нет | **ОТСУТСТВУЕТ**: нет режима редактирования сообщений |
| Forward bar | "Forward from: User" bar | Нет | **ОТСУТСТВУЕТ** |
| Web page preview | Inline preview ссылки над composer | Нет | **ОТСУТСТВУЕТ** |
| Cancel button | X кнопка для закрытия reply/edit/forward bar | `onReplyCancelPress` callback | Есть в API, реализация зависит от вызывающего кода |

### 2.6 Фичи iOS отсутствующие у нас

1. **Voice recording** (press-and-hold mic) с waveform, timer, slide-to-cancel
2. **Video message recording** (круглые видео-сообщения)
3. **Rich text editing** (bold, italic, spoiler, monospace, links)
4. **Emoji keyboard** (custom emoji picker с stickers, GIFs)
5. **Attachment menu** (photo, file, location, contact, poll)
6. **Mentions autocomplete** (@username)
7. **Bot commands autocomplete** (/command)
8. **Hashtag search**
9. **Edit message mode**
10. **Forward message bar**
11. **Web page preview** above composer
12. **Scheduled messages**
13. **Slow mode indicator**
14. **Send button animation** (crossfade mic <-> send)
15. **Silent message** mode
16. **Input text formatting toolbar**

---

## 3. ПРИОРИТИЗАЦИЯ ДОРАБОТОК

### Высокий приоритет (видно пользователю сразу)
1. Member count в subtitle для групп/каналов
2. Развёрнутые typing indicators (тип + имена)
3. Network state indicator (Connecting/Updating)
4. Send <-> Mic анимация перехода
5. Verified/premium badge рядом с именем

### Средний приоритет (улучшение UX)
6. Unread count на кнопке back
7. Search button в top bar чата
8. Mute icon рядом с именем
9. Attachment menu (хотя бы photo + file)
10. Voice recording (press-and-hold mic)

### Низкий приоритет (продвинутые фичи)
11. Rich text editing
12. Emoji keyboard
13. Mentions/hashtag/bot command autocomplete
14. Edit/Forward message mode
15. Web page preview
16. Secret chat lock icon
