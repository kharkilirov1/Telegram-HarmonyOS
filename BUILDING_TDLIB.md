# Building and Integrating TDLib for HarmonyOS

## Architecture

```
Repository root
├── tdlib/                         ← git submodule (TDLib source, for building)
│   └── (https://github.com/tdlib/td.git)
│
└── entry/src/main/cpp/
    ├── CMakeLists.txt             ← links against prebuilt TDLib
    └── third_party/
        └── tdlib/                 ← prebuilt artifacts go HERE
            ├── include/
            │   └── td/telegram/td_json_client.h
            └── lib/
                ├── arm64-v8a/
                │   └── libtdjson.so
                └── x86_64/
                    └── libtdjson.so
```

**The git submodule (`tdlib/`) and the prebuilt path (`cpp/third_party/tdlib/`) are separate concerns.**
- Submodule = source code for building TDLib yourself.
- `third_party/tdlib/` = where CMakeLists.txt looks for pre-compiled binaries.
- Build artifacts are NOT checked into git (`.gitignore` excludes `build/`).

## Step-by-step: building TDLib from source

```bash
# 1. Initialize the submodule
git submodule update --init tdlib

# 2. Build TDLib for HarmonyOS (ARM64)
#    Requires: HarmonyOS NDK (from DevEco Studio SDK Manager)
cd tdlib
mkdir build-arm64 && cd build-arm64
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=$OHOS_SDK/native/build/cmake/ohos.toolchain.cmake \
  -DOHOS_ARCH=arm64-v8a \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=../install-arm64
cmake --build . --target tdjson -- -j$(nproc)
cmake --install .

# 3. (Optional) Build for x86_64 emulator
cd ..
mkdir build-x86_64 && cd build-x86_64
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=$OHOS_SDK/native/build/cmake/ohos.toolchain.cmake \
  -DOHOS_ARCH=x86_64 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=../install-x86_64
cmake --build . --target tdjson -- -j$(nproc)
cmake --install .
```

## Step-by-step: placing prebuilt artifacts

```bash
# 4. Copy artifacts to the path CMake expects
TDLIB_DEST=entry/src/main/cpp/third_party/tdlib

mkdir -p $TDLIB_DEST/include
mkdir -p $TDLIB_DEST/lib/arm64-v8a
mkdir -p $TDLIB_DEST/lib/x86_64

# Headers (same for all ABIs)
cp -r tdlib/install-arm64/include/td $TDLIB_DEST/include/

# Libraries
cp tdlib/install-arm64/lib/libtdjson.so $TDLIB_DEST/lib/arm64-v8a/
cp tdlib/install-x86_64/lib/libtdjson.so $TDLIB_DEST/lib/x86_64/   # if built
```

## Step-by-step: using a custom TDLib path

If your prebuilt TDLib is elsewhere, override at configure time:

```bash
# Via CMake variable (highest priority)
hvigorw assembleHap -p cppCmakeArgs="-DTDLIB_DIR=/path/to/my/tdlib"

# Via environment variable
export TDLIB_DIR=/path/to/my/tdlib
hvigorw assembleHap
```

## Verifying the setup

CMake will print a diagnostic box during configure:

```
-- ┌─ TDLib REAL mode ──────────────────────────────
-- │ ABI:     arm64-v8a
-- │ Header:  .../third_party/tdlib/include/td/telegram/td_json_client.h
-- │ Library: .../third_party/tdlib/lib/arm64-v8a/libtdjson.so
-- │ SONAME:  libtdjson.so.1.8.61
-- └────────────────────────────────────────────────
```

If TDLib is missing in a **debug** build, you'll get a warning and STUB mode:

```
-- ┌─ TDLib STUB mode (dev only) ───────────────────
-- │ ...
-- │ STUB WILL NOT CONNECT TO TELEGRAM SERVERS.
-- └────────────────────────────────────────────────
```

If TDLib is missing in a **release** build, CMake will **FATAL_ERROR** (fail-fast).

## TDLIB_DIR resolution priority

| Priority | Source | Example |
|----------|--------|---------|
| 1 (highest) | `-DTDLIB_DIR=<path>` on cmake CLI | `-DTDLIB_DIR=/opt/tdlib` |
| 2 | `TDLIB_DIR` environment variable | `export TDLIB_DIR=/opt/tdlib` |
| 3 (default) | `<cpp dir>/third_party/tdlib` | `entry/src/main/cpp/third_party/tdlib` |

## TDLib version

Current expected version: **1.8.61** (SONAME: `libtdjson.so.1.8.61`).

If you build a different version, update `TDLIB_RUNTIME_SONAME` in
`entry/src/main/cpp/CMakeLists.txt`.
