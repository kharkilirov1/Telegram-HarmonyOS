# TgChatScreenPage — план полной декомпозиции

> Для агентных исполнителей: выполнять по одному проверяемому срезу; после каждого среза — независимое ревью и повторные проверки. Не делать один механический перенос 5930 строк.

**Цель:** оставить `TgChatScreenPage.ets` единственным владельцем маршрута, аккаунта и жизненного цикла, но убрать из него реализацию отдельных функций и крупные блоки разметки без изменения поведения чата.

**Область:** только экран чата и его непосредственные `ui/pages/chat`/`tg_ui` компоненты, их тесты и документы. TDLib, AppStore, публичные use-case контракты и визуальный дизайн не переписывать ради уменьшения файла. Commit/push и установка HAP — не часть автоматического выполнения.

## Отправная точка и критерий размера

- На 2026-09-29 до первого среза: `dev@faf66b3`, dirty working tree; `TgChatScreenPage.ets` — **5930 физических строк**, 112 `@Local`, SHA-256 `7EED22EFC56CA09C0CDCEE93143D32E74229E306E23FCE88912664D31E69BA06`. Это снимок рабочего дерева, не HEAD. Не откатывать уже существующие правки.
- В действующих `AGENTS.md`/`DECISIONS.md` числового предела длины ArkTS-файла не найдено. Во внешнем ревью указана **средняя** длина 300–500 строк; это не правило проекта. Для этой работы вводим проверяемый бюджет: **каждый новый production `.ets` ≤500 физических строк; итоговый page-координатор ≤700**. Бюджет не оправдывает разрыв ownership, дублирование состояния или фиктивные wrapper-файлы. Если 700 невозможно без переноса `@Local`/route-owner, выносить этот архитектурный риск на отдельное решение с runtime witness, а не объявлять работу законченной по числу строк.
- Базовые проверки в исходном дереве: `node scripts/run-host-tests.cjs` — 60/60; `scripts/smoke-ui-phase0.ps1` — PASS; последовательные `entry@default` и `entry@ohosTest` debug `assembleHap --no-daemon --no-parallel --no-incremental` — BUILD SUCCESSFUL. HAP не подписан и новая сборка на сохранённую emulator-сессию не устанавливалась.
- На исходном снимке 37 скриптов прямо содержали `TgChatScreenPage.ets` (17 `.cjs`, 19 `.ps1`, 1 `.sh`); более широкий поиск имени страницы находит и другие зависимости без суффикса. Это карта зависимостей, **не** 37 поведенческих тестов. После каждого переноса повторять оба поиска, перенаправлять source-text assertions к реальному владельцу и сохранять отдельную проверку wiring страницы. Не удалять утверждение только потому, что оно перестало находить старую строку.

## Инварианты, которые нельзя менять ради разбивки

1. **Единственный владелец route/account/lifecycle.** `bindChatRoute`/`activateChatRoute`/`aboutToDisappear`, `openLease`, `navigationToken`, `accountStore`, подписки и порядок teardown остаются под одной page-owned координацией. Асинхронные помощники получают захваченную capability; они не выбирают аккаунт через глобальный getter. Старые callbacks не действуют на новую страницу или другой аккаунт.
2. **Реактивность V2.** Текущие `@Local` остаются в странице при поведенческих переносах. Обычный mutable `controller.state` не эквивалентен `@Local`; для переноса state нужен отдельный дизайн с `@ObservedV2/@Trace`, сборкой и живым UI witness. Визуальные дети получают конкретные `@Param/@Event`, не весь AppStore.
3. **Общая операция отправки.** Edit/forward/text/media используют общий page-owned operation token и арбитраж режимов. Нельзя заводить независимые `busy` флаги, которые поздний ответ сбрасывает за другую операцию. Draft на закрытии пишется в прежний owning account, edit-buffer в draft не попадает.
4. **Timeline — упорядоченная транзакция.** В `rebuildTimeline` сохранить последовательность anchor → diff → pending downloads/open → gallery refresh → unread/scroll restore → jump/reply. Не добавлять вторую store-подписку или второй `Scroller` в дочернем компоненте. `LazyForEach`, keys и reuse не менять в рамках extraction.
5. **Таймеры/подписки/контекст callback.** Сохранять identity для отмены и generation fencing. `Window.off` снимает лишь callback страницы. Popup callback захватывает generation конкретного открытия. Teardown страницы не останавливает app-global playback.
6. **UI-геометрия.** Page владеет safe area, `composerTotalHeight`, размещением слоёв и связью IME resize ↔ timeline bottom alignment. Вынесенные компоненты не добавляют второй inset/фон, не меняют токены и iOS-визуальную иерархию.

Официальные HarmonyOS `harmonyos_docs` подтверждают V2 `@Local/@Param` и ограничения `@BuilderParam`; при реализации каждого ArkUI-среза запрашивать конкретный API заново. iOS source (`C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Sources\ChatController.swift`, `ChatControllerNode.swift`) используется для иерархии/состояний; текущий shipped iOS runtime остаётся визуальным арбитром. Структура референса не является разрешением копировать код.

## Карта файлов и порядок извлечения

Названия ниже — целевая ownership-карта, а не повод заранее создать пустые файлы. Каждый пункт закрывается отдельно и уменьшает исходную страницу; если существующий контроллер уже владеет поведением, расширять его только в пределах бюджета и без нового цикла импортов.

Шаги 1 и 2 независимы: первый фактически начат со sticker search после предыдущего обсуждения; top-bar mapper остаётся следующим низкорисковым срезом.

| Шаг | Целевой владелец / материал текущей страницы | Что остаётся в page | Обязательный focused witness |
|---|---|---|---|
| 0 | `scripts/check-chat-screen-split.cjs` — инвентарь реальных методов, imports, 37 page-dependent tests и LOC для целевых файлов; без автоматического fail на промежуточном состоянии | Исходный dirty diff и hash сохраняются | Снимок 5930 строк, baseline tests/build, diff-check; «отключённый вызов нового модуля» должен сделать integration check красным |
| 1 | `ChatTopBarPresentation.ets`: чистые initials/status/typing/connection formatters из ~1955–2046 и вычислительная часть ~2128–2229 | Выбор AppStore snapshot, chat-access observation, member hydration и присваивание `@Local` | Таблица missing/bot/online/offline/group/channel/typing-expired/connection; сравнение с прежними результатами |
| 2 | `ChatStickerSearchController.ets`: regular sticker debounce, request identity и последовательная загрузка preview из ~4008–4090 | `@Local` items/loading, panel visibility и typed wiring | Реальный controller path, A→B→A, close/reopen, stale response/preview; null twin убирает generation guard |
| 3 | `ChatEmojiPanelController.ets` и `ChatGifPanelController.ets`: search/load/cache/cursor из ~3612–3876 и ~4144–4448, **разные** владельцы, не один `PanelGodController` | Выбор режима панели, draft/entities/selection и отправка | Debounce, language/cursor, next page, stale pack/tab/account; null twin отключает request/cursor guard |
| 4 | `ChatPinnedMessagesController.ets`: загрузка/pagination/dedupe из ~1526–1719 | Visibility, overlay placement, Back и jump | Current-chat request identity, fallback, load-more dedupe; late old-chat result inert |
| 5 | `ChatBotMenuController.ets` и `TgChatMessageActionsPopup.ets`: bot-menu data из ~2241–2336 и только popup content из ~3378–3511 | Bind anchor, context/generation, action dispatch, route ownership | Stale dismiss не закрывает новое меню; action target и bot URL scoped; UI tree проверяется на устройстве |
| 6 | `ChatMediaOpenController.ets`/`ChatGalleryCoordinator.ets`: tap→download/open и gallery item reconciliation из ~2828–3248; переиспользовать существующие `ChatMediaDownloadController` и `MediaGalleryState` | Page handle global playback, `@Local` overlay state, transition placement | Tap→download→rebuild→open; не открывать stale file; gallery index/identity после refresh; mutation no-op refresh даёт red |
| 7 | `ChatHistoryCoordinator.ets` и `ChatTimelineUpdatePolicy.ets`: history retry/window, pagination decision, reply hydration plan, чистые части ~2337–2827 и ~4825–5080 | Единственный store subscription, `Scroller`/`DataSource` lifetime, упорядоченный `rebuildTimeline`, mark-read eligibility и вызовы scroll/jump | Fake-timer edge-loop, retry generation, unread initial snapshot, anchor preservation, pending media/reply order; проверка старого harness на реальном production path |
| 8 | `ChatDraftController.ets`: сериализация/восстановление/debounce из ~4538–4651; при необходимости отдельно вынести чистые shared-media-link helpers из ~955–1064 | Captured owning account, edit/forward arbitration, page closing order | Account A→B, edit text не становится draft, custom emoji offsets, late timer inert; mutant убирает store/operation guard |
| 9 | `TgChatTimelineViewport.ets`, `TgChatComposerDock.ets`, `TgChatScreenOverlays.ets` (`@ComponentV2`) — разметка `buildMessageItem`/timeline, composer panels, gallery/pinned/search из ~5080–5923. Не переносить бизнес-логику в UI-компоненты | Корневой `NavDestination`, layer order, safe area, height/focus/scroll coordination, onReady/onShown/onBackPressed | Main+ohosTest compile, actual `@Param/@Event` wiring, no-op event mutant; light/dark, IME, scroll, overlays и visual parity на свежем HAP |
| 10 | Финальная стяжка `TgChatScreenPage.ets`: удалить мёртвые imports/fields/methods, сохранив одного координатора | Route/account/lifecycle и cross-feature arbitration | LOC budget, все focused + host + PS + smoke + обе сборки + runtime matrix ниже |

Не расширять произвольно `ChatComposerController.ets` (сейчас 597 строк), `ChatMessageActionsController.ets` (670), `GlobalMediaPlayback.ets` (712) или `ChatTimelineVO.ets` (1409): они уже выше бюджета новых файлов и не должны стать местом свалки. Их отдельная переработка — только если конкретный срез действительно зависит от неё.

## Цикл выполнения каждого шага

- [ ] До правки: зафиксировать exact working-tree diff затронутых файлов; прочитать соответствующие `STATUS.md`, `TASKS/TODO.md`, `DECISIONS.md`, `ARCHITECTURE.md`, `REFERENCES.md`, iOS-файл и HarmonyOS docs; для TDLib-пути сверить `td_api.tl`.
- [ ] Написать behavioral RED на старом/отсоединённом production path или исполняемый null twin. Source-text совпадение само по себе не доказывает вызов. Записать ожидаемые вход/выход и failure output.
- [ ] Перенести **один** ownership-срез; типизированный host/API, никаких plain-record TDLib cast, `any`, новых global singletons или безымянных чисел в UI.
- [ ] Перепривязать относящиеся к срезу source-driven tests к новому владельцу, оставить page→owner integration; убедиться, что подмена owner на no-op ломает хотя бы один тест.
- [ ] Проверить focused test, затем `node scripts/run-host-tests.cjs`, относящиеся `.ps1`/UI smoke, `entry@default` и `entry@ohosTest` **последовательно**, `git -c core.whitespace=cr-at-eol diff --check`; перечитать изменённый код.
- [ ] Перед следующим шагом независимый reviewer проверяет state/lifecycle/route ownership и фактический diff. Красный тест сначала диагностировать, а не удалять. Обновить `STATUS.md`, `TASKS/TODO.md`, `TASKS/LESSONS.md` компактно после принятого среза.

## Агентная координация

- Один **integrator** в каждый момент редактирует `TgChatScreenPage.ets`. Остальные агенты параллельно готовят только **непересекающиеся** production-файлы, focused tests либо read-only review; page integration выполняется последовательно. Запрещены два одновременных writer'а страницы и общий массовый regex move.
- Для каждого шага: implementer → свежий reviewer по спецификации/качеству → владелец задачи лично проверяет findings и повторяет witness. Для высокорисковых шагов 6–10 нужен отдельный Astra Ultra reviewer, если доступен; лимит модели не заменяется молча утверждением «агенты проверили».
- Агент может предлагать дополнительный срез, но не менять контракт route/account, TDLib, визуал или линию acceptance без отдельного решения. Никаких commit/push и установки приложения без разрешения пользователя.
- 2026-09-29 запущены три Astra Ultra read-only аудитора: два завершили аудит архитектуры/тестов, архитектор LOC-карты завершился по лимиту; worker первого sticker-среза тоже прерван лимитом. Его частичный RED-тест надо либо довести до принятого среза, либо убрать из autodiscovery, не оставлять сломанную host suite.

## Финальная приёмка и граница честного статуса

1. `TgChatScreenPage.ets` ≤700 физических строк; каждый **новый** `.ets` ≤500; нет дублированного state/source, циклов imports и God-host интерфейса. Число строк — измерение, не доказательство корректности.
2. Все найденные прямые и косвенные зависимости от страницы пересмотрены по назначению; behavioral path нового владельца вызывается, null twins дают red; host/PS/UI smoke и serial обе сборки зелёные **после последней правки**. `ohosTest` compile ≠ запуск тестов.
3. На свежем HAP проверить аккаунт/маршрут/back/reopen, история и оба направления pagination, search+flash, reply/edit/forward/draft, sticker/emoji/GIF, download→gallery/playback, pinned/menu, keyboard/IME/safe-area, light/dark. Сравнить со свежим iOS визуальным witness там, где менялась разметка. Зафиксировать процесс/HAP и экран/логи; не доверять одной строке `hdc install`.
4. Обновление HAP поверх сохранённой emulator-сессии может стереть данные и потребовать повторного входа; до разрешения пользователя этот runtime gate открыт. При отсутствии подписи/target — записать точный blocker и **не** называть разбиение безрегрессионно принятым.

## Прогресс 2026-09-29

- Срез regular sticker search выполнен первым: новый `ChatStickerSearchController.ets` (132 строки); `TgChatScreenPage.ets` 5930 → 5876 строк. Typed host передаётся как `this`, `@Local` items/loading остаются у страницы. Focused 37/37, request-id mutant 36/37 и page-wiring mutant 0/1; общий host 61/61, 19 page-зависимых `.ps1`, обе сборки и diff-check PASS. Новый HAP не устанавливался.
- Срез top-bar presentation: новый `ChatTopBarPresentation.ets` (178 строк) забрал чистые initials/status/typing/connection и subtitle/avatar mapping; page 5876 → 5730 строк. Выбор snapshot, chat-access observation, member hydration и публикация `@Local` остались в page. Behavioral baseline на старом и новом page — 51/51; connection, spinner-latch, skipped-observe и repeated-hydration mutants красные. Оба UI smoke, 19 page-зависимых `.ps1`, общий host 62/62 и последовательные main/ohosTest сборки PASS. Source-text localization checks перенаправлены к владельцу; отдельные checks закрепляют page→helper wiring и восемь `@Local`→`TgChatTopBar` props. Astra Ultra review не нашло production-расхождения, выявленные им три пробела тестов закрыты. Новый HAP не установлен; device acceptance открыта.
- Следующие строки таблицы остаются открытыми. Лимит Astra Ultra помешал завершить одного архитектора и worker; частичный RED-тест worker доведён локально, но это не заменяет независимое ревью после новых изменений.



## Полное выполнение 2026-10-01

Пользователь разрешил закончить всю декомпозицию, не останавливаясь на промежуточных срезах. Актуальная ownership-карта, staging-владение агентов и критерии завершения: [CHAT_SCREEN_DECOMPOSITION_2026-10-01.md](CHAT_SCREEN_DECOMPOSITION_2026-10-01.md). Исходный снимок этой реализации — текущие 5730 строк; прежний dirty patch сохраняется. Page остаётся владельцем одной session и наблюдаемых state slices; реализация route/lifecycle делегируется этой единственной session с сохранением прежнего lifetime и guard order.
