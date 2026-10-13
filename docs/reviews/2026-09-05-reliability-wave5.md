# Reliability wave5 — права участников и блокер эмулятора

2026-09-05. **Source/host/forced build подтверждены. Device acceptance, effective group/media policy и публикационная готовность не достигнуты.**

## Результат

1. **Исправлена подмена group access вложенными полями.** Parser читает только authoritative top-level `status`, `@type`, `rights`, `is_member` и group wrappers. Ранее malformed payload с вложенным creator и настоящим banned мог дать composer. Теперь actual normalizer → combined reducer → channel policy даёт banned. Legacy getters остальных доменов не менялись.
2. **Перестали теряться индивидуальные ограничения.** Девять независимых bits `chatMemberStatusRestricted.permissions` доходят через live update и прямую hydration до scoped store: text, audio, documents, photos, videos, video/voice notes, polls, other messages. Store глубоко копирует permissions; producer mutation не меняет принятую версию. Отсутствующий объект — `undefined`, не «всё разрешено»; в имеющемся объекте только literal top-level true разрешает конкретный бит.

**Второй пункт — слой данных, не готовое управление отправкой в группах.** Групповая page/policy ещё опирается на default basic permission. Per-media guards, unknown group hydration, admin/booster exceptions и UI состояния требуют следующей вертикали. Channel policy получила строго разобранный статус, но её продуктовая семантика здесь не переписывалась.

## До/после и проверка пути

- Новый actual-source harness до production patch: **6 PASS / 103 FAIL**. После: тот же набор **109/109**; затем шесть actual native test bodies через явный Hypium host adapter → **115/115**.
- In-memory `--mutant=alias`: **113 PASS / 2 FAIL**, exit 1. Ловит alias nested permissions.
- In-memory `--mutant=legacy-status`: **110 PASS / 5 FAIL**, exit 1. Падает в том числе composer-vs-banned witness. Production файлы mutation-прогоны не изменяют.
- Покрыты late hydration после live revoke, account reset, restricted → member без старых permissions, все девять clone fields. Malformed cases доказывают defensive parsing, а не факт получения таких payload от Telegram.

## Изменённый код

- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/models/td/common/index.ets` — strict string getter, обходящий regex/cache.
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/core/model/dto/GroupAccessDto.ets` — строгий parser, `GroupSendPermissionsDto` и explicit clone.
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/core/events/normalizers/ChatNormalizer.ets` — строгие wrappers.
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/core/utils/stateClone.ets` — глубокая копия permissions при принятии event.
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/ohosTest/ets/test/GroupPermissionPayload.test.ets` — шесть native cases; регистрация в `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/ohosTest/ets/test/List.test.ets`.
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-group-permission-payload.cjs` — actual-source pipeline/hydration/mutation harness.

Чужой dirty tree сохранён. Commit/push, установка HAP и account-действия не выполнялись.

## Итоговая проверка

- Все **22 CJS host scripts** exit 0; исторический review-witness **8/8**.
- Все **36 PS scripts + UI-smoke: 37/37**, включая split/root geometry/unread fixtures.
- `node --check`: **23/23**; `git -c core.safecrlf=false diff --check`: exit 0.
- Последовательный forced `assembleHap`, main затем `module=entry@ohosTest`, `--no-incremental --no-daemon`: оба exit 0.
  - Main `CompileArkTS`: **2 min 37 s 616 ms**; `BUILD SUCCESSFUL in 5 min 12 s 883 ms`.
  - `OhosTestCompileArkTS`: **1 min 2 s 483 ms**; `BUILD SUCCESSFUL in 1 min 33 s 902 ms`.
- SHA256 **39** modified/new `.ets` совпали до и после build. Последующих source edits не было.
- Build имеет warnings, в том числе `icudtl.dat` missing и отсутствие `signingConfigs`. HAP unsigned. Native tests **не запускались на устройстве**: host execution и ohosTest compile — отдельные свидетельства.

Счётчики, build lines и hashes: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-05-reliability-wave5-evidence.json`.

## Почему runtime-проверка не состоялась

Первый SceneBoard panic записан в wave4. В этом продолжении проверены две отличающиеся гипотезы без удаления образа/данных:

| Попытка | Наблюдение | Вывод |
|---|---|---|
| 22:14:12, Pura API24, `-noWindow -hdcPort 10001`, PID 6896 | 22:16:49.680 — `SceneBoard exits 4times in 240000ms`; 22:17:02.886 — sysrq kernel panic. HDC `[Empty]`. Штатный `-stop`. | Системный guest crash повторился. Listener 10001 не наблюдался: переданный флаг не доказывает, что port path активировался. |
| 22:19:31, обычный `-start` без `-noWindow`, Windows process Hidden, PID 14384 | Kernel log не обновился. Launcher: `Can not allocate virtual memory : 4`, `Commit charge is not enough!`. | Это preflight отказ, **не новый guest panic**. Влияние headless режима проверить не удалось. |

Во второй попытке после `-stop` PID оставался жив. Проверены executable/arguments, затем завершён только собственный preflight process. Финальный повторный CLI witness: Pura API24 и Pura X Vie `isRunning=false`; HDC `[Empty]`. API26 не запускался.

Логи: `C:/Users/Kharki/AppData/Local/Huawei/Emulator/deployed/Pura API24/Log/kernel.log` и `C:/Users/Kharki/AppData/Local/Huawei/Emulator/deployed/Pura API24/Log/Emulator.log`. Commit объясняет конкретный preflight отказ; **первопричина SceneBoard crash не установлена**. Ни GPU, ни RAM не объявляются доказанной причиной. Image/session reset, изменение pagefile/security, остановка чужих CPL/Codex и offline чтение userdata не выполнялись.

## Grounding и следующий срез

- Прочитан TDLib контракт: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/generate/scheme/td_api.tl:924,2147–2164`.
- Прочитаны iOS `sendSomething`/admin semantics: `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramCore/Sources/ApiUtils/TelegramGroup.swift` и `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramCore/Sources/ApiUtils/TelegramChannel.swift`. Layout не менялся; нового visual witness нет.
- Прочитаны `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/DialogParticipant.cpp:456–491` и `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/ChatManager.cpp:8483–8495`: creator/admin обходят default restrictions, есть отдельный booster path. Следующий selector нельзя свести к безусловному default AND individual.
- `harmonyos_docs` опрошен; запрос rule ID дал FTS `no such column: no`, простой запрос работает, но точного релевантного правила не дал. Новые platform APIs не вводились; ArkTS проверен целевым compiler. После недоступного context-mode/ранее зависшего CPL использовалось bounded чтение реальных локальных исходников, без переустановки tools.

Дальше: full default/per-kind transport → effective selector с membership/admin/booster semantics → bounded group hydration → page subscription → отдельные text/media/voice/sticker/GIF/forward guards и UI состояния → device acceptance. Полный production-parity roadmap остаётся активным. Зелёные suites не доказывают надёжность и полноту на уровне iOS.
