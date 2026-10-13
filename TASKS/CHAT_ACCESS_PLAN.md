# Chat access — channel, basic group и ordinary supergroup permissions

2026-09-06. **Channel/group permissions, forward, safe Delete/edit и route/account ownership реализованы source + host + compile в указанных сценариях.** Полная history/native-count/account/device parity не доказана. Текущий отчёт: `docs/reviews/2026-09-06-reliability-wave17.md`; следующий срез — `TASKS/CHAT_ROUTE_OWNERSHIP_PLAN.md`.

## Wave17 — текущий route ownership срез

- Captured params до async/push; эффекты после binding; navigation owner отличает same-chat страницы; forward transfer привязан к route token. Три caller-open заменены page-owned logical lease.
- Lifecycle86/86, callers69/69, lease78/78; 36CJS/38PS/review8, final serial compile и72 stable hashes. Early read snapshot исправлен для chat, известного к Ok.
- Отдельный host probe остаётся FAIL: первый chat после Ok теряет unread boundary. TDLib noRead→Ok без increment позволяет release A закрыть live B в source-derived модели. Оба gates открыты; shared media/jump/search требуют отдельного аудита. Device runtime не исполнен.

## Wave16 — сохранённый lifecycle/account срез

- Captured gateway/store до restore; close без global adapter re-acquisition; scoped draft restore, edit/forward preservation. Retained component account identity переживает disappear и запрещает A→B rebind.
- Public isScopeCurrent защищает от revoked scope, но не запрещает Back для удалённого chat. Navigation visibility/clear/Back не затрагивают другой account/chat; одинаковые account/chat у двух pages ещё требуют unique owner.
- 49/49 focused, reappear 7/7, mutations 7/6/6/4 FAIL; 33 CJS / 38 PS+smoke / review 8/8; final serial обе compile и 65 stable hashes. Initial delayed route и native acquisition не объявлены решёнными; HDC [Empty], новых boots/install нет.

## Wave15 — сохранённый edit/draft срез

- Fresh strict source → native-cache can_be_edited → typed text/caption mutation → matching Message. Caption removal разрешается реальной page/atom chain; scheduled aliases rebase canonical ID. No automatic replay/optimistic store write; edits сохраняют ввод до подтверждения, old callbacks не очищают newer typing и чужой busy.
- Received entities/preview проходят actual serializer; UTF-16 splice, semantic-target removal и directional nesting проверены. Full rich text/multi-splice/dynamic limits не реализованы. Сохранение editor до подтверждения — intentional iOS deviation.
- persistDraft больше не отправляет account A buffer через runtime B; captured scope, revoked-state guard и closing Back/disappear path покрыты. Соседние closeChat/draft-restore global paths требуют отдельного аудита.
- 174/174 (46 native bodies через host), edit-only UI-chain 53/53, draft 32/32, сохранённый delete 101/101; 32 CJS / 38 PS+smoke / review 8/8, final обе compile и 65 stable hashes. 16 engaged edit mutations + account mutant обнаружены. HDC [Empty], новых boots/install нет; demo20 local-only и native/device acceptance открыты.

## Wave14 — сохранённый destructive-action срез

- Native confirmation предлагает только per-message self/everyone modes; Cancel — отдельный no-op, captured index map. Exact mode повторно проверяется перед dispatch, неизвестные properties запрещают mutation. Strict received Ok; unknown outcome без auto-retry и без scope fallback.
- Account/chat/lifecycle/use-case/intent fencing, one local confirmation flow и own-generation cleanup. Прямой channel-share Forward отменяет pending delete до async lookup, как и Reply/Edit/new menu.
- 101/101 (20 native bodies через host), 30 CJS / 38 PS+smoke / review 8/8; final main/ohosTest compile и 60 stable hashes. TDLib Ok не per-ID/atomic receipt. Undo и Saved/scheduled/repeating/paid/giveaway semantics, runtime dialog acceptance остаются отдельными gates.

## Wave13 — сохранённый menu/picker-срез

- `ForwardMessagesUseCase.getSourceAvailability` пересекает normal/secret routes всей selection; source capability отдельна от source composer permissions. `ChatForwardSourceController` даёт loading/allowed/denied/retry без auto loop.
- Stable action ID + source/opening/account/lifecycle identity. Dismiss factory captures generation; replacing intent отменяет старый picker; duplicate-open и one-shot result fencing. Target route flags влияют на rebuild/select, Compose сохраняет семантику.
- 62/62 (12 native bodies через host), 29 CJS / 38 PS+smoke / review 8/8; final main/ohosTest compile, 54 ArkTS + 3 resource hashes стабильны. Disabled Forward — deliberate Harmony adaptation, visual/device gate открыт.

## Wave12 — сохранённый dispatch-срез

- `getMessageProperties` typed command/serializer, exact target `getChat`, mode-specific source flags и request-bound snapshots. Проверка до comment, повторно до forward; after-await callback проверяет owning operation и текущую capability.
- Source kinds проверяются в basic И ordinary supergroup. Unknown source metadata пока conservative deny, не разрешение по общему text composer. Source-menu flow реализован Wave13; metadata hydration остаётся отдельным gate.
- 75/75 (25 native bodies через host), 28 CJS / 38 PS+smoke / review 8/8; forced main/ohosTest compile PASS, 51 hashes стабильны. Mutations 24/11/2/14/9 FAIL; HDC [Empty], новых boots/install нет.

## Wave11 — сохранённая boost-вертикаль

- `SupergroupBoostsDto` → strict `updateSupergroupFullInfo` → typed event → combined reducer → отдельная map. Known zero отдельно от unknown; FullInfo response использует captured request ID, не активную страницу.
- `loadBoosts` singleflight/dequeue live guard/account fencing; controller stages membership → defaults → потенциально нужные boosts. Уже разрешённые kinds не блокируются ожиданием FullInfo.
- Page subscribed на active supergroup access/boosts, reactive kind snapshot и fresh dispatch. Partial failed load при composer получает отдельный native Retry; общий unknown использует существующий action bar. Никакой silent automatic retry loop.
- 32/32, 9 native bodies через host, 27 CJS / 38 PS+smoke / review 8/8; final main/ohosTest compile, 50 stable hashes. Demo 19 и новый Button требуют real visual/device witness. Следующее: source-forward eligibility и прочие перечисленные exceptions.

## Проверенные точки входа

- `ui/pages/chat/ChatInputPanelPolicy.ets` — pure policy; `TgChatScreenPage.ets` — scoped state, active-group subscription, input/send guards; `ChatAccessController.ets` — bounded unknown hydration/retry.
- `core/model/dto/GroupAccessDto.ets` → `ChatNormalizer.ets` → `AppEvent.ets` → combined `reducers/index.ets`/`chatsReducer.ets` → state maps; статус не зависит от наличия newChat.
- `domain/usecases/loadChatAccess.ets` — scoped single-flight, exact getSupergroup/getBasicGroup, identity guard при dequeue; `TdObject.getTopLevelNumberStrict` исключает вложенные/усечённые ID.
- `tdlib/td/generate/scheme/td_api.tl:2147–2171`: creator имеет is_member, administrator — rights, restricted — is_member/permissions, left и banned — отдельные состояния.
- `td_api.tl:2327,2372`: basicGroup/supergroup содержат собственный status текущего пользователя.
- Лично прочитанный iOS-референс: `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/ChatInterfaceStateInputPanels.swift:234–255,351–365`. Kicked выбирает DeleteChat panel; broadcast проверяет membership/sendSomething; editAllMessages при активном редактировании — отдельное исключение. Это source behavior reference, не visual acceptance.

## Узкая вертикаль

1. Перед кодом обновить grounding через harmonyos_docs; проверить точные `updateSupergroup/updateBasicGroup`, `getSupergroup/getBasicGroup` и administrator-rights в локальном td_api.tl.
2. Typed access DTO/model: role, membership, posting rights, явный unknown. Хранить group access по group ID, чтобы update до newChat не терялся; покрыть clone и reset.
3. Actual normalizer → AppEvent → reducer → pure panel selector → page. Для broadcast channels убрать order/archiveOrder/default permissions из решения о доступе.
4. Unknown загружается через scoped gateway/store и точный getGroup, не FullInfo; failure остаётся unavailable, не guessed member. Pending request не должен восстановить A после R2 reset.
5. Editing-only admin реализован: composer только во время разрешённого редактирования; новые text/media/sticker/GIF/voice sends запрещены. Обычные группы попутно не переделывались: group permission intersection, threads/forums и iOS DeleteChat parity остаются отдельными срезами.

## Матрица первого среза

| Истинное состояние | Панель |
|---|---|
| Creator-member / admin с can_post_messages | Composer |
| Member / admin без posting rights | Mute/Unmute |
| Admin с can_edit_messages, без posting, активный edit | Composer только для edit; пустой edit без микрофона |
| Left / creator is_member=false | Join |
| Banned | Без отправки и Join; явное недоступное состояние, не выдуманная membership |
| Unknown / ошибка hydration | Loading/unavailable без разрешения отправки |

Unknown/banned различаются в typed selector и тестах. Unknown ждёт один запрос; ошибка валидного ID даёт явный Retry, не бесконечную загрузку. Некорректный ID и banned показывают локализованное unavailable без Join/отправки/бесполезного Retry. Новая destructive Delete action не часть этого фикса; сырые technical errors не выводятся.

## Acceptance

- [x] **Wave9 basic group:** Basic-group defaults: 9 bits end-to-end, per-kind send/voice/forward/picker guards, media-only composer и bounded getChat hydration. Explicit @Local UI snapshot + scalar @Param flags. 52/52 (6 native bodies через host adapter), 26 CJS / 37 PS+smoke / review 8/8; final main/ohosTest compile PASS, 48 hashes стабильны. HDC [Empty], device/visual acceptance открыта. Отчёт: `docs/reviews/2026-09-06-reliability-wave9.md`.
- [x] **Wave6 ownership:** forward revalidation до dispatch/после comment, общий page token с text/media, account/draft/attachment restore guards. Focused 51/51, mutations 17/26/12/6 FAIL, forced main/ohosTest compile PASS. Это source/host gate; device runtime не подтверждён (`docs/reviews/2026-09-05-reliability-wave6.md`).
- [x] **Wave5 payload foundation:** strict group/status/type/member/rights wrappers; 9 individual send bits, deep clone, live/hydration/reset tests. 115/115 host, forced main/ohosTest build PASS. `docs/reviews/2026-09-05-reliability-wave5.md`.
- [x] **Group vertical:** ordinary megagroup effective permissions/booster full-info policy, fresh action guards и reactive UI реализованы в Wave11; forward source dispatch eligibility — Wave12. Source action availability/metadata recovery и device acceptance остаются отдельными gates.
- [x] RED matrix: 19 PASS / 55 FAIL на старой page; текущая расширенная matrix 79/79 с actual policy-call witness.
- [x] Grant/revoke, member↔left, banned/unknown; любые main/archive order не меняют вывод.
- [x] Group update до/после newChat; partial updates не стирают access; clone/reset сохраняют/очищают его корректно.
- [x] Hydration/retry с R2 scoped capabilities; joinChat→ok само по себе не меняет membership на member.
- [x] Focused suites + review-witness 8/8; fixture уточнена реальной ролью, expected composer не ослаблен.
- [x] Edit-only new-send/voice guards 51/51; text/media completion ownership 52/52, включая revoke/edit/roundtrip/new operation.
- [x] Forced main/ohosTest compile, UI-smoke и соседние source-contract checks.
- [ ] Device witness на реальных ролях/переходах с разрешением на account-действия; свежий iOS visual reference для новых панелей.

## Следующие срезы и стабильные source pointers

- Полный default/individual payload, 9-kind UI/dispatch и boosts map реализованы (Wave9/11); не повторять старую диагностику basic-bit collapse как текущее состояние.
- Forward action availability и stable-ID/lifecycle flow реализованы Wave13. Следующее: unknown source kinds требуют bounded metadata hydration и видимого recovery, не unconditional allow; остальные actions требуют собственной messageProperties policy вместо edit/pin/delete heuristics.
- Temporary source ID: properties и forward используют разные persistent-ID resolution paths; не обходить denial через `F || C`. Проверять local TDLib при изменениях ID handling.
- `supergroup.join_to_send_messages` и iOS `ChatInterfaceStateInputPanels.swift:246–252` имеют discussion-thread exception для left. Нельзя переносить его на любой group chat без учёта контекста. Basic group и broadcast не смешивать с megagroup.
- Отдельные gates: edit/expiry, migrated/deleted groups, real role/boost transitions и native/device acceptance. `forwardMessages` acceptance не server delivery; comment+forward не атомарны.

Wave13 grounding: CPL HTTP short timeout, direct known-source fallback; `harmonyos_docs` Local/ForEach/PopupStateChangeParam; TDLib schema/C++ и iOS context-menu selection intersection прочитаны. Device/visual witness отсутствует; старый runtime не принимает новый slice.
