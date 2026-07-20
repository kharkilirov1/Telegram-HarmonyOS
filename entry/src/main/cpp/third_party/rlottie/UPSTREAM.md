# Telegram rlottie snapshot

- Source repository: `https://github.com/Nekogram/Nekogram.git`
- Source revision: `c17b0a46c` (working tree verified clean before copy)
- Source path: `TMessagesProj/jni/rlottie`
- Canonical upstream: `https://github.com/TelegramMessenger/rlottie.git`
- Snapshot date: `2026-07-19`

The snapshot is kept in-tree because the application must build reproducibly
without depending on the external reference checkout. It is compiled into the
separate `libtg_rlottie.so` shared NAPI module; it is not merged into TDLib.

Licensing is documented by the upstream `licenses/` directory. The library is
primarily LGPL-2.1-or-later, with the bundled FreeType, Pixman, RapidJSON and
stb portions covered by their corresponding files in that directory.
