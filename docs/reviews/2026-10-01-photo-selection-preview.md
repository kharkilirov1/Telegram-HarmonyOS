# Превью выбранных фотографий — 2026-10-01

Выбранные 1–10 фотографий показываются перед отправкой: большая фотография, упорядоченные миниатюры, удаление и перемещение раньше/позже. URI остаётся идентичностью действия; перестановка сохраняет текущую фотографию. Удаление последней очищает вложение и сохраняет caption/reply. Превью находится над существующим composer.

## Владение и отправка

Порядок выбранных фотографий хранится в `ChatComposerState.pendingAttachmentUris`. Изменения проходят atom → binding → Session → ComposerController → Context setter, создают новый массив и увеличивают input revision. Повторяющиеся точные URI нормализуются при выборе; provider authority сохраняется. Состояние отправки хранится в одном `@Trace isSending` с прямым Context alias. Владение page/subscriber/route сохраняется.

Все 1–10 фотографий проходят общий PhotoAlbumController с проверками владельца и состояния: одна фотография использует существующий single use case, 2–10 — один album request. Snapshot содержит порядок, caption/reply и владельцев route/account/usecase/input. Переход в edit/forward до завершения отправки сохраняет новые данные даже без изменения revision. Photo Cancel и завершение picker также проверяют busy, режим, разрешения и актуальность snapshot.

Учёт использованных URI сохраняется после перестановки, выбора подмножества или одной фотографии и нескольких batches. Пересечение требует явного Cancel/Send again до копирования; запись создаётся до transport await. Откат известного отказа до принятия снимает только собственную запись. После 128 разных URI дальнейшие отправки требуют подтверждения; старые URI не забываются. Этот учёт защищает от повторной отправки и не подтверждает доставку.

`ChatAttachmentFilePreparer` читает source через native FD, копирует его в уникальный app-owned путь, закрывает source в finally и удаляет только собственные ещё не переданные файлы. Переданные пути сохраняются для TDLib upload. Protected observer после успешного open позволяет native test увидеть точный FD; production observer пустой. Исключение observer также проходит через finally. Закрытие проверяется на точном handle, без угадывания FD или чтения запрещённого `/proc`.

## Референсы

Pinned registry: [REFERENCES.md](../../REFERENCES.md). Все восемь references и licensing boundaries остаются зафиксированы в [принятом reference audit](2026-10-01-photo-album-references.md). Новый [паспорт атома](../../entry/src/main/ets/ui/tg_ui/spec/TgPhotoSelectionPreview.md) указывает iOS selected-list/photo-strip и HarmonyOS native Image/strip APIs.

iOS current — ordered identity/selection/reorder; старый iOS snapshot — историческая проверка поведения. Android/Nekogram — limit/selection/send semantics; HarmonyOS UX examples/Codelabs — native components и file/image patterns. Petrelgram — ArkTS/TDLib архитектурный reference, не готовая зависимость. ArkGram — ограниченный HAP-derived UX reference, без права копирования runtime/assets. Текущая реализация написана локально; reference деревья, pins, зависимости и assets не менялись. Explicit move buttons — отдельный HarmonyOS UX выбор; iOS drag/visual parity не утверждается.

`harmonyos_docs` MCP не доступен. API decisions сверены с публичными declarations установленного SDK и official OpenHarmony Image documentation; native execution проверяет применённый контракт.

## Проверки

| Проверка | Результат |
| --- | --- |
| Новый controller host suite | 90/90 PASS; 7 assertion-only mutants RED |
| Прежний album controller host suite | 23/23 PASS |
| Все host suites | 66/66 PASS |
| PS/Bash UI smoke | PASS |
| Forced serial main/ohosTest builds | BUILD SUCCESSFUL; source SHA и ABC markers проверены |
| Native PNG/JPEG file IO | 9/9 PASS: raw path/self-bundle URI, bytes/decode/source preservation, uniqueness/owned cleanup, failures/exact-FD closure |
| Native preview | Один полный сценарий PASS: actual atom → Session/controller, reorder IDs, remove, busy, error/empty, горизонтальная лента из 10 фото/decode; gateway 0 |
| SDK focused/full | 122/122 и 866/866 PASS; 0 ignored |
| Independent chief | FINAL ACCEPTED; границы и hashes в отдельном отчёте |

Первый native запуск выявил readiness race; bounded waiting теперь требует настоящую TestAbility/Scroll. `/proc/self/fd` недоступен, initial FD cases оставлены RED в истории; новый exact-owned-handle witness проверяет native stat до и EBADF после close. Первые screenshots выявили недоступные цвета текста/error и искажённые пропорции от fixed-square sourceSize; mounted colors и native autoResize подтверждены финальными пикселями. Ten-photo test сначала использовал default vertical scrollSearch; исправлен документированный параметр vertical=false для горизонтальной ленты, сами ten/decode assertions сохранены. Полный набор завершённых assertions, hashes и границы: [evidence](2026-10-01-photo-selection-preview-evidence.json), [chief review](2026-10-01-photo-selection-preview-astra-review.md).

## Границы и следующий приоритет

Изолированный credential-free `com.telegram.harmonyos.chatrefactor20261001` API24; native screenshots используют только оригинальные synthetic PNG. Public bundle metadata исходного приложения совпадает до/после. Настоящая gallery/provider grant, picker read, Telegram send/receive/delivery и production Dock native mount не проверены. Directory-source native failure не доказывает запись partial destination bytes; injected host fault отдельно проверяет такую cleanup ветку. Current iOS light/dark/narrow visual comparison также остаётся отдельной acceptance.

Следующий согласованный этап — account/session reliability: воспроизвести ранее обнаруженный pinned fallback и запоздалые ответы regression tests, исправить узко и пройти независимый Astra xhigh review. Затем — сохранение точной причины gateway errors и точечные обновления списков с проверкой позиции/плавности. Typed video receive/render/gallery и mixed photo/video album остаются дальнейшими продуктовыми срезами. Real picker/provider и authenticated delivery acceptance требуют отдельного согласованного сценария с аккаунтом. Новый preview не является заявлением о завершении всей media parity.

## Локальная установка

Перенос проверяет SHA всех 1015 публичных файлов исходного dirty-дерева и сохраняет before-images для изменяемых существующих файлов. HEAD, index/cached diff и остальные публичные файлы должны совпасть после переноса. Точный installation receipt и status сохраняются в локальном `photo-preview` evidence. Commit/push/PR/merge не выполняются.
