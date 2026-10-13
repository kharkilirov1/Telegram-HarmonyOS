# REFERENCES — external source registry

Last verified: **2026-07-10** (original registry).
Petrelgram entry verified: **2026-10-01**; other pins were not refreshed.

Heavy third-party reference trees live outside this repository under:

```text
C:\Refs\Telegram
```

Do not clone them back into the project and do not create a junction from
`рефенсы/`. The retained `.gitignore` rule is only a guard against accidental
future clones.

## Reference priority

1. **Latest installed Telegram iOS runtime screenshots/video** — actual shipped visual truth.
2. **Current public Telegram iOS source** — component hierarchy, states, behavior, and constants; it may lag the shipped App Store build.
3. **`harmonyos_docs` + HarmonyOS examples** — platform-correct ArkUI implementation.
4. **Telegram Android / Nekogram** — product behavior and edge-case fallback.
5. **Old Telegram iOS snapshot / ArkGram RE** — historical or clean-room comparison only.

## Registry

| Reference | Canonical local path | Origin / snapshot | Pinned state | License boundary | Role |
|---|---|---|---|---|---|
| Telegram iOS current | `C:\Refs\Telegram\Telegram-iOS-current` | `https://github.com/TelegramMessenger/Telegram-iOS.git` | `master` @ `6e370e06d147b091b07903071cb1b8a22152492d` | No root license file in checkout; inspect upstream terms before reuse | Primary source-level iOS UI reference |
| Telegram iOS old snapshot | `C:\Refs\Telegram\Telegram-iOS-snapshot-2026-02-10` | ZIP/source snapshot, no `.git` | README SHA-256 `A4FBB531084525F0BAE35A2E1D09E6347E9F8B760ABB6F52CFB84867ABC86B49` | No root license file | Historical pre-refresh comparisons only |
| Telegram Android | `C:\Refs\Telegram\telegram-android` | `https://github.com/DrKLO/Telegram.git` | `master` @ `ce8c61c47ec48a84014c8d1d0592f0e22a9dbb22` | GPL-2.0 | Telegram behavior fallback |
| Nekogram | `C:\Refs\Telegram\Nekogram` | `https://github.com/Nekogram/Nekogram.git` | `main` @ `c17b0a46c7741cad18bed64e02cc7b05fad4d74a` | GPL-2.0 | Extra feature/state and edge-case reference |
| HarmonyOS UX examples | `C:\Refs\Telegram\HarmonyOSComponentUXExamples` | `https://gitcode.com/HarmonyOS_Samples/HarmonyOSComponentUXExamples.git` | `master` @ `c3cef227ab70404fb7adcca4018f6d1cf7b153d2` | Apache-2.0 | Native ArkUI/HarmonyOS UX patterns |
| HarmonyOS codelabs | `C:\Refs\Telegram\HarmonyOS-Codelabs` | `https://gitcode.com/openharmony/codelabs.git` | `master` @ `c151753a7316873091cb065a5c9cbd79c6ea713c` | No root license file; inspect per-sample notices | Platform examples |
| ArkGram RE | `C:\Refs\Telegram\ArkGram-RE` | HAP-derived reverse reconstruction v1.0.1, no `.git` | preserved 2026-07-10 | No license; no code/assets reuse | Clean-room HarmonyOS behavior comparison only |
| Petrelgram | `C:\Refs\Telegram\Petrelgram` | `https://github.com/miramira8295/Petrelgram.git` | `main` @ `a5e1ec763b08d549630a58f9efe96677bb3245de` (shallow clone, 2026-10-01) | Root Apache-2.0; native dependencies and mascot assets have separate notices/terms | Secondary HarmonyOS/TDLib implementation and feature reference; not the iOS visual contract |

## Petrelgram inspection boundary

- Source: [pinned tree](https://github.com/miramira8295/Petrelgram/tree/a5e1ec763b08d549630a58f9efe96677bb3245de), [root license](https://github.com/miramira8295/Petrelgram/blob/a5e1ec763b08d549630a58f9efe96677bb3245de/LICENSE).
- Actual layout: `entry/src/main/ets/tdkit`, `store`, `pages`, `services`, `util`; native bridge in `entry/src/main/cpp`; host tests in `entry/src/test` and native smoke tests in `entry/src/ohosTest`.
- Useful study areas: the optional Worker bridge (disabled in the pinned runtime), account-scoped stores, timeline/scroll ownership, download/streaming policies, localization checks, folders/topics/privacy and calls. See the [comparative code review](docs/reviews/2026-10-01-petrelgram-comparison.md) for exact source paths, limitations and priorities.
- Petrelgram aims at Telegram Android behavior/layout. Keep the accepted Telegram iOS runtime/source hierarchy and the AppStore/tg_ui contracts of this project when adapting an idea.
- Reference only: no runtime source/assets copied, no build dependency or submodule added, no junction into the project. The clone has no installed native binaries, credentials or dependency packages; it was not built or run.
- Apache-2.0 at the root does not replace TDLib/tgcalls/WebRTC/codec licenses or asset permissions. Inspect per-component licenses and notices before any future reuse; `scripts/tgcalls/README.md` identifies LGPL-3.0 for tgcalls and `UTYA_DUCK_NOTICE.txt` identifies the mascot source without granting a reuse license.

## Safe refresh workflow

References are pinned inputs. Do not silently pull them during implementation.

```powershell
git -C <reference-path> fetch origin
git -C <reference-path> log --oneline HEAD..origin/<branch>
git -C <reference-path> merge --ff-only origin/<branch>
```

After a deliberate refresh:

1. update the pinned commit in this file;
2. verify every cited source path still exists;
3. compare affected component passports before changing ArkTS;
4. rerun the narrow UI smoke/build relevant to resulting project edits.

The Telegram iOS clone intentionally leaves 13 native/build submodules
uninitialized because the project uses it for UI source inspection, not iOS
compilation. Initialize them only if a real iOS build becomes necessary.

