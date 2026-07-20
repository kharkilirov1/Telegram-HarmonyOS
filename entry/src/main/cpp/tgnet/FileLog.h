#ifndef TG_RLOTTIE_FILE_LOG_COMPAT_H
#define TG_RLOTTIE_FILE_LOG_COMPAT_H

// Telegram's rlottie snapshot includes this Android tgnet header in two source
// files, but does not use any symbol from it. Keep a deliberately empty
// compatibility header instead of pulling the unrelated Android networking
// stack into the HarmonyOS renderer.

#endif // TG_RLOTTIE_FILE_LOG_COMPAT_H
