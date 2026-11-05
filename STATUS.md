# STATUS — Telegram-HarmonyOS

Current state only. Every superseded dated snapshot, and the pre-compaction version of this file,
lives in `TASKS/ARCHIVE/STATUS-history-2026-10-18.md`. Reports referenced here are immutable
checkpoints — see `docs/reviews/INDEX.md` for all 81 of them.

## Where it stands — 2026-10-23

| Area | State |
|---|---|
| Receive scheduling (drain) | **Accepted.** Bounded correction, 15/15 regressions, independent Astra review. |
| Receive-drain topology / slice budget | **Closed — no change.** Null result on threads; shipped pacing measured 2026-10-23 (~2.8–3.1× slower than the zero-delay model, −18 % from 8→64 ms, frame ordering non-monotone); `DRAIN_BUDGET_MS` stays 8. |
| Main reliability (request timeouts) | **PARTIAL.** 2/4 observed timeouts on the exact official package; root cause not established. |
| Source publication | `dev` pushed to `origin/dev`, CI green on `d706143`; six probe/docs commits since, not yet pushed. |
| Install over authenticated main | **Not done** for the correction. Not released, not signed. |
| Notifications / push | **Absent.** No `notificationManager` / `wantAgent` / push code in `entry/`. |
| Authenticated delivery / providers / shipped-iOS / signing | **Open** since 2026-09-27. |

## Latest checkpoint — 2026-10-21…23

**Receive-drain investigation closed, and its own measurement corrected.** Three days of synthetic
work asked whether the drain should move off the main thread and whether its slice budget should
change. A Worker arm and a main arm were indistinguishable once arrival timing was fixed; a budget
sweep then reported that 8 ms was the worst setting. On 2026-10-23 that sweep was corrected: it
yielded with a zero delay while the shipped drain schedules its next slice at
`max(2, min(250, elapsed × 2))`, so its time column belongs to a model the app does not implement. The
"measured hop counts" were arithmetic (no counter existed), and the "8 ms consumer work" quantum was an
injected artificial delay, not an observation. **Recommendation withdrawn; `DRAIN_BUDGET_MS` stays 8;
no receive-drain work is open.** [Topology](docs/reviews/2026-10-20-drain-topology-spike.md) ·
[sweep](docs/reviews/2026-10-21-drain-budget-sweep.md)

**The shipped pacing was then measured, not just predicted.** An isolated bundle ran both yield models
back-to-back on the emulator, n = 3 per budget: the shipped drain costs ~2.8–3.1× the zero-delay model
(5461 vs 1950 ms at 8 ms on the same 1288 ms of work), its budget curve is −18 % from 8 → 64 ms
instead of −27 %, and its frame gaps are non-monotone (207 / 285 / 216 / 130 ms). The 2026-10-21
headline "8 ms is worst on both axes" is therefore not reproduced; the constant still does not move,
because the gain is half the claimed one and the host is an emulator. The host itself is a 2014 Xeon
with a 97 %-full disk, so every absolute millisecond in that run is an upper bound.
[Re-run](docs/reviews/2026-10-23-drain-yield-model-rerun.md)

**Worker NAPI door opened, then not needed.** The native TDLib module loads and answers inside an
ArkTS Worker on the emulator, and the running process reports TDLib 1.8.61 — which closed the
"is the shipped binary 1.8.60?" half of the provenance question.
[Report](docs/reviews/2026-10-20-worker-napi-probe.md)

**TDLib pin aligned, provenance still open.** The submodule is pinned at `11e254af6`, whose
`CMakeLists.txt` declares 1.8.61; the exact upstream revision that built the shipped `.so` remains
unrecorded. [Report](docs/reviews/2026-10-19-tdlib-version-provenance.md)

**Competitor artifact re-checked.** The ArkGram note was corrected on 2026-10-23: the analysed package
is 1.0.1 (not 3.2), `compileSdk 26.0.0.23 / Beta1`, several previously listed platform APIs are absent
from every retained artifact, and the concurrency result — no ArkTS worker/taskpool usage — is the part
that stands. [Report](docs/reviews/2026-10-21-arkgram-analysis.md)

## Repository tidy-up — 2026-10-24

Documentation and repository structure were reconciled; no product code changed.

- **F6-sticker-pack-paging (lead).** Листание по стикер-паку: `StickerPackSticker` + парсер `getStickerSet`
  (id/files/thumbnail/emoji/format/размер), `nextStickerPackIndex` (клампинг без зацикливания),
  `buildStickerPackGalleryItems`/`stickerPackStartIndex`, `ChatMediaViewState.stickerPackStickers`/
  `stickerPackPagingIndex`, оверлей подменяет галерею на пак и держит индекс (старт — по `fileId`
  тапнутого стикера), карточка пака остаётся. Новая суита `test-sticker-pack-paging.cjs` (141-я):
  stepping, парсинг пака, элементы, проводка; обновлены `test-sticker-pack.cjs` и
  `test-chat-screen-decomposition.cjs` (125 полей). Гейты: host **141/141**, оба smoke, hvigor BUILD
  SUCCESSFUL. Остаток F6: TGS/предзагрузка соседних файлов, witness.
- **Roadmap rewritten.** `TASKS/AGENT_EXECUTION_PLAN.md` now states the current route only. Release
  Track v2 (R0→R3+, `v0.1.0` as the goal, "pixel fidelity is not a goal") moved to
  `TASKS/ARCHIVE/AGENT_EXECUTION_PLAN_release-track-v2_2026-07-02.md` and is not to be executed.
  `DECISIONS.md` D24 records the mandate change, D25 records which documents are authoritative.
- **Authority resolved.** `docs/ai/*` is an archive (`docs/ai/README.md`); the `tg_ui` master plan keeps
  only its visual-contract role. The open "canon winner" question in `TASKS/TODO.md` is closed.
- **`TASKS/` decluttered.** 10 historical slice plans moved to `TASKS/ARCHIVE/` with an index; 7 active
  documents remain.
- **Docs made truthful.** `README.md` rewritten (API 23 compatible / 26 target, x86_64-only ABI,
  verification matrix, documentation map, emulator gotchas); `ARCHITECTURE.md` scope and reference list
  fixed; test counts corrected to 87 `.test.ets` files; dead links repaired; policy for dead links in
  dated reports documented in `docs/reviews/INDEX.md`.
- **Hygiene.** Removed a stale crash dump and an empty `presentation/viewmodels/` stub; documented that
  `AGENTS.md`/`CLAUDE.md` are intentionally not versioned.

## Engineering protocol — 2026-10-25

Введён обязательный цикл среза и инструменты планирования; код продукта не менялся.

- `TASKS/SLICE_PROTOCOL.md` — преflight (статус/референс/доки), разбор iOS-эталона, швы для
  связанных фич без спекулятивных абстракций, тест до реализации, implementation, gates,
  side-by-side с iOS, Definition of Done, реестр долга.
- `TASKS/SLICE_TEMPLATE.md` — шаблон плана среза (референс → контракт → швы → состояния → тест →
  приёмка).
- `TASKS/CAPABILITY_MATRIX.md` — 105 строк по пользовательским возможностям iOS: 36 `available`,
  56 `partial`, 9 `missing`, 3 `frozen`, 1 `blocked`; `unverified` = 0. У каждой строки —
  код-доказательство и связанные фичи; `available` без witness не ставится.
- `TASKS/WORKMAP.md` — M0 (верифицировать 9 `unverified` строк), S1 (typing indicator, C2),
  S2 (стикеры/TGS, D13).
- `TASKS/TODO.md` — добавлен раздел **Debt**: долг с владельцем и триггером, иначе срез не закрыт.
- Правила зашиты в `AGENT_EXECUTION_PLAN` (preflight + глобальные правила), `AGENTS.md`/`CLAUDE.md`
  (memory pack), `README` (карта документов).

## Slice wave — 2026-10-25

Первый прогон по `SLICE_PROTOCOL`, три агента параллельно + design-срез от lead.

- **S3a (lead).** Данные реакций: `Message.reactions` + чистая модель в `AppState` (порядок chosen →
  count → key, кап 6 + «+N», инкрементальный `applyReactionDelta`), парсер TDLib-снимка и типов в
  `MessageDto`, события `messageReactionsUpdated`/`messageReactionChanged` в normalizer и reducer,
  VO `ReactionChipVO` с stamp'ом в ключе строки только при наличии реакций. Host-тест
  `test-reactions-model.cjs`; D10 → `partial` (рендер и постановка — S3b/S3c). Гейты: host **98/98**,
  оба smoke, hvigor BUILD SUCCESSFUL.
- **S3b (lead).** Подвал реакций: атом `TgReactionsFooter` на примитивах (Flex wrap, «+N»,
  кастомный эмодзи → нейтральный глиф, акцент только для своей реакции), токены и цвета light/dark,
  паспорт и demo. Врезан в текстовый бабл через `TgChatTimelineRow → TgMessageRouter →
  TgTextBubbleV3`; строка пересобирается по reaction-stamp. Host-контракт
  `test-reactions-footer.cjs`. **D10 остаётся `partial`:** медиа-баблы (S3b.1), пикер (S3d) и
  witness не сделаны. Гейты: host **99/99**, оба smoke, hvigor BUILD SUCCESSFUL.
- **S3c (lead).** Постановка/снятие реакции: `SetMessageReactionsCommand` + сериализатор
  (`reactionTypeEmoji` / `reactionTypeCustomEmoji`, int64 строкой, `is_big=false`), use case и
  `ChatReactionController` — оптимистичный снимок записывается до отправки, при ошибке
  восстанавливается предыдущий, guard по токену страницы и по парному тапу, в TDLib уходят только
  chosen-ключи. Тап по чипу доведён от атома до контроллера через session/ports. Host-контракт
  `test-reactions-send.cjs`. Гейты: host **100/100**, оба smoke, hvigor BUILD SUCCESSFUL.
  **D10 остаётся `partial`:** S3b.1 (медиа-баблы) и runtime-witness.
- **S3d (lead).** Пикер реакций: `chat.available_reactions` парсится в `ChatDto`/`Chat`
  (`chatAvailableReactionsAll` / `Some`, `updateChatAvailableReactions`), модель
  `availableReactionKeys` берёт дефолтный ряд iOS (12 реакций) при «all»/неизвестном чате, иначе —
  серверный список с капом 12; `chatAllowsReactions` скрывает пикер, когда чат запрещает реакции.
  Атом `TgReactionPicker` (горизонтальный скролл, токены, spec+demo) врезан над меню действий:
  long-press → попап → тап закрывает меню и уходит в S3c-контроллер. Host-контракты
  `test-reactions-availability.cjs` + `test-reactions-picker.cjs`. Гейты: host **102/102**, оба
  smoke, hvigor BUILD SUCCESSFUL. **D10 остаётся `partial`:** S3b.1 (медиа-баблы), теги,
  runtime-witness.
- **S3d.1 (lead).** Пикер стал per-message: `GetMessageAvailableReactionsCommand` +
  сериализатор (`getMessageAvailableReactions`, int64 сообщения строкой, `row_size=12`), парсер
  `availableReactions` (`top`/`recent`/`popular` + `allow_custom_emoji`/`are_tags`),
  use case, который не бросает исключение (ошибка → пустой снимок). Модель `pickerReactionKeys`
  сливает top→recent→popular с дедупом и капом 12, пустой ответ падает на чатовый ряд. Попап при
  открытии синхронно сеет чатовый ряд и асинхронно заменяет его ответом TDLib; устаревший ответ
  отсекается по generation + lifecycle + chatId + messageId, чат с запретом реакций не получает их
  из ответа. Host-контракт `test-reactions-picker-data.cjs`. Гейты: host **103/103**, оба smoke,
  hvigor BUILD SUCCESSFUL. **D10 остаётся `partial`:** рендер кастомных эмодзи (D16), теги,
  runtime-witness.
- **S3b.1 (lead).** Подвал реакций добрался до медиа: роутер рисует `TgReactionsFooter` под
  фото/видео/альбомом/кружком/гиф, документами/аудио/голосом, контактом/локацией/опросом — вне
  медиа-контейнера, с выравниванием по стороне бабла (как в iOS), и не дублирует подвал текстового
  бабла. Стикер-ветка без подвала: у её колонки фиксированная высота картинки — записано долгом.
  Host-контракт `test-reactions-media-footer.cjs` (наличие 6+ вызовов, отсутствие проводки в
  `TgMediaBubbleShellV2`, сохранение inline-подвала текста). Гейты: host **104/104**, оба smoke,
  hvigor BUILD SUCCESSFUL. **D10 остаётся `partial`:** стикер, геометрия медиа-ряда без witness,
  рендер кастомных эмодзи (D16), теги, runtime-witness.
- **S4 (lead).** Мёртвые контролы из аудита закрыты: Toggle «Notifications» в профиле теперь отправляет
  `SetChatMuteCommand` (откат при ошибке, токен страницы), строка «Data and Storage» удалена до
  появления экрана, мёртвая проводка `attachmentMenuLabels` вырезана из шести файлов, неиспользуемые
  DTO `TdAutoDownloadSettings`/`Presets` удалены. Новый host-guard `scripts/test-dead-controls.cjs`
  не даёт им вернуться. Гейты: host **97/97**, оба smoke, hvigor BUILD SUCCESSFUL.
- **M0 (matrix-verifier).** Девять `unverified` строк верифицированы по коду: B6/C10/D20/D24/H4 —
  `missing`, D29/E1/J5/J7 — `partial`. `unverified` = 0.
- **D16-reaction-picker-emoji (lead).** Кастомные реакции в пикере: `ReactionPickerEmojiState`
  (`@ObservedV2`, `@Trace paths/revision`), `customReactionIds` (разбор `custom:`-ключей),
  `prefetchReactionPickerEmoji` (через общий prefetch-координатор), `syncPickerPaths`. Атом
  `TgReactionPicker` при `aboutToAppear` и смене `keys` синхронизирует состояние, префетчит и рисует
  `Image` вместо fallback-глифа, сохраняя глиф-запас. Новая суита
  `test-reaction-picker-emoji.cjs` (140-я): разбор ключей, наблюдаемое состояние, sync/prefetch/reset,
  проводка атома. Гейты: host **140/140**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток D16: TGS для
  кастомных эмодзи в тексте, набор-пикер, witness.
- **D16-custom-emoji-page (lead).** Prefetch теперь запускается со страницы: `ChatMessageCustomEmojiCoordinator`
  собирает сущности из строк сообщений (текст и подпись), делает один проход на чат (in-flight +
  `resolvedChatIds`, сброс при смене чата), по прибытии файлов вызывает один `rebuildTimeline`; хук стоит
  в `ChatTimelineTransactionCoordinator` сразу после `applyDiff`. Render key строки получил
  `customEmojiRenderStamp` (ноль при пустой карте, иначе хэш по сортированным id+path), поэтому
  перестройка доходит до списка. Суита `test-custom-emoji-render.cjs` расширена (хук, порт, проход, ключ);
  `test-timeline-updates.cjs` получил стаб. Гейты: host **138/138**, оба smoke, hvigor BUILD SUCCESSFUL.
  Остаток D16: TGS-анимация, выбор кастомной реакции, witness.
- **D16-custom-emoji-producer (lead).** Продюсер карты путей: `customEmojiPathCache` (синглтон id→file URI,
  принимает путь или готовый URI) и `CustomEmojiPrefetchCoordinator.prefetch` (сбор pending id из сущностей,
  лимит 64, дедуп, in-flight-набор, запись `localPath`/thumbnail в кэш, ошибки не кэшируются). Чистый
  `buildChatTimeline` заполняет `row.customEmojiPaths` из кэша. Суита `test-custom-emoji-render.cjs`
  расширена (кэш-нормализация, сбор pending, лимит, prefetch, повторный проход без запроса, отказ, чтение
  кэша builder-ом). Гейты: host **138/138**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток D16: вызов prefetch
  из страницы и перестройка строк, TGS-анимация, выбор кастомной реакции, witness.
- **D16-custom-emoji-render (lead).** Цепочка рендера: `splitRichSpans` помечает спан `customEmojiId`,
  `TgTextBodyV3` рисует `ImageSpan` (20 px, CENTER) при наличии пути и глиф-fallback без него;
  `customEmojiPaths` добавлен в row VO и протянут row → router → bubble → body. Суита
  `test-custom-emoji-render.cjs` (138-я): splitter (id на emoji-спане, plain/другие типы, смещённый
  сегмент), наличие ImageSpan/fallback, токен, проводка карты. Гейты: host **138/138**, оба smoke,
  hvigor BUILD SUCCESSFUL. Остаток D16: координатор заполнения карты, TGS-анимация, выбор кастомной
  реакции, witness.
- **D16-custom-emoji-resolver (lead).** Резолвер кастомных эмодзи: `getCustomEmojiStickers` (команда,
  сериализатор int64-массива), `CustomEmojiResolverUseCase` — валидация int64-строк, дедуп, батч ≤50, кэш
  ≤200 с вытеснением, парсер файла/thumbnail/format (TGS/WebM), запрос `downloadFile` при отсутствии файла,
  `invalidate` для повторного чтения после file-update, ошибки не кэшируются. Суита
  `test-custom-emoji-resolver.cjs` (137-я): wire, границы id, парсинг, кэш/батч/скачивание, отказы,
  вытеснение. Гейты: host **137/137**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток D16: рендер картинки,
  выбор кастомной реакции, witness.
- **D16-custom-emoji-entity (lead).** Идентичность кастомного эмодзи в тексте больше не теряется:
  `TextEntityDto.customEmojiId` парсится из `custom_emoji_id`, `TextEntity.customEmojiId` живёт в AppState,
  копируется в двух builder-ах reducer-а (including `cloneMessage`) и в `stateClone` → `CustomEmojiTextEntity`.
  Суита `test-reactions-model.cjs` расширена (`parseMessageContent` с custom-сущностью, поле у обычной
  сущности, клонирование). Гейты: host **136/136**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток D16:
  рендер картинки стикера, выбор кастомной реакции, witness.
- **A5-taken-username (lead).** Ответы TDLib теперь разбираются по типу: `appErrorFromTdlib` различает
  `USERNAME_OCCUPIED` и `USERNAME_INVALID` (специфичный `userMessage`, `tdlibCode`, `requestRejected`),
  `isUsernameTakenError` даёт странице признак, `suggestProfileUsernameAlternatives` строит до трёх
  валидных вариантов (санитайз, буквенный префикс, лимит 32). UI: при занятом username — строка ошибки и
  тапабельные чипы, клик подставляет значение и сбрасывает состояние; строка в base/ru/zh. Суита
  `test-edit-profile.cjs` расширена (mapping трёх ошибок, recognizer, генератор вариантов, UI-проводка).
  Гейты: host **139/139**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток A5: интерактивный редактор, witness.
- **A5-avatar-crop (lead).** Кроп аватара: `avatarCrop` (центрированный квадрат, uniform scale до 512,
  валидация rect) и `AvatarImagePreparation` (decode через ImageKit, `crop` с `Region{size}`, scale,
  JPEG-пакер, запись в `cacheDir`, release pixelMap/source, ошибка → пустой путь). Страница использует
  подготовку вместо прямой копии. Новая суита `test-avatar-crop.cjs` (139-я): квадрат для landscape/portrait/
  square/tiny/мусорных размеров, scale-границы, вся pipeline и release, проводка страницы. Гейты: host
  **139/139**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток A5: интерактивный редактор/зум, «username
  занят», witness.
- **A5-avatar (lead).** Смена аватара: `setProfilePhoto` (команда + сериализатор, `inputChatPhotoStatic` +
  `inputFileLocal`, `is_public`), `EditProfileUseCase.updatePhoto` (trim, пустой путь — ошибка, Ok-контракт).
  На странице — «Change photo»: `PhotoViewPicker` (1 изображение) → копия в `cacheDir` (`fileIo`) →
  `updatePhoto`, busy/notice-состояния и inline-ошибка; 3 строки в base/ru/zh. Суита
  `test-edit-profile.cjs` расширена (wire фото, updatePhoto, валидация, picker/copy-проводка, локали).
  Гейты: host **138/138**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток A5: кроп/редактор, «username
  занят», witness.
- **A5-edit-profile-page (lead).** Экран редактирования: `TgEditProfilePage` (route + `EditProfileRouteParams`),
  поля first/last/username/bio с лимитами, inline-хинт username, счётчик био, Save-гейт, последовательные
  updateName→updateUsername→updateBio, pop по успеху, inline-ошибка при отказе. Вход — шапка профиля в
  `SettingsPage` → `MainTabsPage.pushEditProfile` с текущими значениями (первым добавлены raw-поля).
  Суита `test-edit-profile.cjs` расширена (page/route/entry/локали). Гейты: host **136/136**, оба smoke,
  hvigor BUILD SUCCESSFUL. Остаток A5: аватар, обработка «username занят», witness.
- **A5-edit-profile-data (lead).** Слой данных редактирования профиля: команды `setName`/`setBio`/
  `setUsername` (+payload/фабрики) и сериализатор; `EditProfileUseCase.updateName/updateBio/
  updateUsername` — trim, снятие `@`, лимиты (имя 64, био 70, username 5..32, латиница/цифры/`_`,
  первая буква), пустой username удаляет, строгий Ok-контракт ответа, ошибки `AppError`. Суита
  `test-edit-profile.cjs` (136-я): wire трёх методов, границы валидации, trimmed payloads, отказы
  gateway/не-Ok. Гейты: host **136/136**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток A5: UI-страница,
  аватар, witness.
- **H4-chart-reveal (lead).** Анимация диаграммы хранилища: `revealProgress` 0→1 через `animateTo`
  (420 ms, EaseOut, токен `STORAGE_CHART_REVEAL_DURATION_MS`), ширина сегмента = измеренная доля ×
  reveal, нулевые сегменты не попадают в дерево. Суита `test-data-storage.cjs` расширена (токен,
  aboutToAppear, animateTo, revealedPercent), старая width-ассерта в `test-cache-limit.cjs` обновлена.
  Гейты: host **135/135**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток H4: witness.
- **I1-notification-tap (lead).** Тап по уведомлению открывает чат: `wantAgent` START_ABILITY с
  `parameters.chatId` и UPDATE_PRESENT_FLAG (ошибка агента деградирует в обычное уведомление),
  `chatOpenIntake` (валидация id, take/clear, singleton), `captureChatOpen` в onCreate/onNewWant,
  `MainTabsPage.consumeChatOpen` пушит `ChatScreenRouteParams`; при неавторизованной сессии запрос
  сохраняется до следующего появления. Суита `test-message-notifications.cjs` расширена (intake, wantAgent,
  ability/tabs-проводка); стабилизационный харнесс получил `captureChatOpen` и стаб intake. Гейты: host
  **135/135**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток I1: inline reply, группировка, per-chat
  настройки, witness.
- **I1-message-notifications (lead).** Локальные уведомления: чистый `notificationPolicy` (background +
  входящее + не активный чат + не mute; текст «Имя: превью», caption/медиа-fallback, лимит 160) и
  `MessageNotificationBridge` на NotificationKit (basic text, `requestEnableNotification` с деградацией в
  disabled, уникальные id, ошибки логируются). Runtime получает sink через `setMessageNotificationSink` и
  вызывает его после committed batch; EntryAbility запрашивает разрешение после initialize, чистит sink и
  останавливает bridge в onDestroy; foreground берётся из существующего
  `navigationUIState.applicationForeground`. Суита `test-message-notifications.cjs` (135-я): гейт, текст,
  bridge/runtime/ability-проводка. Гейты: host **135/135**, оба smoke, hvigor BUILD SUCCESSFUL.
  Остаток I1: переход по тапу (wantAgent), inline reply, группировка, witness.
- **D24-inline-translation (lead).** Inline-перевод: `MessageTranslationEvent` → `messagesReducer`
  (клонирование + `translatedText`/`translationVisible`) → row → `TgMessageRouter` → `TgTextBubbleV3`
  (divider с токеном 0.25, блок перевода, плашки «Translated» и «Show original»), тоггл из плашки
  возвращает оригинал; меню ведёт Translate → Show Translation → Show original, кэш остаётся источником
  мгновенного показа. Событие добавлено в routing-таблицу `reducers/index.ets` и в независимую
  expectation-таблицу `test-unread-count-routing.cjs`. 2 строки в base/ru/zh. Суита
  `test-translate-message.cjs` расширена (state/reducer/clone, row/router/bubble, тоггл, локали). Гейты:
  host **134/134**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток D24: выбор языка, witness.
- **D24-translation-cache (lead).** Кэш переводов в контроллере меню: bounded 50 записей по
  `chatId:messageId:lang`, вытеснение старейшей, повторный Translate не ходит в сеть; лейбл меню
  переключается на Show Translation, если перевод уже есть; локальный валидатор кода языка, чтобы сборка
  меню не зависела от модуля use case. Строка `action_show_translation` в base/ru/zh. Суита
  `test-translate-message.cjs` расширена (кэш, per-chat ключ, вытеснение, лейбл). Гейты: host
  **134/134**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток D24: inline-перевод под баблом, выбор языка,
  witness.
- **C2-typing-pulse (lead).** Пульсация typing-точек по iOS (0,7 s): токены длительности/тика/минимумов,
  чистый модель-модуль `TgTypingPulse` (10 шагов, scale 0.6→1, opacity 0.35→1, фаза +3 шага, wrap),
  `TgChatTopBar` держит `typingPulseStep` и interval только когда Typing-подзаголовок видим, сбрасывает
  фазу и чистит таймер при уходе/смене режима. Суита `test-typing-pulse.cjs` (134-я): токены, bounds,
  пик/сдвиг фаз, wrap, шаг, проводка виджета. Гейты: host **134/134**, оба smoke, hvigor BUILD
  SUCCESSFUL. Остаток C2: device witness (анимация).
- **D24-translate (lead).** Перевод сообщений: команда `translateText` (+payload/фабрика),
  сериализатор `_text_json`/`to_language_code`, `TranslateMessageUseCase` (trim, лимит 4096,
  валидация кода языка `xx`/`xxx-YY`, парсер `TranslatedText`, AppError), пункт меню Translate для
  текстовых сообщений; целевой язык — системный (`i18n.System.getSystemLanguage`, fallback `en`),
  результат показывается диалогом, ошибка — тостом. 3 строки в base/ru/zh. Суита
  `test-translate-message.cjs` (133-я): wire с экранированием, парсер, валидация, use case, меню.
  Гейты: host **133/133**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток D24: inline-перевод в бабле,
  кэш, выбор языка, witness.
- **D11-comment-send (lead).** Отправка комментария: `SendMessageParams.topicThreadId`,
  `SendMessagePayload.topicThreadId`, `_topic_id_json` (`messageTopicThread`) в `serializeSendMessage`
  (null для обычных сообщений), фабрика с 5-м аргументом; страница запоминает `threadChatId`/`threadId`
  из `MessageThreadPage` и шлёт comment через composer (`TextInput` + Send, блокировка на время
  отправки, очистка драфта и перезагрузка треда после успеха, ошибка не теряет текст). 2 строки в
  base/ru/zh. Суита `test-message-thread.cjs` расширена: wire топика/обычного send, контракт composer.
  Гейты: host **132/132**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток D11: witness.
- **D11-thread-entry (lead).** Вход в комментарии: `MessageDto.isChannelPost` (`is_channel_post`) и
  `replyCount` (`interaction_info.reply_info.reply_count`) проходят DTO→Message→reducer→VO→rows;
  меню сообщения канала показывает Comments (N) при наличии треда, обработчик пушит маршрут через
  `openMessageThread`/`MessageThreadRouteParams`. Строка `action_comments` в base/ru/zh. Суита
  `test-message-thread.cjs` расширена: парсинг полей, VO/reducer/menu/nav-контракт, route params.
  Гейты: host **132/132**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток D11: отправка комментария,
  witness.
- **D11-thread-page (lead).** Страница комментариев `TgMessageThreadPage` (route `TgMessageThreadPage`,
  params `MessageThreadRouteParams`): заголовок с reply-count, список комментариев (автор из users-store,
  время, текст), пагинация по `next_offset` через `onReachEnd`, состояния loading/empty/error+retry,
  lifecycle-токен против устаревших ответов; парсер дополнен `MessageThreadComment` (id, senderUserId,
  date, text, isOutgoing). 4 строки в base/ru/zh. Суита `test-message-thread.cjs` расширена (парсер
  комментариев, контракт страницы/роута/параметров, лимит 500 строк, локали). Гейты: host **132/132**,
  оба smoke, hvigor BUILD SUCCESSFUL. Остаток D11: точка входа из поста, отправка комментария, witness.
- **D11-thread-data (lead).** Слой данных комментариев: команды `getMessageThread` и
  `getMessageThreadHistory` (payload/фабрики), сериализатор с raw int64 для message_id/from_message_id,
  парсеры `MessageThreadPage` (reply_count из `reply_info`, unread из top-level `unread_message_count`,
  список id, `next_offset`), `MessageThreadUseCase.loadThread/loadHistory` с валидацией (chatId,
  messageId, fromMessageId, offset 0..100, limit 1..100), аккуратные ошибки `AppError`. Суита
  `test-message-thread.cjs` (132-я): wire, парсеры, валидация, отказы gateway/`@type`. Гейты: host
  **132/132**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток D11: страница треда, отправка комментария,
  witness.
- **H8-unblock (lead).** Заблокированный peer в приватном/секретном чате получает панель UNBLOCK
  вместо композера: `selectChatInputPanel` → `unblock`, действие `unblock` в chrome/портах/контексте,
  лейбл через `bottomBarActionLabel`, обработка в `handleChatBottomBarAction` через
  `SetMessageSenderBlockedUseCase.unblock(user, peerUserId)` (use case заведён в activation, чистится в
  teardown); состояние снимает сам TDLib (`updateChatIsBlocked`). 1 строка в base/ru/zh. Суита
  `test-chat-unblock.cjs` (131-я): политика (private/secret/group), лейбл, проводка derive/handler,
  chrome/context, activation/teardown, локали. Гейты: host **131/131**, оба smoke, hvigor BUILD
  SUCCESSFUL. Остаток H8/G4: witness.
- **G4-delete-and-exit (lead).** Удалённый из группы участник получает панель iOS:
  `chatBottomBarDeleteAndExit` (ChatChromeState), сообщение «You were removed from this group.»,
  красная кнопка Delete and Exit (атом `TgChatBottomBar`, `@Param restrictedActionText` +
  `@Event onRestrictedAction`); derive ставит флаг только для `banned` + group; действие идёт через
  существующий `handleChatBottomBarAction` → `ChatExitCoordinator.deleteAndExitChat` (leave с
  игнорированием ошибки → deleteChatHistory(remove, revoke) → назад). 2 строки в base/ru/zh. Суита
  `test-chat-exit-delete.cjs` (130-я): лейбл/сообщение, derive, флаг в chrome/портах, атом/dock,
  exit-хелпер. Гейты: host **130/130**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток G4: witness.
- **F6-карточка пака (lead).** `ChatStickerPackCoordinator`: `visibleStickerSetId`,
  `syncStickerPackCard` (загрузка при смене видимого стикера, очистка на не-стикере), `loadStickerPack`
  (валидация id, токены запроса/жизненного цикла, тихий отказ), `toggleStickerPackInstalled`
  (install/remove с проверкой busy). Поля `stickerPackSetId/Title/Installed/Busy` в
  `ChatMediaViewState`, порт `ChatMediaOverlayPort.loadStickerPack/toggleStickerPackInstalled`, слой
  session/bindings/activation/teardown, открытие вьювера вызывает sync, в оверлее плитка с названием
  пака и Add/Remove Stickers (2 строки в base/ru/zh). Суита `test-sticker-pack.cjs` расширена:
  видимый id, загрузка/повтор, установка, очистка, ошибки, устаревшие ответы, проводка UI. Гейты:
  host **129/129**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток F6: TGS-анимация, листание по паку,
  witness.
- **F6-данные пака (lead).** `sticker.set_id` протянут DTO → `MessageContent` → reducer (map+clone) →
  `ChatTimelineVO` → `MediaGalleryItem.stickerSetId`; новый `StickerPackUseCase`: `load(setId)`
  (`getStickerSet` → title/isInstalled/isArchived/stickerCount) и `setInstalled(setId, installed)`
  (`changeStickerSet`), валидация int64-id (`0` и мусор отвергаются). Суита `test-sticker-pack.cjs`
  (129-я): валидация, парсинг, wire обеих команд (точные цифры int64), ошибки, вся проводка модели.
  Гейты: host **129/129**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток F6: UI-карточка пака во
  вьювере, TGS-анимация, witness.
- **F6-срез (lead).** Просмотр стикеров: `MediaGalleryItem.type` расширен `sticker`,
  `ChatMediaGalleryCoordinator` добавляет стикер-сообщения в галерею (path/thumbnail/размеры,
  source/author/time), поиск целевого индекса учитывает `sticker`, `TgMediaGalleryPage` рисует
  стикеры фото-веткой (`Image` Contain + thumbnail-fallback при незагруженном файле), в
  `TgMessageRouter` тап по стикеру вызывает `onMediaGalleryOpen`. Новая суита
  `test-sticker-viewer.cjs` (128-я): сбор элемента, поиск индекса, render-ветка, tap-проводка,
  модель, fallback. Гейты: host **128/128**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток F6:
  карточка пака (getStickerSet/changeStickerSet уже есть), TGS-анимация, witness.
- **G6-предзаполнение (lead).** `parseMemberModerationState` (chatMember → administrator rights по
  16 флагам / restricted permissions+until / banned until / creator / member) и
  `ChatMemberAdminUseCase.loadState` через `getChatMember`; `TgChatAdminRightsPage` подставляет
  текущие 10 прав админа, `TgChatRestrictRightsPage` — текущие 14 разрешений и ближайший пресет
  срока по остатку. Суита `test-chat-member-admin.cjs` расширена: парсинг admin/restricted/banned/
  member-состояний, `getChatMember`-wire и ошибки `loadState`, предзаполнение на обоих экранах.
  Гейты: host **127/127**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток G6: «снять админа» с
  сохранением прав, witness.
- **G6-частичные права (lead).** `TgChatRestrictRightsPage`: 14 разрешений (текст/фото/видео/аудио/
  голосовые/видеосообщения/документы/опросы/GIF-стикеры/превью ссылок/приглашения/закрепление/
  профиль/темы) + строка срока (1ч/1д/1н/навсегда) + кнопка Restrict; переключатели означают
  «разрешено», `chatPermissionsToJson` уходит в `SetChatMemberStatusPayload.permissionsJson`,
  статус restricted собирается из переданного объекта (пусто → всё запрещено). Пункт Restrict в меню
  участника навигирует на экран, ban остаётся с inline-меню срока. 19 строк в base/ru/zh. Суита
  `test-chat-member-admin.cjs` расширена: partial-wire (разрешённые права true, остальные false),
  дефолт «всё запрещено», экран/route/14 ключей/локали. Гейты: host **127/127**, оба smoke, hvigor
  BUILD SUCCESSFUL. Остаток G6: предзаполнение прав админа, срок в promote-экране, witness.
- **G6-сроки (lead).** Ban/restrict спрашивают срок вторым меню (1 час/1 день/1 неделя/навсегда),
  `MODERATION_DURATION_SECONDS`/`MODERATION_DURATION_OPTIONS`/`moderationUntilDate(now, duration)`
  (0 = forever, невалидные → 0), до вызова `apply` с `untilDate`; 5 строк в base/ru/zh. Суита
  `test-chat-member-admin.cjs` расширена: пресеты, арифметика until-даты, границы (0/отрицательная/
  дробная), wire timed-restrict (`restricted_until_date`) и timed-ban (`banned_until_date`),
  проводка меню и локали. Гейты: host **127/127**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток G6:
  restrict с частичными правами, предзаполнение прав админа, witness.
- **G6-экран прав (lead).** `TgChatAdminRightsPage`: 10 тоглов `chatAdministratorRights`
  (manage chat, change info, delete messages, invite, restrict, pin, topics, video chats,
  promote, anonymous), кнопка Add Administrator, сохранение через
  `ChatMemberAdminUseCase.apply(..., 'promote', 0, rights)`, тост и pop, ошибка сохранения; route +
  params, `TgProfileMemberRow`/список участников: пункт Add Admin теперь навигирует на экран вместо
  назначения с правами по умолчанию. 14 строк в base/ru/zh. Суита `test-chat-member-admin.cjs`
  расширена: проводка навигации, экран/route, все 10 ключей прав, локали. Гейты: host **127/127**,
  оба smoke, hvigor BUILD SUCCESSFUL. Остаток G6: частичные ограничения, сроки, предзаполнение прав,
  witness.
- **G6-продолжение (lead).** Promote/demote: `ChatAdminRightsPayload` (16 флагов
  `chatAdministratorRights`, по умолчанию все false), `buildAdminRightsJson`, статус
  `chatMemberStatusAdministrator`, действия `promote`/`demote` в use case, меню участника
  расширено до 5 пунктов (Add Admin/Remove Admin/Ban/Unban/Restrict), 2 строки в base/ru/zh.
  Суита `test-chat-member-admin.cjs` расширена: маппинг promote→administrator/demote→member, wire
  прав (все 16 false), демоут в обычное членство, меню из 5 кнопок. Гейты: host **127/127**,
  оба smoke, hvigor BUILD SUCCESSFUL. Остаток G6: UI-тоглы прав, частичные ограничения, сроки,
  witness.
- **G6-срез (lead).** Модерация участника: команда `setChatMemberStatus` с тремя статусами
  (`chatMemberStatusMember` / `Banned` / `Restricted` — restricted остаётся в чате, все 14 прав
  false), `ChatMemberAdminUseCase.apply` (ban/unban/restrict, валидация chatId/userId/даты,
  `untilDate` 0 = навсегда), long-press строки в списке участников открывает showActionMenu
  Ban/Unban/Restrict с тостами результата, `onLongPress` добавлен в `TgProfileMemberRow`, 5 строк
  в base/ru/zh. Новая суита `test-chat-member-admin.cjs` (127-я): маппинг действий в статусы,
  wire всех трёх статусов (включая запрет всех прав при restrict), валидация, ошибки, проводка
  long-press/меню и локали. Гейты: host **127/127**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток G6:
  promote/demote с выбором прав, частичные ограничения, сроки, witness.
- **D21-срез (lead).** Отложенные сообщения: `getChatScheduledMessages` + `ScheduledMessageDto`
  (int64 id строкой, send_date, превью, порядок новые первыми), `EditMessageSchedulingState`
  (null → отправить сейчас, дата → перенос), отмена через `deleteMessages` (id уходит в wire как
  точные цифры), поддержка планируемой отправки в `SendMessagePayload.scheduledDateSeconds` +
  `_scheduling_state_json`, `ScheduledMessagesUseCase` (load/sendNow/reschedule/cancel, валидация
  id и даты ≤367 дней), экран `TgChatScheduledMessagesPage` (меню строки Send Now / In 1 hour /
  Delete, пустое состояние, ошибки), route + params, 6-й пункт Manage-меню (ровно шесть кнопок),
  `openScheduledScreen`. Новая суита `test-scheduled-messages.cjs` (126-я): DTO-фильтрация/порядок,
  wire всех четырёх команд (включая int64 без потерь в raw JSON), валидация, ошибки, экран/route/
  подменю, 9 строк в 3 локалях; пять admin-суит обновлены на шестой пункт. Гейты: host **126/126**,
  оба smoke, hvigor BUILD SUCCESSFUL. Остаток D21: пикер даты из композера, repeat-периоды,
  доступ у не-админов, witness.
- **D20-срез (lead).** Автоудаление сообщений в чате: поле `Chat.messageAutoDeleteTime`
  (парсинг `chat.message_auto_delete_time` в `ChatDto` + маппинг в reducer), команда
  `setChatMessageAutoDeleteTime` с валидацией 0…366 дней, `ChatAutoDeleteUseCase`
  (`load`/`set`, пресеты `AUTO_DELETE_PRESETS`), экран `TgChatAutoDeletePage` (текущее значение,
  5 пресетов, ✓ на выбранном, оптимистичная запись с откатом, loading/error), route + params,
  пункт Auto-Delete в Manage-подменю (5 кнопок), `openAutoDeleteScreen` в навигационном helper.
  Новая суита `test-chat-auto-delete.cjs` (125-я): пресеты/валидация, load/set wire, ошибки,
  маппинг Chat↔DTO↔reducer, экран/route/подменю, 11 строк в 3 локалях; четыре admin-суиты обновлены
  на пятый пункт подменю. Гейты: host **125/125**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток D20:
  self-destruct секретных чатов, per-message TTL, witness.
- **C9-остаток (lead).** Иконка копирования: SVG-ассет `ic_selection_copy` в форме iOS SF Symbol
  `doc.on.doc`, токен `SELECTION_PANEL_COPY_ICON`, панель рисует copy через общий `buildIconButton`
  (как forward/delete/report) — одинаковая геометрия, press-feedback и disabled-тинт; текстовый глиф
  остаётся только в демо. Паспорт `spec/TgSelectionPanel.md` дополнен разделом Copy icon. Контракт
  `test-selection-mode.cjs`: наличие токена/ассета, `buildIconButton` для copy, отсутствие глифа.
  Гейты: host **124/124**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток C9: device-witness.
- **C2-остаток (lead).** Мульти-typing в группе: `ChatTypingInfo.senders` (до 5, новые первыми) +
  чистая `applyTypingAction` (upsert/cancel, undefined при последнем cancel), reducer кладёт набор в
  `typingActions`, шапка форматирует «A»/«A и B»/«A и ещё N» через `formatTypingActors`, mode = Typing
  только если все печатают; private-чат по-прежнему показывает activity-строку. Legacy-объекты без
  `senders` нормализуются `activeSenders`. Новая суита `test-multi-typing.cjs` (124-я): upsert,
  порядок, cap, отмена одного/последнего, форматирование имён, проводка reducer/шапки, 2 строки в 3
  локалях; в `test-chat-top-bar-presentation.cjs` добавлены фикстуры typing-хелперов. Гейты: host
  **124/124**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток C2: пульсация точек, witness.
- **H4c (lead).** Кэш: сегментированная диаграмма. `StorageUsageSegment` + чистые
  `storageChartScale`/`storageSegmentPercent` (шкала = лимит, иначе total; сегмент не превышает
  100%), молекула `TgStorageUsageChart` (stacked-полоса, легенда, 4 токена
  `STORAGE_CHART_*`), страница собирает сегменты из files/database/languagePacks/logs и передаёт
  caption; плоская полоса заменена. Контракт `test-cache-limit.cjs`: шкала, проценты (в т.ч. clamped
  100 и нули), модель сегмента, проводка страницы и компонента. Гейты: host **123/123**, оба smoke,
  hvigor BUILD SUCCESSFUL. Остаток H4: анимация/точные iOS-пропорции, witness.
- **H4-остаток (lead).** Кэш: график занятости (полоса `total / limit`, красная при достижении,
  подпись `formatStorageBytes(total) / formatStorageBytes(limit)`, без лимита — просто total) и
  авто-применение лимита: `shouldAutoEnforce(limit, usage)` + `autoEnforce` в
  `LoadStorageStatisticsUseCase`, вызов после загрузки статистики (один раз за загрузку, тост
  `data_storage_limit_enforced`, перезагрузка статистики), guard сбрасывается при reload. Контракт
  `test-cache-limit.cjs`: предикат (равенство/0/-1/negative usage), wire `optimizeStorage` с
  `size = limit` и `ttl/count = -1`, отсутствие запроса ниже лимита, проводка графика и авто-вызова.
  Гейты: host **123/123**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток H4: iOS-диаграмма по
  категориям, witness.
- **S12k + S15 (lead).** C10: тап по администратору открывает профиль — `DirectUserProfileRouteParams`
  экспортирован, `captureProfileLoadContext` переиспользован, `TgChatAdministratorsPage` пушит
  `TgProfilePage` с контекстом и логирует ошибку. App Linking: объявлены `pathStartWith: "+"` для
  `t.me` и `telegram.me`, поэтому короткая форма `t.me/+hash` больше не требует явного want
  (ведущий «+» не пересекается с username и зарезервированными путями). Контракты: суита
  администраторов проверяет экспорт параметров/контекста и проводку тапа, суита внешних ссылок —
  оба `+`-uri. Гейты: host **123/123**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток: witness.
- **S12j (lead).** C10: права участников. Команда `setChatPermissions` (полный JSON объекта),
  `ChatPermissionsDto` (14 бит + `clone` + `chatPermissionsToJson`), `ChatPermissionsUseCase`
  (`load` через `getChat` → `chat.permissions`, `save` целиком, валидация chatId), экран
  `TgChatPermissionsPage` (14 тумблеров `PermissionToggleRow`, оптимистичная запись с откатом при
  ошибке, loading/error), route + params, пункт Permissions в Manage-подменю (4 кнопки), host
  `openPermissions`. Навигация admin-экранов вынесена из страницы в `chatAdminNavigation.ets`
  (страница 442 строки). Новая суита `scripts/test-chat-permissions.cjs` (123-я): round-trip DTO/JSON
  (15 ключей), wire `setChatPermissions` с вложенным `permissions`, валидация до gateway, ошибки
  (нет прав/unsupported), экран/route/подменю/19 строк в 3 локалях; контракты admin-экранов
  обновлены на helper. Гейты: host **123/123**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток C10:
  профиль по тапу из админов, witness.
- **S12i (lead).** C10: администраторы группы. Команда `getChatAdministrators` + сериализатор,
  `ChatAdministratorDto`/`ChatAdministratorsDto` (user_id/custom_title/is_owner, невалидные и
  чужие записи отбрасываются), `ChatAdministratorsUseCase` (валидация chatId, ошибки), экран
  `TgChatAdministratorsPage` (имена из users store, фолбэк «User <id>», owner-метка · custom title,
  пустое состояние, ошибка), route `TgChatAdministratorsPage` + `ChatAdministratorsRouteParams`,
  Manage-подменю расширено пунктом Administrators (3 кнопки), host `openAdministrators` и навигация
  со страницы чата. Новая суита `scripts/test-chat-administrators.cjs` (122-я): разбор DTO
  (фильтрация невалидных), wire `getChatAdministrators`, валидация до gateway, ошибки, экран/route/
  подменю/7 строк в 3 локалях. Гейты: host **122/122**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток
  C10: экран прав (`setChatPermissions`), профиль по тапу из админов, witness.
- **S12h (lead).** C10: ссылки-приглашения группы. Команды `getChatInviteLinks`/
  `createChatInviteLink`/`revokeChatInviteLink` + сериализаторы, `ChatInviteLinkDto`/
  `ChatInviteLinksDto` (primary/лимит/участники/заявки/revoked), `ChatInviteLinksUseCase`
  (load/create/revoke, валидация chatId и ссылки, trim), экран `TgChatInviteLinksPage` (список,
  Create Invite Link, отзыв по тапу, primary не отзывается, ошибки, счётчик), route
  `TgChatInviteLinksPage`, `ChatInviteLinksRouteParams`, в меню — Manage-подменю (Members /
  Invite Links) вместо плоского пункта, `openInviteLinks` в host и навигация со страницы чата.
  Новая суита `scripts/test-chat-invite-links.cjs` (121-я): разбор DTO (primary, пустые ссылки
  отбрасываются), wire всех трёх команд, trim, валидация до gateway, ошибки, экран/route/
  подменю/11 строк в 3 локалях. Гейты: host **121/121**, оба smoke, hvigor BUILD SUCCESSFUL.
  Остаток C10: права участников, администраторы, witness.
- **S12g (lead).** C10: ролевые admin-пункты. `getChatMember` (+сериализатор с
  `_member_id_json`), `ChatMemberRole`/`readChatMemberRole`/`canManageChat` и
  `ChatMemberRoleUseCase` (валидация id, ошибка роли → `unknown`, меню не блокируется); меню
  переписано с индексного switch на типизированные `ChatMenuAction` + `applyMenuAction`, для
  creator/administrator в шестислотовое меню добавляется Members и скрывается Report; страница
  даёт `currentUserId` и открывает `TgProfileMembersPage` (supergroupId/memberCount из store),
  route-навигация с фолбэком-тостом. Контракт `test-chat-header-actions.cjs`: роли creator/
  administrator/member/left/unknown, `canManageChat`, wire `getChatMember` (chat_id + sender JSON),
  валидация и фолбэк, новые пункты меню, проводка страницы. Гейты: host **120/120**, оба smoke,
  hvigor BUILD SUCCESSFUL; страница 438 строк. Остаток C10: управление группой/ссылками/правами,
  witness.
- **S12f (lead).** C10: Report по выбранным сообщениям. `ReportChatPayload.messageIds` и
  `_message_ids_json` через общий билдер, `ReportChatUseCase.submitMessages` (непустой набор, safe-int
  id, chatId до gateway), `ChatActionsCoordinator.submitReportMessages` + host-колбэк
  `requestReportMessages` (шаг `messages` больше не тост), страница входит в режим выделения
  (`view.timeline.selectionActive`, пустой набор), `TgSelectionPanel` получил `showReport`/
  `reportLabel`/`onReport` (+ токен `SELECTION_PANEL_REPORT_GLYPH`), отправка конвертирует строковые
  id в числа и очищает выделение после успеха, закрытие панели снимает intent. Контракт
  `test-chat-header-actions.cjs`: wire с int53 message_ids, валидация (пусто/0/chatId) до gateway,
  проводка coordinator/страницы/панели/токена. Гейты: host **120/120**, оба smoke, hvigor BUILD
  SUCCESSFUL; страница 399 строк. Остаток C10: ролевые admin-пункты, witness.
- **S12e (lead).** C10: шаг комментария в Report. `ReportChatUseCase.submitComment` (trim,
  обязательный текст, option_id/chatId до gateway), `ChatActionsCoordinator.submitReportComment` +
  host-колбэк `requestReportComment` (шаг `text` больше не тост), страница: `@Local`-state и
  `TgReportCommentOverlay` (молекула, `@Param`/`@Event`), отправка/отмена/ошибки, 4 строки в 3
  локалях. Контракт `test-chat-header-actions.cjs`: wire `reportChat` с option_id и обрезанным
  текстом, валидация (пустой текст/option/chatId) до gateway, проводка coordinator/страницы/оверлея.
  Гейты: host **120/120**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток C10: шаг выбора сообщений
  (`reportChatResultMessagesRequired`), ролевые admin-пункты.
- **S14c (lead).** Внешние chat-invite ссылки: команды `checkChatInviteLink`/`joinChatByInviteLink`
  (+сериализаторы), `ChatInviteLinkInfoDto` (chat_id 0 = не участник, title/description/
  member_count/creates_join_request/is_public/тип), `ChatInviteLinkUseCase` (валидация `t.me/+…`/
  `t.me/joinchat/…` до gateway, trim, check/join), экран `TgChatInvitePage` (проверка при входе,
  превью, Join/Open Chat, подсказка про заявку, ошибки), route зарегистрирован,
  `MainTabsPage` маршрутизирует `chatInvite` с pop-callback → `openJoinedChat` (гидрация
  `createNewChatEvent` + chat screen), App Linking объявляет `t.me/joinchat` и `telegram.me/joinchat`
  (плюс уже объявленный `addlist`). Контракт `test-external-links.cjs`: 5 валидных/5 невалидных форм,
  wire обеих команд, разбор info, success/trim/ошибки, страница/route/9 строк в 3 локалях. Гейты:
  host **120/120**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток: `t.me/+…` в манифесте не выразить
  через pathStartWith (нужен отдельный фильтр/уточнение), witness.
- **S14b (lead).** Внешние `t.me/<username>` открывают чат: `ResolveUsernameUseCase`
  (`searchPublicChat`, валидация username 4..32, trim, ошибки «Invalid username»/«Username not found»),
  в `MainTabsPage.consumeExternalLink` ветка `username` → `openUsernameLink`: DTO гидрируется в store
  через `createNewChatEvent` и открывается chat screen (`pushChatScreenRoute`), токен отсекает
  устаревшие ответы, ошибка — тост `external_link_failed` (3 локали). Контракт `test-external-links.cjs`
  расширен: валидные/невалидные username, wire `searchPublicChat`, success/trim/not-found/failure,
  проводка MainTabsPage и строки. Гейты: host **120/120**, оба smoke, hvigor BUILD SUCCESSFUL.
  Остаток: chat-invite ссылки, witness.
- **S14 (lead).** Внешние ссылки: `t.me/addlist`. `ExternalLink` (классификатор folder/chat-invite/
  username/unknown + одноразовый `externalLinkIntake`), `EntryAbility.onCreate(want)`/`onNewWant`
  сохраняют `want.uri`, `MainTabsPage.consumeExternalLink` маршрутизирует folder-ссылку в
  `TgFolderLinkPage` с `FolderLinkRouteParams` (страница подставляет ссылку и сразу проверяет),
  `module.json5` объявляет browsable-skill (`entity.system.browsable` + `ohos.want.action.viewData`)
  для `https://t.me/addlist` и `https://telegram.me/addlist`. Классификатор сохраняет регистр slug,
  резервирует `addlist`/`joinchat`. Контракт `test-external-links.cjs` (13 случаев, intake, проводка,
  module.json5); stabilization-харнесс обновлён под новую сигнатуру onCreate (обе мутационные
  контроли снова проходят). Гейты: host **120/120**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток:
  маршрутизация chat-invite/username, witness.
- **S13j (lead).** B7: превью папки по invite-ссылке и добавление. Команды
  `checkChatFolderInviteLink`/`addChatFolderByInviteLink` (+сериализаторы, ids через
  `buildChatIdArrayJson`), `ChatFolderInviteLinkInfoDto` (chatFolderInfo + missing/added, int53),
  `FolderInviteLinkUseCase` (check/add, trim, проверка формы `t.me/addlist/...` до gateway), новый
  экран `TgFolderLinkPage` (ввод ссылки, Check → карточка «название, N chats, M missing», Add Folder)
  и строка «Open Folder Link» в экране папок; route зарегистрирован. Контракт
  `test-folder-link-preview.cjs`: wire обеих команд с int53, DTO, 13 вариантов формы ссылки,
  use case успех/валидация/ошибки, проводка страницы/route, 12 строк в 3 локалях. Гейты: host
  **119/119**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток B7: автоматическое открытие внешних
  `t.me/addlist` (нет роутера ссылок), witness.
- **S13i (lead).** B7: рекомендованные папки. `getRecommendedChatFolders` (команда + сериализатор),
  `RecommendedChatFolderDto` (переиспользует `ChatFolderDto`, int53 included-чаты, пустой folder
  отбрасывается), `LoadRecommendedChatFoldersUseCase`; секция RECOMMENDED в `TgChatFoldersPage`:
  название + описание + Add, добавление создаёт обычную папку через `createChatFolder` с флагами и
  included-чатами рекомендованной папки, строка исчезает после успеха. Контракт
  `test-chat-folder-settings.cjs`: wire (только `@type`), разбор двух папок с int53, use case
  успех/ошибка, проводка страницы, 4 строки в 3 локалях. Гейты: host **118/118**, оба smoke, hvigor
  BUILD SUCCESSFUL. Остаток B7: folder link preview/`addChatFolderByInviteLink`, witness.
- **S11c (lead).** H4: «Maximum Cache Size». `OptimizeStoragePayload` (size/ttl/count/immunityDelay)
  и сериализатор (раньше всегда отправлял нули — лимит стёр бы весь кэш),
  `LoadStorageStatisticsUseCase.enforceCacheLimit` (0 = Unlimited → запрос не отправляется;
  валидация до gateway; ttl/count = -1 = дефолты TDLib), строка в Data and Storage с выбором
  256 МБ/512 МБ/1 ГБ/2 ГБ/Unlimited через `showActionMenu`, сохранение в `preferences`
  (`storage_settings`/`max_cache_bytes`), применение с тостом и перечитыванием статистики. Контракт
  `test-cache-limit.cjs`: wire clear/limit, use case (unlimited/валидация/ошибка), форматирование,
  проводка страницы, 3 строки в 3 локалях. Гейты: host **118/118**, оба smoke, hvigor BUILD
  SUCCESSFUL. Остаток H4: iOS-график, авто-применение лимита, witness.
- **S13h (lead).** B7: ограничение invite-ссылки набором чатов + фикс расширения при
  переименовании. `chatIds` в `ChatFolderInviteLinkPayload` и фабриках, сериализатор create/edit
  пишет `buildChatIdArrayJson(chatIds)` (пустой массив = все чаты папки), use case валидирует id до
  gateway (ошибка не заворачивается в «Failed to …»), создание ссылки идёт через выбор чатов
  (`TgFolderChatsPage`, предвыбор — included-чаты папки), переименование передаёт сохранённый
  `editingLinkChatIds`, строка ссылки показывает «· N». Контракт
  `test-chat-folder-settings.cjs`: create/edit wire с int53 и фильтрацией, сохранение набора при
  rename, валидация, ошибки, проводка страницы, строка `folders_link_chats`. Гейты: host **117/117**,
  оба smoke, hvigor BUILD SUCCESSFUL. **Осталось (B7):** folder link preview, recommended folders,
  witness.
- **S12d (lead).** C10: Report с причинами + вынос меню в координатор. `reportChat` (команда,
  сериализатор с base64 `option_id`, `ReportChatDto` для `reportChatResult*`), `ReportChatUseCase`
  (start → chooseOption, валидация), `chat.can_be_reported` в модели/DTO/reducer; в меню шестой
  пункт Report: список причин через `showActionMenu` (до 6), успех — тост, шаги text/messages честно
  сообщаются (ввода комментария и выбора сообщений пока нет — долги). Меню/действия вынесены в
  `ChatActionsCoordinator` (typed host-класс), страница снова в бюджете (≤500 строк,
  decomposition-тест восстановлен вместе с lifecycle-хуками). Контракт
  `test-chat-header-actions.cjs` расширен (wire, DTO-шаги, use case, проводка). Гейты: host
  **117/117**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток C10: ввод комментария/выбор сообщений,
  ролевые пункты, witness.
- **S12c (lead).** C10: Leave Chat и Share My Contact. `LeaveChatUseCase` (`leaveChat`, валидация
  chatId) и `ShareMyContactUseCase` (`sendMessage` + `inputMessageContact`: телефон/имя из store,
  тримминг, проверка userId) + сериализаторы; пятый пункт меню в шапке контекстный — Leave для
  group/supergroup/channel (подтверждение, тост, выход из чата), Share My Contact для
  private/secret (свои данные из `state.auth.userId`/`state.users`, ошибка — тост). Контракт
  `test-chat-header-actions.cjs`: wire обеих команд (экранирование кавычек в имени), use case
  (валидация, ошибки), проводка меню, локали. Гейты: host **117/117**, оба smoke, hvigor
  BUILD SUCCESSFUL. Остаток C10: Report и ролевые пункты, witness.
- **S12b (lead).** C10 закрыт до `available`: в шапке чата появилась «…»-капсула
  (`@Param showMoreAction` + `@Event onMorePress`, нативный material и fallback, theme-foreground
  токен), не заменяющая поиск; открывает `showActionMenu` с Chat Info (профиль), Mute/Unmute
  (`SetChatMuteUseCase`), Clear History и Delete Chat (`deleteChatHistory`, remove=true для удаления,
  revoke), подтверждения/тосты, после удаления — выход из чата. Состояние читается из live-store
  (`activeChatId`), не из догадки. Контракт `test-chat-header-actions.cjs`; оба smoke обновлены:
  theme-foreground-токен теперь пинится на 4 действия (back/search/more/close). Гейты: host
  **117/117**, оба smoke, hvigor BUILD SUCCESSFUL. Остаток: Share Contact/Report, роли, witness.
- **S13f (lead).** B7: редактирование invite-ссылки. `editChatFolderInviteLink` (команда,
  сериализатор, `editLink` в use case с trim имени и проверкой ссылки), UI: тап по строке ссылки
  открывает инлайн-редактор имени (TextInput + Save/Cancel), после сохранения — тост и перезагрузка
  списка. Контракт `test-chat-folder-settings.cjs`: wire editChatFolderInviteLink (включая
  `chat_ids: []`), trim в payload, валидация до gateway, ошибка, проводка страницы, 2 строки в 3
  локалях. Гейты: host **116/116**, оба smoke, hvigor BUILD SUCCESSFUL.
  **Осталось (B7):** ограничение ссылки набором чатов в UI, folder link preview, witness.
- **S13e (lead).** B7: пригласительные ссылки папки. Команды `getChatFolderInviteLinks`/
  `createChatFolderInviteLink`/`deleteChatFolderInviteLink` + сериализатор, `ChatFolderInviteLinkDto`
  (список, int53 `chat_ids` через raw items, пустая ссылка — не валидная),
  `ManageChatFolderInviteLinksUseCase` (list/create/delete, trim имени, лимит 32, отказ до gateway),
  секция Invite Links в редакторе: список, создание, копирование в pasteboard, удаление с
  подтверждением. Контракт `test-chat-folder-settings.cjs`: wire-формы трёх команд, разбор списка
  (int53), use case успех/ошибки/валидация, проводка страницы, 12 строк в 3 локалях. Гейты: host
  **116/116**, оба smoke, hvigor BUILD SUCCESSFUL. **Осталось (B7):** `editChatFolderInviteLink`,
  folder link preview, witness.
- **S13d (lead).** B7: выбор конкретных чатов в папку. Новый экран `TgFolderChatsPage` (список по
  `selectOrderedChats`, чекбоксы, счётчик в шапке, «Done» возвращает `FolderChatSelectionResult`
  через pop-callback), `includedChatIds` в `ChatFolderDraftPayload` + сериализатор (невалидные id
  отфильтровываются, use case отвергает до gateway), редактор загружает выбор из `ChatFolderDto`,
  показывает «Included chats: N» и передаёт его в `chatFolder` JSON. Контракт
  `test-chat-folder-settings.cjs`: ids в wire (включая int53 `9007199254740001`), фильтрация
  невалидных, отказ use case, проводка редактора/страницы/route, строки. Гейты: host **116/116**,
  оба smoke, hvigor BUILD SUCCESSFUL. **Осталось (B7):** shareable-ссылки, folder link preview,
  witness.
- **S13c (lead).** B7: include-флаги в редакторе папки. Раньше `ChatFolderDto` читал 5 include-флагов
  (contacts/non-contacts/bots/groups/channels), но UI их не показывал и не отправлял. Теперь все 10
  флагов переключаются, сбрасываются при создании, подгружаются из `getChatFolder` при
  редактировании и уходят в `chatFolder` JSON. Контракт `test-chat-folder-settings.cjs`: true-значения
  всех include-флагов в wire (create), их сохранение в edit-payload, проводка страницы и 5 строк в
  3 локалях. Гейты: host **116/116**, оба smoke, hvigor BUILD SUCCESSFUL.
  **Осталось (B7):** выбор конкретных чатов (`included_chat_ids`), shareable-ссылки, folder link
  preview, witness.
- **S13b (lead).** B7: чтение полной папки. Закрыт долг «редактор не видит флаги»: `getChatFolder`
  (td_api.tl:12051) → `ChatFolderDto` (name, icon, color_id, is_shareable, pinned/included/excluded
  int53 через `TdObject.getTopLevelRawItemArrayStrict`, 7 include + 3 exclude флагов);
  `ManageChatFoldersUseCase.fetchFolder` (валидация, ответ не chatFolder — ошибка), страница
  подгружает флаги при выборе папки, блокирует Save до чтения, не сбрасывает фильтры при
  переименовании. Контракт `test-chat-folder-settings.cjs`: wire getChatFolder, разбор всех полей
  (включая int53 `9007199254740001`), случаи «ok»/пустой chatFolder, fetchFolder успех/ошибки,
  проводка страницы. Гейты: host **116/116**, оба smoke, hvigor BUILD SUCCESSFUL.
  **Осталось (B7):** выбор чатов и shareable-ссылки, include_* флаги в UI, folder link preview,
  witness.
- **S13 (lead).** B7: экран настроек папок (остаток S7b.4). `TgChatFoldersPage` (Settings → Chat
  Folders, строка получила destination): список папок из AppStore (`updateChatFolders`), создание/
  переименование/удаление через `createChatFolder`/`editChatFolder`/`deleteChatFolder` — полный
  `chatFolder` JSON (name/formattedText с экранированием, icon, color_id, вектора, 7 флагов), лимит
  имени 12 символов, trim перед отправкой, подтверждение удаления, тосты, список обновляется
  подпиской на store. Контракт `test-chat-folder-settings.cjs`: wire-форма create/edit/delete
  (включая кавычки/бэкслеши в имени), валидация до gateway (пустое/13 символов/12 — ок, folderId),
  ошибки, проводка страницы/route/settings, 18 строк в 3 локалях. Гейты: host **116/116**, оба
  smoke, hvigor BUILD SUCCESSFUL. **Осталось (B7):** выбор чатов и shareable-ссылки, folder link
  preview, witness.
- **S12 (lead).** C10 «Меню действий чата» из `missing` → `partial`. В `TgProfileNavigationBar`
  добавлена кнопка «…» (`showMore`/`onMorePress`, `ic_more`, нативный material + fallback), в профиле
  — `showActionMenu`: Mute/Unmute (`SetChatMuteUseCase`), Clear History (`deleteChatHistory`
  remove=false), Delete Chat (remove=true, revoke=true) с подтверждениями и тостами; после удаления
  профиль закрывается. Попутно: `DeleteChatHistoryUseCase` ужесточён — chat_id обязан быть
  положительным int53 (раньше −1 и 0.5 проходили). Контракт `test-profile-actions.cjs`: use case
  (clear vs delete payloads, валидация, ошибка), проводка атома и страницы, 8 строк в 3 локалях.
  Гейты: host **115/115**, оба smoke, hvigor BUILD SUCCESSFUL. **Осталось (C10):** меню в шапке
  самого чата, Share Contact/Report, проверка ролей, witness.
- **S10d (lead).** H8: вкладки Messages/Stories. `LoadBlockedSendersUseCase.fetchPage` принимает
  `blockList` (`main`/`stories`), страница держит `@Local blockList`, рисует две вкладки, при
  переключении сбрасывает список/offset/total и перезагружает, «Show More» остаётся на выбранном
  списке; разблокировка по-прежнему обнуляет блок-лист (в TDLib один `block_list`). Контракт
  `test-blocked-users.cjs`: проброс stories в команду, дефолт main, вкладки/сброс/пагинация в
  странице, строки `blocked_tab_*` в 3 локалях. Гейты: host **114/114**, оба smoke, hvigor
  BUILD SUCCESSFUL. **Осталось (H8):** iOS-карточки, witness.
- **S10c (lead).** H8: блокировка из профиля. Данные: `Chat.isBlocked` ← `chat.block_list`
  (`blockListMain`), `updateChatBlockList` нормализуется в `ChatUpdateDto.isBlocked` и применяется
  reducer’ом (create + оба merge-пути). Действие: `SetMessageSenderBlockedUseCase` (block/unblock с
  валидацией) + строка Block/Unblock в профиле для private/secret с подтверждением, оптимистичным
  переключением и тостом. Контракт `test-blocked-users.cjs` расширен: парсинг blockListMain против
  blockListStories и отсутствия, use case (payload blocked true/false, senderType chat/user, отказ
  невалидным входам), проводка профиля (`canBlockPeer`, `chat.isBlocked`, строки), 4 новые строки в
  3 локалях. Гейты: host **113/113**, оба smoke, hvigor BUILD SUCCESSFUL.
  **Осталось (H8):** blockListStories UI, iOS-карточки, witness.
- **S10b (lead).** H8: пагинация списка заблокированных. `blockedSenderSelectors`
  (`blockedSenderKey`, `mergeBlockedSenders` с дедупликацией, `hasMoreBlockedSenders` по
  loaded-vs-total) + страница: «Show More» запрашивает следующий `offset` (число загруженных),
  дописывает страницу, `isLoadingMore` блокирует повтор. Контракт `test-blocked-users.cjs`
  расширен: ключи/дедуп/порядок, honestly-правило hasMore (пусто, догрузка, полный список,
  уменьшившийся total), проброс offset в команду, проводка страницы, строка `blocked_show_more`
  в 3 локалях. Гейты: host **113/113**, оба smoke, hvigor BUILD SUCCESSFUL.
  **Осталось (H8):** блокировка из профиля, blockListStories UI, iOS-карточки, witness.
- **S11b (lead).** H4: авто-скачивание по сетям. `TgAutoDownloadPage` (вход из Data and Storage):
  `getAutoDownloadSettingsPresets` → три пресета (low/medium/high), секции Mobile/Roaming/Wi-Fi,
  тап по строке применяет пресет через `setAutoDownloadSettings` (все 9 полей + маппинг
  networkType*), показывается сводка (лимиты фото/видео через `formatStorageBytes`) и пометка
  «Applied: level» в рамках сессии. Ограничение зафиксировано на экране и в матрице: в этой версии
  TDLib нет getter’а текущих настроек, поэтому реальный активный пресет не читается. Контракт
  `test-auto-download.cjs`: разбор всех полей пресетов, выбор уровня, проводка команд (маппинг сетей,
  9 полей), use case (пресеты→применение, отказ без пресетов до gateway, ошибки), экран/route/вход
  из хранилища/локали. Гейты: host **114/114**, оба smoke, hvigor BUILD SUCCESSFUL.
  **Осталось (H4):** лимит кэша, iOS-диаграмма, witness.
- **S11 (lead).** H4 «Данные и хранилище» из `missing` → `partial`. Экран `TgDataStoragePage`
  (Settings → Data and Storage): быстрые размеры (`getStorageStatisticsFast`: медиа, БД, языковые
  пакеты, логи), разбивка по чатам (`getStorageStatistics` с `chat_limit`, сортировка по размеру),
  «Clear Cache» через `optimizeStorage` с нулевыми лимитами после подтверждения; `formatStorageBytes`
  в DTO-модуле, имена чатов из `AppState`, состояния loading/error/retry. Строка Data and Storage,
  удалённая как мёртвая 2026-10-25, восстановлена уже с route и destination — `test-dead-controls.cjs`
  переписан на «строка есть И ведёт на зарегистрированный экран» вместо `doesNotMatch`. Контракт
  `test-data-storage.cjs`: форматирование размеров, точные int64 в статистике, сортировка и отсев
  мусора, проводка команд/сериализатора (нулевые лимиты, пустые фильтры), use case (fast→full,
  необязательная разбивка, fatal fast-ошибка, clearCache, валидация), экран/route/settings/локали.
  Гейты: host **113/113**, оба smoke, hvigor BUILD SUCCESSFUL. **Осталось (H4):** авто-скачивание по
  типам/сетям, лимиты кэша, iOS-диаграмма, witness.
- **S10 (lead).** H8 «Заблокированные пользователи» из `missing` → `partial`. Экран
  `TgBlockedUsersPage` (Settings → Blocked Users, отдельная строка и route): список из
  `getBlockedMessageSenders`, имена из `AppState` (user first+last или @username, chat title, иначе
  fallback с id), разблокировка через `setMessageSenderBlockList` с null-блок-листом после
  подтверждения и с перезагрузкой; состояния loading/error/retry/empty. Контракт
  `test-blocked-users.cjs`: DTO user/chat (включая мусорные записи и null-слоты), проводка команд
  (blockListMain/Stories, block vs null), use case (валидация пагинга до gateway, unblock, пустой
  ответ), экран/route/settings/локали. Гейты: host **112/112**, оба smoke, hvigor BUILD SUCCESSFUL.
  **Осталось (H8):** «показать ещё», блокировка из профиля, blockListStories UI, iOS-карточки,
  witness.
- **S9b (lead).** H5: разделы и завершение всех. `SessionDto.sessionType` + `sessionSelectors`
  (`isWebSession`, `splitSessionsByKind`, `canTerminateOthers`) делят список на Active/Web по
  `sessionType*` (браузеры Brave/Chrome/Edge/Firefox/Opera/Safari/Vivaldi — web, остальные — app);
  экран рисует две секции, «Terminate All Other Sessions» появляется только когда есть что завершать
  и уходит в `terminateAllOtherSessions` после подтверждения. Контракт `test-sessions.cjs`
  расширен: `sessionType` в DTO (включая отсутствующий тип), классификация всех 17 типов, порядок
  секций, `canTerminateOthers`, команда/сериализатор terminate-all, use case, секции/строки в
  странице, 13 локалей. Гейты: host **111/111**, оба smoke, hvigor BUILD SUCCESSFUL.
  **Осталось (H5):** привязка к 2FA, подтверждение новых сеансов, iOS-карточки, witness.
- **S9 (lead).** H5 «Устройства/сессии» из `missing` → `partial`. Новый экран `TgSessionsPage`
  (Settings → Devices; строка уже была, добавлен `onOpenDevices` → push на root-стек):
  `getActiveSessions` → `SessionDto`, текущий сеанс помечен и не завершается, `terminateSession`
  после подтверждения и с перезагрузкой списка. Попутно: `TdObject.getTopLevelRawObjectArrayStrict`
  — старый `getTopLevelObjectArrayStrict` пересобирает дочерние объекты через JSON.parse и теряет
  точность int64 (id сессии `9007199254740993` превращался в `...992`); слайсы исходного текста
  сохраняют литерал. Контракт `test-sessions.cjs`: DTO (точный int64, флаги, пустые поля, null-слоты,
  неправильные payloads), команды/сериализатор, use case (валидация id до gateway, пустой ответ не
  роняет), экран/route/settings/локали. Гейты: host **111/111**, оба smoke, hvigor BUILD SUCCESSFUL.
  **Осталось (H5):** завершить все остальные сеансы, разделить web-сессии, привязка к 2FA,
  iOS-раскладка секций, witness.
- **S8b.2 (lead).** B6: «Add to folder». `AddChatToListPayload`/фабрика/сериализатор получили
  `chatList: folder` + `folderId` (`chatListFolder` JSON), `MoveChatToListUseCase.addToFolder(chatId,
  folderId)` валидирует вход и шлёт `addChatToList`; `selectAddToFolderTargets` отдаёт только папки,
  где чата ещё нет; меню рисует секцию с названиями папок (`chat_context_add_to_folder` в base/ru/zh).
  Удаление из папки в этой версии TDLib отсутствует — пункт не предлагается. Контракт
  `test-chat-list-context-menu.cjs` расширен: команда/фабрика/сериализатор (регрессия archive),
  `addToFolder` (включая отказ при неверных id и то, что main). Гейты: host **110/110**, оба smoke,
  hvigor BUILD SUCCESSFUL. **Осталось (B6):** Join chat/channel, Select, Add to contacts, Remove from
  recents.
- **S8b.1 (lead).** Bugfix: «mark as unread» не был двусторонним. TDLib держит `is_marked_as_unread`
  отдельно от `unread_count`, присылает `updateChatIsMarkedAsUnread`, а приложение этот апдейт
  игнорировало — после переключения состояние в списке оставалось прежним, а меню предлагало
  «mark as unread» повторно. Добавлены парсинг `chat.is_marked_as_unread`, обработчик
  `updateChatIsMarkedAsUnread`, поле `Chat.isMarkedAsUnread` (создание + оба merge-пути reducer),
  `ChatItemVO`/diff строки, условие меню и обработчик (`markAsRead`, если есть unread или ручная
  метка). Контракт `test-chat-list-context-menu.cjs` расширен: парсинг full chat, dispatch через
  реальную registration-map, установка/снятие флага в reducer, «mark as read» для помеченного чата,
  VO и diff. Гейты: host **110/110**, оба smoke, hvigor BUILD SUCCESSFUL.
- **S8a (lead).** B6 «Контекстное меню чата» из `missing` → `partial`. Long-press по строке списка
  открывает меню (`bindContextMenu`, `ResponseType.LongPress`) с iOS-порядком действий: mark
  read/unread → archive/unarchive → pin/unpin → mute/unmute → delete (destructive). Модель — чистый
  селектор `chatContextMenuSelectors.ets` (Saved Messages меню не получает), действия делегируются
  существующим use case, архив/разархив через `handleMoveToArchive`/`handleMoveToMain`. Лейблы
  `chat_context_*` в base/ru/zh, токены `CHAT_CONTEXT_MENU_*`, контракт
  `test-chat-list-context-menu.cjs` (труth table по состояниям, иконки-ассеты, проводка, локали,
  токены). Гейты: host **110/110**, оба smoke, hvigor BUILD SUCCESSFUL. **Осталось (B6):**
  пункты по типу чата (Add to contacts, Join chat/channel, Add/Remove from folder, Select, Remove
  from recents), выделение нескольких чатов.
- **S7b.3 (lead).** B7: пагинация по папке. `LoadChatsPayload` получил `chatList: folder` +
  `folderId` (фабрика `createLoadChatsCommand(limit, chatList, folderId)`), сериализатор отправляет
  `chatListFolder` JSON; новый `LoadFolderChatsUseCase` держит один запрос на папку в полёте, cooldown
  1.5 c после ответа (TDLib может ответить пусто), отменяется вместе со страницей; `ChatListPage`
  запрашивает первую страницу при выборе папки и догружает её на скролле вместо основного списка.
  Контракт `test-chat-folders.cjs`: проводка команды/фабрики/сериализатора (включая регрессию archive),
  дедупликация в полёте, cooldown, folder 0, отмена, проводка страницы. Гейты: host **109/109**,
  оба smoke, hvigor BUILD SUCCESSFUL. **Осталось (B7):** экран настроек папок, folder link preview.
- **S7b.2 (lead).** B7: полоса папок подключена к списку. `TgChatListFilterBar` получил
  `TgChatListFilterTab` (id/title/unread), режим реальных папок с горизонтальной прокруткой и
  бейджами (легаси All/Unread/Personal остаётся фолбэком при одной вкладке), `TgChatListNavigationBar`
  пробрасывает `filterTabs`/`selectedFolderId`/`onFolderFilterChange`, `ChatListPage` строит вкладки
  из `selectChatFolderTabs` и при выборе папки перестраивает список из `selectChatIdsForFolder`
  («All chats» — прежний `orderedChatIds`). Счётчики: `updateUnreadChatCount` →
  `chatListUnreadCountUpdated` (`main`/`archive`/`folder:<id>`) → `ChatFoldersState.unreadByList` →
  бейджи. Строка «All» локализована (`chat_folders_all`, base/ru/zh). Контракт `test-chat-folders.cjs`
  дополнен: клавиши списков (folder id 0 отбрасывается), сохранение папок при обновлении счётчика,
  бейджи вкладок, контракты atom/navbar/page и три локали. Гейты: host **109/109**, оба smoke,
  hvigor BUILD SUCCESSFUL. **Осталось (B7):** пагинация `loadChats(chatListFolder)`, экран настроек
  папок, folder link preview.
- **S7b.1 (lead).** B7: принадлежность чатов к папкам. `ChatDto` парсит **все** `chatListFolder`
  позиции (`folderOrders`, типизированный `extractFolderPosition`), `Chat` их зеркалит,
  `updateChatAddedToList`/`updateChatRemovedFromList` обновляют членство (`folderId`/`folderOrder`/
  `folderRemoved` → `applyFolderUpdate` в `chatsReducer`), `selectChatIdsForFolder` отдаёт состав
  папки в её собственном порядке (`chatListMain` намеренно не используется). Контракт
  `test-chat-folders.cjs` расширен: парсер позиций, оба update-а (включая `folder_id = 0`),
  добавление/удаление членства без изменения main/archive order, сортировка состава. Гейты: host
  **109/109**, оба smoke, hvigor BUILD SUCCESSFUL. **Дальше (S7b.2):** data-driven
  `TgChatListFilterBar` + фильтрация списка и пагинация `chatListFolder` + unread по папкам.
- **S7a (lead).** B7 «Папки чатов» из `missing` → `partial` (слой данных). TDLib-контракт
  `updateChatFolders` (td_api.tl:9683) нормализуется в `chatFoldersUpdated` (папки, позиция
  «All chats», флаг тегов); состояние зеркалируется в `AppState.chatFilters`
  (`ChatFolderInfo`/`ChatFoldersState`), роутинг через `chatFoldersReducer` (полная замена,
  `cloneStateForChats`), селектор `selectChatFolderTabs` ставит «All chats» на позицию TDLib и
  клампит выход за границы. Контракт `test-chat-folders.cjs`: разбор нормализатора (включая
  malformed/unknown записи), замена состояния без мутации, все позиции вкладки, проводка
  регистрации/роутинга + сверка с `td_api.tl`. Гейты: host **109/109**, оба smoke, hvigor
  BUILD SUCCESSFUL. **Дальше (S7b):** data-driven панель фильтров, фильтрация списка по
  `chatListFolder` + `updateChatAddedToList/RemovedFromList`, счётчики непрочитанного по папкам.
- **S6c (lead).** D7: аватар-закладка в шапке чата. `ChatAvatarPresentation.isSavedMessages`
  вычисляется по `state.auth.userId` (токен/приватный чат), идёт через port
  `chatIsSavedMessages` → `ChatChromeState` → `TgChatTopBar.avatarIsSavedMessages` →
  `TgAvatar.symbolIcon`, т.е. вместо инициалов аккаунта рисуется `sys.symbol.bookmark_fill`.
  Гейты: host **108/108**, оба smoke, hvigor BUILD SUCCESSFUL.
- **Witness-блокер (снят фактически).** Эмулятор доступен (`hdc list targets` → `127.0.0.1:5555`,
  API 26), **unsigned HAP ставится** (`hdc install -r` → success), приложение запускается свежим
  процессом (PID 20175, STIME 02:36:55 < now 02:37:26), но сессия **не авторизована**: экран ввода
  номера. Т.е. блокер witness-ов — не подпись и не сборка, а отсутствие залогиненного аккаунта
  (нужен номер + код). Доказательство: скриншот `snapshot_display` 1280×2832 (auth-экран).
- **S5c (lead).** Долги C9 закрыты частично: выбранная строка теперь подсвечивается
  тинтом (`SELECTION_ROW_TINT` → `selection_row_tint` в base/dark), а диалог удаления называет
  размер выбора — «Delete %d messages?» / «Удалить %d сообщений?» / «删除 %d 条消息？»
  (`delete_messages_count`, `messageCount` в `NativeDeleteMessageConfirmation`, один диалог и один
  `deleteMessages` на весь выбор). Хост-контракт `test-selection-mode.cjs` расширен: поведенческая
  проверка заголовка для 1 и N сообщений, токен/цвет тинта, проводка строки. Гейты: host **108/108**,
  оба smoke, hvigor BUILD SUCCESSFUL. **Остаётся:** Copy глифом (нет ассета), device-witness.
- **S6b (lead).** D7 получил точку входа: строка «Saved Messages» в настройках больше не
  мёртвая — `SettingsPage` эмитит `onOpenSavedMessages`, `MainTabsPage` открывает уже существующий
  чат либо создаёт его через `createPrivateChat(my_id)` (td_api.tl:8726), гидрирует стор
  `createNewChatEvent` и пушит экран чата. Транзакция открытия (запись navigation/chat-состояния,
  nav-lock, откат при исключении, защита от нового владельца) вынесена в общий
  `ChatOpenTransaction.pushChatScreenRoute`; на неё переведены и `ChatListPage`, и
  `TgArchivedChatsPage` — три копии блока свёрнуты в одну. Host-контракты
  `test-chat-open-transaction.cjs` (4 сценария транзакции + проводка) и обновлённый
  `test-saved-messages.cjs`. Гейты: host **108/108**, оба smoke, hvigor BUILD SUCCESSFUL.
  **Долг:** пункта в меню iOS нет (только настройки), аватар в шапке чата не обновлён, device-witness.
- **S6a (lead).** D7 «Избранное» из `missing` → `partial` (представление): предикат
  `isSavedMessagesChat` (private-чат с `peerUserId === state.auth.userId`), заголовок «Saved Messages»
  в списке и в шапке чата вместо имени аккаунта, аватар-закладка через новый `TgAvatar.symbolIcon`
  (`sys.symbol.bookmark_fill`), флаг `isSavedMessages` в VO и в diff строки списка. Host-контракт
  `test-saved-messages.cjs`. Гейты: host **107/107**, оба smoke, hvigor BUILD SUCCESSFUL. **Долг:**
  точки входа нет (строка в настройках без `onRowClick`, нет пункта меню/создания чата), верхняя
  панель чата и строки других экранов не проверены, device-witness.
- **S5b (lead).** C9 «панель выделения сообщений» из `missing` → `partial`. Вход — пункт
  «Select» в меню действий; состояние `selectionActive`/`selectedMessageIds` в
  `ChatTimelineViewState` с alias-геттерами; делегаты входа/тоггла/выхода, `selectionTitle`,
  copy (тексты в порядке таймлайна), forward (тот же `startForwardMessages`), delete
  (`ChatDeleteMessageController.requestMany` — одна доступность, один диалог, один
  `deleteMessages`); панель `TgSelectionPanel` с паспортом/demo и токенами заменяет композер; строка
  в режиме выделения показывает чек-индикатор и блокирует тапы бабла (`.enabled(false)`), тап строки
  — тоггл. Строки «Select»/«%d selected» в base/ru/zh. Гейты: host **106/106**, оба smoke, hvigor
  BUILD SUCCESSFUL. **Долг:** иконки вместо текстовых действий, подсветка выбранных баблов, диалог
  pass по apple-design + iOS-источнику: панель = строка input-панели 40 px, действия — круги
  40×40 (иконки close/forward/delete, Copy — глиф ⧉), стекло через `TgGlassPolicy`, press-feedback —
  нативный эффект `Button`, счётчик SemiBold по центру.
  удаления с формулировкой для N сообщений, device-witness.
- **S5a (lead).** C6 «разделитель непрочитанных» верифицирован и доведён: модель уже создавала
  запись `kind='unread'` (`firstUnreadIncomingIndex`, sticky-граница, `'0'` как валидная граница,
  сброс sender-group), но строка матрицы висела `missing` без тестов. Добавлены паспорт
  `TgUnreadMarker` (геометрия сверена с iOS `ChatUnreadItem.swift`: 25 px, радиус 0, отступы 6/5),
  отдельный ресурс `chat_unread_messages` («Unread messages», ru/zh — было «Unread» из строки
  фильтра чатов) и host-контракт `test-unread-divider.cjs` (6 сценариев + геометрия + локали).
  Гейты: host **105/105**, оба smoke, hvigor BUILD SUCCESSFUL. C6 → `partial`: witness скролла к
  непрочитанному на устройстве не снят (долг в TODO).
- **S1 + S1.1 (typing-slice).** TTL активности 8 s по iOS, откат по дедлайну без новых store-change,
  группа — только имя, приватный — текст активности, статические точки из токенов, «печатает…» в
  трёх локалях, единый TTL в шапке и списке. Восстановлен harness `chat-screen-source.cjs` для
  не-delegate helper'ов. Host 96/96, smoke и build зелёные. **C2 остаётся `partial`:**
  визуальный witness требует второго аккаунта/клиента.
- **S2 (sticker-slice).** `TgsPlaybackPolicy`: играть только видимое, поверхность (панель — никогда),
  LRU-кеш распакованного Lottie по `fileId`, бюджет 4 инстанса, `@Monitor('tgsPath')`, pass-through
  `fileId` до плеера, warn-лог провала декода. Найдены причины «живой рендер не пойман» и перегруза
  API23. Build + 4 статических TGS-контракта зелёные. **D13 остаётся `partial`** до witness.
- **S3 (lead).** Дизайн reactions: контракт TDLib (`setMessageReactions`, `updateMessageReactions`),
  швы в VO/команды, состояния, разбиение S3a–S3d —
  `docs/specs/2026-10-25-reactions-design.md`.
- **Долги** внесены в `TASKS/TODO.md` §Debt: пульсация точек, мульти-typing, статичная панель стикеров,
  нативный TGS-рендерер, witness C2/D13; плюс мёртвые контролы из аудита — отдельными дефектами.
- `harmonyos_docs` MCP в этой сессии недоступен (только colab/rea/rea-linux) — оба агента
  зафиксировали это ограничением, новых ArkUI API не вводили.
- **Witness: D13 закрыт, C2 открыт.** Второй подъём HVD (watchdog подавлен) дал стабильный гост;
  HAP + ohosTest установлены, сессия залогинена. On-device тесты: `ChatHeaderStatus` 8/8,
  `TgsPlaybackPolicy` 12/12. В чате `HUAWEI Chat` пойман живой TGS-цикл: `tgs playback started
  key=file:11696 players=1`, повторный вход — снова старт, но без повторного декода (кеш по `fileId`);
  diff двух кадров через 700 мс различается только в области стикера (3 274 px) — анимация живая.
  **D13 → `available`.** Для C2 третья попытка (группа `HUAWEI Chat`, 906 участников, 25 дампов
  layout за ~4 мин) не поймала ни одного события набора — нужен второй участник, поэтому C2 остаётся
  `partial`, а цель помечена блокером по этому пункту.
- **Наблюдение:** первый `aa start` на этом прогоне дал `sysfreeze ... LIFECYCLE_TIMEOUT` (debug HAP,
  эмулятор); второй запуск поднялся нормально. Записано наблюдением в `TASKS/TODO.md` §Debt, не
  диагнозом: release-сборки нет, на устройстве не проверялось.

## Checkpoint — 2026-10-18

**Receive scheduling correction.** The drain tested its 8 ms budget before transferring, so a single
clock access or batch parse could consume a quantum with zero progress; an escalating multiplier
`elapsed * (1 + drainHotStreak)` stretched pauses to 250 ms even for a finite already-admitted
backlog. Now one transfer is guaranteed per turn, bounded by 50 transfers / 4 new batches, with the
inter-turn delay at twice the measured work and no backlog-age multiplier. Same-fixture native
comparison: admission→dispatch 31 847 → 5 598 ms, 37 rejected → 0. Four-variant split: baseline
6/15, progress-only 14/15, pacing-only 7/15, combined 15/15. FIFO, deadlines, byte/batch limits,
ownership, ACK ordering and no-uncertain-replay unchanged. [Report](docs/reviews/2026-10-18-receive-latency.md)

**Main acceptance stays PARTIAL.** The exact official package was installed over the existing session
(UID/install identity retained) and getMe, profile, chat list, existing history, Back and same-PID
background/resume were observed across two instances. But 2/4 unique observed request timeouts
(loadChats/getChat/setOption) remained, against historical 87/5 under different windows and workload.
No speedup is claimed. [Report](docs/reviews/2026-10-18-main-receive-acceptance.md)

**Diagnostic main localized, did not explain.** Two cold processes (PIDs 9355/10050) reproduced 4/10
timeout tokens. Selected batches reach Ark admission *after* their deadlines, and native send→copy
intervals overlap four-batch capacity waits by 17.8–36.5 s (88–93%). The second 3 456-record trace
stays PARTIAL at its 120 s cutoff; its initial history failed after an openChat timeout and a later
ordinary reopen displayed messages. Observer cost and TDLib response-ready timing remain unknown, so
**no further production fix is proposed**. [Runtime](docs/reviews/2026-10-18-main-diagnostic-runtime.md) ·
[build/isolated gates](docs/reviews/2026-10-18-bounded-timeout-diagnostics.md)

**Cleanup.** Thirty old Telegram HAPs permanently deleted under explicit authorization after exact
path/size/SHA-256 checks (1 508 061 896 bytes); all ten retained HAPs hash-verified.

## Carried forward — 2026-10-15

Scoped receive/privacy corrections are accepted locally: candidate12 host 95/95 plus static checks,
both official SDK builds inherited from source11, isolated native-postfull-v3 pair install, final
native focus 19/19 and full 1208/1208. Native/ArkTS credits cover active parsing; uncertain delivery
is never replayed. Photo observation remains PARTIAL despite a separate Hypium PASS; the older
unlogged keyboard mismatch and Slowmode title-wait cause remain UNCLASSIFIED.
[Report](docs/reviews/2026-10-15-receive-stabilization.md)

## What is not proven

Source, host and compile checks do not substitute for device, SDK, delivery or visual acceptance.
The unresolved boundary on main is *why consumer progress is too slow*: requested pacing, synchronous
parse/dispatch/store/listener/render work, scheduler contention and synchronous logging are not
partitioned, and TDLib response-ready timing is unobserved. Capacity being full is a symptom, not a
diagnosis; deadlines and memory bounds must not be relaxed to hide an admitted-wait timeout.

The iOS reference was refreshed on 2026-10-18 (`master` @ `f1dd7a2`, 31 572 commits). All 82 source
paths cited from these docs still resolve, but **59 of the 82 files changed upstream**, so their
line-number citations are unverified until re-read. See the refresh log in `REFERENCES.md`.

## Project facts

- **Branch:** `dev` is canonical, tracks `origin/dev`. `main` untouched; dev→main decision deferred.
- **Phase:** production quality against the iOS reference (user mandate 2026-08-31; v0.1.0 tag as a
  goal withdrawn).
- **Tests:** 87 `.test.ets` files under `entry/src/ohosTest/ets/test/` (DevEco `entry@ohosTest`);
  96 host behavioural suites in `scripts/`, run by `node scripts/run-host-tests.cjs` —
  **Node ≥ 24 required**.
- **Architecture:** solo mode, no `presentation/viewmodels/`; chat-page controllers centralized.

## Key documents

| Document | Purpose |
|---|---|
| `TASKS/TODO.md` | **Active queue**: open gates, backlog, decisions needed from the user |
| `TASKS/AGENT_EXECUTION_PLAN.md` | Canonical route (order of phases) |
| `TASKS/PRODUCTION_PARITY_PLAN.md` | Per-phase exit criteria and evidence boundaries |
| `TASKS/LESSONS.md` | Dated blocks + numbered lessons (83–163) |
| `docs/reviews/INDEX.md` | All review reports, newest first (78) |
| `probe/README.md` | Receive-drain harness, status, recorded runs |
| `TASKS/ARCHIVE/INDEX.md` | History — read-only, not instructions |
| `REFERENCES.md`, `ARKGRAM_REFERENCE.md` | External reference registry and competitor notes |
| `ARCHITECTURE.md`, `DECISIONS.md` | Structure and recorded decisions (D1–D25) |
| `README.md` | Build, verification, documentation map |
| `AGENTS.md`, `CLAUDE.md` | Local assistant rules (not versioned, see `.gitignore`) |
