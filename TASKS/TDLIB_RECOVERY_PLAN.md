# R2 — безопасное восстановление после authorizationStateClosed

Статус 2026-09-05: **реализовано в source; host/compile PASS; device acceptance открыт**. Отчёт: `docs/reviews/2026-09-05-reliability-wave2.md`.
Не считать ручное `initialize()` или зелёный gateway-only тест доказательством безопасного повторного входа.

## Проверенная исходная проблема

- Исходный review-witness доставляет настоящий Closed через gateway/dispatcher с native mock; client остаётся ready, повторный initialize не создаёт новый ID (1 вместо 2).
- TDLib `td_api.tl`: Closed — terminal; logOut закрывает экземпляр. `td_json_client.h` требует применять updates/responses в receive order и отправить первый запрос, чтобы получать updates.
- `authReducer.ets` сохраняет account-owned buckets и прежний userId при closed: очистка только части phone/code полей при waitPhoneNumber недостаточна.
- `TdGatewayAdapter` хранит ссылку на gateway; разрушение singleton целиком оставляет старые references неработоспособными. `AppStore.resetState()` синхронен, тогда как dispatch queue асинхронна.

## Границы реализации

Native client lifecycle — `TdGateway`; account reset-barrier — `AppCoreRuntime`; auth continuation generation — `AuthSideEffect`; показ login/main — login router. Сохранять identity gateway и lifecycle root store/подписчиков. Account adapters/views намеренно менять: старые capabilities отзываются и не получают доступ к B. Не запускать recovery во время explicit shutdown.

1. `infra/td/gateway/TdGateway.ets`: current client generation, envelope filtering по `@client_id` в update/response/batch/single fallback; проверять каждый элемент, включая хвост старого batch. Duplicate Closed не должен дважды запускать recovery.
2. Terminal cleanup до broadcast Closed: закрыть обычные send, invalidation старых attempts/batches, отклонить pending non-retryable lifecycle error, очистить timeout. Sleeping `sendWithRetry` сверяет captured generation после backoff.
3. Explicit destroy подавляет restart; сохранить корректный close-response/Closed-waiter. LoggingOut, Closing и logOut→ok ещё не разрешают создание клиента.
4. Один awaited runtime barrier до нового client ID: остановить account watchers/async continuations, сбросить caches, очистить account state через очередь store. Нужна отдельная account generation; нельзя просто увеличить runtime token и оставить callback, захвативший старый token.
5. После barrier создать client внутри стабильного gateway/runtime; обновить account adapter. Общий NAPI receive loop сохранён: `td_receive` batch переносит top-level `@client_id` без изменений. Отправить bootstrap/parameters; состояние login подтверждать только native auth, а позднюю вспомогательную query-error не считать опровержением уже полученного Ready/Wait*.
6. `core/sideeffects/AuthSideEffect.ets`: старые setTdlibParameters/getMe/ready continuations не изменяют flags/state нового клиента. Одного сброса boolean при Closed мало.
7. `ui/pages/login/LoginRouter.ets`, `LoginRouterPage.ets`, `ui/controllers/LoginController.ets`: убрать выдуманное подтверждение waitPhoneNumber после logout; при auth-loss снять main UI/старые transition timers и account navigation. Ошибка logout не доказывает сброс.
8. Recovery single-flight и bounded: одна автоматическая попытка на инцидент; terminal во время bootstrap или ошибка создания не должна давать бесконечный цикл. Ошибка наблюдаема и явно retryable пользователем, без скрытых повторных account-действий.

## RED → GREEN acceptance

- [x] Closed через actual batch path с native fixture автоматически создаёт client 2; bootstrap request адресован 2.
- [x] Gateway/root store identity и lifecycle-подписчики сохраняются; account views/adapters отзываются; unnecessary receive-loop restart отсутствует.
- [x] Старые callbacks/responses/duplicate Closed/хвост batch/single fallback не меняют новый client и не разрешают его pending.
- [x] Pending reject ровно один раз; timeout снят; спящий retry старого аккаунта ничего не отправляет.
- [x] Destroy до recovery и Closed во время destroy создают ноль новых клиентов; close waiter завершается.
- [x] Повторный bootstrap Closed/create failure ограничен; ошибка видима и отзывает account work. Поздняя query-error после реального Ready/Wait* не ломает живой client.
- [x] Account A seed + delayed getMe/params/media → Closed → B: очищены seeded maps/auth и account navigation; старые writes/reads отсекаются. Проверка navigation — отдельный actual bridge host witness, не UI screenshot.
- [x] Wrong-number/logout не показывают ложную готовность ввода; следующий шаг следует реальному auth state.
- [x] Initialize/shutdown overlap, single-flight, same-instance reuse без данных A: 5/5 host.
- [x] R1 ordering/shutdown host 6/6 и прежний TdGateway suite 14/14 PASS; actual AuthSideEffect включён в runtime/full-chain harness.
- [ ] Исполнить focused ohosTest на устройстве; скомпилированные suites не выдавать за выполненные.
- [ ] Реальный device сценарий account/recovery/auth UI, включая navigation, network interruption и logout, с отдельным согласованием использования аккаунта.

Automatic recovery подключён через проверенный host account barrier, не gateway-only shortcut. Native TDLib/ArkUI device execution пока не проверено: `hdc list targets` → `[Empty]`, `signingConfigs: []`. Account/logout/device сценарий согласовать отдельно; не использовать пользовательскую сессию как disposable test fixture.
