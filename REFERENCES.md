# REFERENCES — external source registry

Last verified: **2026-07-10**

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

