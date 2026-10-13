# Полная декомпозиция экрана чата — 2026-10-01

Рефакторинг установлен локально в `C:/Users/Kharki/Desktop/Telegram-HarmonyOS`, ветка `dev`, HEAD `faf66b3e066afccdbbfa36442eb9122073f509b2`. Коммитов, push/PR/merge нет. Исходный dirty patch сохранён; before-hash guards и backups проверяют каждую замену. Baseline — текущая страница пользователя, 5730 строк, SHA-256 `c69b694f53706e08c1553be1e376162a899597859f59498c5505e70091ce47d1`.

## Фактические границы

`TgChatScreenPage.ets` теперь 164 строки, SHA-256 `720af6dd8be4f42fb752ed109edea25d56df2a34b7e096869181a411eeb15901`: destination/lifecycle wiring и композиция. Одна созданная страницей Session сохраняет route/account/lifecycle ownership. Шесть stable readonly `@ObservedV2` моделей содержат 112 единственных `@Trace` backing fields с исходными типами/defaults. Context хранит 106 оперативных полей и прямые aliases, без копии UI-state; platform callbacks ленивые.

Session содержит конструктор и 284 типизированных delegates, без перенесённого монолита алгоритмов. 32 связных модуля поведения имеют по 2–30 exports для route/lifecycle, timeline/history, interaction/composer, media/playback, panels/catalog и pinned/search. Каждый получает свой narrow port; общий набор 39 ports существует только в композиции. Shared scroll cache сохраняет прежний lifetime. Семь V2 UI children получают models и UI-only callbacks, без store/gateway/use-case/subscription доступа.

Независимое ревью сверило 277 исходных тел после обратного лексического receiver-преобразования, все 8 builders и развёрнутый `build()`: geometry, modifier sites, hit testing, keys, layer/handler order сохранены. Единственный удалённый метод `entryReuseId` не имел вызовов. 112 aliases/defaults, delegate arguments и отсутствие import cycles проверены. Digest 54 production-файлов декомпозиции: `67f5e3d5b708c75c9697218c8af199a9a53956ac4945cae78685d0cd22c6fe62`.

| Крупнейший новый/заменённый файл декомпозиции | Строк |
| --- | ---: |
| `ChatScreenSession.ets` | 477 |
| `ChatScreenContext.ets` | 394 |
| `ChatStickerCatalogCoordinator.ets` | 342 |
| `TgChatComposerDock.ets` | 312 |
| `ChatRouteActivationCoordinator.ets` | 303 |
| `ChatTimelineViewportCoordinator.ets` | 291 |
| `TgChatTimelineRow.ets` | 237 |
| `ChatPinnedMessagesCoordinator.ets` | 230 |
| `ChatPlaybackCoordinator.ets` | 219 |
| `ChatPageTeardownCoordinator.ets` | 206 |

Все новые production `.ets` ≤500; главный page ≤700. LOC дополняет проверку связности: Session — композиция, Context — handles/aliases, StickerCatalog — один catalog lifecycle, ComposerDock — визуальная поверхность, RouteActivation — одна guarded transaction, TimelineViewport — scroll/unread/position.

## Проверки и отдельно выявленные baseline дефекты

| Проверка | Итог |
| --- | --- |
| Original host baseline | 62/62 PASS |
| Actual checkout после установки | 63/63 host PASS; 20/20 PowerShell и Bash UI smoke PASS |
| Final verification candidate gate |22/22;284 delegates,98 binding payload checks;14 anchored mutants RED|
| Forced serial main / ohosTest SDK builds | PASS / PASS, ArkTS compilation без ошибок |
| Первый полный SDK run, до fixture поправок | 794: 792 passed, 2 failed, 0 errors |
| Первый focused SDK run с новой suite | 77: 76 passed, 0 failed, 1 error — прежний DataSource alias defect |
| Итоговый affected/new focused SDK run | 79: 79 passed, 0 failed, 0 errors |
| Итоговый полный SDK run | 806: 806 passed, 0 failed, 0 errors, 0 ignored |

Первый SDK failure в `ChatTimelineVO.test.ets` ожидал `file:///data/...`, а [fileUri SDK contract](https://github.com/openharmony/docs/blob/master/en/application-dev/reference/apis-core-file-kit/js-apis-file-fileuri.md) даёт sandbox URI с bundle. Expected теперь получен `fileUri.getUriFromPath` для того же точного fixture path; equality и остальные assertions сохранены. Второй failure в `LoadPinnedMessage.test.ets` был отдельным: positive fixture пропустил обязательный `is_downloading_completed=true`. Production projection требует завершённую загрузку. Добавлен negative case для false/missing flag с прежними semantics и пустым thumbnail path. Все три связанные production-файла и обе исходные test files совпадали с baseline — это не регрессии decomposition.

Новый реальный scroll-cache SDK test также выявил прежний `ChatTimelineDataSource.applyDiff`: `oldItems` был alias массива, изменяемого prepend splice, поэтому растущий old length приводил к чтению undefined и терял корректную anchor-tail обработку. Baseline SHA `1e152e560314ca8891ae6a5689f46d0f4473c67d67298fedbfb1f5f2d190dc17` подтверждён для original source snapshot и checkout до исправления. Узкая отдельная правка — snapshot `this.items.slice()`; исходный failing scenario сохранён, direct/anchor regression tests проверяют порядок, обновления и tail. Итоговый DS — 466 строк, SHA `6e3e44dd38619747c91a9b9e3984604ea7f2456d7c48ac0e3e66f81d56c0a75c`. Другие feature changes не вводились.

Финальный whitespace audit убрал один конечный ASCII-пробел в export signature `ChatReplyHydrationCoordinator`; тела методов не менялись. Обе SDK-сборки повторены PASS; main и ohosTest `modules.abc` побайтно совпали с уже прошедшими SDK runtime. SHA HAP после перепаковки отличается; runtime-tested ohosTest HAP SHA `694745b89292fc7c27aad8e33d15895f99a4abecc006a77be4a690c84a319a96`, его test bytecode SHA `7262086f91e4fb871628caafc4376f4e4a7327049490ffb946e0fa649b7be696`.

## SDK/runtime witness и пределы

Использован установленный DevEco toolchain без установки зависимостей. SDK-копия исключает local secrets, получает dummy API ID0/hash empty и публичный build profile без signingConfigs. Production bytes совпадают с установленным исходником; для emulator отличаются только bundle/label metadata. `harmonyos_docs` MCP отсутствует: API grounded в официальных OpenHarmony docs, локальных SDK declarations и фактическом compiler/runtime.

Existing `Pura 90 Pro Max` API24 запущен штатно headless, HDC `127.0.0.1:5555`. HAP установлен под `com.telegram.harmonyos.chatrefactor20261001`; metadata исходного `com.telegram.harmonyos` совпадает до/после. Его данные, сессия, app version и update time не менялись. JsUnit запустил `TestAbility`, а не production bootstrap; framework report parsed по passed/failed/errors, а не только HDC exit code.

11 новых real SDK cases создают настоящие Session/slices, проверяют stable identities, единственные aliases, arrays/session isolation, send-operation retirement, stable-key/unread restore, empty-route guards и lifecycle timers/generation, а также direct/anchor DataSource regression. Финальный candidate SDK Driver проверил12 native before/after presence selectors и отсутствие6 прежних значений. Эти slices принадлежат fixture Session; отдельно mounted real ChatPage создаёт другую production Session. Driver открыл настоящий `TgChatScreenPage` под Navigation, нашёл actual top-bar `Chat`, `TextArea` и localized empty label, вернулся Back. Test-only fixture не заменяет production widgets.

**Authenticated acceptance открыт:** dummy config останавливает production bootstrap на missing credentials. Empty route не проверяет реальные messages, history/pagination, reply/edit/forward/delete/send, emoji/GIF/sticker/bot/pinned/search, media/recording/playback, IME/safe areas, account switch/teardown. Нужны login отдельного candidate и fresh current-iOS comparison; physical-device witness не выполнен. Полный SDK suite не закрывает эти product flows.

## Документы и evidence

Обновлены compact snapshots `STATUS.md`, `TASKS/TODO.md`, `TASKS/LESSONS.md`, actual boundaries `ARCHITECTURE.md`, decision D17 в `DECISIONS.md`, execution plan `TASKS/CHAT_SCREEN_DECOMPOSITION_2026-10-01.md`. [Машинный evidence](2026-10-01-chat-screen-decomposition-evidence.json) фиксирует SHA, suite counts и runtime scope.

Сырые логи, manifests, backup bytes и final preservation audit сохранены в `C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/chat-split`: `installed-host-final.log`, `tests/installed-verification-summary.json`, `emulator-verification/sdk-build-final.log`, `emulator-verification/sdk-ohosTest-final.log`, `emulator-verification/ohosTest-focused-final.log`, `emulator-verification/ohosTest-full-final.log`, `installed-verification.json`, `final-public-source-audit.json`. Проверены 916 исходных public source files и совпадение всех 61 установленных entry source files с SDK-копией (55 production +6 tests). Scoped diff check не нашёл новых whitespace errors; общий diff содержит прежние untouched native whitespace issues. Petrelgram остаётся отдельным pinned reference, его runtime/dependencies не переносились.

## Закрытие verification findings после независимого review

Два P2 проверок исправлены в final candidate: nullable waits больше не проходят при missing slices; static gate отвергает composer text loss и scroll argument swap. SDK registered-callback probe21/21:3 positive no-match contracts и18 expected assertion failures для всех6 slices; static mutation audit14/14 RED.Native SDK79/79 и806/806 PASS, failures/errors/ignore0, raw completion counts проверены;host63/63,gate22/22,PS/Bash smoke иforced serial ohosTest build PASS. Два промежуточных SDK79/78/1 сохранены:strict undefined/nonnull-array assumptions не соответствовали native no-match result; финал нормализует толькоnull/undefined в0, проверяет actual array length и не перехватывает API errors. Production/пinned код не менялся.

Pinned coordinator/API gap унаследован: fixture A search→registry B→A rejection вызываетB getPinned черезglobal helper. Штатная достижимость не доказана: runtime shutdown/init serialization,scope invalidation иgateway generation fences сохранены. Это возможное чужое capability acquisition при явно заданном ordering, не доказанный device leak и не регрессия split. В этой задаче gap не исправлялся.

3 verification fixes установлены в actual checkout, 6 документов обновлены. Два auto-review отказа из-за прежнего read-only scope разрешены повтором той же команды после transcript evidence. Непричастные baseline files, runtime source, прежняя работа пользователя и index/history сохранились. Final tested public copy иSDK copy, hashes, raw logs, candidate115-path manifest, exactbaseline patch и942-file predecessor snapshot находятся в C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/chat-split/verification-fix. Отдельное решение о commit требует рассмотренного predecessor с 34 overlaps,без автоматического включения265 ранее dirty файлов. Authenticated/visual acceptance не заявлен.
