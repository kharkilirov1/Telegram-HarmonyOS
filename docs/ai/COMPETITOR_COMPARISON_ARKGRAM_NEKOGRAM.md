# Telegram-HarmonyOS vs ArkGram vs Nekogram

Snapshot: **2026-07-10**

## Короткий вывод

`Telegram-HarmonyOS` не надо превращать ни в копию ArkGram, ни в порт Nekogram.

- **Текущий проект сильнее по инженерному фундаменту:** typed TDLib boundary, normalizers, serial `AppStore`, reducers/use-cases/selectors, atom-first `tg_ui`, 413 test cases и воспроизводимые smoke/build scripts.
- **ArkGram полезнее всего как ближайший HarmonyOS product reference:** та же платформа, ArkUI, TDLib, API 23–26, tablet/adaptive patterns, proxy/settings/media flows. Но публичного source repo нет; доступна только некомпилируемая reverse reconstruction v1.0.1 без лицензии. Код и assets копировать нельзя.
- **Nekogram сильнее всех по feature breadth:** это почти полный Telegram Android плюс собственные настройки. Но его Android custom Views, direct MTProto/TGNet, controller/event-bus architecture и GPL-2.0 код не являются переносимой основой для ArkTS/TDLib.

Практическая стратегия: **сохранить текущую архитектуру**, использовать ArkGram для platform-native UX/state matrices, а Nekogram — для product semantics, edge cases и feature backlog. Реализация только clean-room поверх существующих TDLib contracts.

## 1. Зафиксированные snapshots

| Проект | Локальный root | Snapshot | Статус источника |
|---|---|---|---|
| Telegram-HarmonyOS | `C:\Users\Kharki\Desktop\Telegram-HarmonyOS` | branch `dev`, HEAD `3e70a288385a36b2eea65b93e9a79c70aeb495ac` | Обычный git source tree, clean до создания этого отчёта |
| ArkGram | `C:\Refs\Telegram\ArkGram-RE\out\ArkGram-project` | reverse reconstruction v1.0.1 из HAP | Не git repo, не upstream source, не собирается, license отсутствует |
| Nekogram | `C:\Refs\Telegram\Nekogram` | branch `main`, HEAD `c17b0a46c7741cad18bed64e02cc7b05fad4d74a` | Canonical public source, clone clean и совпадает с `origin/main` |

Canonical Nekogram подтверждён через [официальный сайт](https://nekogram.app/) и [Nekogram/Nekogram](https://github.com/Nekogram/Nekogram). README самого repo указывает тот же clone URL и lineage от Telegram Android.

### Что было клонировано

До аудита Nekogram отсутствовал. Canonical reference path после external migration:

```powershell
git clone --filter=blob:none --single-branch --branch main `
  https://github.com/Nekogram/Nekogram.git `
  C:\Refs\Telegram\Nekogram
```

Проверено после clone:

```text
## main...origin/main
local HEAD  = c17b0a46c7741cad18bed64e02cc7b05fad4d74a
origin/main = c17b0a46c7741cad18bed64e02cc7b05fad4d74a
```

`.gitmodules` отсутствует. Репозиторий объявляет version `12.8.1`, GPL-2.0 и текущий release v12.8.1 от 2026-06-18.

### Почему ArkGram не клонирован

На машине уже был более полезный для анализа локальный HAP-derived artifact:

- `C:\Refs\Telegram\ArkGram-RE\out\ArkGram-project`
- `C:\Users\Kharki\Desktop\Telegram-HarmonyOS\ARKGRAM_REFERENCE.md`

Публичного ArkGram source repo не найдено:

```text
gh search repos 'ArkGram' ...                       -> []
gh search code 'com.matheusrv.arkgram' ...          -> []
```

[HomoArk/Homogram](https://github.com/HomoArk/Homogram) — отдельный HarmonyOS Telegram client; доказанной связи с ArkGram нет. Clone URL для ArkGram поэтому не выдумывался. Официальный distribution channel: [@arkgram_hmos](https://t.me/arkgram_hmos).

## 2. Метод и границы доказательств

1. Прочитаны `STATUS.md`, `TASKS/TODO.md`, `DECISIONS.md`, `ARCHITECTURE.md`, `TASKS/AGENT_EXECUTION_PLAN.md` и релевантные исходники.
2. CPL MCP и HTTP `127.0.0.1:3878` были недоступны. Использован CLI fallback.
3. CPL `scan` успешно выполнен для Telegram-HarmonyOS и Nekogram. `skeleton/retrieve` зависали на больших деревьях и были заменены точечным source audit.
4. HarmonyOS decisions сверены через локальный `harmonyos_docs` MCP: `UIAbility`, `NavPathStack`, `@ComponentV2`, `@ReusableV2`, `Repeat`/`reuse`.
5. Ключевые claims проверены прямым чтением manifests, build files, entry points, backend/state classes, feature surfaces, tests и CI workflows.
6. LOC используются только как scale indicator. ArkGram LOC особенно несопоставимы: decompiler раздувает форматирование и теряет типы/имена/методы.

Не выполнено:

- Nekogram не собирался: clone не содержит required secrets, `google-services.json`, signing config и `local.properties`.
- ArkGram RE не может быть собран по определению.
- Device tests Telegram-HarmonyOS не перезапускались: `hdc list targets` сейчас возвращает `[Empty]`.

## 3. Сравнение в одной таблице

| Критерий | Telegram-HarmonyOS | ArkGram v1.0.1 RE | Nekogram 12.8.1 |
|---|---|---|---|
| Платформа | HarmonyOS NEXT, ArkTS/ArkUI, phone/tablet/2in1 | HarmonyOS NEXT, ArkTS/ArkUI, phone/tablet | Android, Java/Kotlin + large native stack |
| SDK | compatible 23, target 26 | min 23, target/compile 26 Beta1 | min 23, target 36, compile 37 |
| Telegram backend | TDLib submodule + NAPI bridge | TDLib via unknown native `libentry`/`libtdjson` | Direct MTProto/TL, TGNet/JNI; **не TDLib** |
| State/data flow | Normalizers -> serial Redux-like `AppStore` -> selectors/VO -> UI | Global managers + `AppStorage`/`PersistentStorage` mutation | Account-scoped controllers + `MessagesStorage` + `NotificationCenter` event bus |
| Navigation | HDS/ArkUI shell, typed UI coordination, route map | Global legacy `router`; `Navigation/NavPathStack` не найден | Custom Android fragment/ActionBar stack from `LaunchActivity` |
| UI strategy | iOS-first tokenized `tg_ui`, atoms/specs/demos | Same-platform native UI, но большие page/view monoliths | Mature Telegram Android custom Views, not Compose |
| Core messaging | Release-track MVP: auth, chats, history, search/jump, send/reply/edit/delete/forward/drafts | Broad beta surface, но v1.0.1 имел feature and stability gaps | Почти полный Telegram Android surface |
| Advanced Telegram | Calls history only; нет live calls, Stories, create/manage workflow для secret chats, group/channel management, push, proxy/privacy/payments | Нет calls/topics/group-channel management в beta; proxy есть; push extension есть, но push заявлен нерабочим | Calls, Stories, groups/channels/topics, secret chats, notifications, proxies, payments, bots/web apps |
| Tests | 21 ETS / 4,223 lines; 413 `it`; static UI smoke | В RE artifact tests/build/CI не восстановлены | Instrumentation module есть, но отключён; 4,218 markers в основном generated, 8 handwritten markers |
| CI | Static smoke всегда; hvigor build только на opt-in self-hosted runner | Нельзя судить по RE | GitHub Actions собирает signed release APK/AAB и attestation, но tests/lint не запускает |
| Release gate | Fresh unsigned HAP builds; `signingConfigs: []` | Distributed HAP, upstream process закрыт | 49 GitHub releases, signed multi-ABI APK/AAB pipeline |
| Localization | base + ru_RU + zh_CN | Upstream channel заявлял 35 locales; RE resources неполны | 47 Android values dirs, 41 dirs with Nekogram strings |
| License | `entry/oh-package.json5` говорит MIT, но root LICENSE отсутствует | License отсутствует; closed/reconstructed artifact | GPL-2.0 |
| Прямой code reuse | Внутренняя база | **Запрещён/небезопасен** | **GPL + Android/backend mismatch** |

## 4. Telegram-HarmonyOS: фактическая позиция

### 4.1 Архитектура

```text
EntryAbility (UIAbility / Stage Model)
  -> AppCoreRuntime
    -> TdGateway / MainThreadDispatcher
      -> EventNormalizer
        -> serial AppStore + reducers
          -> AppStoreBridge / selectors / view models
            -> ArkUI pages + tg_ui atoms/molecules
```

Ключевые файлы:

- `C:\Users\Kharki\Desktop\Telegram-HarmonyOS\entry\src\main\ets\entryability\EntryAbility.ets`
- `C:\Users\Kharki\Desktop\Telegram-HarmonyOS\entry\src\main\ets\app\bootstrap\AppCoreRuntime.ets`
- `C:\Users\Kharki\Desktop\Telegram-HarmonyOS\entry\src\main\ets\infra\td\gateway\TdGateway.ets`
- `C:\Users\Kharki\Desktop\Telegram-HarmonyOS\entry\src\main\ets\infra\td\serialization\CommandSerializer.ets`
- `C:\Users\Kharki\Desktop\Telegram-HarmonyOS\entry\src\main\ets\core\store\AppStore.ets`
- `C:\Users\Kharki\Desktop\Telegram-HarmonyOS\entry\src\main\ets\ui\pages\MainTabsPage.ets`
- `C:\Users\Kharki\Desktop\Telegram-HarmonyOS\entry\src\main\ets\ui\pages\chat\TgChatScreenPage.ets`

TDLib submodule: `cb863c1600082404428f1a84e407b866b9d412a8` (`v1.8.0-9195`). Native bridge exports create/send/receive/execute/start-loop/stop-loop; ArkTS drain has explicit time budget/yield/backoff.

### 4.2 Масштаб и quality surface

```text
Main ArkTS                    215 files / 42,293 lines
ohosTest ETS                   21 files /  4,223 lines
Test markers                  413 it / 112 describe
tg_ui                          83 ETS + 43 MD
tg_ui atoms/demos/specs        38 / 38 / 42
```

Сильные стороны:

- лучшее разделение protocol/domain/state/UI из трёх examined trees;
- typed command serializers и DTO/accessor boundary вместо ad-hoc JSON casts;
- deterministic reducers и serial dispatch;
- отдельные view models для chat list/timeline;
- iOS source of truth + token-first design system;
- component passports и demos, которых нет у конкурентов в доступных trees;
- реальные smoke/build/device-witness procedures в repo.

Слабые стороны:

- это ещё MVP, а не полный Telegram client;
- `TgChatScreenPage.ets` остаётся большим coordinator (~3.1K lines);
- нет signing/release artifact;
- нет root license/third-party notice policy;
- CI build opt-in, device tests не являются обязательным CI gate;
- accessibility markers в ArkTS не найдены;
- локализация и advanced settings значительно уже;
- docs дрейфуют: `STATUS.md` говорит 413/413 green, а старый unchecked TODO всё ещё описывает зависание runner.

## 5. ArkGram: чему он реально учит

### 5.1 Что известно точно

Manifest RE artifact:

```text
bundle          com.matheusrv.arkgram
version         1.0.1
buildMode       debug
min API         23
target API      26
compile SDK     26.0.0.23 Beta1
VM              ark13.0.1.0
devices         phone, tablet
```

Архитектура по восстановленному tree:

```text
EntryAbility / pages
  -> TelegramController and feature managers
    -> TdClient / TdDispatcher / parsers
      -> libentry / TDLib
  -> TelegramState + AppStorage/PersistentStorage
    -> large views/pages
```

RE tree содержит 159 `.ets`. Physical LOC (~137K) не является original LOC. Самые большие восстановленные файлы:

- `view/ChatMessageItem.ets` ~7.7K lines;
- `settingsUI/chatUI/view/ChatDetailScreen.ets` ~6.1K;
- `pages/CommentThread.ets` ~5.1K;
- `view/ChatInputArea.ets` ~3.5K.

Полезные feature references:

- adaptive phone/tablet/fold selection models and detail panes;
- proxy management and link parsing;
- sessions/device screens and QR flows;
- storage/power-save/privacy/settings hierarchy;
- media viewer and sticker/TGS handling;
- deep links;
- notification scope/category/exception taxonomy;
- TDLib receive-loop/event separation.

### 5.2 Почему его архитектуру нельзя принимать за эталон

- Широко используется global `router`; `Navigation/NavPathStack/NavDestination` references не найдены.
- Состояние живёт в global managers/AppStorage, а UI-файлы монолитны.
- В доступном artifact нет source build, tests, CI или license.
- Native binaries и bridge source отсутствуют.
- Локальный v1.0.1 уже stale: официальный channel 2026-07-10 объявил v1.0.2 с polls, pinned messages и fixes.
- Наличие `ArkGramPushExtension` не доказывает working push; официальный channel сам отмечал push как неработающий.

Использование допустимо только как **clean-room behavioral reference**. Нельзя копировать decompiled code, resources, Arkmojis, metadata IDs или native binaries.

## 6. Nekogram: чему он реально учит

### 6.1 Это Telegram Android fork, а не самостоятельный компактный client

CPL scan:

```text
31,211 files / 14,119 source files / 708,717,381 bytes
Java, C/C++, C++, Go, Kotlin, JavaScript, Python, Ruby
```

Сопоставимые first-party metrics:

```text
org/telegram Java+Kotlin       1,788 files / 1,391,269 lines
tw/nekomimi custom code           78 files /    15,579 lines
Upstream files touching Neko      103
NekoConfig references             240
```

Крупные Telegram upstream classes показывают цену зрелости: `ChatActivity.java` ~47.8K lines, `ChatMessageCell.java` ~29.1K, `MessagesController.java` ~24.6K, `MessagesStorage.java` ~18.3K. Это battle-tested breadth, но не maintainability template для нового ArkTS client.

### 6.2 Backend и state

```text
LaunchActivity / custom fragment stack
  -> account-scoped controllers
    -> ConnectionsManager / direct MTProto TL requests
      -> TGNet/JNI native stack
  -> MessagesStorage / SQLite
  -> NotificationCenter event bus
  -> large Android custom Views
```

Главная несовместимость: Telegram-HarmonyOS использует TDLib. Nekogram behavior нельзя переносить через копирование `MessagesController`, `TLRPC`, `ConnectionsManager` или native TGNet; для каждой функции нужен эквивалентный TDLib contract.

### 6.3 Собственные функции Nekogram

`NekoConfig.java` и settings classes подтверждают, среди прочего:

- system emoji, folder icons, sticker size;
- hide bottom navigation, reduced chat colors;
- configurable double-tap actions;
- per-message/chat/article translation with multiple providers;
- transcription provider selection and voice enhancements;
- message details, no-quote forward, quick forward;
- media preview/autopause, preferred original quality;
- hide Stories/time-on-sticker/channel buttons;
- download speed boost;
- cloud settings sync;
- QR, passcode, custom emoji/sticker settings.

Это хороший **taxonomy/backlog reference**, но не готовый ArkUI implementation.

### 6.4 Tests и CI

`TMessagesProj_AppTests` существует, но module закомментирован в `settings.gradle` и отстаёт по SDK/JVM/NDK/CMake. В нём 4,218 test markers, однако подавляющее большинство сгенерировано из TL scheme; вне generated dirs найдено только 8 markers.

GitHub Actions `build.yml`:

- на push в `main/dev/ci` поднимает JDK 21, Android SDK/NDK и ccache;
- injects signing/secrets;
- выполняет `assembleRelease`, `bundlePlay`, Sentry source upload;
- attest/upload multi-ABI APKs и AAB;
- **не запускает tests или lint**.

То есть Nekogram заметно впереди по release automation, но не доказывает превосходство test discipline.

## 7. Feature gap matrix

Legend: `yes` — surface найден; `partial` — ограниченный/недоказанный путь; `no` — surface не найден; `unknown` — RE не позволяет заключение.

| Feature | Telegram-HarmonyOS | ArkGram v1.0.1 | Nekogram 12.8.1 |
|---|---:|---:|---:|
| Phone/code/password auth | yes | yes | yes |
| QR auth | yes | yes | yes |
| Chats/history/search | yes | yes | yes |
| Reply/edit/delete/forward | yes | yes | yes |
| Drafts | yes | no in published beta gap list | yes |
| Media/gallery/voice/stickers/GIF/polls | mostly yes | partial; v1.0.2 added/fixed polls | yes |
| Chat search + jump-to-message | yes | partial/unknown | yes |
| Live voice/video calls | no; history only | no in beta | yes |
| Group/channel create/manage | no surfaced command/use-case | no in beta | yes |
| Topics | no | no in beta | yes |
| Stories | no | unknown/no surfaced UI | yes |
| Secret chats | partial: existing chats parsed/rendered; нет create/manage workflow | unknown | yes |
| Push notifications | no | extension exists, runtime reported broken | yes, FCM/GMS path |
| Proxy management | no | yes | yes |
| Full privacy/devices/storage settings | partial | yes | yes |
| Payments/passport/bots/web apps | no | partial/unknown; bot settings explicitly unavailable in beta | yes |
| Tablet/adaptive split UI | declared device support, limited proof | dedicated adaptive tree | yes via Telegram Android tablet UI |
| Translation customization | no | unknown | yes, Neko-specific |
| Accessibility evidence | no markers found | unknown | Android/upstream surface, not audited |

## 8. Что брать и что не брать

### Из ArkGram брать

- same-platform state matrices and screenshots;
- HarmonyOS API 23–26 ArkUI behavior;
- adaptive detail-pane/fold taxonomy;
- proxy, sessions, storage, power-save and deep-link flows;
- notification hierarchy as product model, not its relay implementation;
- TDLib event-loop separation ideas.

### Из ArkGram не брать

- decompiled code/resources/assets;
- metadata IDs, credentials or unknown binaries;
- global router/AppStorage architecture;
- security, tests or push claims that cannot be reproduced.

### Из Nekogram брать

- full Telegram behavior checklist and edge cases;
- settings taxonomy;
- message action customization;
- translation-provider abstraction at product level;
- folder/chat/media appearance options;
- release pipeline ideas: repeatable multi-ABI artifacts, provenance/attestation;
- mature flows for notifications, sessions, proxies, privacy and group/channel management.

### Из Nekogram не брать

- Java/Kotlin Views/Activities/Fragments;
- direct MTProto/TGNet/native stack;
- controller/event-bus/SQLite architecture;
- Firebase/GMS/analytics/Sentry defaults without privacy review;
- GPL code or assets without an explicit licensing decision.

### В Telegram-HarmonyOS сохранить

- TDLib as protocol boundary;
- serial `AppStore` + reducers/normalizers;
- use-cases/selectors/view models;
- atom-first `tg_ui` and iOS visual source of truth;
- focused tests and runtime witnesses;
- small feature slices instead of competitor-scale rewrite.

## 9. Рекомендуемый порядок работ

Этот список не отменяет текущий frozen release roadmap. До v0.1.0 не надо начинать large feature wave.

### P0 — release credibility

1. Добавить root license и third-party notices; сейчас package manifest говорит MIT, но юридического root LICENSE нет.
2. Закрыть signing config и получить fresh release build/AppFreeze witness.
3. Сделать HarmonyOS build обязательным CI gate, когда доступен стабильный runner; сейчас он opt-in.
4. Перезапустить 413 device tests и убрать противоречащий им stale TODO.
5. Провести accessibility pass на login/chat list/chat/composer.

### P1 — ближайший feature parity после релиза

1. Notifications/push с документированным trusted relay/provider или platform service; не копировать неизвестную ArkGram схему.
2. Proxy management.
3. Sessions/devices + privacy/storage settings.
4. Group/channel create/join/leave/manage basics.
5. Проверяемый tablet/2in1 split layout.
6. Расширение localization beyond ru/zh.

### P2 — большие пласты

1. Live calls.
2. Stories/topics/secret chats.
3. Translation provider abstraction.
4. Nekogram-like customization только после telemetry-free privacy/design review.

## 10. License и security boundary

- ArkGram RE не имеет license: **никакого code/assets reuse**.
- Nekogram GPL-2.0: прямое копирование может создать GPL obligations для derivative/distribution. Нужна отдельная юридическая оценка; этот отчёт не является legal advice.
- Telegram-HarmonyOS не имеет root LICENSE, хотя entry package декларирует MIT. Это release blocker уровня governance.
- Nekogram использует Firebase, GMS, analytics, Sentry и external translation/transcription providers. Любой аналог требует threat model, consent/data-flow disclosure и opt-out.
- ArkGram push implementation/extension и unknown native binaries нельзя считать доверенными reference implementations.

## 11. Свежая verification

### Telegram-HarmonyOS

```text
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-ui-phase0.ps1
tg_ui shell smoke checks passed.
EXIT_CODE=0
```

```text
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-build.ps1
clean:       BUILD SUCCESSFUL in 8 s 947 ms
assembleHap: BUILD SUCCESSFUL in 51 s 253 ms
EXIT_CODE=0
```

Build witness подтверждает ArkTS/native compile и HAP packaging. Он также повторно подтвердил известный blocker:

```text
WARN: Will skip sign 'hos_hap'. No signingConfigs profile is configured in current project.
```

Были ArkTS warnings в `TdGateway.ets`, `TgBubbleTail.ets` и `TgTgsPlayer.ets`; build они не остановили.

### Repositories

```text
Telegram-HarmonyOS: ## dev...origin/dev
Nekogram:           ## main...origin/main
Nekogram HEAD == origin/main == c17b0a46c7741cad18bed64e02cc7b05fad4d74a
```

Ожидаемые изменения target tree после аудита: этот отчёт и компактные snapshot updates в `STATUS.md`, `TASKS/TODO.md`, `TASKS/LESSONS.md`; application code не менялся.

## 12. Primary references

External:

- [Nekogram official site](https://nekogram.app/)
- [Nekogram canonical GitHub repository](https://github.com/Nekogram/Nekogram)
- [ArkGram official Telegram channel](https://t.me/arkgram_hmos)
- [Homogram candidate, explicitly not treated as ArkGram](https://github.com/HomoArk/Homogram)

Local source anchors:

- `C:\Users\Kharki\Desktop\Telegram-HarmonyOS\ARCHITECTURE.md`
- `C:\Users\Kharki\Desktop\Telegram-HarmonyOS\STATUS.md`
- `C:\Users\Kharki\Desktop\Telegram-HarmonyOS\TASKS\TODO.md`
- `C:\Users\Kharki\Desktop\Telegram-HarmonyOS\ARKGRAM_REFERENCE.md`
- `C:\Refs\Telegram\ArkGram-RE\out\ArkGram-project\entry\src\main\module.json`
- `C:\Refs\Telegram\Nekogram\README.md`
- `C:\Refs\Telegram\Nekogram\LICENSE`
- `C:\Refs\Telegram\Nekogram\build.gradle`
- `C:\Refs\Telegram\Nekogram\TMessagesProj\build.gradle`
- `C:\Refs\Telegram\Nekogram\TMessagesProj\src\main\java\tw\nekomimi\nekogram\NekoConfig.java`
- `C:\Refs\Telegram\Nekogram\.github\workflows\build.yml`
