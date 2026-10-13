# Reliability wave8 — membership и активность basic groups

2026-09-06, `dev`. Полная цель активна; этот срез не означает готовность всех групп/media или публикации.

## Результат

Basic group больше не получает право писать только из default `canSendBasicMessages` или из одноимённого channel registry. Page учитывает собственные membership/status и `is_active`; left/removed/inactive не получают composer/Join/send, активные creator/admin не блокируются default text restriction. Unknown basic group получает bounded `getBasicGroup` hydration и явный retry после ошибки. Live deactivation доходит до actual send getters и останавливает следующий элемент media batch.

**42/42 focused PASS**, включая 8 native test bodies через host adapter. Все **25 CJS**, **37 PS+UI smoke**, review **8/8**, syntax **26/26** проходят. Main и ohosTest принудительно пересобраны; **45 modified/new `.ets` hashes** совпали до/после сборок. На устройстве новый код не проверен: HDC Offline.

## Baseline и контракт

Первый новый harness дал **2 PASS / 30 FAIL**. Из 30 ошибок **29 были поведенческими**, одна — ошибка самого harness: не извлечён actual `shouldReactToStoreChange`. Метод подключён без копирования логики; отдельный mutation с удалением его basic-group branch даёт 1 FAIL и доказывает участие subscription path. К исходным 32 случаям добавлены 8 native bodies и 2 проверки live/deferred исходов; итог — 42.

Лично прочитаны:
- `tdlib/td/generate/scheme/td_api.tl:2320–2327`: `basicGroup.status`, `is_active`, `upgraded_to_supergroup_id` — самостоятельные поля. Статус администратора не означает активность старой группы.
- `tdlib/td/telegram/DialogParticipant.cpp:456–487`: creator/admin не ограничиваются group defaults; это не channel posting rights.
- `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/ChatInterfaceStateInputPanels.swift:396–425`: basic-group Removed/Left выбирает DeleteChat, затем проверяется sendSomething. Channel Join нельзя переносить сюда бездумно.

Новая destructive Delete action и переход в upgraded supergroup **не добавлены**. До отдельной реализации/приёмки показывается локализованное unavailable без ошибочного Join/send. Полный sendSomething/per-media contract пока не выполнен; ниже указаны пределы.

## Production-изменения

1. `GroupAccessDto.ets`: typed `isActive`; для `basicGroup` требуется literal top-level boolean `is_active`. Missing, coercible и nested значения не считаются authoritative update. Supergroup schema не требует этого поля.
2. `stateClone.ets`: `cloneGroupAccess` сохраняет false. Иначе inactive group превращалась бы в active при клонировании.
3. `ChatInputPanelPolicy.ets`: отдельная basic-group branch, строгие kind/ID/activity; unavailable проверяется **до** creator/admin exception. Активный member продолжает подчиняться basic default bit; individual basic restriction также учитывается.
4. `ChatAccessController.ets`: account-scoped one-shot работает для channel и basic group, выбирает правильный GroupKind и ID. Переключение типа при одинаковом числовом ID инвалидирует старую UI generation; lifecycle/retry/reentrancy guards сохранены.
5. `TgChatScreenPage.ets`: basic map используется согласованно в panel derivation, hydration observe, fresh send capability и subscription gate. Смена другого basic group не перерисовывает текущий чат. Retry проверяет именно basicGroupId, а не supergroupId.
6. `string.json` base/ru_RU/zh_CN: отдельная строка «Эта группа недоступна». Геометрия/материалы atom не менялись; state passport `TgChatBottomActionBar.md` уточнён, старый disk-full blocker в нём заменён актуальной диагностической границей.

Пути production-файлов: `entry/src/main/ets/core/model/dto/GroupAccessDto.ets`, `entry/src/main/ets/core/utils/stateClone.ets`, `entry/src/main/ets/ui/pages/chat/{ChatInputPanelPolicy,ChatAccessController,TgChatScreenPage}.ets`.

## Верификация

`scripts/test-basic-group-access.cjs` загружает настоящий normalizer → combined reducer → scoped store → page selector/getters, actual composer/text/media/forward use cases и hydration controller. Заменены только transport, platform file I/O и presentation. Это не реальные account sends.

Проверены creator/admin/member/restricted/left/banned, inactive creator/admin/member, invalid ID, same-ID channel collision, strict activity + clone, active/other group subscriptions, exact getBasicGroup single-flight, malformed response/retry, channel→basic supersession, live status над late response, account reset, deactivation во время media batch. Новый `BasicGroupAccess.test.ets` зарегистрирован в `List.test.ets` и скомпилирован; его 8 bodies дополнительно исполнены через host adapter, **не через device Hypium**.

Соседние fixtures приведены к настоящему контракту: valid basic payload содержит `is_active:true`, writable group имеет реальный active member status. В negative nested/wrong-ID fixtures остальные поля тоже валидны, чтобы новый activity guard не скрывал проверяемый дефект. Expectations разрешённого/запрещённого действия не ослаблялись. Старый controller case «group never hydrates» заменён актуальной границей channel/basic-group; новый basic hydration проверяется непосредственно.

| In-memory mutation | PASS / FAIL | Изменений применено |
|---|---:|---:|
| `ignore-activity` | 36 / 6 | 1 |
| `wrong-map` | 25 / 17 | 3 |
| `no-subscription` | 41 / 1 | 1 |
| `channel-hydration` | 38 / 4 | 1 |
| `drop-activity-clone` | 35 / 7 | 1 |
| `relax-active-parser` | 32 / 10 | 1 |

Все mutations дают exit 1; исходники на диске не меняются. Полный регрессионный прогон: **25 CJS / 37 PS+smoke**, review **8/8**, syntax **26/26**, `git diff --check` exit 0. В каждой из 3 локалей одна новая строка, duplicate names нет.

Сборки, последовательно `assembleHap --no-incremental --no-daemon`:
- main CompileArkTS **2 min 51 s 56 ms**, build **5 min 39 s 279 ms**, exit 0;
- OhosTestCompileArkTS **1 min 7 s 218 ms**, build **1 min 47 s 629 ms**, exit 0;
- 45 source hashes совпали до/после обеих сборок. Source после них не менялся.

Warnings остаются (`icudtl.dat missing`, нет signingConfigs); HAP unsigned. Build/host PASS не означает device/visual acceptance. Подробные counters, outputs и hashes: `docs/reviews/2026-09-06-reliability-wave8-evidence.json`.

## Runtime и оставшаяся работа

Свежий HDC check: 10001/5555 Offline. В этом срезе эмулятор не перезапускался, HAP не устанавливался, сессии не менялись. Предыдущие обычные boots existing API24/API26 и clean API24 со SceneBoard panic описаны в wave6; причина OS crash не установлена. Нового UI screenshot нет.

Следующая вертикаль — **default 9 send bits и точные per-kind guards/UI для basic groups**, включая возможность media-only composer. Нельзя считать basic text boolean всем sendSomething. Затем/параллельно — megagroup membership, booster-aware full-info state/hydration и permissions; текущая ordinary supergroup branch этим срезом не исправлена. Channel R6/forward/recovery suites сохранены, но это не доказательство надёжности всего клиента.

Открыты также upgraded-group CTA, DeleteChat parity, прочие отмеченные recovery/forward/network risks, device acceptance, сравнение имеющегося UI с текущим iOS, функциональная полнота и publication gates. Никаких commit/push/publish не было.

Grounding: harmonyos_docs вернул официальный enabled/Button example; UI availability не заменяет action guard. После предыдущих CPL timeouts использован точный local-source fallback, без ещё одного 300s retry. Новый независимый subagent review не выполнялся; результат опирается на проверенные source/host/mutation/compile witnesses.
