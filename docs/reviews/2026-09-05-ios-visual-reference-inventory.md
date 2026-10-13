# Инвентаризация iOS visual references — 2026-09-05

## Результат и граница доказательства

**Текущий raw shipped-runtime witness установленного Telegram iOS не подтверждён.** В ограниченно проверенных локальных каталогах есть исторические iPhone-кандидаты, но нет сопровождающей фиксации версии приложения/build, iOS и достоверной даты съёмки. Переименовывать их в «current» нельзя.

**Пригодный публичный fallback получен:** 10 неизменённых JPEG из официальных Telegram blog / App Store, 1 180 729 bytes суммарно. Все 10 декодированы и визуально просмотрены; сохранены в `.codex/ui-reference/ios-2026-09-05/`. Это опубликованные разработчиком демонстрации iOS UI / рекламные композиции, **не независимо проверенная запись установленной текущей сборки**. Январский poster вообще не показывает интерфейс чата и исключён из сравнений.

Дата проверки/скачивания — **2026-09-05**. Дата статьи, дата версии в магазине, дата скачивания и дата съёмки — разные величины. Отчёт не выставляет общей оценки parity и не закрывает visual acceptance после reliability.

## 1. Область проверки и метод

- Сначала прочитаны `REFERENCES.md` и `STATUS.md`, затем релевантные части `TASKS/TODO.md`, `DECISIONS.md` и исторического design-документа.
- Локальное перечисление ограничено `.codex/ui-audit/` (`Get-ChildItem -Recurse -Depth 3 -File`), `docs/reviews/`, корнем `design/`, корнем `C:\Refs\Telegram` и `Telegram-iOS-current/docs/` (depth 1). Более глубокие каталоги и весь диск не сканировались. `design/` содержит только `logo/` и дальше не исследовался.
- В `.codex/ui-audit` на указанной глубине: 1 358 JPEG, 201 JPG, 190 PNG, 1 WEBP, 1 GIF, 3 MP4; 20 Markdown-файлов. Это число файлов, **не число iOS witnesses**. Проверены имена iOS/reference-кандидатов, размеры и соседние provenance-документы; поиск ссылок выполнялся только в Markdown и максимум на глубине 4.
- Потенциально приватные локальные screenshots, видео, JSON/XML UI dumps и логи сообщений **не открывались визуально, не копировались и не включались в отчёт**. Для нескольких изображений прочитаны только file/header metadata и SHA-256. Тексты переписки и содержимое фотографий не извлекались.
- Внешние источники: только публичные `telegram.org`, `apps.apple.com` и изображение CDN `is1-ssl.mzstatic.com`, без авторизации/аккаунтов. HTML читался в памяти; `poster`, `source` и App Store `srcset` использованы как точная связь page → asset.
- CPL: вызов `cpl_skeleton` не вернул ответ до ограниченной остановки ожидания; дальнейшие CPL-вызовы из той последовательности не исполнились. Использован прямой bounded file-list/read fallback, без повторных попыток и перестройки индекса.
- `harmonyos_docs`: запрос `snapshot screenshot` не ответил за локальный лимит 12 s; повторов не было. Новых ArkUI/API решений здесь нет: platform-grounding ограничен классификацией локальных audit-документов, не утверждением о поддержке API.
- Build, emulator, hdc, вход в Telegram и публикация не выполнялись. Единственный новый документ — этот отчёт; остальные новые файлы — 10 публичных JPEG в разрешённом каталоге. Родительские reliability/permissions/unread изменения не затрагивались.

## 2. Локальная инвентаризация: не смешивать классы

Пути ниже относительны корню проекта, кроме явно абсолютных. Даты каталогов/mtime не удостоверяют дату съёмки.

| Класс | Найденный объект | Проверенное происхождение / дата | Допустимое использование |
|---|---|---|---|
| iOS **source**, не screenshot | `C:\Refs\Telegram\Telegram-iOS-current` | Локальный HEAD `6e370e06d147b091b07903071cb1b8a22152492d`; commit time `2026-06-05T01:05:54+02:00`, subject `Force build`. Совпадает с pin в `REFERENCES.md`, last verified там 2026-07-10. Fetch/pull не делался. | Структура/состояния/constants; не доказательство сентябрьского shipped UI. Никакой GPL/source-код не копировался. |
| Исторический iOS source | `C:\Refs\Telegram\Telegram-iOS-snapshot-2026-02-10` | Наличие каталога; происхождение ZIP/no-git описано реестром, заново не аттестовано. | Только исторический источник; название snapshot не равно версии приложения. |
| Кандидаты локального iPhone runtime, приватность не установлена | `.codex/ui-audit/2026-07-10/iphone16promax-runtime/` | 3 JPG; каждый 589×1280; размеры 86 154 / 71 691 / 75 742 bytes; mtime UTC 2026-07-10. В каталоге нет manifest/README/version witness. Изображения не просматривались. | Возможный исторический материал для владельца; модель устройства пока только из имени каталога. Не current, не public, не raw/native-resolution attest. |
| Исторический App Store-кандидат | `.codex/ui-audit/2026-07-10/ios-appstore/00.png` … `06.png` | 7 PNG, 392×696; mtime UTC 2026-07-10; рядом нет URL/version manifest. | Имя каталога не доказывает URL и версию. Не подменять новыми US-изображениями молча: наборы и размеры различаются. |
| Историческая официальная иллюстрация — пока только label | `.codex/ui-audit/2026-07-10/telegram-official-liquid-glass.webp` | 133 684 bytes; mtime UTC 2026-07-10; SHA-256 `4F3BC6BB5FF3D446193E01F8DE7C35F84FF5E58AC7E9B13A3A5C646433DABC5B`. Ссылка-источник в проверенных Markdown не найдена. | Не считать текущим runtime по слову `official`; визуально не открывался. |
| Неполный iOS-ref / crop, происхождение не установлено | `.codex/ui-audit/2026-08-29/bars-fade-api24/ios-ref-messages.jpg`; `crop-ios-top.png` | 410×502 / 66 012 bytes и 410×225 / 204 359 bytes; mtime UTC 2026-08-29. Нет связки URL/device/version/capture date. | Не измерять полный экран/safe area по этим crops; не выводить текущую версию из свежего mtime. Не открывались визуально. |
| HarmonyOS implementation audit с iOS в названии | `.codex/ui-audit/2026-07-11/ios-native-liquid-composer/decision.md` | Документ явно описывает HarmonyOS runtime API 23, `TgComposerInput`, API26 guard и HAP install. Прочитан в этой сессии; исторические PASS не воспроизводились. | **Не iOS runtime**, несмотря на заголовок. Подходит как исторический контекст HarmonyOS-реализации. |
| Непроверенные filename-кандидаты | `2026-08-11/unfreeze-reopen/w2-waveform-ios.png`, `wb-voice-ios-wave.png` под `.codex/ui-audit/` | Только существование и размеры файлов; ни происхождение, ни платформа изображений не проверены. | Исключены из iOS baseline. Суффикса `ios` недостаточно. |
| HarmonyOS screenshots, исторические | `.codex/ui-audit/2026-08-29/bars-fade-api24/`; `.codex/ui-audit/2026-08-31/bottom-bar-glass/` | Наличие файлов подтверждено. Attribution к HarmonyOS — по `STATUS.md` / `TASKS/TODO.md`; новый runtime не запускался. В `bottom-bar-glass` есть `02-topbar-underglass.jpeg` и `06-crop-bottom.png`. | Будущая локальная before/after сторона, не iOS reference и не свидетельство сегодняшних reliability-правок. Изображения не раскрывались. |

**Вывод ограничен проверенной областью:** отсутствие надёжного current witness здесь не доказывает его отсутствие на всех устройствах/дисках пользователя.

## 3. Версия и актуальность публичного fallback

| Источник | Проверенный факт | Что не доказано |
|---|---|---|
| [App Store US, Telegram Messenger, id686449807][store] | При обращении 2026-09-05 карточка показывает **12.9.3**, HTML содержит `<time datetime="2026-08-21">` рядом с этой версией. | Это наблюдаемая версия **US listing**, не утверждение о глобально последней версии, установленном приложении или версии изображений. Capture date/build/OS у screenshots не указаны. |
| [Telegram: Welcome Messages…][aug] | Дата страницы **2026-08-25**. Более свежий из проверенных Telegram blog-материалов. | `TG-13` в URL и 13-летие Telegram не являются номером версии iOS. Более поздняя статья не отменяет наблюдаемые данные App Store. |
| [Telegram: Rich Text Editor, Communities…][jul] | Дата страницы **2026-07-14**. | Дата релизной публикации не подтверждает дату монтажа/съёмки каждого asset. |
| [Telegram: AI Summaries, New Design…][jan] | Дата страницы **2026-01-03**, раздел New Design явно относится к iOS Liquid Glass. | Не текущий сентябрьский visual baseline. На странице есть также видео с `alt=" Android design"`; все embedded media нельзя объявлять iOS. |

Все blog-кадры ниже — **публичное официальное изображение iOS UI в рекламной рамке**, а не подтверждённый прямой framebuffer capture. iPhone-рамка не аттестует модель, iOS/build или настройки accessibility/material. Для принятия конкретного atom нужно учитывать эту границу.

## 4. Публичные изображения: точные ссылки и просмотренное содержимое

Локальные файлы: [каталог public reference](../../.codex/ui-reference/ios-2026-09-05/). Изображения скачаны без генерации, редактирования, ресайза и crop с нашей стороны. App Store URL взят буквально из `srcset`; сегмент `600x1334` — bounding request, **фактический JPEG 600×1301**, а не 600×1334.

### App Store — дата съёмки/версия изображения неизвестна

Все шесть файлов получены с [US listing][store] 2026-09-05; каждый 600×1301. Текущая доступность в магазине не превращает маркетинговые screenshots в version-pinned runtime.

| ID / локальный файл | Точный публичный asset | Просмотренное состояние / полезность |
|---|---|---|
| AS0 `appstore-us-iphone-00.jpg` | [JPEG 0][as0] | ChatList light: stories, folders, row meta/unread, floating tabs/search. Главный full-layout референс списка. |
| AS1 `appstore-us-iphone-01.jpg` | [JPEG 1][as1] | Group dark, верхний chrome, активная запись voice. Не idle composer. |
| AS2 `appstore-us-iphone-02.jpg` | [JPEG 2][as2] | Private chat light; composer над открытой emoji-панелью. |
| AS3 `appstore-us-iphone-03.jpg` | [JPEG 3][as3] | Secret chat dark; lock/title, idle composer с timer. Не обычный private-chat default. |
| AS4 `appstore-us-iphone-04.jpg` | [JPEG 4][as4] | Private chat light с яркими обоями; верхние капсулы и idle composer. |
| AS5 `appstore-us-iphone-05.jpg` | [JPEG 5][as5] | Profile; для ChatList/composer/topbar чата вторичен. |

### Telegram blog — дата публикации известна, capture/build неизвестны

| ID / локальный файл | Page → точный poster | Просмотренное содержимое и ограничение |
|---|---|---|
| TG-JAN `telegram-2026-01-03-liquid-ios-poster.jpg` | [2026-01-03][jan] → [JPEG poster][jan-poster] | 1080×1080, заставка: стеклянная форма на сетке в рамке iPhone. **Нет ChatList/composer/topbar — исключить из геометрического сравнения.** |
| TG-JUL-CL `telegram-2026-07-14-communities-poster.jpg` | [2026-07-14][jul] → [JPEG poster][jul-cl-poster] | 1080×1080, увеличенный ChatList light: верхние действия, stories, folders, верхние строки. Низ экрана обрезан композицией; по нему нельзя судить о tabs/safe area. |
| TG-JUL-ED `telegram-2026-07-14-editor-poster.jpg` | [2026-07-14][jul] → [JPEG poster][jul-ed-poster] | 1080×1080, channel с длинным постом под верхними капсулами; внизу Broadcast composer. Это posting state, **не** read-only subscriber Mute/Join. |
| TG-AUG `telegram-2026-08-25-welcome-poster.jpg` | [2026-08-25][aug] → [JPEG poster][aug-poster] | 1080×1080, group light: back / title+subtitle / avatar, отдельная pinned lane, idle composer. Самый свежий датированный полезный кадр этой выборки; клавиатура не показана, самый низ обрезан. |

### Видео: обнаружены и доступны, но не просмотрены

Из HTML соответствующих страниц извлечены пары `poster` → `<source type="video/mp4">`. Для четырёх точных URL HEAD вернул **200, Content-Type video/mp4**, Content-Length не был указан. Файлы не скачивались и не проигрывались: duration, frame timestamps, состояния в середине, движение/рефракция **не проверены**.

| Страница / HTML label | Прямая ссылка |
|---|---|
| 2026-01-03 / `Liquid iOS` | [Liquid iOS MP4][jan-video] |
| 2026-07-14 / `Rich Text Editor` | [Rich Text Editor MP4][jul-ed-video] |
| 2026-07-14 / `Telegram Communities` | [Communities MP4][jul-cl-video] |
| 2026-08-25 / `How to Add a Welcome Message` | [Welcome Message MP4][aug-video] |

Наличие видео и iPhone в poster — не аттестация всех кадров как iOS. Для motion review требуется отдельный просмотр с отметками времени, без выдуманных timestamps.

## 5. Самые полезные сравнения после reliability

Это **порядок будущих сравнений**, не перечень найденных в HarmonyOS visual defects. Новая HarmonyOS-сторона в этой сессии не снималась.

| Область | Брать сначала | Проверять отдельно | Не заключать по этим assets |
|---|---|---|---|
| ChatList | AS0 для целого экрана; TG-JUL-CL для увеличенного верхнего участка | Иерархию title/actions → stories → folders → rows; avatar/title/preview; правую ось time/status/unread; pinned/muted; clearance последней строки над tabs/search | Реальные размеры pt/vp, поведение scroll/collapse, dark parity, точную геометрию community expansion. |
| Chat topbar | TG-AUG; TG-JUL-ED при длинном контенте; AS1/AS3 только для соответствующих dark states | Раздельные back, title+subtitle, avatar surfaces; общий верхний fade/backdrop **отдельно** от капсул; вторую pinned lane и проходящий под ней контент | «Нужно удалить весь фон», численный blur/radius, отсутствие transition flash, coverage длинных русских заголовков. |
| Chat composer | TG-AUG и AS4 для idle light; AS2 для emoji-open; AS1 для recording; TG-JUL-ED для channel posting | Attach / input body / action как отдельные формы; совпадение baseline; keyboard clearance; смену action и высоты по состоянию; соответствие posting/readonly роли | Idle parity по recording кадру; обычный composer по secret-chat timer; Mute/Join/Restricted по Broadcast; send/right guards или корректность live permissions. |

После parent reliability-гейтов нужен свежий matching-state HarmonyOS witness, затем узкий визуальный delta-review по одному atom/состоянию. Исторические HarmonyOS screenshots не доказывают вид текущего дерева.

### Минимум для настоящего current shipped iOS acceptance

1. Без раскрытия аккаунта зафиксировать дату capture, Telegram version/build, iOS version, устройство и logical viewport/scale. Версию подтвердить отдельным безопасным witness, не именем файла.
2. На публичном/специальном тестовом контенте получить ChatList light/dark, chat idle/scrolled+pinned, keyboard-open, emoji-open, multiline text/action и channel/group bottom-panel states по роли. Не импортировать личные переписки в public bundle.
3. Записать theme, text size, locale, Reduce Transparency/Motion и относящиеся к effects настройки; для движения — реальные timestamps и неизменённый original.
4. Сравнивать равные состояния/viewport; promotional рамки и масштабирование не использовать для прямого px→vp вывода. Public pages могут менять assets: сохранять URL, SHA-256 и дату retrieval отдельно от capture.

## 6. Проверяемый manifest скачанных файлов

Путь всех строк: `.codex/ui-reference/ios-2026-09-05/`. SHA-256 относится к реально скачанным bytes, не к оригинальной несжатой съёмке.

| Файл | Bytes | SHA-256 |
|---|---:|---|
| `appstore-us-iphone-00.jpg` | 105720 | `87B015EDC33233F33B1487D616A6C5D49D58649076EA50A483A394FE88716129` |
| `appstore-us-iphone-01.jpg` | 110766 | `71D2AEC4FB9707918ADF5A5A5BF368F16F85DD2897219022CB6AAB9C92CBAEB3` |
| `appstore-us-iphone-02.jpg` | 130457 | `1028D38189B110C63E58B45E133C1288F85F6DD2443D1F48058B8E4BBC964C51` |
| `appstore-us-iphone-03.jpg` | 96790 | `89807910791913A7B8CA81C51EEA4E108A36672B7F4563080D761E0CCC422363` |
| `appstore-us-iphone-04.jpg` | 127006 | `651DB5999EE89823A86C5437865A4DE9D266515E6F7408599203B5077802F75E` |
| `appstore-us-iphone-05.jpg` | 123119 | `13F087FD8DE8AF16EB2C3277AA38ADDACEAC8904F3817784BADFA580078A3BF7` |
| `telegram-2026-01-03-liquid-ios-poster.jpg` | 273709 | `DEC1FEF5BF40C6201DABE776327A0CE2BC82C68747A8100A1F4FF98017CC443F` |
| `telegram-2026-07-14-communities-poster.jpg` | 64892 | `9D268ADB9CB91A52987313C2AA3617A0586BDA88CC32B9ECE27D8328AAE9BE4F` |
| `telegram-2026-07-14-editor-poster.jpg` | 72795 | `3DCA3F10DFDA0D972C94BD4184620B09F0609691BECD1E13981F54FB9CE72511` |
| `telegram-2026-08-25-welcome-poster.jpg` | 75475 | `8774476049ED4AC339C99EE93613D62300228353DE30DF55FB9687F3A32617B1` |

Каталог `.codex/ui-reference` попадает под существующий gitignore; это локальный reference cache, не автоматически включённый в commit asset pack. Ignore-правила не менялись, `git add -f` не выполнялся. Полные первичные URL сохранены ниже для восстановления. Copyright остаётся у правообладателей: материалы предназначены для локального сравнения, не для переноса в ресурсы приложения или публикации.

## 7. Проверка отчёта

- Все 10 JPEG открыты через image viewer; dimensions получены из image headers.
- Metadata/hashes/total bytes manifest проверяются по локальным файлам, а не по числам в URL.
- Четыре MP4 проверены только HTTP HEAD; ограничения просмотра записаны явно.
- Релизная дата App Store прочитана из HTML `datetime`, а не выведена из относительного `Aug 21`.
- Проверка документа: перечитать итог, проверить ссылки/manifest, выполнить scoped `git diff --no-index --check` для нового файла. Build/test не требуется для этой document-only работы и намеренно не запускался.

[store]: https://apps.apple.com/us/app/telegram-messenger/id686449807
[jan]: https://telegram.org/blog/new-design-ai-summaries
[jul]: https://telegram.org/blog/communities-editor-invisible-messages
[aug]: https://telegram.org/blog/welcome-messages-buttons-TG-13
[as0]: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/71/84/a7/7184a791-6e76-027e-507f-383f17926ba7/0_APP_IPHONE_63_0.png/600x1334bb-60.jpg
[as1]: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/d4/4d/77/d44d77ab-19b6-db76-0064-4fe46809ae44/1_APP_IPHONE_63_1.png/600x1334bb-60.jpg
[as2]: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/e3/78/9c/e3789c34-2c9f-2fb8-49f4-b6092883bea8/2_APP_IPHONE_63_2.png/600x1334bb-60.jpg
[as3]: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/ac/e1/9b/ace19b05-08fb-8d87-b9cd-b6b123d99383/3_APP_IPHONE_63_3.png/600x1334bb-60.jpg
[as4]: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/59/a6/d1/59a6d15d-2e24-a43b-2408-fdecf5b3aa6f/4_APP_IPHONE_63_4.png/600x1334bb-60.jpg
[as5]: https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/31/75/41/317541b2-c15b-e550-96d6-5a1548f2ec12/5_APP_IPHONE_63_5.png/600x1334bb-60.jpg
[jan-poster]: https://telegram.org/file/400780400064/5/NHuHYzKA4CA.273709.jpg/cf2819c8ce622a3c1e
[jul-ed-poster]: https://telegram.org/file/400780400243/4/Wh7_R-p9RRI.72795.jpg/25de6fd9c9f8d60799
[jul-cl-poster]: https://telegram.org/file/400780400627/2/m0_w0ABzq9E.64892.jpg/dd79c8957289c99b38
[aug-poster]: https://telegram.org/file/400780400992/8/IE2p82bnRTQ.75475.jpg/2d5ded71fc1253025f
[jan-video]: https://telegram.org/file/400780400489/3/mgjfNAD3TmE.8365548.mp4/b03a859eab60b66457
[jul-ed-video]: https://telegram.org/file/400780400590/3/2Af8cY9bcnE.9365402.mp4/dab9e1b06f06212475
[jul-cl-video]: https://telegram.org/file/400780400937/7/7FrlfQ3X9TA.9490984.mp4/905d7975740c1999ae
[aug-video]: https://telegram.org/file/400780400607/4/1NdVJSSPrCQ.5535652.mp4/e9d9f4244828a5e01f
