# Reliability Wave15 — редактирование без потери ввода и межаккаунтной записи draft

Дата: 2026-09-06. Ветка `dev@faf66b3`; изменения не закоммичены.

## Результат

**Исправлен submit редактирования:** проверяются сообщение и разрешение, text и caption идут разными TDLib-командами, результат сверяется с запрошенным сообщением. Ввод остаётся доступным до подтверждения; ошибка и запоздалый callback не стирают новый текст. Устранена возможность отправить draft страницы аккаунта A через текущий gateway аккаунта B.

**174/174 focused; 53/53 edit-only/UI-chain; 32/32 account-draft; 32 CJS suites, 38 PowerShell + UI-smoke, исходный review witness 8/8. Обе final forced ArkTS compilation прошли.** Это source/host/compile-срез, не доказательство надёжности всего клиента.

Машиночитаемые результаты, команды, mutations и hashes: [evidence](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-06-reliability-wave15-evidence.json).

## Baseline → исправление → проверка

| Найденная проблема | Исправление | Свидетельство |
|---|---|---|
| Невалидный ID/отсутствие права, fulfilled Error и чужой Message принимались как успех | Strict ID/source/result; повторный `getMessageProperties.can_be_edited` перед mutation | Исходные 6 проверок: 0 PASS / 6 FAIL; сохранены в расширенных 174/174 |
| Draft и edit mode очищались до завершения запроса; duplicate submit не имел общего owner | Выделен `ChatEditMessageController`: account/use-case/chat/lifecycle/intent и общий send token; cleanup только своей операции | Pending/error/cancel/new typing/revoke; mutation draft-retention даёт 37 FAIL |
| Caption отправлялся через text API; пустую caption нельзя было удалить из composer | Typed `editMessageCaption`, точный content whitelist, caption-above flag; page-owned `allowEmptyEdit` | Actual menu → page → atom → composer → controller → domain → caption command входит в 53/53 |
| Entity metadata терялась через `TdObject.toJSON()`, являющийся lazy builder/cache | Отдельный received JSON accessor, strict entity payloads; serializer сохраняет вложенный type | Реальный URL loss был воспроизведён; domain → wire tests включают URL, user ID и строковый custom-emoji int64 |
| Snapshot draft принадлежал A, а глобальный runtime/gateway уже B | `persistDraft` сверяет owner scope до acquisition и перед dispatch; revoked scope не восстанавливается из глобального state | 32/32; снятие обеих scope-проверок действительно engaged (2), даёт 1 FAIL: A draft must never reach B gateway |

Не все 174 проверки существовали в baseline: исходные 6 сохранены, остальные добавлялись по новым контрактам и reviewer findings.

## Что именно защищено

- Fresh source read выбирает text/game либо один из семи caption kinds. Caption допускает пустую строку; обычный text — нет. Caption placement и пять preview options сохраняются.
- `expectedOriginalText` останавливает overwrite при изменившемся исходном тексте. `getMessageProperties` читает TDLib native cache/database: это **не запрос гарантированно свежего server state**.
- Scheduled Message ID допускает изменение date bits только при совпавшем scheduled server ID и распознанном scheduling state. Ordinary IDs сравниваются точно. После результата обновляются canonical ID и baseline, но не новый пользовательский ввод/selection.
- Strict formattedText/entities проверяются и у source, и у результата: UTF-16 boundaries, обязательные поля, допустимые типы, crossing/directional nesting. Например quote → code разрешён, code → formatting и semantic → quote не подменяются симметричным правилом.
- Single-splice fallback переносит стабильные ranges, не сохраняет старый скрытый URL/custom-emoji target на заменённом тексте и убирает неоднозначные изменённые styles. **Это не полноценный rich-text editor:** несколько раздельных правок могут потерять иначе неизменённые entities внутри общего splice.
- Unknown outcome не вызывает автоматического повторения mutation. Application store не переписывается оптимистически; это не отменяет внутренних TDLib side effects. `MESSAGE_NOT_MODIFIED` user-account TDLib уже нормализует в успешный Message.
- Pending edit отменяется при другом intent; old completion не разблокирует чужую отправку. После успеха новый ввод сохраняется; без нового ввода завершается текущий edit.
- `persistDraft` сохраняет корректный Back/disappear путь даже после сброса global navigation, но никогда не подбирает state другого аккаунта.
- Два сообщения об ошибке добавлены в base, ru_RU и zh_CN. Demo state 20 — **local-only** удаление caption: меняет только label, не отправляет запрос аккаунту.

## Референсы и отличие от iOS

Локальный TDLib HEAD `cb863c1600082404428f1a84e407b866b9d412a8`; iOS HEAD `6e370e06d147b091b07903071cb1b8a22152492d`.

- [td_api.tl](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/generate/scheme/td_api.tl): `editMessageText` 10922–10927, `editMessageCaption` 10956–10962; Message/FormattedText/entity/preview/scheduling contracts.
- [MessagesManager.cpp](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/MessagesManager.cpp): eligibility 22347–22464, text/game 22646–22683, native-cache properties 14753–14799, scheduled lookup 29568–29581.
- [MessageId.h](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/MessageId.h) и [MessageEntity.cpp](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/MessageEntity.cpp): scheduled bit layout и directional nesting. Это не заявление о полном воспроизведении TDLib normalization.
- [ChatControllerLoadDisplayNode.swift](C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/Chat/ChatControllerLoadDisplayNode.swift): 1764–1817 — rich edit state; 2302–2327 — commit flow. **В прочитанном iOS editor закрывается до RPC success. Сохранение ввода до подтверждения здесь — осознанная reliability adaptation, не буквальная iOS parity.**
- `harmonyos_docs`: запрос `"TextAreaOptions" AND "binding"`, официальные ArkUI TextAreaOptions и Two-Way Binding Between Built-in Component Parameters. Источник поддерживает platform/state grounding; UI корректность всё равно требует runtime witness.
- Четыре субагента разделили contract review, typed serializer, native fixtures и account-draft slice; их критические находки воспроизведены основным агентом. Подробности работ не заменяют приведённые исполняемые проверки.

## Проверка финального кода

| Свидетельство | Результат |
|---|---|
| `test-edit-message-safety.cjs` | 174/174, из них 46 actual Hypium bodies через host adapter: 14 edit + 32 serializer |
| `test-edit-only-send-guard.cjs` | 53/53, включая реальную caption UI-chain |
| `test-chat-draft-account-scope.cjs` | 32/32 |
| Сохранённый delete regression | 101/101 |
| Все `test-*.cjs` | 32 suites, exit 0 |
| PowerShell + UI-smoke | 38 scripts, exit 0 |
| Исходный review / syntax | 8/8; 33 CJS syntax checks |
| Final main | CompileArkTS 29 s 321 ms; BUILD SUCCESSFUL 54 s 543 ms |
| Final ohosTest | OhosTestCompileArkTS 26 s 176 ms; BUILD SUCCESSFUL 53 s 359 ms |
| Hash boundary | 62 ArkTS + 3 resource JSON неизменны до/после accepted builds и regression run |

Hash set относится к **накопленным dirty tracked/untracked файлам**, не только к Wave15. Builds не warning-free: есть прежние SDK icudtl.dat/NAPI warnings. Native test compilation и исполнение Hypium bodies в Node **не означают запуск тестов на устройстве**.

Все 16 focused mutations реально engaged по одному разу и дали FAIL:
`properties 5; identity 10; dispatch 13; caption-route 15; context 20; busy-owner 4; draft-retention 37; raw-entity 2; semantic-target 2; entity-validation 23; source-conflict 2; scheduled-key 2; entities 2; preview 1; outcome 24; cancel-intent 1`.
Отдельный account-scope mutant: 2 engagements, 1 FAIL. Это чувствительность конкретных checks, не исчерпывающая оценка качества.

## Эмулятор: проверено и заблокировано

Свежий `hdc list targets` вернул **[Empty]**. Новых boots/installs в Wave15 не было; запросов реальному аккаунту не отправляли.

[Wave10 runtime report](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-06-reliability-wave10.md) содержит три изолированных API24 boots с реальным shell, затем SceneBoard LIFECYCLE_TIMEOUT → kernel panic **до установки Telegram**, чёрный screenshot и fault captures. Конкретная OS/GPU/RAM причина не доказана. Нынешний [Empty] не является новым воспроизведением crash. Повторять тот же boot без новой диагностической гипотезы бессмысленно; рабочие профили и сессии не сбрасывались.

Открыты: native keyboard/caption action, demo20 Light/Dark/layout, callback lifecycle, реальные TDLib updates и visual comparison с текущим iOS runtime. Ни emulator acceptance, ни публикационная готовность не заявлены.

## Изменённые файлы

- Domain/transport: `entry/src/main/ets/domain/usecases/editMessage.ets`, новый `EditMessageFormatting.ets`; `core/model/AppCommand.ets`, `infra/td/serialization/CommandSerializer.ets`, `models/td/common/index.ets`.
- UI runtime: новый `entry/src/main/ets/ui/pages/chat/ChatEditMessageController.ets`; `ChatMessageActionsController.ets`, `TgChatScreenPage.ets`; `ui/tg_ui/atoms/TgComposerInput.ets`, demo и `spec/TgIosNativeLiquidComposer.md`.
- Три локализованных `entry/src/main/resources/*/element/string.json`.
- Tests: новые `scripts/test-edit-message-safety.cjs`, `scripts/test-chat-draft-account-scope.cjs`, `EditMessagesSafety.test.ets`; актуализированы edit-only/delete host fixtures, `CommandSerializer.test.ets`, `UseCases.test.ets`, `List.test.ets`, forward native host fixtures.
- Рабочие STATUS/TODO/LESSONS, Chat Access/Production Parity plans и этот отчёт/evidence. Полные production paths и SHA256 — в evidence. Старые незакоммиченные изменения других срезов сохранены.

## Следующий срез — не закрытые обещания

1. Аудит account ownership соседних `closeChat`/draft restore lifecycle paths.
2. Edit entry: native `can_be_edited` вместо outgoing/hasText эвристики, incoming administrator, stale menu callback; восстановление прежнего compose draft/reply при cancel и безопасные edit → Reply/Forward переходы.
3. Rich-text editor, multi-splice history, динамические text/caption limits и Unicode length. Сейчас preflight всё ещё использует общий лимит 4096 UTF-16 units.
4. Edit/expiry/thread/specialized editors, special Delete/Undo, source metadata recovery; отдельный device/visual/soak gate и локализация системного emulator crash.

Нельзя объявлять надёжность равной/лучшей iOS по числу PASS. Маршрут reliability → existing UI → features/UI → publication остаётся активным.
