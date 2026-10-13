# Media account/page ownership — reliability continuation

Предыдущий turn — progress: playback operation ownership, final 49 host suites и builds сохранены. Текущий срез не заменяет полную production parity цель.

## Проверяемые условия
- [x] AppStore invalidation синхронно отзывает одноразовых scope observers до возврата; отмена/исключение/reentrancy не теряют новые observers. Actual Store23/23 +13 controls.
- [x] Playback принадлежит captured account scope; shutdown/failure/recovery reset отзывает старое audio/metadata/search и page capabilities без ожидания UI notification. Actual runtime methods включены в37/37 account cases.
- [x] Page handle связан с account/chat/lifecycle; старый cleanup не снимает новый handler, одноимённые message IDs разных чатов не смешиваются; уход со страницы не останавливает легитимный global player. Page47/47, actual chain23/23; first-bind/cross-chat reentry защищены intent token.
- [x] AVSession создание/команды/teardown имеют generation ownership; stale callbacks fenced в host SDK boundary. Постоянные SDK failure и физический device acceptance остаются отдельным открытым гейтом.
- [x] RED/GREEN и negative controls; actual Store+Global+controller и actual page chain; independent review F1/F2 закрыты,53 host suites/38PS+Bash/final forced serial builds PASS,775 hashes стабильны. Отчёт: `docs/reviews/2026-09-28-media-account-remediation.md`.

## Write ownership
- Core worker: AppStore.ets, test-app-store-invalidation.cjs, scoped report.
- Page worker: TgChatScreenPage.ets, test-chat-media-page-ownership.cjs, scoped report.
- Parent: GlobalMediaPlayback.ets и capability API, account media tests/fixture integration, документация.

## Выбранная интеграция
Runtime уже вызывает invalidateScopes/resetStateQueued при shutdown/recovery/failure. Generic one-shot scope invalidation observer закрывает синхронную границу без зависимости core store от UI или SDK. Media получает captured scoped AppStore от существующего account-bound route. Вместо выдачи raw global controller page получает guarded MediaPlaybackPageHandle; scoped unsubscribe имеет identity, а не только chatId. Сохраняется воспроизведение при обычном уходе из чата.

Реальная Telegram-сессия/данные, сообщения, microphone, установка HAP, commit/push не затрагиваются. Источники: harmonyos_docs AVSession destroy/activate и локальные lifecycle refs; фактический AppCoreRuntime и ChatScreenRouteParams — authority для account boundaries.
