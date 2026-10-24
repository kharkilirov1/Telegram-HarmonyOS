# Review reports — index

81 dated reports, newest first. Each report is an immutable checkpoint: it records what was
verified on its date and what stayed open. Verdicts live inside the reports, not in this table —
do not read a title as a PASS. A report may carry a dated corrections block (for example the
2026-10-21 drain and competitor notes, corrected on 2026-10-23); the original result stays visible
and the correction says what it changed.

Two things are dead **by design** inside old reports: links to build outputs
(`entry/build/**/*.hap`), offline evidence JSON, and absolute `C:/Users/...` or `C:/Refs/...` paths.
They were valid on their date. Do not "fix" a report to match today's tree — write a new dated report
in this directory and let it supersede the old one (`DECISIONS.md` D25).

## 2026-10 (36)

| Date | Report | Title |
|---|---|---|
| 2026-10-25 | [2026-10-25-typing-indicator.md](2026-10-25-typing-indicator.md) | Typing indicator slice — TTL 8 s, deadline rollback, static dots (witness pending) |
| 2026-10-25 | [2026-10-25-stickers-tgs.md](2026-10-25-stickers-tgs.md) | Stickers/TGS slice — visibility policy, fileId cache, instance budget (witness pending) |
| 2026-10-25 | [2026-10-25-matrix-verification.md](2026-10-25-matrix-verification.md) | Capability matrix — nine `unverified` rows verified against code |
| 2026-10-23 | [2026-10-23-drain-yield-model-rerun.md](2026-10-23-drain-yield-model-rerun.md) | Drain yield-model re-run — shipped pacing measured on the emulator |
| 2026-10-21 | [2026-10-21-arkgram-analysis.md](2026-10-21-arkgram-analysis.md) | ArkGram competitor analysis — 2026-10-21 (corrected 2026-10-23) |
| 2026-10-21 | [2026-10-21-drain-budget-sweep.md](2026-10-21-drain-budget-sweep.md) | Drain slice budget sweep — recommendation withdrawn 2026-10-23 |
| 2026-10-20 | [2026-10-20-drain-topology-spike.md](2026-10-20-drain-topology-spike.md) | Drain topology spike — null result (corrected 2026-10-23) |
| 2026-10-20 | [2026-10-20-worker-napi-probe.md](2026-10-20-worker-napi-probe.md) | Worker NAPI probe — 2026-10-20 |
| 2026-10-19 | [2026-10-19-tdlib-version-provenance.md](2026-10-19-tdlib-version-provenance.md) | TDLib version provenance and emulator precondition — 2026-10-19 |
| 2026-10-18 | [2026-10-18-receive-latency.md](2026-10-18-receive-latency.md) | Bounded receive scheduling correction — 2026-10-18 |
| 2026-10-18 | [2026-10-18-main-receive-acceptance.md](2026-10-18-main-receive-acceptance.md) | Main receive-candidate acceptance - 2026-10-18 |
| 2026-10-18 | [2026-10-18-main-diagnostic-runtime.md](2026-10-18-main-diagnostic-runtime.md) | Main diagnostic runtime - 2026-10-18 |
| 2026-10-18 | [2026-10-18-bounded-timeout-diagnostics.md](2026-10-18-bounded-timeout-diagnostics.md) | Bounded timeout diagnostics - 2026-10-18 |
| 2026-10-15 | [2026-10-15-receive-stabilization.md](2026-10-15-receive-stabilization.md) | Receive and privacy stabilization - 2026-10-15 |
| 2026-10-13 | [2026-10-13-source-checkpoint.md](2026-10-13-source-checkpoint.md) | Reviewed source checkpoint - 2026-10-13 |
| 2026-10-13 | [2026-10-13-native-validation.md](2026-10-13-native-validation.md) | Official SDK and existing-emulator validation — 2026-10-13 |
| 2026-10-02 | [2026-10-02-slow-mode.md](2026-10-02-slow-mode.md) | Timed slow mode — completed local validation, 2026-10-03 |
| 2026-10-02 | [2026-10-02-slow-mode-chief-review.md](2026-10-02-slow-mode-chief-review.md) | (no heading) |
| 2026-10-02 | [2026-10-02-send-forward-errors.md](2026-10-02-send-forward-errors.md) | Bounded send/forward errors and application TDLib406 - 2026-10-02 |
| 2026-10-02 | [2026-10-02-send-forward-errors-chief-review.md](2026-10-02-send-forward-errors-chief-review.md) | Independent chief review — ACCEPTED |
| 2026-10-02 | [2026-10-02-document-video-resend.md](2026-10-02-document-video-resend.md) | Sequential document/video resend - 2026-10-02 |
| 2026-10-02 | [2026-10-02-document-video-resend-chief-review.md](2026-10-02-document-video-resend-chief-review.md) | Chief independent review — existing document/video resend |
| 2026-10-01 | [2026-10-01-pinned-account-ownership.md](2026-10-01-pinned-account-ownership.md) | Pinned account/session ownership - 2026-10-01 |
| 2026-10-01 | [2026-10-01-pinned-account-ownership-chief-review.md](2026-10-01-pinned-account-ownership-chief-review.md) | Independent final review: pinned account/session reliability |
| 2026-10-01 | [2026-10-01-photo-selection-preview.md](2026-10-01-photo-selection-preview.md) | Превью выбранных фотографий — 2026-10-01 |
| 2026-10-01 | [2026-10-01-photo-selection-preview-astra-review.md](2026-10-01-photo-selection-preview-astra-review.md) | Selected-photo preview: independent chief review |
| 2026-10-01 | [2026-10-01-photo-album-sending.md](2026-10-01-photo-album-sending.md) | Отправка фотоальбомов — 2026-10-01 |
| 2026-10-01 | [2026-10-01-photo-album-references.md](2026-10-01-photo-album-references.md) | Фотоальбомы: grounding по всем восьми refs — 2026-10-01 |
| 2026-10-01 | [2026-10-01-photo-album-astra-review.md](2026-10-01-photo-album-astra-review.md) | Independent photo-album review: final code freeze |
| 2026-10-01 | [2026-10-01-petrelgram-comparison.md](2026-10-01-petrelgram-comparison.md) | Petrelgram и Telegram-HarmonyOS: сравнительный code review |
| 2026-10-01 | [2026-10-01-local-readiness.md](2026-10-01-local-readiness.md) | Local readiness after completed stages - 2026-10-01 |
| 2026-10-01 | [2026-10-01-gateway-error-causes.md](2026-10-01-gateway-error-causes.md) | Precise gateway error causes - 2026-10-01 |
| 2026-10-01 | [2026-10-01-gateway-error-causes-chief-review.md](2026-10-01-gateway-error-causes-chief-review.md) | Independent final review: gateway error causes |
| 2026-10-01 | [2026-10-01-chat-timeline-updates.md](2026-10-01-chat-timeline-updates.md) | Targeted chat timeline updates - 2026-10-01 |
| 2026-10-01 | [2026-10-01-chat-timeline-updates-chief-review.md](2026-10-01-chat-timeline-updates-chief-review.md) | Independent chief review — targeted timeline updates |
| 2026-10-01 | [2026-10-01-chat-screen-decomposition.md](2026-10-01-chat-screen-decomposition.md) | Полная декомпозиция экрана чата — 2026-10-01 |

## 2026-09 (45)

| Date | Report | Title |
|---|---|---|
| 2026-09-29 | [2026-09-29-attached-review-remediation.md](2026-09-29-attached-review-remediation.md) | Проверка приложенного код-ревью — 2026-09-29 |
| 2026-09-28 | [2026-09-28-td-client-lifetime.md](2026-09-28-td-client-lifetime.md) | TDLib client lifetime / open_count + ETS async-stop barrier |
| 2026-09-28 | [2026-09-28-store-invalidation.md](2026-09-28-store-invalidation.md) | AppStore: синхронный observer отзыва account scope |
| 2026-09-28 | [2026-09-28-recording-ownership.md](2026-09-28-recording-ownership.md) | R04 — ChatVoiceRecordingController: operation/resource ownership |
| 2026-09-28 | [2026-09-28-recording-independent-review.md](2026-09-28-recording-independent-review.md) | R04 — независимое review после implementation |
| 2026-09-28 | [2026-09-28-playback-remediation.md](2026-09-28-playback-remediation.md) | Playback: владение ресурсами и устаревшие операции — 28 сентября 2026 |
| 2026-09-28 | [2026-09-28-playback-controller-review.md](2026-09-28-playback-controller-review.md) | Независимое focused review playback controller — 2026-09-28 |
| 2026-09-28 | [2026-09-28-native-stop-remediation.md](2026-09-28-native-stop-remediation.md) | Асинхронная остановка TDLib — 28 сентября 2026 |
| 2026-09-28 | [2026-09-28-native-media-remediation.md](2026-09-28-native-media-remediation.md) | Надёжность native bridge и записи голоса — 28 сентября 2026 |
| 2026-09-28 | [2026-09-28-native-lifecycle-contract.md](2026-09-28-native-lifecycle-contract.md) | HarmonyOS TSFN: ownership, lifetime и asynchronous stop |
| 2026-09-28 | [2026-09-28-native-independent-review.md](2026-09-28-native-independent-review.md) | Независимое adversarial review: native startup / callback ownership |
| 2026-09-28 | [2026-09-28-native-env-cleanup-contract.md](2026-09-28-native-env-cleanup-contract.md) | Native TSFN: граница env teardown |
| 2026-09-28 | [2026-09-28-native-delivery-remediation.md](2026-09-28-native-delivery-remediation.md) | Native delivery: безопасное владение payload — 28 сентября 2026 |
| 2026-09-28 | [2026-09-28-media-page-ownership.md](2026-09-28-media-page-ownership.md) | Media page ownership — 2026-09-28 |
| 2026-09-28 | [2026-09-28-media-account-remediation.md](2026-09-28-media-account-remediation.md) | Media account/page ownership — итог среза 2026-09-28 |
| 2026-09-28 | [2026-09-28-media-account-independent-review.md](2026-09-28-media-account-independent-review.md) | Независимое review: account/page ownership и AVSession |
| 2026-09-28 | [2026-09-28-global-media-ownership.md](2026-09-28-global-media-ownership.md) | Global media playback ownership — 2026-09-28 |
| 2026-09-28 | [2026-09-28-feature-first-assessment.md](2026-09-28-feature-first-assessment.md) | Сначала функции, потом полировка? |
| 2026-09-28 | [2026-09-28-client-retirement-remediation.md](2026-09-28-client-retirement-remediation.md) | Завершение TDLib clients без потери владельца — 28 сентября 2026 |
| 2026-09-27 | [2026-09-27-remediation.md](2026-09-27-remediation.md) | Исправления после ревью — 27 сентября 2026 |
| 2026-09-27 | [2026-09-27-mark-read-ci-review.md](2026-09-27-mark-read-ci-review.md) | Независимое ревью mark-read / CI — 2026-09-27 |
| 2026-09-27 | [2026-09-27-history-independent-review.md](2026-09-27-history-independent-review.md) | R10 — independent read-only review, 2026-09-27 |
| 2026-09-27 | [2026-09-27-github-comparison.md](2026-09-27-github-comparison.md) | Telegram-HarmonyOS: что сделано и чем локальный проект отличается от GitHub |
| 2026-09-27 | [2026-09-27-chat-history-generation-fix.md](2026-09-27-chat-history-generation-fix.md) | R10 — LoadChatHistory: jump и владение окном |
| 2026-09-27 | [2026-09-27-chat-creation-auth-privacy-fix.md](2026-09-27-chat-creation-auth-privacy-fix.md) | R02 / R21 — создание чатов и приватность OTP, 2026-09-27 |
| 2026-09-06 | [2026-09-06-reliability-wave9.md](2026-09-06-reliability-wave9.md) | Reliability Wave9 — basic-group media permissions |
| 2026-09-06 | [2026-09-06-reliability-wave8.md](2026-09-06-reliability-wave8.md) | Reliability wave8 — membership и активность basic groups |
| 2026-09-06 | [2026-09-06-reliability-wave7.md](2026-09-06-reliability-wave7.md) | Reliability wave7 — пересылка: запрос, частичный результат и повтор |
| 2026-09-06 | [2026-09-06-reliability-wave17.md](2026-09-06-reliability-wave17.md) | Wave17 — route/account ownership и проверка границ |
| 2026-09-06 | [2026-09-06-reliability-wave16.md](2026-09-06-reliability-wave16.md) | Reliability Wave16 — account ownership страницы чата |
| 2026-09-06 | [2026-09-06-reliability-wave15.md](2026-09-06-reliability-wave15.md) | Reliability Wave15 — редактирование без потери ввода и межаккаунтной записи draft |
| 2026-09-06 | [2026-09-06-reliability-wave14.md](2026-09-06-reliability-wave14.md) | Reliability Wave14 — безопасное удаление сообщений |
| 2026-09-06 | [2026-09-06-reliability-wave13.md](2026-09-06-reliability-wave13.md) | Reliability Wave13 — доступность source actions и безопасный picker |
| 2026-09-06 | [2026-09-06-reliability-wave12.md](2026-09-06-reliability-wave12.md) | Reliability Wave12 — проверки пересылки до побочных действий |
| 2026-09-06 | [2026-09-06-reliability-wave11.md](2026-09-06-reliability-wave11.md) | Wave11 — права супергрупп, boosts и восстановление после ошибки |
| 2026-09-06 | [2026-09-06-reliability-wave10.md](2026-09-06-reliability-wave10.md) | Wave10 — запуск эмулятора и локализация системного сбоя |
| 2026-09-06 | [2026-09-06-native-open-count-gap.md](2026-09-06-native-open-count-gap.md) | Wave17: logical lease не доказывает native open-count safety |
| 2026-09-05 | [2026-09-05-reliability-wave6.md](2026-09-05-reliability-wave6.md) | Reliability wave6 — forward ownership и запуск эмуляторов |
| 2026-09-05 | [2026-09-05-reliability-wave5.md](2026-09-05-reliability-wave5.md) | Reliability wave5 — права участников и блокер эмулятора |
| 2026-09-05 | [2026-09-05-reliability-wave4.md](2026-09-05-reliability-wave4.md) | Надёжность — срез 4: live permissions и потерянные event routes |
| 2026-09-05 | [2026-09-05-reliability-wave3.md](2026-09-05-reliability-wave3.md) | Надёжность — срез 3: channel access и безопасное завершение отправки |
| 2026-09-05 | [2026-09-05-reliability-wave2.md](2026-09-05-reliability-wave2.md) | Reliability wave 2 — R2, TDLib recovery и изоляция аккаунтов |
| 2026-09-05 | [2026-09-05-reliability-wave1.md](2026-09-05-reliability-wave1.md) | Надёжность — первый срез, 2026-09-05 |
| 2026-09-05 | [2026-09-05-project-review.md](2026-09-05-project-review.md) | Ревью Telegram-HarmonyOS — 2026-09-05 |
| 2026-09-05 | [2026-09-05-ios-visual-reference-inventory.md](2026-09-05-ios-visual-reference-inventory.md) | Инвентаризация iOS visual references — 2026-09-05 |

## Non-report evidence

Three artefacts live beside the reports and are inputs to them, not checkpoints:

| File | Purpose |
|---|---|
| [2026-09-05-review-witness.cjs](2026-09-05-review-witness.cjs) | reproduction witness for the 2026-09-05 review |
| [2026-10-13-source-change-map.json](2026-10-13-source-change-map.json) | machine-readable source change map for the 2026-10-13 checkpoint |
| [2026-10-13-native-validation-evidence.json](2026-10-13-native-validation-evidence.json) | native validation evidence for the same checkpoint |

