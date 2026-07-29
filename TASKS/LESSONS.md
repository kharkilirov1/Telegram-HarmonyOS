# LESSONS — repeated mistakes and project-specific pitfalls

Last updated: 2026-07-22

## 118. height('100%') в auto-sized контейнере — грабля, пойманная ТРИЖДЫ
- Процентная высота внутри контейнера без собственной высоты (Stack/Row по контенту) резолвится против РОДИТЕЛЬСКОГО CONSTRAINT: в списке это вьюпорт (рельса на весь экран, бабл-гигант с карточкой в центре пустоты — пользовательский репро), при unconstrained — 0 (рельса тихо исчезает). Отсюда «некоторые корректны, некоторые нет».
- Хронология одной и той же грабли: quote bar (TgTextBodyV3) → reply snippet (TgReplySnippet) → link preview rail (TgLinkPreviewBubble). Правило: вертикальные рельсы/акцентные полосы в атомах — ТОЛЬКО `LayoutPolicy.matchParent`; при добавлении атома с полосой грепать `height('100%')`.
- Побочный витнесс тяжести бага: appfreeze нашего приложения в faultlog совпал по времени с прокруткой гигантского бабла (лейаут на всю высоту вьюпорта в reuse-строке).
- Эмулятор-инсталлы при тесном диске: HAP с двумя ABI (по две копии libtdjson ~35MB) — половина мёртвая; abiFilters x86_64-only даёт 83M вместо 152M и проходит порог. Вернуть arm64 перед сборкой на устройство.

## 117. Системные медиа-команды и диск эмулятора: два коротких урока
- Системные play/pause обязаны быть СТРОГИМИ и идемпотентными, не toggle: иконка карточки Пункта управления живёт своей жизнью и при рассинхроне toggle инвертирует состояние вместо схождения. Рецепт: pause → метод контроллера с guard'ом «только из playing»; play → гейт по isPlaying + toggle (из паузы toggle строго играет). Витнесс цикла: `cmd pause→JsPause Task`, `cmd play→JsPlay Task`, итоговый state playing.
- Диск эмулятора, уровень 2: порог install ≈1ГБ свободного; когда `bm clean -c` не спасает — `bm uninstall -n <bundle> -k` (keep-data) + install: код пересоздаётся, data/el2 с TDLib-сессией остаётся (проверено — чат-лист без перелогина). Медиа-кэш TDLib (animations 300M+, photos 200M+) и /data/log недоступны на запись из hdc shell (undebuggable сборка, smode запрещён) — чистить их можно только изнутри приложения (optimizeStorage — кандидат в настройки).

## 116. Обложки треков: пользовательская гипотеза ≠ механизм, референс решает
- Гипотеза «iOS берёт обложку из фото канала» разбилась о референс: Telegram-iOS качает арт СЕРВИСОМ по title+performer (MusicAlbumArtResources → AlbumCoverResource → webDocuments DC). В TDLib это готовое поле `audio.external_album_covers` — каскад ID3→external закрыл кейс без всякой эвристики по фото.
- Когда поля нет в наших моделях и td_api.tl недоступен (вендорен только .so) — `strings libtdjson.so | grep <field>` мгновенно подтверждает поддержку полем этой сборки TDLib.
- Диск эмулятора (код 9568288 insufficient disk memory при install): `bm clean -n <bundle> -c` (кэш, НЕ -d — там сессия) + `rm /data/local/tmp/*.json|png` (мои дампы/скрины копятся десятками MB) — освобождает сотни MB без потери логина.

## 115. AVSession/bindSheet/фон: заметки v2+v3
- AVSession подключается к уже готовому глобальному плееру одним листенером: мета-словарь на смене assetId + троттленный playback-state (флипы + ≥3с позиции) — сессия «бесплатно» даёт карточку Пункта управления, локскрин и команды с наушников. Контекст берётся в aboutToAppear корневой страницы (`getUIContext().getHostContext() as common.UIAbilityContext`), не в EntryAbility.
- Витнесс «команда из системы дошла» — hilog в session.on-колбэке, а «пауза исполнена» — родные `JsPause Task Start/Out/End` логи AVPlayerNapi: `JsGetState`-строки живут только пока тикает прогресс-таймер, после паузы их просто нет (отсутствие ≠ не сработало).
- Промежуточная модель обязательна: DTO-поле без дублирования в MessageContent (AppState) и ОБОИХ редьюсерах (messagesReducer + filesReducer clone-путь) — компайл-ошибка в VO-маппере. Поля медиа-контента живут в ЧЕТЫРЁХ местах.
- Слепой «already»-чек в патч-скриптах (grep по второй строке replacement) молча пропускает файлы — после массовых python-патчей перепроверять каждый файл грепом цели.
- bindSheet(560vp, showClose) — самый дешёвый нативный «полноценный плеер»: drag-bar, жест закрытия и скругления бесплатно; onDisappear синхронизирует @Local-флаг при жестовом закрытии.

## 114. Island Player v1: три ловушки одного среза
- TDLib file id — ТОЛЬКО `getTopLevelNumber('id')`: generic вложенный `getNumber('id')` первым находит `remote.id` (строка) и молча возвращает 0 → «no newer track» при живом кандидате. Грабля уже была описана комментарием в parseSharedMediaItem — читай соседний рабочий парсер ДО написания своего.
- Открытие чата — ритуал ChatListPage (активный чат в navigationUIState+chatUIState+AppStorage, unread-снапшот, navLock, requestOpenChatData). Голый `pushPathByName('TgChatScreenPage')` из другой страницы рендерит сплит-плейсхолдер «Чат не выбран». Внешним инициаторам — tick-мост параметром в живой ChatListPage.
- Хронологию сообщений мерить ТОЛЬКО по message id (int64, длина+лексика), не по видимым таймстампам: «изменено 20:05» — время правки, а не поста; из-за этого два «провала» ⏭ были на самом деле корректным концом плейлиста. Диагноз дал полный дамп ста id из инструментированного цикла.
- searchChatMessages с ненулевым from_message_id + отрицательным offset + фильтром вернул пусто на живом TDLib; надёжный паттерн — from='0' (newest-first) и выбор соседа в коде.

## 113. HdsTabs miniBar: prop-состояние не должно опережать style-транзакцию (линза под плеером)
- Механика HDS miniBar двухканальная: prop `miniBarStyle`/`barWidth` рендерят состояние БЕЗ ширинной транзакции, а `applyMiniBarStyle()` анимирует оба бара только при ДЕЛЬТЕ внутреннего стиля. Если prop уже EXPAND (отрендерен пока бар скрыт) — поздний apply = no-op без колбэков; бар выходит рассинхронённым (mini широкий, таб полный, внахлёст).
- Три слоя фикса, каждый подтверждён инструментацией (`onBarStyleChange`/`onMiniBarAnimationStart`/`onTabBarAnimationStart` + hilog): (1) защёлка applied — prop COLLAPSE до транзакции на видимом баре, флаг+apply в одном кадре (паттерн активации Search); (2) транзакция из монитора, сработавшего внутри animateTo (rootBarHidden flip), вкладывается в чужую анимацию и ломает раскладку — признак: mode=NORMAL вместо APP_TRIGGER; отложить до конца show-анимации; (3) ручной `barWidth=48` prop давит РАЗВЁРНУТЫЙ таб-бар в 48px «вертикальными колонками букв» — 48vp-линза одного таба создаётся только транзакцией, prop держать полной шириной.
- Диагностический приём: bounds-дамп текстовых нод таб-бара мгновенно отличает «настоящую линзу» (один таб) от «раздавленных табов» (все лейблы узкими вертикальными колонками x≈143-178).
- `hilog -b D -D 0x0020` включает debug-уровень домена на живом устройстве — debug-инструментация компонентных границ бесплатна в проде и бесценна в дебаге.

## 112. Глобализация плейбека и HDS-транзакции стиля: три ловушки одного среза
- Зеркало состояния и «нулевые» эмиты: `openAndStart()` начинается с `release()`, который эмитит снапшот `messageId='0'` — листенер-зеркало честно чистило мету, затирая только что опубликованный тайтл нового трека. Мета обязана жить у владельца (wrapper) и повторно применяться на КАЖДОМ ненулевом снапшоте, а не записываться однажды в UI-стейт.
- `HdsTabsController.applyMiniBarStyle()` на скрытом (или только что пере-показанном) баре игнорируется без ошибки: prop `miniBarStyle` рендерит контент, но таб-бар не сжимается в линзу — плеер рисуется поверх табов. Один отложенный re-assert 360мс (паттерн search-фокуса) НЕ решает; открытый пункт — хендшейк через onTabBarAnimationStart/onBarStyleChange.
- Скролл-охота по прыгающему чат-листу — худший способ добраться до сообщения: живые обновления телепортируют строки между дампом и кликом. Надёжные пути: фильтры (Личные), профиль → Shared Media (Voice/Files/Links — стабильный список), guard «клик в той же итерации, что и дамп».
- Эмулятор способен уронить ХОСТ: temp-файл qemu раздулся до ~66ГБ → C: 0 байт → сборки падают на `MergeProfile` с кодом `00308018` («Unknown Error», на деле нет места), затем гибнет сам эмулятор (temp освобождается его крашем). Перед длинной сессией — `df -h /c`; `entry/build` с вендоренным нативом весит гигабайты и удаляется безопасно.

## 110. hdc install печатает «AppMod finish» и при ПРОВАЛЕ установки
- Repro: диск эмулятора заполнился (HAP вырос до 158MB из-за вендоренного нативного слоя) → `install failed due to insufficient disk memory. code:9568288`, но следом всё равно печатается `AppMod finish`. Усечённый `| tail -1` показывал только его — цепочка build→install→force-stop→start выглядела зелёной, а рантайм крутил СТАРЫЙ код: новые логи не появлялись, хотя строка была в собранном `modules.abc`.
- Диагностическая лестница, которая сработала: лог отсутствует → grep строки в built HAP/abc (строка есть) → значит стейл-рантайм → полный вывод install → ошибка места.
- Правила: (1) успех установки = grep «install bundle successfully», не «AppMod finish»; (2) при «фикс не проявился» первым делом сверять, что артефакт ДОЕХАЛ (строка-маркер в abc + успешный install), лишь потом дебажить код; (3) держать `/data/local/tmp` чистым — витнесс-артефакты прошлых сессий съели место.

## 111. Скролл-колбэки List получают и не-жестовые кадры
- `onScrollFrameBegin` стреляет и на layout/data-шторм кадрах при холодной синхронизации (прилетают с положительным offset) — авто-скрытие острова срабатывало без единого касания. Фильтр: реагировать только на `ScrollState.Scroll | Fling`.
- Паттерн «адаптивный бар»: дочерняя страница шлёт latch-free события по гистерезису (24vp аккумулированного направления), хост дедуплицирует против своего состояния и владеет guards/сбросами (поиск, сплит, вход в чат, смена таба). Латч на стороне отправителя рассинхронизируется с принудительными показами хоста.
- Анимируемость: свод всех входов в один `@Local`, меняемый внутри `animateTo` (`@Local`-ссылка на `@ObservedV2`-синглтон + `@Monitor('field.path')` — документированный паттерн) — дал анимированный hide/show нативного `HdsTabs` без кастомного рендера бара.

## 109. Git Bash молча конвертирует абсолютные аргументы hdc в C:/Program Files/Git/…
- Repro: `aa test … -s unittest /ets/testrunner/OpenHarmonyTestRunner` из Git Bash умирал с `Cannot find module '…entry_testC:/Program Files/Git/ets/testrunner/…'` («App died»), а `hdc file recv /data/local/tmp/x.png` падал с «no such file or directory, path:C:/Program Files/Git/data/…» — MSYS переписывает всё, что похоже на POSIX-путь.
- Fix: префикс `MSYS_NO_PATHCONV=1` для ЛЮБОЙ hdc-команды с remote-путями (`shell aa test`, `shell uitest dumpLayout -p`, `file recv/send`). Рецепт on-device раннера из урока 67 работает из Git Bash только с этим флагом.
- Также: перед инструментальным `aa test` нужен `aa force-stop` — живой процесс приложения даёт тот же «App died» без jscrash-подсказки.

## 108. Рендер-атом и measurement-движок дублируют геометрию — дрейф не ловится компилятором
- В паре TgReplySnippet/TgBubbleLayout полоса бара жёстко считала «1 тайтл + 2 превью», пока maxLines разрешали 2+3; ширина сниппета повторно умножалась на bubble-ratio поверх уже ужатой движком ширины (на regular-ширинах — до 0.42×). Оба дефекта невидимы для сборки и smoke.
- Правило: у каждого числа в атоме (высота, inset, ratio) должен быть ровно один владелец. Полосы/фоны, обязанные совпадать с контентом переменной высоты, — только `LayoutPolicy.matchParent` (паттерн quote-бара, урок про height('100%') остаётся в силе); ширины, уже посчитанные движком, передавать с `maxWidthRatio: 1.0`, а не давать атому «улучшать» их дефолтным ratio.
- При любом изменении атома сверять его констант-лист с соответствующим measure* в TgBubbleLayout; расхождение — дефект, даже если «на глаз похоже».

## 107. Компайл-гейт ohosTest маскирует красноту до первого настоящего прогона
- Первый полный on-device прогон после серии срезов 18–19 июля: 580 тестов и ДВЕ незадокументированные красноты (gallery-refresh читал `sourceMessageId` без фолбэка) поверх двух известных. Все срезы при этом были «зелёными» по OhosTestCompileArkTS.
- Правило из урока 67 усилено: после каждого пласта, трогающего core/domain/VO, гонять сьют на устройстве, а не только компилировать; «known failures» фиксировать поимённо в STATUS, чтобы новый фейл был отличим от фонового.
- Литералы UI-строк в гвардах — мина: `refreshRestoredReplySnippet` сравнивал с literal `'Message'`, тогда как источник ставит локализованное значение — ветка мертва во всех локалях, кроме английской. Гвард и источник обязаны брать одну и ту же локализованную константу.

## 106. A grouped-media row has two identities: the album container and the tapped member
- Telegram collapses several TDLib messages into one visual row, but selection, refresh and spatial transition belong to the exact member. Give every cell a stable real-or-synthetic member identity, attach `geometryTransition` to that cell, and hide only the active cell; binding the primary row id to the whole mosaic creates a smooth but spatially false morph.
- A non-empty album path can be only a thumbnail fallback. Carry `fileId`, `hasLocal`, `downloading`, `progress` and controller-derived failure as index-aligned arrays through Page → Router → live media shell → atom; do not infer transfer completion from `photoPaths[index]`.
- Count-only 2/3/4 grids cannot be polished into iOS parity. Keep mosaic calculation pure, dimension-driven and unit-tested for 2–10, then render deterministic frames with per-cell hit targets. Include album path/local/progress in the recycled-row fingerprint or thumbnail→full replacement can remain visually frozen.
- Runtime acceptance must prove that non-adjacent taps belong to the same hierarchy parent, not merely to visually adjacent mosaics. One verified six-member row produced `42 / 51`, `45 / 51`, `47 / 51` for indices `0`, `3`, `5`; the earlier `45 / 51`, `48 / 51`, `50 / 51` sequence crossed two three-cell rows and therefore could not prove same-row routing.

## 105. A Compose screen must select peers, not merely relabel a dialog picker
- Telegram iOS `ComposeControllerNode` uses contacts plus Group/Contact/Channel actions; showing `TgChatRow` previews under a `New Message` title was a plausible but behaviorally wrong reuse. Keep Forward and Compose as separate surfaces once their data semantics diverge.
- `createPrivateChat` is the source of truth for a known user: validate the returned `Chat` type and exact `peerUserId`, then carry its id through a typed pop result. The reducer update may arrive after the response, so navigation can use that exact returned id/name without inventing an id or choosing another stored dialog.
- On current API23, a typed zero-result pop is also a lifecycle contract: bare Back can remove a destination visually without releasing the caller's duplicate guard. Acceptance must include Back → reopen and distinct destination ids, not only the first successful open.
- Preserve honesty while building parity incrementally: defer Group/Contact/Channel rows until their route and TDLib use case exist, and label source-derived geometry as unverified pixel parity until a current shipped-iPhone Compose capture is available.

## 104. A shared transition ID is not enough to prove a shared-element animation
- ArkUI `geometryTransition` needs the same identity on exactly two in/out nodes, a parent `animateTo` transaction, and a `transition` on disappearing content so it is not destroyed before the morph completes. The project already had the ID and spring, but omitted endpoint retention; final screenshots alone could not expose that gap.
- Bind the media node, not the whole captioned bubble. This keeps sender/reply/caption chrome out of the expanding geometry and gives a natural opacity fallback when the original lazy-list row is no longer rendered.
- Verify motion with an intermediate frame, not only before/after screenshots. The API23 sequence caught the video between bubble and fullscreen sizes, then showed close returning to one source node; that is evidence the geometry path engaged rather than a plausible instant screen swap.

## 103. Remote visual-media open and download are parallel concerns
- A tap on remote visual media must not serialize navigation behind transfer completion. Open the existing gallery immediately and start exactly one idle download; if the transfer is already active, open without issuing a duplicate request. Keep cancel ownership on the transfer control rather than overloading the media-surface tap.
- Full local media, local thumbnail, and TDLib `minithumb` are three different states. Only the full path enables playback; the local thumbnail is the preferred preview, while a blurred minithumbnail is the final continuity fallback for the fullscreen pending state.
- A download log alone does not prove the user-visible path. The acceptance witness must show the gallery and active transfer simultaneously. Here item `8 / 10`, `LoadingProgress [598,1384][710,1496]`, and `ChatMediaDownload fileId=12085` were captured during the same remote-video interaction; the clean package then reopened the resolved video at the same index.

## 102. Peer role must gate ChatList presence before the avatar atom
- Raw `userStatusOnline` is not sufficient UI truth for every peer role. The live bot `zai` reached `ChatItemVO` as online, which produced a plausible but incorrect ordinary-user green dot; the shipped iOS row and the chat-title role both identify it as a bot.
- Keep this adaptation in the view-object projection (`online && !isBot`), not inside reusable `TgAvatar`: the atom should render the boolean it receives, while peer semantics stay with the mapper.
- Verify a semantic removal with stable geometry. Here the dot node `#FF4DCC5E [189,1060][238,1109]` disappeared while avatar `[35,906][245,1116]` and title `[273,945][344,1008]` remained unchanged; a focused test protects the positive ordinary-online branch.

## 101. Date header capsule height and date-header row height are different contracts
- Telegram iOS uses a `22pt` date pill inside a `34pt` list header. Reusing the header height as the pill minimum made Harmony render a `34vp` capsule inside a `46vp` row; the plausible token silently doubled the vertical air.
- Keep date and service-event geometry independent even when they share one atom. The compact date variant can be `22vp / radius 11`, while multi-line service events retain their roomier minimum and padding.
- Date text must follow the app language, not blindly the system locale. `Intl.DateTimeFormat(undefined, ...)` produced English `July 10` inside a Russian Telegram UI on the emulator; Telegram iOS uses presentation strings. App-qualified full month resources and localized order templates produced `10 июля / 11 июля / 14 июля` and preserve English/Chinese ordering separately.
- The reliable witness is a same-chat dump: pill `119px -> 77px`, enclosing item `161px -> 119px`, plus the live label delta. A correct-looking intermediate using the wrong locale gets no completion credit.

## 100. Chat-list density must come from the source formula, not screenshot guessing
- Current Telegram iOS derives the normal base-font row to 72pt and centers its capped 60pt avatar with 6pt vertical insets. The previous 76vp token looked plausible but produced a visibly looser list and only 8vp avatar insets.
- A one-token density change is safe only when Chat and Archive rows share that token and the runtime dump proves both row height and child bounds. Here API23 changed `266px -> 252px` while the avatar remained `210px`, giving the exact 21px/6vp inset.
- Keep horizontal meta/title work independent from vertical density: shrinking the row must not reintroduce the old shared right-meta reserve or alter native HDS chrome.

## 99. Chat-list title and preview do not share one right-side budget
- Telegram iOS measures the title against `date/status` (`titleRectWidth`) and the preview against `badge/mention/pin` (`textMaxWidth`) independently. A single fixed meta column is stable but visibly over-truncates both lines.
- In ArkUI, keep the native intrinsic width of two trailing Row atoms and give the corresponding title/preview body `layoutWeight(1)`. Preserve fixed line heights, not a worst-case horizontal placeholder, in the live row.
- The composed fixed-width `TgChatMeta` can remain for standalone jump probes or older integrations; do not force that conservative demo geometry back into `TgChatRow`.

## 98. TDLib active stories arrive as updates, not as the load response
- `loadActiveStories(storyListMain)` returns only `Ok`; the usable peers arrive through `updateChatActiveStories`. Store the complete typed snapshot and treat `order=0`, a non-main list or an empty story vector as removal.
- Preserve TDLib ordering exactly as `(order, story_poster_chat_id)` descending. Story ids within one peer are chronological, so the last id is the latest and unread is `latest > max_read_story_id`.
- Story poster chat ids can be negative groups/channels; only `0` is invalid. Hydrate missing posters with `getChat`, reuse the existing chat/avatar identity path, never synthesize title avatars, and keep the strip non-interactive until a real viewer route exists.
- `loadActiveStories` returns 404 when exhausted. An empty preview strip is a valid account state, not a reason to render samples.

## 97. Полный emoji-каталог нельзя держать в eager `ForEach`
- Telegram iOS задаёт hierarchy/search/entity behavior, но canonical neutral Unicode palette безопаснее генерировать clean-room из Unicode `emoji-test.txt` в CLDR order, а не копировать GPL-массивы Android/Nekogram. Для Unicode 17.0 после исключения skin-tone modifier rows остаётся 1914 fully-qualified base sequences в девяти keyboard groups.
- `Grid` + обычный `ForEach` создаёт сотни offscreen `Text` cells при открытии People/Flags. Для такого каталога нужен `IDataSource` + `LazyForEach`; category switch делает `onDataReloaded`, а recents остаются отдельным parent-owned набором.
- Source count сам по себе не доказывает engagement. Runtime witness должен выбрать отсутствовавшие раньше People/Flags, увидеть localized section title и проскроллить до изменившегося набора lazy cells; иначе UI мог остаться на старом Recent fallback.

## 96. Safe-area snapshot после adaptive rotation нельзя считать устойчивой геометрией
- При `NavigationMode.Auto` portrait `TYPE_SYSTEM.topRect` после split → stack может кратко вернуться как `0`, хотя runtime bounds по-прежнему начинаются после 137px status area. `Area.globalPosition` и `Area.height` здесь тоже не спасают: `onAreaChange` отдаёт original expanded geometry (`822.857vp`), а UI dump показывает уже clipped bounds.
- Для custom ChatList chrome сохраняй последний реальный portrait top inset вне пересоздаваемого component instance, используй свежие `windowSizeChange.width/height` для различения portrait/landscape и принимай положительный platform inset в любой ориентации. Landscape с нулём остаётся нулём; portrait с transient zero восстанавливает cached inset.
- Динамический `List.contentStartOffset` сам двигает top chrome, но не гарантирует re-alignment первого item после возврата. Если список действительно стоит на start (`headerCollapseOffset == 0`), после изменения inset на следующем layout tick вызови `scrollToIndex(0, false, START)`; scrolled list не сбрасывай. Acceptance — exact initial/round-trip bounds, а не только отсутствие status-bar overlap.

## 95. Link preview нужно вести как сквозной media-aware content path
- Текущий локальный `td_api.tl` определяет `messageText.link_preview`; старый `web_page` в typed-model слое не является актуальным runtime-контрактом. Перед UI-работой проверяй `td_api.tl`, а legacy field оставляй только явным fallback.
- Для preview poster недостаточно DTO/VO: thumbnail id должен попасть в bounded background-download, `filesReducer` обязан сохранить preview identity при clone, а `ChatTimelineDataSource` и media render stamp — инвалидировать recycled row после появления пути.
- В engine-driven text bubble preview задаёт минимальную ширину и отдельную meta-строку; иначе время/status может наложиться на нижнюю часть карточки. ArkUI helper внутри `@ComponentV2` не называй `backgroundColor` и другими common-attribute именами — это конфликтует с `CustomComponent` API уже на CompileArkTS.

## 94. `NavDestination` bounds do not prove that custom transparent chrome is below the status bar
- The old opaque `TgTopBar` measured `TYPE_SYSTEM` internally, so its runtime dump began below the 137px status area. Replacing it with transparent independent capsules and assuming `topInset = 0` moved Back/title directly under the clock even though the route and `NavDestination` were unchanged.
- Production custom/material chrome must measure the current window `getWindowAvoidArea(TYPE_SYSTEM)` itself (or receive the same single-source inset from the page). Keep an explicit `topInset: 0` only for isolated previews.
- Preserve the combined vertical contract while changing surfaces: after adding the measured inset, Forward Search stayed at 36vp, the List returned to the exact baseline `y=479`, and 76vp chat rows remained 266px. Runtime geometry, not a successful build, is the safe-area witness.

## 93. Custom-emoji entities live in UTF-16 text coordinates, not in panel state
- TDLib and Telegram iOS describe entity offsets/lengths in UTF-16 code units; ArkTS strings already expose compatible indexing, so reconciliation must preserve/shift spans around an edit and drop only spans intersected by it. Clearing every custom-emoji id on any `TextArea` change silently destroys valid draft semantics.
- Selection is part of the composer contract: use `TextArea.onTextSelectionChange` for the active range and `TextAreaController.caretPosition` after panel insertions or keyboard handoff. The entity array must travel through draft parsing, normalizer, reducer and deep clone alongside the text.
- Plain `TextArea` can preserve and send the exact custom-emoji id while rendering fallback Unicode. Animated inline media is a different rendering concern and should be a separately gated `RichEditor` migration, not mixed into entity correctness.

## 92. Source points are a hierarchy baseline, not a blind cross-device scale
- Telegram iOS source correctly defines 44pt actions and a 54pt Search collapse path, but copying every point 1:1 into a 1308×2880 Harmony runtime produced visually oversized chat-list chrome. The shipped screenshot plus actual emulator density is the acceptance witness.
- Preserve behavior and hierarchy constants that matter (independent islands, centered title, exact 54vp collapse, pinned filter). For cross-screen consistency, reuse the accepted in-chat control tokens directly (`38vp` visual + `44vp` response) instead of copying their values; derive subordinate rails proportionally (`32vp`) without touching list rows or the native HDS tab bar.
- Shipped dark Telegram iOS uses a semantic navy hierarchy, not the generic global `#1C1C1E / #2C2C2E` pair. Scope the palette to ChatList and inject row surfaces into reusable atoms; do not recolor unrelated screens. If an overlay background covers a collapsing child, shrink that background by the same collapse delta or it becomes an empty opaque plate over content.
- Direct `Text` children in a `Column` can remain cross-axis centered; list title/preview columns that must share the normal text axis need explicit `HorizontalAlign.Start`. Dark glass action glyphs use navigation primary foreground, not Telegram accent blue.

## 91. `contentStartOffset` меняет scroll-witness: проверяй полный возврат, а не один короткий swipe
- У chat-list верхний Search живёт в `List.contentStartOffset`: после collapse первый видимый Archive ещё не доказывает, что список вернулся в исходную expanded-позицию. Короткий автоматизированный swipe может оставить ровно consumed Search band, поэтому filter rail остаётся pinned корректно.
- Надёжный witness — начать жест внутри реального List (не на overlay rail), довести до spring/start boundary и увидеть Search снова. Для collapse state накапливать per-frame offset и clamp к 54vp; `onReachStart` сбрасывает состояние только на истинной границе. Не объявлять баг по промежуточному кадру.
- Title avatars в актуальном Telegram iOS — Story subscriptions, не случайные account avatars. Пока Story runtime/model отсутствует, компонент может принимать real preview inputs, но production page должен показывать обычный title и не рисовать fake circles.

## 90. API availability guard должен быть literal и двойным: `apiAvailable` + `@Available`
- Для API26-only ArkUI API компилятор отклоняет `deviceInfo.apiAvailable(CONSTANT)`, даже если константа равна `'26.0.0'`: версия должна быть literal `deviceInfo.apiAvailable('26.0.0')`, иначе `11706013 Invalid parameters for apiAvailable`.
- Надёжный cross-version паттерн: вынести API26 вызовы в builders с `@Available({ minApiVersion: '26.0.0' })`, а каждый call site держать под literal guard. Это одновременно сохраняет API23 runtime fallback и убирает compatibility warnings; сравнение только `sdkApiVersion >= 26` недостаточно строго для availability checker.

## 89. Gitignore не разгружает IDE: тяжёлые reference repos держать вне workspace
- `рефенсы/` был исключён из Git и CPL scan, но nested repositories всё равно доступны IDE indexers, antivirus и неосторожным recursive tools; один Nekogram уже даёт 31K файлов / ~708 MB. Канон: external root `C:\Refs\Telegram`, pinned registry `REFERENCES.md`, без junction обратно в проект.
- Для актуальности UI source недостаточен сам по себе: latest installed Telegram iOS runtime screenshot/video — shipped visual truth; `Telegram-iOS-current` даёт hierarchy/states/constants и может отставать от App Store. Старый snapshot хранить отдельно для воспроизводимости, не перезаписывать.

## 88. Конкурентный client — behavioral reference, не donor code
- Перед clone/сравнением доказать canonical identity через официальный сайт/README, затем зафиксировать commit, license, platform и backend. ArkGram оказался закрытым HAP-derived artifact без public source/license; Nekogram — GPL-2.0 Android fork с direct MTProto/TGNet, а не TDLib.
- Переносимый результат — feature/state matrix, UX semantics и edge cases. Decompiled ArkGram code/assets копировать нельзя; Android/GPL Nekogram code нельзя подмешивать в ArkTS/TDLib без отдельного licensing decision. Реализация только clean-room поверх локального `td_api.tl`, текущих use-cases/controllers и ArkUI docs.

## 87. Отрицательные chat id — системная мина: гварды `<= 0`/`> 0` молча режут все группы и каналы
- Telegram: supergroup/channel id ОТРИЦАТЕЛЬНЫЕ (-100...). Три экземпляра одного бага в одном потоке (openProfile, loadProfile, onReady-параметр): функция «работает для лички, молча no-op для групп». Валидация только `!== 0`/`=== 0`.
- Грепать при подозрении: `chatId <= 0|chatId > 0` — исключение легитимно только там, где речь О ЮЗЕРАХ (userId положительные, напр. звонки).

## 86. TextArea(text:) — только отображение; программный префилл требует двустороннего биндинга
- Симптом: setDraftText рисовал текст в поле, но первый ввод начинал С ПУСТОГО внутреннего буфера (edit-префилл затирался клавишей). Прямой prop не заталкивает значение в нативный буфер компонента.
- Канон: @Local-зеркало парамет + @Monitor-синхронизация + `TextArea({ text: this.buffer!! })` (двусторонний `!!`, API 18; для V1 — `$$`). Дока TextAreaOptions прямо советует биндить состояние двусторонне.
- Инструментальное: `uinput -K -t` в СФОКУСИРОВАННЫЙ TextArea ненадёжен — то подставляет текст целиком (затирая буфер), то молча дропает; для witness клавиатурного ввода на эмуляторе доверять только реальным тапам по экранной клавиатуре или ручному прогону.

## 85. Скриптовая правка файла: не открывать целевой файл на запись до готовности контента
- python-heredoc с эмодзи в Windows-консоли упал на суррогатах ПОСЛЕ open(p,'w') — целевой файл обнулился (0 байт); git restore спас. Паттерн: собрать контент → проверить encode → писать во временный файл + os.replace; либо просто Edit-инструмент (UTF-8-безопасен).
- Тот же заход, вторые грабли: heredoc-текст с последовательностью «бэкслеш-U» в обычной python-строке ломает парсер (unicodeescape) — не-ASCII в heredoc-скриптах только через именованные переменные с chr()/кодами, а лучше вообще не через heredoc.

## 84. LazyForEach перестраивает строку ТОЛЬКО при смене key — notifyDataChange со стабильным ключом это no-op для V2-строк
- Симптом-цепочка (охота 3 тика): скачанный файл не оживлял бабл до перезахода. Трасса показала: transfers пишутся, rebuild идёт, diff находит строку, notifyDataChange уходит — а @Param в @ComponentV2-строке остаются создания (Monitor-проба молчит). Док-канон: «After message is changed, the KEY of the list item changes. As a result, LazyForEach REBUILDS the item» — ключ и есть механизм обновления.
- Фикс-паттерн: в key запекается render-штамп изменяемого визуального состояния (`msg_<id>_s<stamp>`: пути есть/нет, downloading-флаги, прогресс бакетами по 10%, заполненность альбома), а diff-структура (same-order/append/prepend/anchor) сравнивает stableKey БЕЗ штампа — иначе смена состояния выглядит как смена порядка и валится в reload.
- Смежные грабли той же охоты: (а) `.reuseId()` на ListItem — V1-механизм, с V2-строкой молча оставляет компонент со старыми @Param (для V2 есть @ReusableV2 + `.reuse()`, API 18+); (б) `applyFilePathToContent` клонирует MessageContent вручную и ТЕРЯЕТ uniqueId-поля (uid=0 после клона) — при ручных клонах сверяй список полей с классом.

## 83. Глобальный `hilog -b D` оживляет ВСЕ накопленные debug-логи — это тот же writev-шторм
- 6-й THREAD_BLOCK_6S (17:49): стек снова HiLogPrint→writev. «Безопасные» debug-логи (per-entry timeline на каждый rebuild, per-file normalizer) молчат лишь пока уровень INFO; глобальное включение D на живом синке = шторм = watchdog-килл.
- Правила: (1) per-entry/per-rebuild логов не существует ни на каком уровне — удалять после диагностики; (2) debug включать только точечным доменом `hilog -b D -D 0xD0000XX`; (3) одноразовая диагностика пользовательского клика — info-однострочник (1 тап = 1 строка), виден без смены уровня.
- Смежное: параметры @Param, влияющие на обработчики (fileId!), обязаны передаваться во ВСЕ вызовы компонента — молчаливый дефолт 0 превращает обработчик в no-op без единого лога (photoFileId/videoFileId в Router не передавались с самого создания медиа-веток).

## 82. file:// URI и POSIX-путь — разные валюты: zlib/fs требуют путь, Image/AVPlayer едят URI
- Симптом: `zlib.GZip.gzopen(file://com.telegram…/data/…)` → «No such file or access mode error», хотя Image по тому же значению рисует. Таймлайн-VO раздаёт `fileUri.getUriFromPath(path)` (URI с authority=bundle) — файловые API его не понимают.
- Конверсии: путь→URI `fileUri.getUriFromPath(p)`; URI→путь `new fileUri.FileUri(uri).path` (или срез authority после `file://`). Перед любым fs/zlib-вызовом значения из VO нормализовать в путь.
- Смежное (эмулятор-автоматика): свайп это `uinput -T -m x1 y1 x2 y2 speed` — `-M` (мышь) молча не скроллит список; и hdc-пути `/data/...` в Git Bash требуют `MSYS_NO_PATHCONV=1`, иначе превращаются в `C:/Program Files/Git/data/...`.
- Усиление урока 78: `aa force-stop` может отрапортовать «successfully», не убив процесс (STIME остался старым при живом ps). Проверка свежести бинаря = STIME против `hdc shell date`; при рассинхроне — повторный force-stop с паузой и контролем пустого ps до start.

## 1. Do not mix V1 and V2 ArkUI decorators casually
- `tg_ui` is `@ComponentV2`.
- Active shell pages are `@ComponentV2`.
- The live chat-list row path uses `TgChatRow` as `@ComponentV2`.
- Mixing these layers incorrectly is a reliable way to break hvigor builds.

## 2. `LazyForEach` reuse rules are not interchangeable between V1 and V2
- Current chat list path relies on `LazyForEach` + `.reuseId(...)` with a V2 row component.
- Official docs treat `@ReusableV2` as a different model for V2 components.
- Do not mechanically replace V1 reuse patterns with V2 ones.

## 3. One separator system per list
- Chat rows already carry their own separator strategy.
- Do not enable both row separators and `List.divider` at the same time.

## 4. Safe area and glass bars must be explicit
- Use avoid-area / safe-area helpers for top bar and bottom tab overlap.
- Blur/glass visuals are acceptable only if interaction zones remain safe.

## 5. Runtime reset must clear static caches
- `LoadChatHistoryUseCase` and `LoadChatsUseCase` maintain cross-call/static state.
- If runtime shutdown does not reset them, reopened sessions can behave as if data is already loaded or still in-flight.

## 6. AppStorage is UI-facing state, not background worker state
- TDLib callbacks and reducer/UI work land on the main thread.
- Background paths should move DTOs/data, not mutate AppStorage directly.

## 7. Historical names in docs can be stale
- `AppTopBar`, `AppTabBarItem`, `ChatListItem` still appear in older docs.
- Current runtime path is tg_ui-first for shell/chat screens.
- When docs conflict, trust current code + `MASTER_PLAN_TELEGRAM_UI.md` + `STATUS.md`.

## 8. Token drift creates fake "almost Telegram" UI
- Hex colors and local geometry must move into `TgUiTokens.ets` / resources.

## 9. iOS reference must be inspected before non-trivial UI work
- The project aims for Telegram iOS visual fidelity.
- Skipping iOS source inspection leads to wrong spacing, hierarchy, and state coverage.

## 10. Keep fallback paths until acceptance gates are actually passed
- Deleting legacy/fallback code too early makes regressions harder to isolate.

## 11. `LazyForEach` keys must be persistent, not order-derived
- Use stable dialog identity (`chatId`) for the item key.
- Appending the current index causes unnecessary row churn during reordering.

## 12. Programmatic chat restore can trip `List.onScrollIndex`
- Use `onDidScroll` + `ScrollState` to unlock pagination only after a real user scroll.

## 13. Edge pagination must auto-recheck after fetch, not require scroll-away
- iOS Telegram uses continuous checking (threshold = 5 items, no latch).
- After each `loadOlder`/`loadNewer`, call `recheckPaginationEdge()`.

## 14. Navigation-title weight should approximate iOS semibold
- `FontWeight.Medium` is the safer approximation for centered navigation titles.

## 15. History sender hydration caps must cover the whole default page
- `getChatHistory` batches can contain more than 8 distinct authors in a group.
- Keep sender-hydration cap high enough to cover the default history page size.

## 16. Generic regex field extraction can pick nested `id` values
- `TdObject.getNumber('id')` is unsafe for payloads like TDLib `user`.
- For identity-bearing payloads, prefer explicit top-level extraction (`getTopLevelNumber`).

## 17. Freeze a patchset boundary as soon as the HiLog loop turns green
- Write down what belongs to current stabilization batch vs. later work.

## 18. Direct TDLib responses with `@extra` do not update the store by themselves
- Use cases receiving direct responses must manually normalize and dispatch.

## 19. `getChat` needs a direct `chat` normalizer path
- Direct TDLib `getChat` responses have type `chat`; without a handler they don't populate state.

## 20. DevEco hvigor can exist locally even when `PATH` says otherwise
- Default path: `C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat`
- Build smoke scripts should probe the default DevEco install path.

## 21. TDLib `getChatHistory` short batches are ambiguous
- Official TDLib docs allow fewer messages than requested even when more history exists.
- `messageCount < limit` must NOT immediately flip `canLoadOlder=false`.

## 22. Do not render a tiny initial batch as if it were stable chat history
- Defer committing suspiciously tiny initial batches until the top-up completes.

## 23. One top-up can still be too shallow for Telegram history
- Use a bounded top-up loop while oldest-message progress continues.

## 24. In `LazyForEach`, mutable content must not be part of item identity
- Keep identity stable by dialog id (`chatId`); avoid broad reuse pools.

## 25. Prefer stock ArkUI components over thin wrapper atoms
- Custom atoms that only wrap a stock component with token styling add no real value.
- Only create an atom when it adds genuine logic: enums, computed state, composite layout.
- Use stock ArkUI components directly with token styling inline for new screens.

## 26. Avatar photos are the single biggest "demo vs real app" visual signal
- TDLib provides `file.id` in `profile_photo.small` but does NOT auto-download.
- Priority: implement `downloadFile` flow before any further UI polish work.

## 27. File download architecture: cross-cutting reducer for fileId→path mapping
- `updateFile` from TDLib only carries `file.id` + `local.path` — no entity context.
- The `filesReducer` scans `users` and `chats` maps for matching `photoSmallFileId` on `fileDownloaded`.

## 28. TDLib file objects: `getNumber('id')` fails due to nested `remote.id` string
- Use `getTopLevelNumber('id')` which does character-by-character parsing respecting JSON nesting depth.

## 29. `JSON.stringify(TdObject)` produces empty/truncated output — use native accessors
- Never `JSON.stringify` a TdObject for data extraction. Always use `.getString()` / `.getNumber()` / `.getBool()` / `.getObject()` API.

## 30. (deleted — merged into #29)

## 31. Scroll compensation for prepend must be synchronous
- Call `scrollToIndex` synchronously right after `applyDiff()`.
- Using `setTimeout(16ms)` creates a visible 1-frame shift/flicker.

## 32. Pagination latch pattern is unnecessary overhead
- Neither Android nor iOS Telegram use a latch for pagination.
- `recheckPaginationEdge()` provides continuous loading without latches.

## 33. Prepend scroll compensation: pre-capture + viewport freeze + cascade block
- Save indices AND yOffset BEFORE `applyDiff`.
- Freeze viewport with immediate `scrollTo({ yOffset, animation: false })`.
- Block cascade: set `blockAutoPaginationUntilUserScroll = true` during prepend.

## 34. Prefer ArkUI native `maintainVisibleContentPosition(true)` over custom prepend scroll hacks
- Keep the native flag on for chat history lists.

## 35. Do not mix `onDatasetChange` with `onDataAdd/onDataDelete/onDataChange` in one LazyForEach datasource
- Keep one notification family per datasource.

## 36. Never recheck pagination synchronously in the same promise `finally` that dispatches history
- Schedule edge recheck to the next tick; retry after diff has settled.

## 37. Media status controls need explicit state machines
- Telegram iOS models media controls as explicit states (download, progress, play, pause).
- Map each bubble's control to a finite state machine, not ad-hoc branches.

## 38. Determinate media progress should imply an active transfer
- `downloadProgress in [0, 1)` counts as active even if `isDownloading` is false.

## 39. Composer accessory panels belong inside the text capsule
- iOS places panels inside `textInputContainerBackgroundView`, not as separate floating capsules.

## 40. Platform root tab bars must collapse on detail routes
- When chat detail is visible: HDS bar height, margin, mask, and opacity collapse to 0.

---

## Review-driven additions (2026-05-18)

## 41. Map-based dispatch beats chained if/else for method routing
- `TdGateway.getMethodTimeout()` used 8 if/else branches mapping methods to timeouts.
- Replaced with `Record<string, number>` + `??` default — O(1) lookup, adds a new method without growing the function body.

## 42. Docs files grow without bound if every task appends status entries
- `STATUS.md` reached 1220+ lines, `LESSONS.md` reached 527+ entries, `TODO.md` 428KB.
- These files should be working snapshots, not changelogs. The git history is the changelog.
- Trim aggressively. If a doc exceeds ~200 lines, consolidate or archive.

## 43. Large page files are the first architectural smell to address
- `TgChatScreenPage.ets` at 3094 lines mixes subscriptions, 6 use cases, composer, emoji panel, gallery, navigation, voice playback, and context menu.
- A page this size is impossible to review, hard to test, and prone to merge conflicts.
- Decompose before adding more features: ViewModel + Controller + Panel sub-components.

## 44. Direct TDLib adapter responses are `TdObject`, not plain records
- `TdGatewayAdapter.send()` returns the `TdObject` from the gateway as `Object`.
- Do not cast direct TDLib responses to `Record<string, Object>` and index into them.
- Use `TdObject` accessors (`getObject`, `getString`, `getBool`, `getNumber`) for direct responses too.

## 45. ArkTS object literal restrictions affect controller extraction
- Do not return ad-hoc object-literal host adapters from component methods; ArkTS rejects untyped object literals.
- Prefer explicit host methods on the component and pass `this` to extracted controllers.
- Avoid host method names that collide with `@Local` field names.

## 46. Command serializers should be handler-dispatched, not switch-owned
- Keep each TDLib command serializer in a small handler function.
- Register handlers by command type so adding a command does not grow one high-conflict switch body.

## 47. Side-effect tests need explicit seams
- Pure use cases can be tested with a fake `TdGatewayPort`.
- `AuthSideEffect` currently couples to singleton TD gateway and app context; keep basic seam tests local until a richer injectable runtime seam exists.

## 48. Debounced search needs one narrow owner and stale-result guards
- Screen-wide message search belongs in a controller; a chat-owned auxiliary panel may keep its short-lived timer in the page while the page owns that panel lifecycle.
- Always trim the query, enforce the minimum length, increment a request id, and re-check request/query/panel/lifecycle state before applying results.
- Telegram emoji keyword search is a two-stage flow: `searchEmojis` supplies Unicode candidates, then `searchStickers(stickerTypeCustomEmoji)` uses those candidates plus the query. Local glyph substring filtering is not equivalent.
- Regular sticker search uses the same TDLib method with `stickerTypeRegular`, but GIF search does not. Do not relabel saved GIFs or local filtering as search; production GIF search needs the separate inline-bot result path.

## 49. `searchCallMessages` is not `getChatHistory`
- TDLib `searchCallMessages` takes opaque `offset:string` and returns `FoundMessages.next_offset`.
- Do not reuse chat-history `from_message_id` / `next_from_message_id` semantics for calls search.
- Ground call-history pagination in `td_api.tl` before wiring UI state.

## 50. User-initiated media downloads must carry the tap intent
- Starting `downloadFile` is not enough for product behavior: document/audio/voice taps should resume into open/play after `fileDownloaded` updates the message path.
- Store the intent with chat id + lifecycle token + message id + file id, and resolve it only from rebuilt timeline entries.
- Clear the intent on cancel, navigation, or pending-download reset to avoid stale auto-open/play.

## 51. Download failure state needs a page-local change signal
- A controller can record failed `downloadFile` requests, but the UI will not repaint unless the page observes controller version changes.
- Keep retry state page-local for on-demand media failures; clear it on retry, cancel, resolved local path, and navigation reset.
- Do not over-polish the error UI first: expose status through bubble params and keep tap-to-retry behavior deterministic.

## 52. Open media galleries must refresh from the rebuilt timeline
- A gallery opened on an unloaded photo/video can outlive the `downloadFile` request that resolves the local path.
- Do not let the overlay keep stale `MediaGalleryItem` snapshots; rebuild gallery params after timeline diff, preserve current item by message/file identity, and clear local pending UI when the path appears.
- Include photo and album file ids in resolved-download cleanup, not only document/audio/voice/video.

## 53. Startup background downloads must be bounded
- AppFreeze baseline `THREAD_BLOCK_6S` showed cold-start TDLib batches plus repeated `DownloadMedia` scans/enqueues on the main thread.
- Background media download watchers must throttle store-triggered scans, cap enqueues per scan, and avoid full-size media auto-downloads during startup.
- Keep full photo/video/document/audio under explicit tap/download continuation; use background auto-download only for thumbnails and genuinely small Telegram media.

## 55. Release track replaces breadth phases
- Phase-роадмап без видимой пользователю финишной черты («media behavior completion») привёл к дрейфу и потере ориентира.
- План v2: MVP-чеклист как единственный гейт R1, явный freeze-список, после v0.1.0 — одна фича = один релиз v0.x.
- Мета-тулинг (heartbeat/sweep) заморожен, пока реальная регрессия его не потребует.

## 56. Полный эмуляторный цикл доступен из CLI без DevEco GUI
- `Emulator.exe -start "<hvd name>"` (из `DevEco Studio\tools\emulator`) поднимает зарегистрированный инстанс; справка бинаря богаче официальной доки (`-list`, `-config`, `-license`).
- Unsigned HAP ставится на эмулятор через `hdc install -r` — подпись нужна только для реального устройства; это разблокирует автономный цикл build→install→run→observe.
- Использовать hdc из SDK DevEco, не из PATH; в Git Bash device-пути требуют `MSYS_NO_PATHCONV=1`, а `file recv` на Windows ломается на абсолютных путях — принимать файл относительным именем из целевого каталога.
- `uitest uiInput click/swipe/keyEvent` + `snapshot_display` достаточно для прогона UI-чеклиста без ручного участия.

## 57. Cold-start freeze — это конвейер TDLib-батчей, не загрузки медиа
- Свежий `THREAD_BLOCK_6S` (2026-07-03 01:34): main thread 8+ секунд в `uvLoopTask`, стек в `libtdlib_napi.so`, батчи по 50 ответов каждые ~90 мс; media-вотчер стартовал только через минуту после фриза — троттлинг загрузок работает (hilog: Enqueued 4→4→2 шаг 600 мс), но не лечит корень.
- Направление фикса: чанкинг/yield обработки батчей в главном потоке, backpressure на NAPI-мосту, отложенные тяжёлые редьюсеры на холодном старте.
- AppFreeze-детекция сработала на debug-провизии эмулятора, несмотря на release-only оговорку в доках — эмулятор пригоден для freeze-ретестов.

## 58. Штормы NAPI-батчей лечатся бюджетным дрейном на main thread
- Решение P0: очередь батчей в TdGateway + осушение слайсами по 8 мс с yield через `setTimeout(0)` — watchdog и vsync получают ход между слайсами, cold-start freeze ушёл (80+ с чистого старта против фриза на ~17 с).
- Дрейн обязан работать и в состоянии 'destroying': close-flow ждёт `authorizationStateClosed` через тот же конвейер; очередь чистится только в самом конце destroy/cleanup.
- Следующий резерв производительности (если понадобится): убрать двойную сериализацию — dispatchItem делает `JSON.stringify`, а нижние слои снова парсят.

## 59. ArkUI: события не приходят на статичном крае и до привязки контроллера
- `onDidScroll` не стреляет, когда лист упёрся в край и контент не движется — «разблокировку по скроллу» надо дублировать через `onTouch` (drag ≥ порога), иначе флаг вечный.
- `TabsController.changeIndex()` в `aboutToAppear` — no-op (контроллер ещё не привязан к построенному компоненту); стартовый таб задаётся параметром `index` в опциях Tabs/HdsTabs.
- Одноразовые `schedulePaginationRecheck` глотаются suppress-окном — на статичном крае перепланируй recheck, там `onScrollIndex` больше не стрельнёт.

## 60. `hdc install -r` одного HAP'а пересоздаёт весь бандл
- Установка ohosTest-HAP через `install -r` удалила entry-модуль и ВСЕ данные приложения — TDLib-сессия эмулятора потеряна, потребовался ручной релогин.
- Multi-HAP бандл обновлять только полным набором HAP'ов; тестовый HAP не ставить поверх рабочей сессии.
- Прогон юнитов: `hvigorw onDeviceTest` требует подписанный HAP; ручной `aa test -s unittest OpenHarmonyTestRunner` в этой конфигурации завис — до R2 юниты гонять из DevEco.

## 66. TDLib remote.unique_id — единственный стабильный ключ файла
- file.id пере-нумеруется между парсом сообщения и завершением загрузки; `remote.unique_id` стабилен. Матчить медиа и transfers надо по unique_id, id — вторично.
- Реализация: append-only реестр `aliases[uniqueId]→fileId[]` в filesReducer, шарится по ссылке между клонами стейта (монотонен, вне diff-пути → мутация на месте допустима и дёшева при штормах). resolveContentPath: промах по fileId → фоллбэк по любому transfer через алиас.
- Гейзенбаг живого witness: во fresh-сессии тапы-загрузки не стреляли через uitest, а инструментальный `aa test` не отдаёт репорт на этом эмуляторе — детерминированный witness делаем юнит-тестом чистой resolve-функции (экспортировать из VO), а не флаки-UI.

## 65. Гибрид V1/V2: реактивность рвётся на швах, notify вручную
- V2-баблы обновляются по `@Param` только когда V1-родитель (LazyForEach + reuse) пере-рендерит вызов; стор — вне ArkUI-реактивности; поля контроллеров не видит ни одна система.
- Правило (CLAUDE.md №13): состояние, влияющее на строку списка, живёт в VO (diff+notify) или `@ObservedV2`/`@Trace`. Забытый ручной `notifyItemChangedByMessageId` = молчаливый баг (фикс мгновенного отклика `e387795`).
- Пока миграция половинчатая — каждый источник состояния для строки проверять на «доедет ли до баббла без ручного notify».

## 64. hilog.info в горячем пути — сам по себе источник THREAD_BLOCK
- Per-file info-логи (мои диагностические трейсы + старый лог FileNormalizer на каждый updateFile) при медиа-шторме насыщают hilog-сокет: main thread блокируется ВНУТРИ `HiLogPrint`/`writev` — freeze-лог показывает стек в libhilog_napi.
- Диагностика Гейзенбага: инструментируй редко-срабатывающие ветки (пропуск divider — раз на ребилд), никогда — per-item в штормовых потоках; временные трейсы удалять сразу после снятия показаний.
- Горячие пер-файловые логи переведены на hilog.debug (не эмитится по умолчанию) — шторм-ретест чистый.

## 63. file id из updateFile может не совпадать с fileId контента в сторе
- Трасса filesReducer показала msgMatch=0 для тумб, поставленных самим вотчером из контента: TDLib пере-нумерует file id между постановкой и завершением (или страницы истории подменяют сообщения с новыми id).
- Канонический путь «fileDownloaded → применить путь в content» ненадёжен; `files.transfers` заполняется на КАЖДЫЙ updateFile — использовать его как источник истины: VO-билдер добирает пустые контент-пути из завершённых transfers, перерисовка по transfers уже есть.
- Диагностические трейсы (`DownloadMedia: enqueue`, `FilesReducer: fileDownloaded`) оставлены для root-cause follow-up.

## 62. setTimeout(0) из таймерного колбэка не покидает uv-таймерную фазу
- Нулевой таймер, перевзведённый внутри собственного колбэка, дозревает в той же фазе цикла: «yield» через `setTimeout(0)` сливает всю цепочку слайсов в один `uv_timer_task` — freeze-лог показывает его вместо uvLoopTask, JS-стек в интерпретаторе.
- Реальный yield для чанк-обработки на main thread — задержка ≥1 мс: слайс уезжает в следующий оборот цикла, watchdog/vsync исполняются между слайсами.
- Малый бэклог маскирует проблему (весь дрейн укладывается в <6 с) — проверять именно на максимальном шторме: свежий логин/полная ресинхронизация.
- Даже 1 мс ненадёжна: loop handler прокачивает дозревшие таймеры внутри одного uv_timer_task, а GC-давление растягивает слайсы (третий freeze — стек в malloc). Надёжный инвариант — пейсинг: задержка следующего слайса ≥ фактической длительности предыдущего (≤50% занятости main thread при любом размере элементов).

## 61. Незарегистрированная цель ohosTest = мёртвые тесты
- В `entry/build-profile.json5` отсутствовал target `ohosTest` — весь тестовый сьют никогда не компилировался и накопил синтаксическую гниль (`it('...', async 0, ...)` во множестве файлов, unknown-cast).
- Регистрация цели + починка синтаксиса вернули компайл-гейт: `hvigorw --mode module -p module=entry@ohosTest assembleHap` теперь зелёный и должен быть частью верификации при правках тестов.
- Формат цели подтверждён локальными официальными Codelabs (`targets: [{name: "default"}, {name: "ohosTest"}]`), когда RAG-база молчит — локальные референсы вторые в очереди.

## 54. HarmonyOS timer/AppFreeze doc contracts for the throttled media watcher
- Docs DB cross-check (2026-07-02): `setTimeout` returns `number` in ArkTS, so the `as number` cast is redundant; `clearTimeout` with a stale/unknown id is a documented safe no-op, but timers must be cleared on the thread that created them.
- Timers do not fire while the app is in background; expired timers fire after foreground restore — the 600ms rescan chain pauses in background and resumes on foreground, which is acceptable for auto-downloads.
- `THREAD_BLOCK_6S` is a watchdog activation check inserted into the main thread; chunking scans via `setTimeout` yields the event loop between chunks, which is exactly what the watchdog needs.
- AppFreeze detection applies to release-version apps only (not debug) — re-verification must match the original capture's build type.

## 67. Декомпилированный конкурент (ArkGram) как native ArkTS-референс
- ArkGram даёт нативные ArkUI-паттерны/числа, которых нет в iOS/Android-рефах: connection-state в шапке через реактивный `StorageLink`+`declareWatch`, `maxSelectNumber:10` мультивыбор, `Button.stateEffect` press-фидбэк, компоновка топ-бара (Row 60, title 16/Bold, статус 12px `#2AABEE`).
- Где мы уже сильнее — НЕ копировать: measure-driven rich-text (`TgTextBodyV3`), инкрементальный `applyDiff`, `maintainVisibleContentPosition`-prepend, изолированные `NavPathStack`. Копировать его ffmpeg/ручной translate было бы регрессом.
- Аудит выявил и неверные факты субагентов: `TgVideoPlayerPage.ets` из находки не существует (видео в галерее — через `TgInlineVideoView`). Проверять пути перед правкой.

## 68. RAG-база неполна — witness для непокрытых API берётся из build
- `clickEffect`, `TextAreaController.stopEditing`, `@ReusableV2` НЕ находятся в `search_harmonyos_docs` (2 разных запроса каждый), но `clickEffect`/`stopEditing` реальны — build подтвердил компиляцию. Для непокрытых RAG API witness = сам build (+ grep использований в проекте/Codelabs), а не «RAG молчит → значит нет».
- `avoidAreaChange` (Callback<AvoidAreaOptions>, `.type`===`TYPE_SYSTEM`), `getFocusController().requestFocus(id)` (12+) — RAG подтвердил с примерами. Сверяйся, где база отвечает.

## 70. Слияние uv-таймерной фазы лечится эскалацией, не константным пейсингом
- Пейсинг «пауза ≥ elapsed» (Lesson 62) не выдержал шторм при открытии тяжёлого канала: drain+watcher+history-таймеры дозревают в паузе и продлевают один uv_timer_task, main thread CPU-bound 6+с (стек libark_jsruntime, killed).
- Рабочая схема: (1) мультипликативный backoff подряд «горячих» слайсов до жёсткого потолка (250мс) со сбросом при осушении; (2) backpressure-сигнал `isDrainCongested()` — фоновые таймер-потребители (media watcher) откладывают свои тики при шторме.
- Опциональный член порта (`isDrainCongested?: () => boolean`) сохраняет тестовые фейки минимальными; ArkTS-фейк ДОЛЖЕН декларировать поле явно (`= undefined`), иначе присвоение в тесте не компилируется.

## 71. Делегирование кодеру: патч по цепочке слоёв проверять на КАЖДОМ слое
- DeepSeek-кодер провёл `stickerThumbnailPath` DTO→VO→Page→Router→View, но пропустил слой модели (`MessageContent`) и все 3 клон-маппинга редьюсеров — компайл поймал, но клоны потеряли бы значение молчаливо (родственно Lesson 63/65).
- Правило делегату/ревью: для нового поля контента чек-лист слоёв фиксированный — DTO, MessageContent, messagesReducer (dto→content И clone), filesReducer (clone), VO. Grep по соседнему полю (isVideoSticker) даёт полный список точек.
- Отчёт кодера «N/N PASS» без компиляции — не witness; компайл-гейт и build остаются за оркестратором.

## 72. hdc install: только относительный путь из cwd
- `hdc install` с абсолютным Windows-путём склеивает его с cwd (`C:\...\proj\C:/...`) и падает `[Fail]`; при этом `aa start` после провала молча запускает СТАРЫЙ установленный бинарь — ретест на нём был бы ложным witness.
- Всегда: `cd <proj> && hdc install -r entry/build/.../entry-default-unsigned.hap`, и проверять строку `install bundle successfully`.

## 69. Single source of truth для safe-area инсета + smoke-контракт как ограничитель
- Дублирование расчёта инсета (атом `aboutToAppear` + страница) даёт рассинхрон spacer↔contentOffset. Решение: страница считает инсет один раз → атому `@Param topInset`; подписка `avoidAreaChange` (windowSizeChange НЕ гарантирует смену высоты статус-бара) с парным `off()`; fallback — токен ~38vp, не 0.
- `smoke-ui-phase0` требует `.reuseId()` в `ChatListPage` — миграция на `@ReusableV2` (аудит #1) сломала бы контракт. Проектный smoke-контракт закрепляет паттерны: проверяй его перед «улучшением» по аудиту, иначе зелёный аудит = красный smoke.

## 73. Проценты внутри auto-sized контейнера ArkUI = родительский CONSTRAINT, не финальный размер
- Ребёнок с `width('100%')`/`height('100%')` в контейнере, сайзящемся по контенту, получает процент от constraint родителя (в List-элементе — вьюпорт), а не от финальной ширины/высоты. Два проявления в одном стеке: `TgReplySnippet` растягивался `minWidth: containerWidth`-хаком поверх `width('100%')`-каскада; quote-бар `height('100%')` в auto-Row раздувал плашку цитаты до полутора экранов.
- Решение для «полоса высотой с контент»: `LayoutPolicy.matchParent` (API 15+, в RAG есть: «size equals the parent's content area») — резолвится от финального размера родителя. Для ширины по контенту — убирать процентный каскад целиком (hug), Ellipsis у Text работает от `constraintSize.maxWidth` предка.
- Симптом для диагностики: «плашка/бар на весь экран при коротком контенте» — сразу искать процентные размеры в auto-контейнере.

## 74. 8-значный hex в ArkUI — это #AARRGGBB: конкатенация alpha в хвост сдвигает каналы
- `quoteAccentHex + '1F'` дал `#8774E11F` → ArkUI прочитал A=87, R=74, G=E1, B=1F — непрозрачно-зелёная цитата вместо фиолетовой подложки 12%.
- Для «accent с прозрачностью» — только `rgba(r, g, b, a)`-строка (паттерн `accentRgba()` в TgReplySnippet/TgTextBodyV3), не hex-суффикс.

## 76. В проекте ДВА MessageContentType: enum (MessageDto) и union-type (AppState)
- Новое значение типа контента добавляется в ОБА места: `enum MessageContentType` в `core/model/dto/MessageDto.ets` И `export type MessageContentType = '...'` в `core/model/AppState.ets` (строка 12). Забытый union ловится компилятором только на первом сравнении (`no overlap`), а не на присваивании.
- Чек-лист нового contentType поверх урока 71: enum DTO + union AppState + поля DTO/MessageContent + messagesReducer map+clone + VO + Router/Page-рендер + (опц.) reuseId-ветка.

## 75. Парные ветки вычисления sender-ключа обязаны зеркалить друг друга
- Группировка сообщений: `effectiveSenderId` (ветка не-групп) давал `-3` для senderId=0, а `prevSenderId`-трекер хранил `senderChatId` — рассинхрон реальный, фикс верный. Уточнение тика 4: каналы шли ЧЕРЕЗ isGroupChat-ветку (в isGroupChat ошибочно входил 'channel'), поэтому симптом «каналы не группируются» этой парой не объяснялся; после исключения 'channel' из isGroupChat канальная группировка держится именно на зеркальности effectiveSenderId ↔ prevSenderId.
- При правке одной из парных веток (вычисление ключа ↔ обновление трекера) grep по второй обязателен; лучше — выносить в одну функцию.

## 81. AVPlayer stateChange('playing') может теряться — синхронизируй флаг по player.state в timeUpdate
- Witness: прогресс тикал (timeUpdate живой), а isPlaying оставался false — событие 'playing' из on('stateChange') не пришло (подписка стояла до prepare, waitForState снимает только свой handler). Полагаться на дискретные stateChange-события для UI-флага нельзя.
- Паттерн: в `timeUpdate`-обработчике выставлять `isPlaying = player.state === 'playing'` (тики идут только при воспроизведении), а в pause()/stop()-методах — явный `isPlaying=false; emit()` рядом с await, не дожидаясь события.

## 80. stateStyles на ListItem глотает клики swipeAction-кнопок
- Симптом: свайп-панель рисуется, но onClick кнопок не стреляет; на каждый тап в hilog только `AceStateStyle ... ChatListPage` (pressed-обработка ListItem). Виновник — `stateStyles({pressed})` на самом ListItem: он перехватывает касания зоны свайп-экшенов.
- Рабочий канон (witness: Codelabs PersonalAssistantPro + наш live-пин): ListItem БЕЗ stateStyles (+ .onClick допустим), swipeAction в прямой CustomBuilder-форме `end: () => { this.builder(item) }`, кнопки — `Button(ButtonType.Normal)` с onClick.
- Диагностика различает «клик не дошёл до кнопки» от «команда не ушла»: grep hilog по тегу usecase-а сразу после тапа.

## 79. Бейдж на HDS/стоковых табах: только custom tabBar-builder
- `BottomTabBarStyle` не имеет badge-API (проверка: `openharmony/ets/component/tab_content.d.ts`, RAG пуст), HDS-badge существует только для HdsNavigation-меню (`@hms.hds.hdsBaseComponent.d.ets`). Рабочий путь: `.tabBar(builder)` с воспроизведением метрик (SymbolGlyph 24 + label 10fp + те же `sys.color.ohos_id_color_activated/bottom_tab_icon_off`), floating-бар HdsTabs кастом-айтем переживает.
- Витнесс интерактивности обязателен: активное/неактивное состояние + переключение (selectedIndex в builder-е реактивен через @Local).

## 77. isGroupChat ≠ «у чата есть лента с отправителями»: channel в нём — дефект вида «имя после каждого сброса»
- `'channel'` в isGroupChat включал sender-name-логику для постов канала; showSenderName проявлялся ТОЛЬКО у первого поста после сброса prevSenderId (date/unread-маркер) — дефект выглядел как «случайное имя над случайным постом» и трижды маскировался под «имя над альбомом». Диагностика: если аномалия появляется строго после date/unread — ищи сбросы prevSenderId.
- Канал — не групповой чат: имени/аватар-лейна нет (iOS), группировка — по senderChatId в else-ветке.

## 78. Горячий путь для hilog — это и per-batch/per-rebuild/per-scroll-tick, а не только per-file
- 5-й THREAD_BLOCK_6S: main завис в `HiLogPrint→writev` (стек libhilog_napi) при скролле-пагинации канала — 8 info-логов loadChatHistory (в т.ч. «already in progress» на КАЖДЫЙ отклонённый скролл-триггер) + per-rebuild «unread divider skipped» в VO. Диагностические info-логи, добавленные «до следующего репро», обязаны быть debug с рождения.
- Смежный факт: `hdc install -r` БЕЗ предварительного `aa force-stop` может не перезапустить процесс (STIME старый) — ретест уйдёт на старый бинарь; witness валиден только после force-stop → start (проверять STIME в ps).
### 2026-07-09 TDLib int64-поля в TdObject — tdGetString молчит
- What happened: поиск по чату логировал «Found 0 messages (total=3)» — TDLib находил сообщения, extractMessageIds возвращал пусто. Диагностический лог показал: messagesLen=3, type=message, но id='' у всех трёх.
- Root cause / insight: message.id в JSON-ответе TDLib — int64-ЧИСЛО; tdGetString для числового поля молча возвращает '', и фильтр `id !== '0'` съедал все результаты. Правильный аксессор — getInt64String('id') (Shared Media им уже пользовался, потому и работал). Тихий null-путь + фильтр = баг без единой ошибки в логах.
- Next time: любое id/int64-поле из TdObject читать только через getInt64String; при «нашлось N, извлеклось 0» первым делом логировать type+значение каждого элемента, а не подозревать TDLib. Витнесс одного удачного запроса («reply» → Found 1) не доказывает корректность пути — тот случай прошёл по другой ветке.
### 2026-07-09 Jump-to-message поверх одно-диапазонного стора
- What happened: навигация поиска работала только по загруженному хвосту; сообщение вне диапазона молча игнорировалось (scrollToMessageId=false и всё).
- Root cause / insight: стор моделирует ОДИН непрерывный диапазон сообщений на чат — влить окно вокруг далёкой цели без reset нельзя (склеится с дырой, пагинация соврёт). Правильная механика Telegram: reset сообщений чата → getChatHistory(from_message_id=цель, offset=-limit/2) → обе кромки пагинации заново открыты (canOlder/canNewer=true — окно в середине). Доскролл — отложенный: pendingJumpMessageId исполняется ПОСЛЕ прихода diff, с кадром задержки (scrollToIndex сразу после полного reload списка не срабатывает), с bounded-попытками (цель могла быть удалена).
- Next time: для witness глубокого прыжка тестовый чат File бесполезен (вся история ~150 сообщений покрывается restore-цепочкой) — брать большую публичную группу (Rozetked: 2994 хита «iphone»). uitest inputText КОНКАТЕНИРУЕТ к содержимому поля — между запросами закрывать/открывать поиск, иначе «llama»+«test»=«llamatest»→0 результатов и ложный вывод.
### 2026-07-09 UI-волна: смок как хранитель дизайн-решений + PowerShell exit-коды
- What happened: пользователь попросил переделать таб-бар (остров → плоский iOS). Смок-гейт закреплял СТАРОЕ решение (barFloatingStyle) и упал — но его падение проскочило в &&-цепочке: PowerShell Write-Error завершился с exit 0, коммит ушёл с красным смоком.
- Root cause / insight: (1) смок-скрипты закрепляют дизайн-решения — при сознательной смене решения гейт обновляется В ТОМ ЖЕ тике; (2) `powershell -File` с Write-Error не гарантирует ненулевой exit — в цепочке && это молчаливый пропуск; вывод смока надо ЧИТАТЬ, не полагаться на код возврата. (3) Имена sys.symbol валидируются компилятором; полный список — SDK toolchains/id_defined.json ('globe' нет, языковой глиф — 'translate'; чат-облачко — 'ellipsis_message(_fill)').
- Next time: перед коммитом смотреть строку «tg_ui shell smoke checks passed.» глазами; при смене UI-паттерна grep смоков на упоминание старого паттерна; json.dumps(indent=2) переформатирует ресурсные json целиком — дифф 8k строк, для точечных вставок лучше текстовый патч.
### 2026-07-09 СобытUser-заглушки: @Event существует не значит подключён
- What happened: тап по reply-снипету молчал. onClick в атоме БЫЛ, @Event onReplyTap в TgTextBubbleV3 БЫЛ — но Router его не прокидывал, событие умирало в дефолтной заглушке `() => {}`. Мои новые onClick-сайты легли на другие ветки Router (videoNote и пр.) — текстовые баблы рисуют снипет внутри атома.
- Root cause / insight: @Event с дефолтной заглушкой компилируется и молча глотает вызовы — grep потребителей события (`onReplyTap`) по молекулам обязателен при подключении цепочки. Витнесс «клик дошёл» — только лог в конечном обработчике (добавлен пост-фактум в jumpToMessageId).
- Next time: подключая событие через слои atom→molecule→page, проверять КАЖДЫЙ мост grep-ом имени события; для тап-цепочек сразу закладывать info-лог в конечный обработчик — скриншот-витнессы скролла двусмысленны (restore/скролл-жесты дают ложные сдвиги).
### 2026-07-09 Черновики: три несвязанных обрыва одной фичи
- What happened: drafts «почти были»: приём updateChatDraftMessage, редьюсер, красное превью в чат-листе — всё готово годами, но фича не работала целиком. Отправки не существовало; первый restore лёг в onActiveChatChanged — МЁРТВЫЙ метод (ноль вызовов, страница пересоздаётся на каждый вход); сохранённый TDLib-ом драфт («Draft response: ok») не появлялся в сторе, потому что chatFromTd не парсил chat.draft_message (только update-поток).
- Root cause / insight: (1) при вкладке в существующий «наполовину готовый» трек сперва трассировать ВЕСЬ путь данных двумя направлениями (в TDLib и обратно), а не только дописывать недостающий конец; (2) поиск точки жизненного цикла — grep вызовов метода, а не доверие имени («onActiveChatChanged» звучит как хук, но никем не вызывается); (3) cpp-лог «TDLib send: <type>» печатает ПЕРВЫЙ @type строки — для команд с вложенными объектами (draftMessage внутри setChatDraftMessage) он врёт; (4) ответ команды логировать, а не глотать catch-ом — «ok» от TDLib сразу сузил поиск до receive-стороны.
- Next time: чек-лист интеграции фичи: команда → сериализатор → ответ-лог → update-нормализатор → ПАРСЕР ПОЛНОГО ОБЪЕКТА (chatFromTd/messageFromTd — updates и full-object пути дублируются!) → редьюсер → VO → строка.
### 2026-07-09 «Не нравятся табы» ≠ «сделай старый iOS»: проверяй тренд, не память
- What happened: на «мне не нравятся табы» я откатил нативный плавающий HDS-остров к плоскому полноширинному бару «как в iOS». Пользователь хотел ОБРАТНОЕ: нативные плавающие табы нового SDK — и был прав вдвойне: Telegram на iOS 26 сам перешёл на плавающий Liquid Glass таб-бар (9to5Mac, 2025-10-13), а barFloatingStyle — канонический API 23 паттерн «immersive material» в HDS-доках.
- Root cause / insight: моё представление об «iOS-паттерне» устарело на поколение (iOS 26 = плавающие стеклянные бары); дизайн-фидбек без деталей интерпретировал по памяти вместо проверки референсов и интернета. Плоский бар был регрессией тренда, а не фиксом.
- Next time: перед сменой дизайн-паттерна — WebSearch на текущий гайдлайн платформ + RAG на нативный API + git log решения (комментарий «API 23: HdsTabs floating» уже говорил, что остров был осознанным выбором). `C:\Refs\Telegram\Telegram-iOS-snapshot-2026-02-10` — снапшот ДО Liquid Glass; для трендовых вопросов брать runtime witness и `Telegram-iOS-current`. «Тупой» вид стеклянных элементов на тёмном фоне часто = слишком тонкий материал (ULTRA_THIN → THICK решает), а не отсутствие блюра.
### 2026-07-09 SDK-апгрейд до HarmonyOS 26.0.0 Beta1 (API 26)
- What happened: пользователь обновил DevEco/SDK. Чистая пересборка (clean + default + ohosTest + smoke) зелёная без единой правки кода; рантайм живой, TDLib-сессия цела. Побочно обновление погасило эмулятор и hdc потерял устройство.
- Root cause / insight: (1) SDK сменил нумерацию 6.1.0(23) → 26.0.0 Beta1 (API 26); target/compatible у нас остались 23 — новые API 26 недоступны до поднятия target (Beta — решение пользователя). (2) Эмулятор поднимается БЕЗ GUI: `Emulator.exe -start "Pura 90 Pro Max"` (tools/emulator) + `hdc tconn 127.0.0.1:5555`; инстансы смотреть `Emulator.exe -list -details` (три: API 21/22/23; API 26 образа нет). (3) hilog-буфер, позиции чат-листа и все живые сессии пережили апгрейд — переустановка HAP не потребовала перелогина.
- Next time: после апдейта DevEco первым делом clean-сборка и `hdc list targets`; эмулятор — CLI-стартом; für API 26 фич — создать 26-образ (`Emulator -install/-create`) и обсудить перелогин + target bump с пользователем.
### 2026-07-09 Login-code баг: служебный чат 777000 выпадал из окна загрузки
- What happened: повторный вход на втором устройстве показывал пустой экран кода — код не доходил. Пользователь настаивал «баг клиента, старая сессия жива». Оказался прав.
- Root cause / insight (найдено live-witness'ом): при активной сессии Telegram шлёт login-code НЕ SMS, а сообщением в служебный чат (user 777000 «Telegram»), тип waitCode=otherSession. Этот чат простаивает и выпадает из нашего топ-N loadChats окна → TDLib перестаёт слать updateNewMessage для него → код никогда не попадает в стор. Reducer-цепочка при этом ИСПРАВНА (проверено чтением: messagesReducer сохраняет сообщения незагруженных чатов, chatsReducer создаёт placeholder на любой updateChat*, rebuildOrderedChatIds включает order=0) — то есть доставленный код отобразился бы; проблема чисто в НЕдоставке. Ключ TDLib: updateNewMessage приходит только для чатов, которые клиент «знает» (getChat) или держит открытыми (openChat), либо которые попали в загруженную позицию списка.
- Fix: AuthSideEffect.onAuthReady → getChat(777000) + openChat(777000). Witness: `chatFromTd id=777000 title="Telegram"` + `chatAddedToList (main list)` + openChat на залогиненном эмуляторе после рестарта.
- Next time: любые «пропадающие» входящие для конкретного чата → проверять known/open-статус чата в TDLib, а не только reducer. resend otherSession-кода невозможен (TDLib 400 antiflood) — для нового кода нужен полный setAuthenticationPhoneNumber; коды запрашивать экономно (флуд-лимит на вход = danger boundary для аккаунта). Два QEMU-эмулятора: новый слушает соседний hdc-порт (5557), подключать `hdc tconn 127.0.0.1:5557`, адресовать `-t`.
### 2026-07-10 «Как делает официальный клиент» = QR login token, не код
- What happened: вход нашего клиента на второй эмулятор упирался в недоставку otherSession-кода. Пользователь: «официальный клиент всегда автоматом заходит». Проверили: официальный механизм мгновенного входа — QR (exportLoginToken → скан активной сессией → Ready), и наша QR-ветка уже была полностью реализована (QrLoginPage + requestQrCodeAuthentication + WaitOtherDeviceConfirmation в нормализаторе) — просто никогда не прогонялась E2E.
- Root cause / insight: E2E-витнесс: тап «Log in by QR Code» → qrCodeLink(63) → QR на экране → скан телефоном → authorizationStateReady за секунды, 2FA не спрошен. Фоновые process-children Bash-сессии умирают вместе с ней — эмуляторы запускать через PowerShell Start-Process (detached), не `bash &` и не `cmd /c start` (аргументы с пробелами теряются).
- Next time: для мультисессийных сценариев вход по QR — дефолтный путь (быстрее, без флуд-лимита кодов, без 2FA-экрана); code-flow оставлять фолбэком. UI-полиш: QR-first порядок экранов как в Telegram Desktop — кандидат в бэклог.
### 2026-07-10 Плавающий бар: канон HDS = gradientMask + bleedIconStyle
- What happened: пользователь снова забраковал табы. На светлой теме (API 24) остров был нечитаем — контент листа и аватары просвечивали прямо сквозь бар. Причина: при возврате barFloatingStyle после «плоского» детура gradientMask не вернулся, а без подложки HDS-остров парит над сырым контентом.
- Root cause / insight: канон из доков (HdsTabsFloatingStyle, UI Design Kit 23): gradientMask с дефолтами light #CCF1F3F5 / dark #99000000, maskHeight = высота бара + 16vp; кастомные табы с выступом (наш бейдж) — через официальный bleedIconStyle() (6.0.2(22)+, легальный выступ до 4vp). Простые табы {icon,text}/BottomTabBarStyle — оба валидны.
- Next time: при «вернуть как было» сверять НЕ с прошлым коммитом, а с доками — прошлый код тоже мог быть неполным;光/тьму проверять ПАРОЙ (маска-баг был невидим на тёмной). Эмуляторы запускать detached через PowerShell Start-Process с -ArgumentList @('-start','Name with spaces') — кавычки в строке аргументов ломаются, массив работает.
### 2026-07-10 Табы 1:1 по ArkGram: barBackgroundStyle, не gradientMask
- What happened: третья итерация табов. Пользователь: «смотри как ArkGram делает». Декомпилят (`C:\Refs\Telegram\ArkGram-RE\out\ArkGram-project\entry\src\main\ets\settingsUI\tabbar\view\MainTabBar.ets`) дал точный рецепт, отличный и от моего, и от «чистых доков».
- Root cause / insight: рецепт ArkGram: (1) подложка через ОТДЕЛЬНЫЙ barBackgroundStyle({maskColor: ЦВЕТ ФОНА ТЕМЫ, maskHeight: 110}) — бесшовно растворяет список в фон, а не полупрозрачный gradientMask из floating-опций; (2) barBottomMargin 30; (3) HdsTabs.backgroundColor(фон) + expandSafeArea(SYSTEM, TOP+BOTTOM); (4) айтемы: BottomTabBarStyle().iconStyle/.labelStyle с selected=accent, unselected= isDark?белый:чёрный (не sys.color-пара). Декомпилят как канон конкретного продукта бьёт и мои представления, и голые доки — у доков дефолты, у продукта — вылизанные значения.
- Next time: для «сделай как X» идти ПРЯМО в декомпилят X (grep по API), а не в доки; порядок референсов для UI: ArkGram-RE → HDS-доки → iOS. Два эмулятора одновременно не всегда взлетают (RAM): light/dark пару снимать переключением темы на одном инстансе, а не двумя инстансами.
### 2026-07-10 Эмулятор умирает с моей сессией: единственный живучий запуск — schtasks
- What happened: три раза подряд эмулятор «пропадал» у пользователя («не вижу») — QEMU гас ровно в момент завершения моих фоновых Bash-задач (qemu.log обрывался на teardown). `cmd /c start` терял аргументы с пробелами, `timeout N` убивал boot, PowerShell Start-Process умирал вместе с родителем.
- Root cause / insight: `Emulator.exe -start "Name"` держит QEMU как своего ребёнка всю жизнь инстанса — любой запуск из моего процессного дерева обречён на смерть при teardown сессии/задачи. Полностью независимое дерево даёт только Планировщик Windows: `MSYS_NO_PATHCONV=1 schtasks /create /tn HmEmuPura23 /tr '"...\Emulator.exe" -start "Pura 90 Pro Max"' /sc once /st 23:59 /f` + `schtasks /run /tn HmEmuPura23`. Витнесс: Emulator.exe жив в tasklist после смерти всех моих задач.
- Next time: эмулятор поднимать ТОЛЬКО через schtasks (задача HmEmuPura23 уже создана — просто `/run`); MSYS_NO_PATHCONV=1 обязателен для слэшей schtasks в Git Bash. Смерть окна диагностировать по обрыву qemu.log, не по hdc.
### 2026-07-10 «Подними апи» = targetSdkVersion 26 как у ArkGram; формат без скобок
- What happened: наш бар был кодом 1:1 с ArkGram, но выглядел иначе. Их HAP: minAPIVersion 6.1.0(23), targetAPIVersion 26.0.0(26) Beta1, compileSdkVersion 26.0.0.23 — а у нас target 23. Поднял target → 26: hvigor отверг и «26.0.0(26)», и «26».
- Root cause / insight: (1) нативная отрисовка системных компонентов (HdsTabs floating material) выбирается по targetAPIVersion пакета — target 23 даёт legacy-рендер на том же устройстве; (2) hvigor: до API 25 формат «5.0.0(12)», с API 26 — «26.0.0» БЕЗ скобок (ошибка 00306042 говорит это прямо); (3) витнесс паритета — module.json внутри HAP (zipfile): все четыре поля (min/target/compileSdk/releaseType) байт-в-байт с ArkGram; bm dump может показать чужой compileSdkVersion из других секций — проверять сам HAP. (4) unsigned HAP ставится на эмулятор без подписи.
- Next time: «выглядит не как у референса при одинаковом коде» → сравнивать манифесты HAP (target/compile), не только исходники. persist.ace.darkmode эмулятор игнорирует (set «success», эффекта ноль) — тему переключать через Settings UI: uitest dumpLayout → «Экран и яркость» → radio Светлый/Тёмный; light/dark пара снята этим путём на одном инстансе.
### 2026-07-10 «Нет в базе» по двум фразовым запросам — ложный вердикт; ключ = точный идентификатор API
- What happened: после обновления RAG (82K→107K чанков, +zh-cn корпус) я дважды не нашёл HDS-доки фразовыми запросами («HdsTabs barFloatingStyle barBackgroundStyle floating tab bar», «UI Design Kit HdsTabs HdsButton») и записал в CLAUDE.md «HDS docs are NOT in it». Пользователь: «должны быть, посмотри ещё» — и был прав: запрос по одиночному точному идентификатору `bleedIconStyle` мгновенно дал kit «UI Design Kit» (HdsTabs, Bottom Tab Bar, Blur/Floating/Bleed страницы, EN+CN).
- Root cause / insight: поиск RAG чувствителен к форме запроса — многословные фразы размывают скоринг, одиночные редкие идентификаторы бьют в цель. Отрицательный результат пары запросов ≠ отсутствие корпуса; вердикт «нет в базе» требует перебора форм: точный API-идентификатор, имя кита, CN-термин. Бонус сверки: ArkGram-рецепт подтверждён доками — barBackgroundStyle это самостоятельный «Tab Bar Blur Style» API (произвольный maskColor/maskHeight), barFloatingStyle-пример доков barBottomMargin 28 vs ArkGram 30, оба валидны.
- Next time: НЕ фиксировать «в базе нет X» без прогона точных идентификаторов (`bleedIconStyle`-стиль запросов — по одному редкому слову). Для HDS-вопросов теперь ПЕРВЫМ идёт RAG (kit «UI Design Kit»), декомпилят ArkGram — вторым как источник продуктовых значений.
- Повторный тик подтвердил паттерн на всех трёх моих ложных «нет»: (2) build-profile/hvigor — киты «Configuration Files» (все поля build-profile.json5), «Troubleshooting Build Errors» (коды 00306042/00303015 — резолвить ошибки hvigor ПО КОДУ через RAG), Packing Tool-маппинг minAPIVersion←compatibleSdkVersion / targetAPIVersion←targetSdkVersion; (3) SymbolGlyph — страницы EN/CN есть («ellipsis_message» находит, «SymbolGlyph sys.symbol» фразой — нет); полный каталог имён символов по-прежнему только в id_defined.json SDK.
### 2026-07-10 Эмулятор-2: CLI-старты убивает сторож CheckSnapshotBooting (mNowBootArguments=0)
- What happened: после смерти hdc-моста у живого гостя (порт 5555 исчез, netstat пуст, isRunning=true) убил инстанс и перезапускал через schtasks — каждый бут умирал на ~21-й секунде. crash_server.log дал дословный диагноз: «CheckSnapshotBooting: Emulator snapshot boot timeout, try to restart» → «KillEmulator <pid>» → «RetryColdBootOnSnapshotFailed: mNowBootArguments size is 0, could not to restart».
- Root cause / insight: (1) при CLI/schtasks-старте сторож не получает boot-аргументов и ждёт БЫСТРЫЙ snapshot-restore (~20с) даже при isHotBoot=false и `-bootMode coldboot` (флаг легален: coldboot/reset/snapshot — но сторожа не переубеждает); полный cold boot HarmonyOS-образа в таймаут не влезает → сторож убивает гостя. DevEco-старт передаёт mNowBootArguments — потому из студии эмулятор живёт. (2) Обход «душить сторожа»: schtasks /run + цикл `taskkill /IM emulator-crash-service.exe /F` каждые 5-6с — дал один успешный добут до «Connect OK», но сторож возрождается лаунчером и в 6-сек окно успел ресетнуть VM. (3) Повторные заходы дорожают: CheckSign образов на измученном диске — минуты (system.img 447с!), лаунчер в это время «пустой» (~140MB) и порт ждать рано. (4) «Прошлый результат 0» у schtasks-задачи ≠ эмулятор жив: лаунчер выходит 0, если счёл инстанс уже запущенным (stale isRunning в момент /run). (5) taskkill/schtasks в Git Bash — ВСЕГДА MSYS_NO_PATHCONV=1 (иначе /PID превращается в путь).
- Next time: стабильный подъём — попросить пользователя запустить из DevEco Device Manager (сторож получает аргументы и сам делает корректный cold-рестарт). Автономный обход — kill-цикл сторожа с шагом ≤3с ДО появления hdc-порта; перед /run проверять isRunning=false через `Emulator -list -details`; смерть моста у живого гостя диагностировать по netstat 55xx + crash_server.log, не по qemu.log.
- ПОДТВЕРЖДЕНО следующим тиком: рецепт воспроизводим — чистый isRunning=false → убить пустой лаунчер → `/run` → цикл `sleep 3; taskkill crash-service; probe tconn` дал Connect OK за 21с (отдохнувший диск = быстрые CheckSign); при подавленном стороже install/aa/uitest работают штатно, гость стабилен. После холодного бута экран на локскрине — unlock-свайп слать ПОСЛЕ полной отрисовки (первый ушёл в пустоту), «Нет сети» в статус-баре первые ~минуту — норма, радио догоняет.
### 2026-07-10 Драфт-reply: TDLib «ok» ≠ «поле принято» — сверять с td_api.tl
- What happened: draft с reply сохранялся «успешно» (Draft response: ok), но восстановление давало reply 0. Наш сериализатор слал плоское `"reply_to_message_id"`, а схема нашей сборки TDLib (tdlib/td/generate/scheme/td_api.tl:2997) требует ОБЪЕКТ: `draftMessage reply_to:InputMessageReplyTo` → `{"@type":"inputMessageReplyToMessage","message_id":N}`. TDLib молча игнорирует неизвестные поля и возвращает ok — поле просто выбрасывалось. Тот же мёртвый формат читали оба парсера (chatFromTd и ChatNormalizer) — симметричная ошибка маскировала себя в юнит-логике и вскрылась только live E2E.
- Root cause / insight: (1) канон формата — локальный td_api.tl сборки, не память и не старые сниппеты; (2) «ok» от TDLib подтверждает конструкцию запроса, не семантику каждого поля; (3) отправку и парсинг одного поля менять СИНХРОННО во всех местах (сериализатор + cold-парсер полного объекта + update-нормализатор — их всегда ТРИ); (4) E2E-восстановление после полного выхода — единственный честный витнесс для persist/restore пар.
- Next time: перед сериализацией нового TDLib-поля — grep td_api.tl на точную декларацию. uitest keyEvent-серии без пауз теряются (26 Backspace → стёрлось 17) — вставлять sleep 0.2 между нажатиями; для чистки композера надёжнее посимвольный цикл с паузой + контроль остатка dumpLayout.
### 2026-07-10 Независимое ревью дневного диффа поймало real-bug: edit-режим × debounce
- What happened: свежий debounce-persist драфта (вчерашняя фича) молча ломал редактирование: композер один на все режимы, setEditMode заливает текст правки в composerDraftText, onTextChange ставит debounce — через 1.5с текст ПРАВКИ уходил как драфт чата, затирая серверный драфт («Draft: <правка>» в чат-листе). Нашёл независимый ревью-агент по диапазону dbe284f..HEAD; я верифицировал цепочку по коду и зафиксил тремя гвардами (debounce/persist skip в edit + kill таймера в clearEditMode(true)). Бонус-фиксы: перерезолв безликого reply-чипа после прихода истории; @type-гвард на draftMessage.reply_to (external-reply с другого девайса не утечёт как локальный id).
- Root cause / insight: (1) мультирежимный композер (draft/edit/forward/attachment) — ЛЮБАЯ новая persist-логика вокруг composerDraftText обязана явно перечислить режимы, в которых она валидна; e2e-витнесс фичи прогонялся только в «обычном» режиме — edit-пересечение вскрыло только ревью; (2) ревью-агент по диапазону коммитов дней — дешёвый ход (один real-bug + 2 risk за прогон), его findings обязательно верифицировать самому по живому коду перед фиксом.
- Next time: после пласта с фичей на разделяемом состоянии — прогнать матрицу режимов этого состояния (edit/forward/attach/search); негативный E2E-витнесс («лога НЕТ») снимать с чистого hilog -r буфера. Ревью диапазона — в конце каждого крупного дня.
### 2026-07-10 413 тестов, которые никогда не запускались: раннер без Hypium-бутстрапа
- What happened: aa test «висел» — TestAbility стартовала и молчала. Диагноз через минимальный pure-hypium сьют: висли не импорты сьютов (гипотеза ревью), а сам бутстрап — OpenHarmonyTestRunner вызывал голый testsuite() (регистрация describe/it без движка), а TestAbility вообще не звала Hypium.hypiumTest. Канон (JsUnit User Guide, RAG по «hypiumTest»): Hypium.hypiumTest(abilityDelegator, abilityDelegatorArguments, testsuite) в TestAbility.onCreate. После фикса — ПЕРВЫЙ в истории репо прогон: 413 тестов, 411 pass сразу.
- Root cause / insight: (1) «ohosTest-компайл green» годами маскировал то, что тесты никогда не исполнялись — компиляция ≠ исполнение; (2) первый настоящий прогон немедленно окупился: production-баг в classifyTdlibError (ветка code >= 500 без верхней границы съедала неизвестные коды как retryable NETWORK) + две тест-неточности (неполный стор → use case правомерно шлёт getUser-обогащение; fallbackTitle: с юзером в сторе имя юзера приоритетнее title чата); (3) хвост aa test-вывода — OHOS_REPORT_RESULT: «Tests run/Failure/Pass»; фейлы искать по OHOS_REPORT_STATUS_CODE: -N (1 = start, 0 = pass).
- Next time: полный прогон = `hvigorw --mode module -p module=entry@ohosTest -p product=default assembleHap` → `hdc install -r <ohosTest hap>` (main HAP тоже, если менялся main-код!) → `aa test -b com.telegram.harmonyos -m entry_test -s unittest /ets/testrunner/OpenHarmonyTestRunner -s timeout 30000`. Гонять после пластов, трогающих core/domain/infra. timeout N в Bash-обёртке НЕ использовать — убивает hdc-клиент до вывода.
- Дважды за день клики уходили в ЧУЖОЕ приложение (Settings поверх; после Back — лончер, тап открыл звонилку): ЛЮБАЯ серия uiInput-кликов начинается с подтверждения фронта — dumpLayout с проверкой знакомого текста нашего экрана, только потом клики. Back-выходы в конце сценария оставляют app в фоне — следующий тик обязан начинаться с `aa start`.
### 2026-07-10 Typing не приходил вовсе: сессия без TDLib-опции online невидима для volatile-апдейтов
- What happened: 13 пустых UI-заходов + сырые логи (0 updateChatAction за 3×4 мин, все контакты «не в сети») → grep: setOption('online') не вызывался НИГДЕ. Telegram-сервер шлёт typing-экшены и живые статусы только сессиям, объявившим себя online (официальные клиенты ставят опцию на каждый foreground). Фикс: команда setTdlibOnline (setOption + optionValueBoolean) из AuthSideEffect.onAuthReady. ДОКАЗАНО: после фикса 9 сырых chatActionTyping/Cancel событий в hilog (чат 8207051071, период ~5.5с). UI-момент разминулся на секунды — datapath TDLib→normalizer подтверждён, рендер остался на live-подтверждение.
- Root cause / insight: (1) «код фичи полный, но событие никогда не наблюдалось» — сначала проверять ПРЕДУСЛОВИЯ ПРОТОКОЛА (opt-in опции сервера), потом свой датапуть; (2) диагностическая лестница, которая сработала: UI-заход → raw-лог в нормализаторе → send-лог cpp → grep опций; (3) hilog -r ПОСЛЕ клика стирает логи самого клика (Opening chat потерян) — чистить буфер ДО действия; (4) info-лог надёжнее per-domain debug на эмуляторе; (5) normalizer уже ведёт stats.byUpdateType — готовый инструмент «какие типы вообще приходят», не забывать про него.
- Next time: для «серверных» фич (typing, статусы, читы-индикаторы) первым делом сверять список TDLib-опций официальных клиентов (online, notification settings); онлайн-декларацию расширить foreground/background-переключением (сейчас только auth-ready) — polish-пункт.

### 2026-07-10 M1 runtime: тему переключает системный Settings UI, а свежесть процесса доказывает PID
- What happened: строка приложения `Оформление` отрисовывалась clickable, но в `SettingsPage.ets` у неё нет callback, поэтому тап не менял экран. Светлая тема была включена через настоящий `com.huawei.hmos.settings` → `Экран и яркость` → `Светлый` с `uitest`; `persist.ace.darkmode` не использовался. На этом API-эмуляторе `aa force-stop -b <bundle>` ошибочно трактует bundle, рабочий синтаксис из `aa help` — `aa force-stop <bundle>`. После корректного stop/start `ps` STIME отставал от `date` примерно на 33 секунды, хотя процесс гарантированно исчезал и PID менялся (`8042` → `8502`, TIME `00:00:00`).
- Root cause / insight: Settings-строка без action — только визуальный affordance; theme witness должен идти через system Settings UI. `ps` STIME на этом образе нельзя считать единственным доказательством свежести из-за рассинхрона emulator wall clock; наблюдаемая пауза без процесса + новый PID — независимый witness. Установка только entry HAP сохранила TDLib-сессию.
- Next time: тему менять `aa start -a com.huawei.hmos.settings.MainAbility -b com.huawei.hmos.settings` → дальше только `uitest dumpLayout/uiInput`; fresh start делать `aa force-stop com.telegram.harmonyos`, дождаться пустого `ps`, затем start и записать before/after PID. Standalone ohosTest HAP поверх рабочей сессии не устанавливать.

### 2026-07-10 M2a runtime: `ps -ef` перед `-split` нужно trim-ить
- What happened: fresh-process цикл действительно дал отсутствие процесса и PID `25199 → 26101`, но первый PowerShell-парсер записал пустые PID/TIME: строка `ps -ef` начиналась пробелами, поэтому `-split '\s+'` создал пустое поле с индексом 0.
- Root cause / insight: сырой табличный вывод shell нельзя индексировать до нормализации; правдой остаётся сохранённая raw-строка, а derived fields должны вычисляться из `line.Trim() -split '\s+'`. Для before/after UI сравнения также нужно фиксировать тот же процесс эмулятора, а не только одинаковый target `127.0.0.1:5555`.
- Next time: сохранять raw `ps -ef` строку первой, затем парсить только trimmed value; в runtime evidence писать emulator PID/start time, HAP hash, process-absence, before/after app PID и `TIME`.

### 2026-07-10 M2b capability spike: documented HDS wiring can still fail the target runtime
- What happened: Contacts used the documented same `Scroller` for `List` and `HdsNavigation.bindToScrollable`, plus native Search/material. `contentStartOffset` immediately collapsed the title; an in-list spacer fixed that but first overlapped Search, then FREE mode clipped the title on scroll. Explicit `HdsNavigationTitleMode.MINI` still rendered large title glyphs clipped at `[56,137][487,151]` on target 26 / Pura API23.
- Root cause / insight: source/API correctness does not prove compatible HDS layout behavior for this root/status-bar composition. After three bounded layout attempts, the correct result was rejection and byte-for-byte rollback, not another magic inset. Also, ohosTest compilation did not catch a `Blank` nested directly under `ListItem`; only a clean main entry build reported that `Blank` must be inside `Row`/`Column`/`Flex`.
- Next time: capability spikes need an early runtime stop condition and rollback backup. Run a clean main build before trusting an ohosTest compile, and keep native title/search replacement out of production until the exact target/runtime combination passes unclipped top and scrolled states.

### 2026-07-11 Composer runtime: typed platform APIs still need absent-result and external-action guards
- `cameraPicker.pick` is typed as returning `PickerResult`, but the API23 emulator returned `undefined`; guard the result before reading `resultCode` and report the hardware/runtime boundary instead of crashing.
- Microphone permission can outlive the initiating long press, so preparing state must queue send/cancel/lock until permission + `AVRecorder.start` completes.
- For voice UI witnesses, prefer drag-up lock followed by delete. Releasing a real recording sends externally; do not use that as a test unless sending is explicitly authorized.

### 2026-07-11 Composer visual parity: features do not satisfy the alignment gate
- The first C2 pass added behavior but left the last voice bubble ending at the physical viewport (`y=2880`) behind the composer (`y=2618`); a screenshot alone made the overlap obvious, while source/build gates stayed green.
- `Scroller.scrollEdge(Edge.Bottom)` and bottom `initialIndex` did not honor the floating composer reliably. `scrollToIndex(last, false, ScrollAlign.END)` is still the correct bottom-alignment primitive, but `contentEndOffset` alone only changes the end position of scroll content; it does not shrink the List viewport during IME/composer resize.
- API23 adaptive blur with a nearly transparent tint needs an explicit 0.75vp edge on separate attach/mic/lock circles and a primary icon tint. Also hide the List scrollbar so it cannot cross the trailing mic.
- Acceptance is geometry + runtime: dump bounds before/after and keep user approval separate from technical completion.

### 2026-07-11 Composer action state: transform one slot instead of moving the action
- Putting send inside the text capsule while hiding the external mic changes both grouping and width exactly when typing begins; it reads as a new control fused into the input rather than the mic changing state.
- Keep one trailing 40vp action node mounted after the capsule and switch only its icon/material/callback. Runtime `dumpLayout` must show identical idle/send bounds; here both are `[1140,1575][1280,1715]`, with only the background changing from glass to `#FF3390EC`.

### 2026-07-11 Bot Menu parity: panel visibility is part of the button state
- Telegram iOS drives `MenuIconNode` from `.menu` to `.close` when `showCommands` changes and renders commands in a glass input-context panel above the composer; a detached system `showActionMenu` loses both relationships.
- On HarmonyOS, render the command context panel in-flow above the composer at full chat width and use the same page-owned visibility state for the three-lines/X morph. Anchoring a screen-width surface to the narrow Menu button produces offset/clipping. The closed glyph is three horizontal lines, not dots.
- iOS also derives `menuButtonExpanded` from `!inputHasText`: empty input shows icon + title, while any typed character collapses it to the 40vp icon-only control. Drive that branch from the live `TextArea` buffer so the width changes in the same frame as typing, not one parent-state update later.

### 2026-07-11 Compact composer: shrink visuals, not the touch contract
- A denser 38vp composer can preserve platform ergonomics by expanding each primary control with ArkUI `responseRegion` to at least 40×40vp; reducing the layout box alone would violate the HarmonyOS minimum touch-target guidance.
- A scrolling popup viewport is not an item limit. Truncating `bot_info.commands` to six silently removed legitimate server commands; render the complete TDLib array and limit only the visible height.
- Reference hierarchy matters across panel types: emoji/stickers are input nodes in the keyboard slot, but Telegram iOS attachments are an `AttachmentController` modal container (Android: `ChatAttachAlert` bottom sheet). Use native ArkUI `bindSheet` for presentation and keep Camera/Photo/Video/Document routing in the existing controller.
- The same split works for long-press actions: the controller returns a typed action model and executes the selected index; the row owns the anchored glass popup. This removes `promptAction.showActionMenu` without moving reply/edit/copy/forward/pin/delete behavior into page rendering code.

### 2026-07-11 Composer focus motion: caret state precedes text state
- If a control must react when the cursor appears, `text.length` is one interaction late. Track `TextArea.onFocus/onBlur` separately and derive Menu expansion from `!focused && text.isEmpty`.
- Animate both the disappearing label and the parent row reflow; animating only icon opacity leaves attach/input/action controls snapping horizontally.
- Keep custom auxiliary-surface motion centralized for bot context and anchored message actions; native sheets should keep their platform transition instead of imitating a custom popup transform.

### 2026-07-11 Adaptive title island: percentage width defeats intrinsic sizing
- ArkUI official guidance confirms that a child `width('100%')` inside a constrained auto-sized component is resolved from the maximum constraint; the short chat title therefore expanded to the full center slot even though the outer capsule had a minimum width.
- Let the title/status `Column` keep its intrinsic width and constrain only the glass parent; on API 20+ make that contract explicit with `LayoutPolicy.wrapContent`. Account for padding separately: a 152vp content minimum plus two 12vp insets produces the intended 176vp visible floor.
- Shared emulator ownership matters: another session driving HOSKEY can take foreground between `uitest` actions. Stop automation rather than treating a foreign-app screenshot as a Telegram witness.
- Independent glass controls must also be independent at the background layer: retaining `TgTopChromeBackground` under correctly shaped capsules still reads as one full-width panel. In chat detail, let wallpaper/timeline show through and apply material only to the capsules.
- When shrinking visual boxes below 40vp, move the touch contract into tokens and recompute centered `responseRegion` offsets. Hard-coded `-1/40` regions became wrong as soon as 38vp controls moved to 36vp; visual density and interaction density must change independently.

### 2026-07-11 Pinned-message jump: visual aggregation must retain source identity
- `getChatPinnedMessage` can point to any member of a media album, while `ChatTimelineVO` renders the album as one row whose primary `messageId` may differ. Matching only the primary id loads the correct history window but never completes the visible jump.
- Every aggregated row must carry all source message ids. Route jump/search/reply consumers through `timelineEntryContainsMessageId`, then center the target with `ScrollAlign.CENTER` so floating top/pinned chrome cannot hide it.
- A pinned-panel X is local presentation state, not an implicit server unpin. Keep destructive/server mutation behind an explicit action; reopening the chat may show the real pinned message again.

### 2026-07-12 Composer avoidance: reserve viewport geometry, then preserve bottom intent
- A floating composer can look correct at idle yet lose the latest bubbles when `KeyboardAvoidMode.RESIZE` shortens the page. Reserve the measured composer height in the content layer so List `y2` follows composer `y1`; do not use end offset as a viewport substitute.
- `TextArea.onFocus` can arrive after child layout has already changed visible indices. Capture whether the timeline was at bottom on `TouchType.Down`, then reapply `ScrollAlign.END` from page `onAreaChange` and composer-height changes. Do not auto-jump users who were reading older messages.
- Runtime acceptance needs three bounds witnesses: idle, focused IME, and long multiline draft. Here List/composer edges were `2654/2653`, `1597/1596`, and `1170/1170`, with the last ListItem ending at the List edge every time.

### 2026-07-13 Composer input modes: focus is not the same as showing IME
- Closing a custom emoji panel and calling ArkUI focus alone can leave `TextArea focused=true` while the soft keyboard stays hidden. The keyboard-mode button must focus through `UIContext.getFocusController().requestFocus` and then call `inputMethod.getController().showTextInput()`.
- Clear custom emoji/sticker state on `TouchType.Down`, before `TextArea.onFocus` and the IME resize pass. Otherwise the custom panel survives long enough to be pushed above the keyboard instead of being replaced by it.
- A media permission prompt can appear over an already-open `SheetSize.LARGE`; keep the sheet functional in loading/empty states. Do not fabricate thumbnails when the emulator PhotoAccessHelper library is empty—record the real empty-state witness and verify populated rendering from real `PhotoAsset.uri` on hardware later.

### 2026-07-13 LazyForEach cache must participate in Lottie visibility lifecycle
- A static chat can still run a full render loop when `LazyForEach.cachedCount` retains animated Canvas rows outside the viewport. Host CPU alone only showed the symptom; a 3-second `hitrace` exposed four repeated `CanvasPaintMethod::UpdateContentModifier` calls on every app VSync.
- `@ohos/lottie 2.0.29` explicitly documents cache/preload as a case where automatic Canvas visibility tracking can fail. Bind each `CanvasRenderingContext2D` with `bindContext2dToCoordinator` before Canvas creation, then destroy the animation and call `unbindContext2dFromCoordinator` on disappearance.
- Verify the same idle state before/after. Here `File` chat changed from `4.13` to `0.46` host cores and from `260` Canvas render tasks / `65` app VSyncs to zero in the same 3-second trace window; chat-list-only measurements would have missed the defect.

### 2026-07-13 Entity keyboard has two independent navigation axes
- Telegram iOS `EntityKeyboard` treats GIF, Stickers and Emoji as peer pager modes in the bottom panel. Favorites, Recent, Premium and installed sticker packs are content groups in a separate top panel. Putting GIF beside pack thumbnails conflates these axes and makes later search/settings behavior impossible to match.
- Do not paint a Favorites tab without data. TDLib already exposes `getFavoriteStickers`; keep the request typed through `AppCommand` and the serializer, cache the resulting real sticker cells, and omit the group when it is empty.
- A clean ArkTS build proves structure and types, not geometry. When runtime is deliberately parked, record visual acceptance as pending instead of promoting source parity to a screenshot-level claim.

### 2026-07-13 Telegram custom emoji are formatted-text entities, not decorative sticker cells
- Telegram iOS enables Unicode and custom emoji in the same `EmojiPagerContentComponent`; TDLib exposes the art as installed `stickerTypeCustomEmoji` packs but sends a selection as `textEntityTypeCustomEmoji(custom_emoji_id)`, with the int64 id preserved as a JSON literal.
- Static grid previews may reuse the sticker download path, but tap handling must keep fallback Unicode and the exact UTF-16 offset/length entity together. A preview-only grid that appends plain Unicode is not custom-emoji support.
- The current plain ArkUI `TextArea` gives no attributed edit delta. Until a rich editor owns spans, clear tracked custom entities on manual edits rather than risk sending stale offsets; keep runtime visual/data acceptance separate from clean source/build gates.
- `getInstalledStickerSets(stickerTypeCustomEmoji)` can truthfully return zero even when Telegram has featured custom-emoji packs. Use typed `getTrendingStickerSets(stickerTypeCustomEmoji)` and parse its distinct `trendingStickerSets` response; deduplicate it after installed ids rather than fabricating pack tabs.
- A synthetic Unicode tab alone must not reserve an otherwise empty horizontal pack strip. Render the strip only when at least one real installed/featured pack exists; API23 proved the intended path with `0` installed, `12` featured and a real `150`-item `Crayons Emoji` set.

### 2026-07-13 GIF search is an inline-bot transaction, not a saved-animation filter
- Resolve `animation_search_bot_username` (fallback `gif`) through `searchPublicChat`, then call `getInlineQueryResults` with the target chat and TDLib `next_offset`. A saved-GIF list and local text filtering are different products and must not be labeled search.
- Keep every `inline_query_id` as an exact decimal string across parser, UI VO and serializer; JavaScript numeric conversion can silently corrupt TDLib int64 values. Send the selected `result_id` with `sendInlineQueryResultMessage` and use direct `inputMessageAnimation` only for saved GIFs.
- ArkUI `Grid.onReachEnd` may fire when content does not fill the viewport or during rebound. Pagination therefore needs request/query/mode/lifecycle checks plus an in-flight and unchanged-offset guard before accepting another page.
- TDLib `minithumbnail.data` is already a low-resolution immediate preview. Feeding its Base64 JPEG directly to ArkUI `Image` avoids blank `?` cells; adding realtime `.blur()` to several visible Base64 cells caused a RenderService `SERVICE_BLOCK` on the API23 emulator and must not be treated as free polish.
- Before automated text input, check `ime -g`. A third-party keyboard can take foreground and invalidate the witness; temporarily switching to `com.huawei.hmos.inputmethod` made `TextInput` focus/input deterministic, and the original IME was restored after the run.

### 2026-07-13 Archive is a parallel TDLib chat list, not a filtered main list
- A chat can carry independent `chatPosition` entries for `chatListMain` and `chatListArchive`; preserving only the first position loses archive order/pin state and can leak archive-only chats into the main fallback list. Normalize and sort each list independently, then let `updateChatPosition` drive both.
- The archive group badge counts unread dialogs, not the sum of unread messages. The latter produced a plausible but visibly wrong `9.6K`; the iOS runtime comparison exposed it immediately and the corrected account value is `11`.
- ArkUI `Button(text)` reserves internal text padding and clipped the Russian Pin label inside a swipe action. A custom `Button { Column { icon; Text } }` with explicit zero padding preserves the compact iOS action hierarchy and localization width. SVGs used through `Image.fillColor` must expose a fill path; `currentColor` stroke assets do not inherit that tint on the API23 runtime.

### 2026-07-13 Calls filters need both query isolation and physical title-bar clearance
- Changing All/Missed must invalidate the previous request generation, clear the accumulated opaque TDLib offset and issue a fresh `searchCallMessages(only_missed=...)`; a selected capsule alone proves no data-path change.
- An HDS `bottomBuilder` owns visual title-bar height, but a custom `List` still needs an explicit matching start offset plus a small separation gap. The first implementation was source-correct yet visibly covered the first avatar.
- Telegram iOS uses short status strings (`Incoming`, `Outgoing`, `Missed`) in the call list. Reusing verbose message-bubble strings made Russian subtitles wrap and broke the right date/info cluster.

### 2026-07-13 Root surfaces need locale-safe text extraction and runtime title-state witnesses
- Harmony resource locales can arrive as underscore tags such as `ru_RU`; normalize them to BCP-47 (`ru-RU`) before `Intl.Collator`, and retain a fallback because an invalid tag throws rather than silently sorting.
- `charAt(0)` is not a valid initials/section strategy for names prefixed by flags or emoji. Scan for the first supported alphabetic character so the avatar and index model agree.
- `contentStartOffset` can move content without defining a safe viewport. Put the title clearance on the actual `List`/`Scroll` viewport and verify top plus scrolled states.
- On target 26 / API23, `HdsNavigationTitleMode.FREE` still collapsed the Settings title into the status bar even with `enableComponentSafeArea`. `FULL` kept the native HDS title safe; this defect was invisible to source and build checks and required a runtime scroll witness.

### 2026-07-13 Scroll-to-bottom unread badge needs a page-retained read boundary
- Telegram iOS feeds the chat-location unread count into the 40vp history navigation button and centers a 20vp badge at `y=-7`; placing the count at the corner produces a different control.
- This client calls `markChatRead` immediately after rebuilding the visible chat, so binding the badge directly to `chat.unreadCount` makes it disappear before the user can use it. Capture the entry value, only raise the retained value on later updates, and clear it when the viewport reaches the true bottom or the user presses the button.
- Runtime acceptance needs the state delta, not only an atom demo: API23 showed `62` at the unread divider, then the button press removed the badge/control and reached the latest message without sending anything.

### 2026-07-13 In-chat search pagination needs the server cursor and an explicit entry path
- `foundChatMessages.total_count` is not the loaded page size, and the next request must use TDLib's opaque `next_from_message_id`; deriving a cursor from the last timeline row can silently repeat or skip results. Prefetch before the 100-result edge and prove the intended path through a `loaded ... more` log plus a counter beyond 100.
- Conditional search fields are not reliably focused by construction alone. Mount the `TextInput`, then request its stable id through `UIContext.getFocusController().requestFocus` on the next frame so the system IME follows.
- Preserve the iOS avatar/info action in group/channel top bars. Search belongs in Peer Info for that state; a one-shot chat-id signal can unwind the profile stack and open the same chat in focused search mode without replacing the avatar with a second search button.

### 2026-07-13 Peer Info navigation is two material islands, not a transparent icon row
- Telegram iOS `PeerInfoHeaderNavigationButtonContainerNode` gives Back and trailing actions separate glass containers with a 16pt side inset and 44pt button contract. A transparent full-width Row with naked glyphs preserves taps but not the shipped hierarchy.
- Keep compact visual geometry separate from interaction geometry: the accepted Harmony controls remain 38vp circles, while `responseRegion` restores the 44vp iOS/platform target.
- ArkUI `systemMaterial` owns background, border and shadow on the native path, so do not layer manual visual attributes over it. Keep adaptive blur/tint/edge only in the API23/fallback builder and prove absence of a full-width plate from the runtime screenshot.

### 2026-07-15 Entity-keyboard settings must load its own data path
- The settings gear is reachable from Emoji before the regular Sticker panel has ever mounted, so reusing only `stickerSetTabs` produces a plausible but false empty sheet. Entering settings must start the regular sticker-pack load independently of the currently visible entity-keyboard mode.
- Keep the peer-mode pill centered with symmetric side slots; placing the gear directly after the pill shifts the control and breaks the iOS geometry.
- A native `bindSheet` is the platform chrome; the installed-pack rows remain custom Telegram content backed by the existing TDLib model.

### 2026-07-15 Recent stickers is a grouped home, not another pack grid
- Telegram iOS composes Saved/Favorites, Recent and all-Premium ordered lists; mirror that hierarchy with real `getFavoriteStickers` and bounded `getPremiumStickers`, and omit only the group whose response is empty. Search and explicit pack tabs remain separate grid states.
- A native `bindSheet` host guarantees platform presentation behavior, not Telegram visual correctness. Reusing the 3%-alpha composer glass with `SheetSize.LARGE` produced a plausible but wrong fullscreen transparent overlay; the runtime witness only moved after separating the sheet surface and constraining it to the iOS-like 67% lower region.
- Keep native transition/dismiss behavior and custom Telegram content as separate contracts: dedicated navy background, top-only sheet rounding, custom 36×4vp grabber and selected-category state. An empty emulator media library is valid evidence for the empty branch, not permission to invent a populated grid.

### 2026-07-15 Nested minimum width can defeat a correct parent max constraint
- `TgMessageRouter.constraintSize(maxWidth)` did not protect a child with fixed `minWidth: 240`; after the avatar lane and a second all-around padding layer, the poll remained wider than the available bubble lane and ArkUI laid it out past the left edge. The official ArkUI contract is explicit that `constraintSize` takes precedence over width/height, so parent and child constraints must agree.
- Telegram iOS already encodes the right rule: poll minimum is `min(280, constrainedWidth)`. Pass the actual available width into the atom, clamp the minimum, and assign inner insets to exactly one owner. Use separate tokens for the 12pt control axis and 50pt text/result axis rather than recovering the geometry through accidental nested padding.
- When the account has no safe live dataset, a temporary synthetic page may exercise the real production router for geometry only, but it must be removed before the final clean build and followed by a production-entrypoint reinstall witness. Never turn a synthetic poll into a claim about TDLib voting behavior.
- A plausible row of emoji does not prove the Premium path. Runtime acceptance needs the grouped screenshot, `getPremiumStickers` count and real preview delta. Here `TdObject.getNumber('id')` silently matched nested string `remote.id` before the file object's numeric `id`, produced zero and prevented every preview request; nested `file` objects must use `getTopLevelNumber('id')`.
- Request only the visible Premium/Favorite cells (`8 + 4`) with asynchronous `downloadFile`, then consume `updateFile` through `FilesState.transfers`. This produced real previews in about two seconds without blocking the panel or fanning out a whole pack; keep emoji as the immediate fallback and retain lifecycle/request deduplication.

### 2026-07-15 Broadcast channels own a different width policy
- Telegram iOS does not solve broadcast-post width by raising the ordinary bubble ratio. `ChatMessageBubbleItemNode` marks `.broadcast` as `allowFullWidth`, then reserves 45pt for the incoming share action (3pt without it). Model this as a semantic chat state, not a global compact-width tweak.
- Derive the state once from the real `Chat.type === 'channel'` value at the page boundary and pass it into `TgMessageRouter`; private/group rows must not infer it from sender/avatar presentation. Runtime acceptance must include a non-channel control.
- Prove the intended branch by measuring the same message lane before and after. Here the channel bubble grew by 136px while the 1224px lane stayed fixed, and the live group retained its avatar-aware width path.

### 2026-07-15 Adjacent actions need the visual bubble edge, not a full-width component host
- `TgMediaBubbleShellV2` painted a 300vp bubble but its root `Row.width('100%')` still occupied the full message lane. Adding Share as the next sibling therefore produced a valid 30vp button whose original bounds began beyond the parent and were clipped to 14px. A clean build did not expose this.
- Constrain the custom-component host to `visualMediaBubbleWidth()` before placing an iOS-style adjacent action. On API23 this moved the button from clipped `[1294,1244][1308,1349]` to fully visible `[1120,1244][1225,1349]` and made the measured bubble/button gap exactly 8vp.
- Wire the compact visual to an expanded `responseRegion` and an existing controller path. Visual size, touch size and domain action are separate contracts; runtime acceptance needs both layout bounds and the resulting picker/navigation state, while a non-channel control prevents accidental global decoration.

### 2026-07-15 Root tabs must react to the keyboard avoid area, not field focus
- A centered overlay can make a native ArkUI `Search` visually correct but non-focusable inside full-screen overlay chrome. Use a blocking idle activation layer only to request the stable Search id, then remove that layer on `Search.onFocus`; do not replace the native caret, selection or IME path.
- Hiding `HdsTabs` synchronously from `Search.onFocus` rebuilt the shell before the IME appeared: the field remained `focused=true`, but the keyboard never opened. Observe the documented `window.AvoidAreaType.TYPE_KEYBOARD` event instead, and collapse the existing native HDS bar tuple only after the keyboard owns a bottom avoid area.
- Fully transparent geometry can still intercept taps. At the terminal Search-collapse state, set the outer row to `HitTestMode.None` and prove the intended path by tapping the overlapping filter rail and observing both selected-background and real-list deltas.

### 2026-07-15 Glass over scrolling content needs a surface-specific veil
- A generic 3%-alpha navigation token looked correct over a static header but let a full-width chat bubble recolor the API23 title island. Keep the realtime blur, but give the chat top bar its own qualified translucent tint; do not globally darken ChatList/Profile/Forward or replace the independent capsules with a full-width plate.
- A shared emulator can invalidate an otherwise successful capture without a command error: another session brought HOSKEY to the foreground between `uiInput` and `snapshot_display`. Verify the foreground screen/bundle before crediting each witness, quarantine mismatched captures, and stop runtime automation when another task is actively using the device.

### 2026-07-15 Root-tab unread is an aggregate, not a loaded-row count
- Telegram iOS drives the root badge from `renderedTotalUnreadCount`, while TDLib supplies the matching main-list aggregate through `updateUnreadMessageCount`; counting loaded chat rows silently changes the unit and breaks as soon as pagination or archive data is involved.
- Use an explicit unknown sentinel plus a loaded-main-only fallback until the first aggregate update arrives. Keep the badge as custom item content inside native `HdsTabs`, so data/Telegram geometry can be custom without taking ownership of the platform island, material or motion.
- Runtime `4.6K` is an intended-path witness here: the previous code could only produce a small loaded-chat count and clamped values above 999 to `999+`.

### 2026-07-15 Shared-element ownership must stop at the media surface
- A working `geometryTransition` is not sufficient evidence of a correct transition. Binding it to the outer media-bubble shell produced a smooth but wrong animation that scaled the entire long caption into fullscreen.
- Match Telegram iOS `transitionNode` ownership: attach the shared identity to the photo/video node, temporarily hide only that source node while preserving its layout, and keep caption, reply, sender and message metadata outside the geometry host.
- Capture the transition, not only its endpoints. The before/after contact sheets exposed the shell-level defect and then proved that open/close now move only the media while gallery caption chrome stays fixed.

### 2026-07-15 Shared Media thumbnails need exact file ids and updateFile completion
- `TdObject.getNumber('id')` can silently match a nested string `remote.id` before the numeric TDLib file id. The resulting `0` looks like “no thumbnail” and prevents the request path entirely; nested `file` objects must use `getTopLevelNumber('id')`.
- Bounded concurrency does not fix head-of-line blocking when every worker awaits `downloadFile(synchronous=true)`. Shared Media should request only the current Grid range with `synchronous=false`, then resolve paths from `FilesState.transfers` on `updateFile`.
- Runtime acceptance needs both the blank→loaded visual delta and command-path evidence. Here the first viewport and a newly scrolled viewport populated in about three seconds while logs showed bounded request pairs followed by `FilesReducer fileDownloaded` updates.

### 2026-07-15 Shared Media direct actions should reuse chat controllers
- Telegram iOS routes Peer Info media through `chatControllerInteraction.openMessage` / `openUrl`, and Telegram Android likewise dispatches each Shared Media kind to its normal viewer/player/browser path. Do not create a second gallery, downloader or audio controller inside Profile; pass a typed one-shot action back to the owning chat and invoke the existing bubble handlers there.
- Preserve the exact URL while building the Shared Media row. Media captions must be classified for the URL filter before photo/video/file branches, otherwise a plausible link row can navigate without knowing what to open.
- Native Preview Kit availability is a probe, not proof that the content rendered. Log `canPreview`, try `openPreview`, then keep the system `viewData` fallback; for the emulator's `.md` sample the intended Preview Kit path engaged, but the platform still reported that no installed viewer supported the format.

### 2026-07-15 Peer Info members need two TDLib paths
- The unfiltered supergroup roster needs pageable `getSupergroupMembers(supergroupMembersFilterRecent, offset, limit)`, while query/basic-group states need `searchChatMembers`; treating the two methods as interchangeable silently loses either pagination or server-side search.
- Preserve both `messageSenderUser` and `messageSenderChat` plus creator/admin/custom-title metadata. Anonymous administrators are chat identities, not malformed users, and the custom Telegram row should hydrate names, avatars and presence from the live stores.
- A member tap can open the existing Profile surface by `userId` without creating a private chat. Hide chat-only controls when no `chatId` exists; runtime acceptance should cover initial load, a query delta, a page beyond 100 and the direct-user destination.

### 2026-07-15 Chat-list preview types are data, visible labels are resources
- TDLib/DTO placeholders such as `[Sticker]` and `[ChatAddMembers]` are useful locale-free transport values but must not become UI strings. Map content, bracket, service and typing states to one stable preview kind, then resolve the label at the `ChatItemVO` boundary.
- Keep the mapping pure enough for focused tests and keep localization in resources. This prevents the loaded-message path and the chat-level `lastMessage` fallback from drifting into different wording.
- A green build cannot prove the localized path engaged. The API23 delta from `Photo` to `📷 Фото` plus a visible dump with zero raw brackets proves resource resolution while the native HDS chrome stays untouched; a live sticker/service row remains opportunistic rather than something to fabricate in the user's account.

### 2026-07-15 Reply originals are relationship-scoped associated data
- `getRepliedMessage(chat_id, replying_message_id)` may return an original whose actual `message.chat_id` differs from `reply_to.chat_id`. Validate the target message id, but keep relation chat and returned origin as separate identities; rejecting or inserting that object into normal history is wrong.
- A reducer-level test does not prove the event reaches production state. New event types must be added to the root reducer route and guarded by a source contract; the missing route produced successful TDLib responses and plausible logs with zero UI delta.
- `LazyForEach.onDataChange` did not refresh frozen `@ComponentV2 @Param` values on API23. Put reply author/preview state into a compact render stamp while preserving a stable identity key for diff/scroll anchoring, then prove the intended path with a visible placeholder-to-content delta.

### 2026-07-16 Intrinsic title decorations need shrink, not weight
- `layoutWeight(1)` makes a short ArkUI `Text` own all remaining Row width, so following mute/verified icons look right-aligned even though their source order is correct.
- Match Telegram iOS `titleLayout.trailingLineWidth`: keep the title intrinsic and apply `flexShrink(1)` only for overflow. Fixed decorations then remain adjacent, while the separate `TgChatMeta` lane still protects date/status/badge geometry.
- Verify the intended path from `uitest dumpLayout`, not a visual guess: the live title ended at `x=715`, mute began at `x=729`, and time meta remained at `x=1149`.

### 2026-07-16 Archive unread is an inactive group-reference state
- Telegram iOS explicitly sets the archive `GroupReferenceData` unread tuple's muted flag to `true`; the aggregate is neutral even when individual archived chats contain unmuted messages.
- Reuse the existing `TgChatMeta` inactive style instead of creating an archive-only badge. This preserves compact-count formatting, size and alignment while changing only the semantic color state.
- A same-count color delta is a stronger witness than two unrelated screenshots: live `15` moved from dominant badge RGB `50/143/236` to `183/182/188` with identical text bounds `[1203,766][1259,836]`.

### 2026-07-17 Shipped color calibration must engage the semantic runtime path
- Measure a stable flat region in the current shipped screenshot instead of copying a stale source constant or judging the hue from memory. Here the supplied iPhone reference yielded approximately `#1E2E3D` incoming and `#406D97` outgoing.
- Change only the qualified semantic resources when hierarchy and behavior are already correct. This keeps light theme, atom composition and native HDS chrome outside the patch.
- A resource assertion and green build do not prove that the live component consumed the value. Pair them with a runtime node witness; the actual API23 bubble `Stack` backgrounds became `#FF1E2E3D` and `#FF406D97`.

### 2026-07-17 Stateful accent and glass-control foreground are different semantics
- A global Telegram-blue icon token can be valid for active state, links and online/activity copy but wrong for neutral navigation glyphs inside the current shipped glass chrome. Scope the foreground at the component contract rather than weakening the global accent.
- Use the qualified primary foreground for neutral Back/Search/Close: it follows dark/light theme automatically and leaves platform material, tint and interaction behavior native.
- Pixel-class delta is useful when `uitest` cannot expose an image tint attribute. The same fixed ROIs changed from `323/409` blue-like pixels to zero and gained `510/620` white-like pixels, proving that the glyph path—not merely the capsule—changed.

### 2026-07-17 A max-width cap can create a false vertical-layout defect
- The text layout engine already had the correct two-pass rule: reserve time/status inline when `lastLineWidth + gap + metaWidth` fits. A stale compact cap of `0.75` made that correct branch miss by a narrow margin, so the same message looked like an inline-meta bug.
- Reconcile tokens against the canonical source/passport before changing layout math. Telegram iOS uses `freeMaximumFillFactor = 0.85` for compact lanes and `0.65` for regular layouts; the repository comment already recorded that while the executable value contradicted it.
- Prove the branch with one stable message, not unrelated screenshots. `edit-guard-test-plus-edit` widened `696px -> 920px` and shortened `161px -> 98px`; the time/status moved from a dedicated row to the text baseline while intrinsic shrink-wrap remained active.

### 2026-07-17 Edited status is model state, not a text heuristic
- A visible message body that looks edited proves nothing about its state. Preserve TDLib `message.edit_date` on full-message parsing and register the separate `updateMessageEdited` event; `updateMessageContent` intentionally does not carry the edit timestamp.
- Measurement and rendering must consume the same localized `edited + time` composition. Otherwise a plausible label can still overflow or force a stale inline/separate-row decision.
- A green parser test or resource assertion is not the runtime witness. Searching the stable live message and observing `изменено 07:42` in the actual `TgMessageMeta` node proves the intended end-to-end path; the dedicated row on the narrower API23 viewport is adaptive overflow behavior, not a regression.

### 2026-07-17 Outgoing secondary is not global secondary or Telegram accent
- Telegram iOS routes outgoing date/status through `theme.message.outgoing.secondaryTextColor`; time, edited copy and delivered/read checks form one bubble-aware semantic, while pending and failed states remain distinct.
- Do not retune global `text_secondary` to fix an outgoing bubble: that silently drifts ChatList, incoming meta and unrelated chrome. Add one qualified resource and bind only the outgoing meta/status tokens.
- Prove the semantic path with a same-node pixel delta. On the stable live `изменено 07:42` ROI, pixels near the new pale-blue semantic changed `0 -> 1460` and pixels near the old grey changed `749 -> 0`; a resource-file diff alone would not prove engagement.

### 2026-07-17 Sticker status is freeform service chrome, not image-media chrome
- Telegram iOS explicitly selects `FreeIncoming` / `FreeOutgoing` for both static and animated stickers; image/location overlays use a different status type and can legitimately keep a stronger background.
- In the default dark iOS theme the free-date fill is black at 20% alpha. Reusing the 40% image-media overlay creates a plausible but visibly heavy black blob on a transparent sticker.
- Hold geometry and content constant when validating a surface-only correction. The API23 `11:16` pill retained identical text/pill bounds while its dump background changed exactly `#66000000 -> #33000000`, isolating the intended semantic path.

### 2026-07-17 Interactive-file secondary copy belongs to the outgoing bubble palette
- Telegram iOS selects one incoming/outgoing `messageTheme` in `ChatMessageInteractiveFileNode`: voice duration uses `fileDurationColor`, audio/file copy uses `fileDescriptionColor`, and inactive waveform bars use `mediaInactiveControlColor`. All three outgoing paths map to outgoing secondary text; active playback maps to outgoing primary.
- Canvas does not accept a `Resource` directly. Resolve the qualified resource through `getUIContext().getHostContext()` and `resourceManager.getColorSync(resource.id)`, then pass the returned numeric color to `strokeStyle`; keep a neutral fallback for the exceptional path.
- Prove that resource resolution—not the fallback—engaged: the same two Canvas bounds lost the old 30%-white composite (`1796/2198 -> 0`) and gained the dark-qualified `#9BBDE0` class (`0 -> 1958/2578`), while fallback-grey pixels remained zero.
- iOS renders the outgoing `SemanticStatusNode` with outgoing-primary fill and a clear foreground. A custom ArkUI icon cannot punch transparency into its parent, so use the qualified bubble fill for the glyph/ring to reproduce the same visual cut-out across play, pause, download, progress and cancel states. The runtime control retained its bounds while Telegram-blue pixels fell to zero and white-primary pixels rose above 16K.
- Do not model voice duration as a trailing third column. `ChatMessageInteractiveFileNode` lays waveform and duration vertically (`18pt` waveform, duration at `y=22`) and derives width from the `2...30s` duration interpolation. On API23 this removed `119px` from the short `0:04` voice while keeping the longer `0:11` bubble wider and preserving both `44vp` controls.
- Do not translate iOS `statusOffset=-10` into a blind `10vp` overlap. The voice progress frame starts at `y=-3` and its status reference is shifted by `+8`, so relative to a `44vp` Harmony control the effective overlap is `5vp`. The runtime delta reduced voice height `301px -> 199px` while leaving a measured `5px` gap between duration and timestamp glyphs.

### 2026-07-17 Anchor unread restore to the semantic marker, not its date neighbor
- A preceding date entry is not a stable proxy for an unread boundary. When older messages from the same day prepend, the date key stays at the start of that day while the unread marker moves deeper into the list; `maintainVisibleContentPosition` can therefore keep the wrong item visible without any error.
- Capture `lastReadInboxMessageId` and unread count before navigation because `viewMessages` may reset the live TDLib fields before `NavDestination` finishes. Treat TDLib `"0"` as a valid first-incoming boundary, not as a missing snapshot.
- Restore once to the marker's exact index, including the late around-unread window path. The API23 witness centered the live full-width bar and label at the same `(654,1410)` point after same-day history expansion.

### 2026-07-17 Bubble grouping belongs to the shared shell, not the content type
- Telegram iOS content nodes describe whether they need a background or force full corners, but merged-neighbor geometry is owned by `ChatMessageBubbleItemNode`. A contact, venue or poll must not silently fall back to a standalone radius just because it has a dedicated content branch.
- Route every background-bearing family through the same `top / middle / bottom` resolver. Static branch coverage matters here because rare contact/location/poll combinations are hard to guarantee in a live account without sending test content.
- Pixel conversion must be bound to the active UI instance. Replacing deprecated global `vp2px` with `this.getUIContext().vp2px` removed the build warning while API23 retained the exact `28x49px` rendering of an `8vp x 14vp` tail.

### 2026-07-17 Peer role precedes presence in the chat title
- A bot can carry an `online` user status, but Telegram iOS resolves `botInfo` before generic presence and shows the bot role instead of an online indicator. Rendering raw presence first turned the real `zai` bot into an ordinary user even though `UserDto.isBot` was already correct.
- Treat title subtitles as product semantics, not transport strings: bot role, presence, activity, members/subscribers and zero-count channel/group labels must all pass through app-language resources before reaching the visual atom.
- Prove the semantic branch on stable live peers. The same API23 Russian title node changed `online -> бот`, while a real broadcast with no member count changed `channel -> канал`; unchanged capsule geometry isolates localization/classification from layout.

### 2026-07-18 Gallery gesture ownership must change with zoom state
- A parent photo recognizer that accepts every pan axis at `1x` silently steals horizontal paging from the surrounding `Swiper`; a parent exclusive tap group can likewise swallow nested download/cancel controls. Keep remote controls outside that recognizer and release any axis the photo does not own.
- Match direct manipulation, not just the final scale. Double tap uses the local tap point, while pinch must preserve the content point under `pinchCenterX/Y` even when the two-finger center translates; every transform then passes through the same contained-media bounds resolver.
- Static source/build gates can prove the arbitration policy exists but not that ArkUI dispatches it as intended on the device. Final acceptance needs one fresh sequence: `1x` horizontal swipe changes the gallery index, zoomed horizontal swipe pans without changing it, and reset restores the baseline geometry.
- A gesture constructor is not a reliable reactive state switch: changing one `PanGesture.direction` expression with `photoScale` compiled but did not prove that the recognizer was rebuilt. Keep vertical-dismiss and all-axis zoom as separate tagged recognizers, then return `CONTINUE`/`REJECT` from `onGestureRecognizerJudgeBegin` using the current scale.
- The final API23 sequence closed the gate: `17 / 76 -> 18 / 76` at `1x`; after zoom the same horizontal swipe remained `17 / 76` and visibly panned; reset restored the baseline crop byte-for-byte after JPEG decode (MAD `0.0`); vertical swipe then dismissed.
- When launching a named HVD through PowerShell, quote the HVD name inside `-ArgumentList` (`-start "Pura 90 Pro Max"`). Passing it as two unquoted arguments makes the emulator launcher exit without starting the device.

### 2026-07-19 Visible Lottie optimization needs a live-path witness
- Recheck pacing hypotheses against current hilog before editing. The real `@ohos/lottie 2.0.29` looper already reported `30 HZ` from the per-animation setting, so adding a global `setFrameRate(30)` would have produced no intended-path delta.
- Canvas transforms are not a safe proxy for a smaller software backing surface in this ArkUI Lottie path. Scaling either the Canvas or its parent kept `animation start for drawing` and `loopComplete` logs alive while the sticker pixels disappeared; only the runtime screenshots exposed the regression, so the experiment was reverted.
- Stable `2.0.32` improves lifecycle robustness but is not a renderer-performance change. Near-identical visible traces and noisy host CPU must be reported as no attributable improvement; keep the P1 open. Preserve Telegram iOS default looping rather than hiding the cost with a static thumbnail or emulator-only bypass.

### 2026-07-19 Native rlottie pixels and Canvas upload are separate contracts
- ArkUI `ImageData(width, height)` defaults to logical `vp`, but its `Uint8ClampedArray` backs physical pixels. Render native frames at `getUIContext().vp2px(...)`; feeding logical dimensions into the physical buffer produces a plausible but wrong strip/partial frame.
- Telegram/Nekogram rlottie exposes numeric ARGB32, whose little-endian memory bytes are already RGBA for Canvas. Only undo premultiplied alpha; swapping R/B again turns Telegram pink/cyan/red art into purple/yellow/blue.
- Correct pixels and perfect offscreen lifecycle do not prove a faster renderer. Full-frame native render plus `putImageData` averaged `3.736` host cores against `2.371` for `@ohos/lottie`; reject it as the default and move the next spike to a direct native surface/XComponent path.

### 2026-07-19 Multi-pin state must come from the filtered collection
- `getChatPinnedMessage` answers only the current pinned message and cannot prove either the total or the current stripe position. Use `searchChatMessages` with `searchMessagesFilterPinned`; preserve `foundChatMessages.total_count` and the opaque `next_from_message_id` as a string.
- TDLib returns pinned search results newest first, while the iOS title-panel stripe counts toward the newest item. Map result index `i` to `totalCount - 1 - i`; never infer a plausible `0 / 1` state or use `lastMessage`.
- A page-level cursor guard matters because a repeated opaque cursor can otherwise loop forever. The live acceptance must cross the first page, not merely show the initial list: API23 moved from `#2548` through the 100-result boundary to visible `#2434...#2421`.
- Reversible spatial continuity is part of navigation behavior. The pinned list enters and exits along the same right-edge path with `responsiveSpringMotion`; an intermediate runtime frame proves that the transition actually engaged rather than appearing only as a final screenshot.

### 2026-07-19 Navigation cancellation must release caller-owned guards
- On the current API23 runtime a bare `NavPathStack.pop()` could remove the picker visually without dispatching the `pushPathByName` result callback that owned the duplicate guard. Pop a typed cancellation result when the caller relies on that callback to restore interaction state.
- A single successful open does not cover this failure mode. The acceptance sequence must be `open -> Back -> open again`; two distinct destination ids prove the first transaction actually released its guard.
- Reusing the Forward picker is an honest functional bridge for selecting an existing dialog, not full iOS Compose parity. Current Telegram iOS uses a contacts-backed surface with `New Group`, `New Contact`, and `New Channel`; keep unsupported actions absent rather than shipping clickable no-ops.

### 2026-07-19 Remote peer search must not rebuild contact UI per TDLib update
- A search response can arrive behind a large TDLib update burst. Rebuilding/sorting the complete reactive contact list on every `users` state identity change turned three valid search requests into `THREAD_BLOCK_6S` before their promises could settle.
- Coalesce store-driven rebuilds from the latest state behind one lifecycle-guarded timer, and cap primitive `user_ids/chat_ids` before any sequential `getChat/getUser` hydration. A UI timeout alone would not remove the update storm.
- Verify both cold and warm behavior. The same API23 cold query survived without a new fault after the fix; cached search then completed in about 0.9 s, and an actual overlapping q1→q2 run sent both request sets while only q2 rows reached the UI.

### 2026-07-19 Server commit and navigation hand-off are different states
- Once an authoritative TDLib creation response arrives, a hydration or `NavPathStack.pop(result)` failure must not return the page to an idle state that can submit the same creation again. Retain the committed result and retry only hydration or result delivery.
- A plausible final screen is not enough: exercise cancellation, return to the caller and reopen the route. The API23 Channel form returned directly to Compose, Compose returned to ChatList, and the top-right action opened it again without a stale guard.
- ArkUI `CommonMethod.align` defaults to centered content. Short form `Scroll` surfaces therefore need explicit `Alignment.TopStart`; source/build checks did not reveal the defect, while the first runtime capture did.

### 2026-07-19 Native HDS visual collapse does not prove hit-box collapse
- API23 rendered a plausible expanded mini-bar while the native `TabBar` retained its idle full-width hit layer above the entire Search field. Inspect runtime bounds and z-order; screenshots alone cannot reveal this interception. Collapsing the selected tab lens to the iOS active `48vp` geometry removed the overlap.
- Keep the real ArkUI `Search` mounted while the HDS lens is collapsed. Then the user's first tap creates the native input session and `onFocus` can drive expansion; a detached custom idle button plus manual IME request can produce a focused-looking field without a correctly resized app surface.
- Do not synchronously call `clearFocus()` from the expanded Close click. The resulting IME resize can move the dock before pointer dispatch finishes and deliver the same tap to an underlying chat row. First mark the dock closing/inert and start `COLLAPSE`, then clear focus with `setTimeout(0)`; verify both the final geometry and absence of navigation.
- `KeyboardAvoidMode` is window-wide state, not a permanent property of one field. A first activation can resize correctly while the next activation overlays the keyboard after another surface changes the mode. Restore `RESIZE` on the native Search touch-down and require `open -> close -> open` runtime geometry, not a one-shot witness.

### 2026-07-19 Album transfer state must stay member-local and authoritative
- Telegram iOS treats ordinary photos and videos differently: a remote photo requests its exact resource and remains in chat, while the existing remote-video path may enter the gallery immediately.
- Carry the changed `fileId` through the controller signal so only the owning album row repaints; when gallery items rebuild, move the hidden/return source identity to the current resolved member.
- Authoritative failure must override an optimistic pending hint, otherwise the spinner never releases into retry. Fast cached media proves request/progress but cannot close cancel/retry acceptance; use a slow uncached resource.

### 2026-07-19 Fresh process and ready UI are separate runtime gates
- A fresh app PID/STIME proves that the new HAP process started, not that its first frame is ready. On API24 the first capture after launch was a blank app surface while the same PID rendered ChatList twelve seconds later.
- Gate visual acceptance on a non-empty expected UI tree or named screen node after confirming process freshness; an arbitrary short sleep can turn a valid build into a false visual failure.
- Theme qualification should be witnessed twice: the system Settings radio state proves light/dark selection, while the app layout colors prove that the qualified `base`/`dark` resources actually engaged.


### 2026-07-29 Смена policy-контракта обязана тянуть за собой grep по ohosTest
- Прошлая teamwork-сессия поменяла union `TgPhotoAlbumTapMode` (`'download'`/`'none'` → `'downloadAndOpen'`/`'open'`), прогнала smoke-build + smoke-ui и объявила победу, но `TgMediaGalleryPolicy.test.ets` остался на старом контракте. `assertEqual('download')` принимает произвольную строку — суженный union компиляцию теста НЕ ломает, падение случилось бы только на on-device прогоне.
- Компиляционные гейты (main + OhosTestCompileArkTS) не свидетельствуют о согласованности строковых ассертов с типами. При изменении любого resolver/policy-контракта — сразу `grep -rn <имя функции> entry/src/ohosTest` и правка таблицы истинности в тесте.
- Незакоммиченный рабочий срез чужой сессии — не «сделано»: аудит той сессии сам себя проверял теми же смоками и пропустил тест. Повторная верификация в новой сессии (свои smoke-build/smoke-ui/ohosTest) заняла ~4 минуты и дала право коммитить.
