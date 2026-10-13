# Полная декомпозиция TgChatScreenPage — план реализации 2026-10-01

> Для исполнителей: реализация и независимое ревью непересекающихся модулей параллельны; единственный integrator устанавливает staging и меняет общую страницу. Пользователь прямо разрешил довести задачу до результата, без остановки на плане и без commit/push.

**Цель:** превратить главную страницу чата в связующий UI-слой, сохранив существующее поведение и iOS UI contract.

**Исходник:** dev@faf66b3e066afccdbbfa36442eb9122073f509b2, dirty working tree; 5730 физических строк; SHA-256 c69b694f53706e08c1553be1e376162a899597859f59498c5505e70091ce47d1. Снимок байтов, method inventory и новый baseline268 пользовательских файлов сохранены вне проекта в task-2/chat-split. Рабочее дерево не изменилось с предыдущего обзора. Уже выполненные sticker-search/top-bar извлечения сохраняются.

**Архитектура:** одна созданная страницей ChatScreenSession владеет прежним route/account/lifecycle context и единственными оперативными полями. Наблюдаемое UI-состояние разделяется на шесть стабильных @ObservedV2/@Trace моделей. Typed aliases читают и пишут единственное backing field; копий состояния нет. Session компонует связные feature modules через типизированные узкие порты. Visual children получают наблюдаемые presentation models и UI-only typed callbacks, без AppStore/use-case capabilities и подписок. UIContext получается лениво через callback страницы.

**Платформа:** ArkTS/ArkUI V2, текущий установленный DevEco SDK. harmonyos_docs в этой среде недоступен; V2-контракт сверяется с официальными OpenHarmony state-management examples и локальными SDK declarations/compiler. Визуальная структура и токены берутся из действующих tg_ui atoms/specs и Telegram-iOS-current ChatControllerNode; новые визуальные решения не вводятся.

## Инварианты

- Сохранить reply/edit/forward/delete, permissions, общую operation identity, отмену и account/route/generation fencing.
- Сохранить точный teardown order, запись draft в прежний owning account после lifecycle revocation, openLease release и app-global playback lifetime.
- Сохранить единственный store subscriber, Scroller/DataSource и упорядоченную rebuildTimeline transaction.
- Сохранить LazyForEach keys, отсутствие V1 reuse, bubble popup captured generation, geometry/modifier attachment sites, safe-area/IME/composer height и layer order.
- Ни новых Petrelgram features, ни посторонних runtime исправлений, ни установки зависимостей/софта, чтения секретов, reset/clean пользовательского дерева.

## Реализация и владение

- [x] Architecture worker: bounded observed presentation models, typed context aliases, composition Session; только architecture staging.
- [x] Runtime worker: bounded lifecycle/route/history/timeline/media/panels/pinned/bot/draft/interaction modules и узкие feature ports; только runtime staging.
- [x] UI worker: реальные TimelineViewport/row, ComposerDock/panels, popup/pinned/gallery presentation components, typed bindings и main page draft; только UI staging.
- [x] Integrator: проверить body parity и ownership graph, установить staging с before-hash guards; перенаправить existing checks на фактических владельцев и закрепить page→component/module wiring отрицательными контролями.
- [x] Независимое итоговое ревью: новый граф, реактивность, teardown, delayed callbacks, overlay geometry и отсутствие dead wrappers/duplicated implementation.

## Критерии завершения

- Main page — только lifecycle/destination/UI composition и явное wiring; цель ≤700 строк. Новые production .ets — ≤500 строк каждый. Бюджет не оправдывает packing алгоритмов или пустые abstractions; каждая обязанность получает связного используемого владельца.
- Все вынесенные modules реально импортируются/вызываются; старые реализации удалены со страницы; отсутствуют временные stubs/TODO для завершения этой работы.
- Focused behavioral проверки охватывают текущие сценарии отправки/редактирования/forward/delete, media, search, lifecycle, account switch, stale callbacks, повтор/отмену. Старые source-only checks дополнены реальным delegate/render wiring; baseline и новые результаты различаются явно.
- SDK-free aggregate host gate, относящиеся PowerShell checks, PS/Bash UI smoke и последовательные main/ohosTest debug compile/build выполнены на итоговом дереве. Отдельный lint/type gate запускается при наличии в текущем toolchain; compiler diagnostics фиксируются.
- Device/UI witness выполняется только при объективно доступном безопасном target, без перезаписи сохранённой пользовательской сессии. Его отсутствие не маскируется host/build успехом.
- Последний git diff/status и SHA-256 сверяют, что не затронуты чужие файлы и сохранён исходный dirty patch. Результат локальный: без commit/push/PR/merge.

## Итог исполнения

Runtime установлен ранее: page164,53 новых production files; DataSource snapshot correction отдельно закреплена. Verification candidate теперь даёт gate22/22,98 bindings/284 delegates,14 mutants RED,SDK callback21/21,host63/63,PS/Bash,forced ohosTest build,SDK focused79/79/full806/806 PASS. Native assertions проверяют6 fixture slices до/после и отсутствиестарых значений; real empty-route ChatPage владеет другой Session. Authenticated/iOS matrix и inherited pinned API gap открыты. 3 исправления проверок установлены, 6 документов обновлены после разрешённого повтора с transcript evidence. Отдельный942-file predecessor public snapshot сохраняет все268 baseline paths/34 overlaps без измененияoriginal index/history. Manifest/patch готовы для отдельного решения после рассмотрения predecessor; commit/push/PR нет.
