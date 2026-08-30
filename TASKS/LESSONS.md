# LESSONS — repeated mistakes and project-specific pitfalls

Last updated: 2026-08-31

## 122. Аудит 08-31: токены централизуют значения, «рецепты» — нет; гейты и слоты проверять матрицей, не памятью
- Урок 121 (рецепт стекла) перенесли в 3 файла, а старый `backgroundBlurStyle` остался в ~10 поверхностях — включая «общий» примитив `TgTopChromeBackground` (мёртвый: consumer только demo). Токен-правка значения расходится везде автоматически; правка рецепта живёт рукописно в `build()` каждого атома и сама никуда не расходится. Стеклянные волны делать через централизованный примитив/политику, не точечными правками «по памяти».
- Гейт нативного материала вручную дублировался в 6 поверхностях как `apiAvailable('26') && useBlur()` БЕЗ emulator-чека (против `TgGlassPolicy.supportsNativeMaterial()`) — на API 26 эмуляторе такие поверхности уходят в плиту ImmersiveMaterial. Правило: платформенный гейт — только через централизованную политику; локальные копии условия = будущий рассинхрон.
- Компосер рендерился в ЛЮБОМ чате (единственный isDisabled = `activeChatId===0`), а в iOS нижняя панель — полиморфный слот из 8+ панелей по статусу/правам (`ChatInterfaceStateInputPanels.swift:13`: Subscriber/Restricted/DeleteChat/Unblock/Handshake/…). Формулировка «готово» в STATUS читалась шире реальности; «сделано» по фичам сверять греп-матрицей состояний, а не по памяти о срезе.

## 121. Стекло в ArkUI: backgroundBlurStyle ≠ стекло на эмуляторном GPU-пути
- Симптом «сплошных плашек»: капсулы топ-бара/компосера с `backgroundBlurStyle(COMPONENT_ULTRA_THIN)` + тинтом выглядели непрозрачными плитами, хотя на референсе iOS — стекло с просвечивающим контентом. При этом полосы фейда на `backdropBlur` БЛЮРИЛИ контент на том же экране.
- Корень: `backgroundBlurStyle` — системный материал окна; на эмуляторном GPU-пути он коллапсирует в непрозрачную плашку (стиль почти не влияет: и THICK, и ULTRA_THIN). `backdropBlur(radius)` сэмплит РЕАЛЬНО нарисованный контент за нодой внутри приложения — работает и даёт настоящее стекло.
- Правила: (1) стекло над контентом приложения = `backdropBlur` + полупрозрачный тинт (клип по радиусу обязателен, это обычный кейс); (2) `backgroundBlurStyle` — только для системных поверхностей (bindSheet blurStyle) и нативных material-путей API 26 (`ImmersiveMaterial`); (3) `renderGroup(true)` снимать с backdropBlur-нод — группа изолирует слой и может убить сэмпл бэкдропа; (4) тинт под стекло должен быть заметным, но не глухим: dark ~40-60%, light ~70-75% (стекло без тинта невидимо, с глухим тинтом — плита снова).
- Диагностический приём: сравни два механизма на одном экране — если градиентные полосы блюрят, а капсула нет, виноват механизм материала, а не GPU в целом.
- Смежное: (1) iOS-эталон (App Store Messages.png, 2026-08) — контент за рядом тайтла ОСТАЁТСЯ читаемым; густой фроз только в статус-стрипе → тиры blur сверху вниз: STRONG (status) → MID (title row) → SOFT → 0, не сплошная стена STRONG на весь бар. (2) Скрим/блюр компосера прижат к нижней кромке экрана (dock-look), а не висит над капсулой; над верхом капсулы — только одна зона растворения. (3) `aa force-stop -b <bundle>` на этом образе может падать «package not installed» при живом процессе — работает позиционный `aa force-stop <bundle>`; `kill -9` из hdc shell запрещён (не root).

## 120. Среда эмулятора после обновлений Windows: слои лжи и лестница фолбэка
- Принудительный ребут от TrustedInstaller (KB-пакет 2026-08-28, включилась VBS) сломал гостя API 26 Beta1 детерминированно: фриз на ~100-й секунде бута (3/3 прогонов, kernel.log обрывается mid-line в фазе init), при этом API 24 образ на том же хосте бутится нормально → взаимодействие образ/драйвер/гипервизор, не проектный код. Не дебажить гостя вечно — держать рабочий фолбэк-инстанс (API 24) и детектить фриз: stall kernel.log ≥3 мин + hdc shell по таймауту.
- Ошибка `devecocli emulator start`: «system image cannot be found, download it again» — обёртка минимум ТРЁХ разных корней: (а) разовый таймаут spawnSync на проверке подписи PowerShell (лечится повтором), (б) префлайт CLI не видит isPublic=0 Beta1 в своём каталоге (лечится прямым запуском `Emulator.exe -start "<name>"`), (в) реальный гейт места: `CheckRuntimeEnv: "No enough space to start Emulator"` в инстансовом `Log\Emulator.log` (порог `freedisk` из config.ini, KB). Истину искать в `deployed\<name>\Log\Emulator.log`, не в тексте CLI.
- Бут требует свободного места больше, чем `freedisk` (конфиг 6ГБ): 7.8ГБ свободно — отказ, 30ГБ — проходит. Образ ~4.4ГБ + userdata qcow2 растёт.
- НЕ смертельные строки каждого бута: `SnUtil "can not read uuid file"` / `"can not read sn"` (после BootComplete) и `BootComplete: "the image is non-public", "User not logged in"` — норма Beta1, не чинить и не выдумывать маркер-файлы в Temp (рукотворный `Temp\<uuid>\uuid.data` ломает ранний путь через ReadSnFromDevManager «отказано в доступе»).
- `sdk-pkg.json` образа: `data.path` обязан совпадать с именем папки на диске (обрыв распаковки оставил `HarmonyOS-7.0.0-B1` при регистрации `HarmonyOS-7.0.0`) — правится точечной правкой метаданных (backup в %TEMP%\deveco), но сам по себе старт не разблокирует.
- `qemu HeartBeat stop!` в Emulator.log = гость умер внезапно посреди сессии. TDLib-сессия переживает рестарт эмулятора + `aa start` без перелогина (проверено на API 24) — рестартовать дешевле, чем реанимировать зомби.

## 119. Петля измерения: высота контейнера из @Local, измеряемого ребёнком этого же контейнера
- Оборачивая компосер в Stack с `.height(composerTotalHeight)` ради бэкдропа-перелива, получил схлопывание компосера до TextArea 8px (witness: `uitest dumpLayout`): Stack фиксированной высоты ограничивает замер детей → компосер сжимается → `onAreaChange` докладывает сжатую высоту в `composerTotalHeight` → Stack сжимается ещё → петля сходится к минимуму контента.
- Правило: НЕ пинить высоту контейнера величиной, которая измеряется (`onAreaChange`) от ребёнка внутри этого же контейнера. Рецепт здесь: Stack обнимает контент (backdrop выше компосера просто переливается вверх — Stack не клипает), компосер сохраняет интринсик-высоту на дне оверлея.
- Диагностика лейаута за 2 минуты: `hdc shell uitest dumpLayout -p ...` даёт точные bounds нод; тапы `uitest uiInput click` — в СЫРЫХ px дисплея (1320x2232), не в vp и не в нормализованных координатах скриншота.
- Прогрессивный блюр в ArkUI: нативного градиентного блюра нет — рабочий паттерн «ступени + скрим»: 2 backdropBlur-полосы (14→7) + чисто градиентный хвост, стопы одного оттенка с wallpaper-base (`chrome_fade_*`). Семантика направления (урок 120-эра, сверено с доками и кодлабом): `direction` — сторона, КУДА движется градиент; стоп-0 стоит на ПРОТИВОПОЛОЖНОЙ стороне (`Bottom` = стоп-0 сверху). Сводить оба билдера к одному соглашению: `Bottom` + стопы по порядку сверху-вниз.

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
