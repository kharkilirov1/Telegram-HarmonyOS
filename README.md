# Telegram-HarmonyOS

Telegram client for HarmonyOS NEXT (API 12+), built with ArkTS/ArkUI and TDLib.

## Architecture

```
ArkTS/ArkUI (UI) → NAPI Bridge (C++) → TDLib (Telegram API)
```

## Project Structure

```
├── AppScope/                    # App-level config
├── entry/                       # Main module
│   └── src/main/
│       ├── ets/
│       │   ├── entryability/    # UIAbility entry point
│       │   ├── pages/           # Page components
│       │   │   ├── Login/       # Auth flow (phone, code, password)
│       │   │   └── Chat/        # Chat list, chat detail
│       │   ├── components/      # Reusable UI components
│       │   ├── models/          # Data models (Chat, Message, User)
│       │   ├── services/        # TDLib client wrapper
│       │   └── viewmodels/      # View models
│       ├── cpp/                 # NAPI bridge to TDLib
│       └── resources/           # Strings, colors, media
├── tdlib/                       # TDLib submodule
├── build-profile.json5          # Project build config
└── oh-package.json5             # Dependencies
```

## Prerequisites

- DevEco Studio 5.0+
- HarmonyOS SDK (API 12+)
- TDLib compiled for HarmonyOS (ARM64)
- Telegram API credentials from [my.telegram.org](https://my.telegram.org)

## Setup

1. Clone with submodules: `git clone --recursive`
2. Build TDLib for HarmonyOS using the NDK
3. Set your API ID and hash in `TDLibClient.ets`
4. Open in DevEco Studio and build

## License

MIT
