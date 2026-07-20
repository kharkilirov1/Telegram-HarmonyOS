#include "napi/native_api.h"
#include "hilog/log.h"
#include "third_party/rlottie/inc/rlottie.h"

#include <algorithm>
#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

namespace {

constexpr uint32_t TG_LOG_DOMAIN = 0x0021;
constexpr const char *TG_LOG_TAG = "TgRlottie";
constexpr size_t MAX_JSON_BYTES = 16 * 1024 * 1024;
constexpr int32_t MAX_SURFACE_EDGE = 512;
constexpr size_t MAX_TELEGRAM_FRAMES = 600;
constexpr double MAX_TELEGRAM_FPS = 60.0;
constexpr const char *SOURCE_REVISION = "Nekogram/c17b0a46c";

struct AnimationEntry {
    std::unique_ptr<rlottie::Animation> animation;
    size_t frameCount = 0;
    double frameRate = 0.0;
    size_t sourceWidth = 0;
    size_t sourceHeight = 0;
    std::mutex renderMutex;
};

std::mutex gAnimationsMutex;
std::unordered_map<int32_t, std::shared_ptr<AnimationEntry>> gAnimations;
std::atomic<int32_t> gNextHandle{1};

napi_value Undefined(napi_env env) {
    napi_value value = nullptr;
    napi_get_undefined(env, &value);
    return value;
}

napi_value Null(napi_env env) {
    napi_value value = nullptr;
    napi_get_null(env, &value);
    return value;
}

napi_value Boolean(napi_env env, bool value) {
    napi_value result = nullptr;
    napi_get_boolean(env, value, &result);
    return result;
}

bool ReadInt32(napi_env env, napi_value value, int32_t &result) {
    return value != nullptr && napi_get_value_int32(env, value, &result) == napi_ok;
}

bool ReadString(napi_env env, napi_value value, size_t maxBytes, std::string &result) {
    if (value == nullptr) {
        return false;
    }
    size_t length = 0;
    if (napi_get_value_string_utf8(env, value, nullptr, 0, &length) != napi_ok || length > maxBytes) {
        return false;
    }
    std::vector<char> buffer(length + 1, '\0');
    size_t copied = 0;
    if (napi_get_value_string_utf8(env, value, buffer.data(), buffer.size(), &copied) != napi_ok) {
        result.clear();
        return false;
    }
    result.assign(buffer.data(), copied);
    return true;
}

void SetNamedInt32(napi_env env, napi_value object, const char *name, int32_t value) {
    napi_value property = nullptr;
    napi_create_int32(env, value, &property);
    napi_set_named_property(env, object, name, property);
}

void SetNamedDouble(napi_env env, napi_value object, const char *name, double value) {
    napi_value property = nullptr;
    napi_create_double(env, value, &property);
    napi_set_named_property(env, object, name, property);
}

std::shared_ptr<AnimationEntry> FindAnimation(int32_t handle) {
    std::lock_guard<std::mutex> lock(gAnimationsMutex);
    const auto iterator = gAnimations.find(handle);
    return iterator == gAnimations.end() ? nullptr : iterator->second;
}

void ConvertRgbaPremultipliedToStraight(uint32_t *pixels, size_t pixelCount) {
    auto *bytes = reinterpret_cast<uint8_t *>(pixels);
    for (size_t index = 0; index < pixelCount; ++index) {
        const size_t offset = index * 4;
        // Telegram's rlottie surface is ARGB32 premultiplied as a uint32_t.
        // On the little-endian x86_64/arm64 targets used here, the backing
        // bytes are already ordered RGBA; only straight-alpha conversion is
        // required for Canvas ImageData. Reinterpreting the numeric value as
        // 0xAARRGGBB swaps red and blue and produces purple/yellow stickers.
        const uint32_t alpha = bytes[offset + 3];
        uint32_t red = bytes[offset];
        uint32_t green = bytes[offset + 1];
        uint32_t blue = bytes[offset + 2];
        if (alpha > 0 && alpha < 255) {
            red = std::min(255U, (red * 255U + alpha / 2U) / alpha);
            green = std::min(255U, (green * 255U + alpha / 2U) / alpha);
            blue = std::min(255U, (blue * 255U + alpha / 2U) / alpha);
        }
        bytes[offset] = static_cast<uint8_t>(red);
        bytes[offset + 1] = static_cast<uint8_t>(green);
        bytes[offset + 2] = static_cast<uint8_t>(blue);
        bytes[offset + 3] = static_cast<uint8_t>(alpha);
    }
}

napi_value CreateAnimation(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value argv[2] = {nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 2) {
        napi_throw_type_error(env, nullptr, "createAnimation(json, key) requires two strings");
        return nullptr;
    }

    std::string json;
    std::string key;
    if (!ReadString(env, argv[0], MAX_JSON_BYTES, json) || !ReadString(env, argv[1], 512, key)) {
        napi_throw_type_error(env, nullptr, "Invalid rlottie JSON or key");
        return nullptr;
    }

    auto entry = std::make_shared<AnimationEntry>();
    entry->animation = rlottie::Animation::loadFromData(json, key, nullptr, rlottie::FitzModifier::None);
    if (!entry->animation) {
        OH_LOG_Print(LOG_APP, LOG_WARN, TG_LOG_DOMAIN, TG_LOG_TAG, "loadFromData failed");
        return Null(env);
    }
    entry->frameCount = entry->animation->totalFrame();
    entry->frameRate = entry->animation->frameRate();
    entry->animation->size(entry->sourceWidth, entry->sourceHeight);
    if (entry->frameCount == 0 || entry->frameCount > MAX_TELEGRAM_FRAMES ||
        entry->frameRate <= 0.0 || entry->frameRate > MAX_TELEGRAM_FPS) {
        OH_LOG_Print(LOG_APP, LOG_WARN, TG_LOG_DOMAIN, TG_LOG_TAG,
            "Rejected animation frames=%{public}zu fps=%{public}.2f", entry->frameCount, entry->frameRate);
        return Null(env);
    }

    int32_t handle = gNextHandle.fetch_add(1);
    if (handle <= 0) {
        gNextHandle.store(2);
        handle = 1;
    }
    {
        std::lock_guard<std::mutex> lock(gAnimationsMutex);
        gAnimations[handle] = entry;
    }

    napi_value result = nullptr;
    napi_create_object(env, &result);
    SetNamedInt32(env, result, "handle", handle);
    SetNamedInt32(env, result, "frameCount", static_cast<int32_t>(entry->frameCount));
    SetNamedDouble(env, result, "frameRate", entry->frameRate);
    OH_LOG_Print(LOG_APP, LOG_INFO, TG_LOG_DOMAIN, TG_LOG_TAG,
        "animation created handle=%{public}d frames=%{public}zu fps=%{public}.2f composition=%{public}zux%{public}zu source=%{public}s",
        handle, entry->frameCount, entry->frameRate, entry->sourceWidth, entry->sourceHeight, SOURCE_REVISION);
    return result;
}

napi_value RenderFrame(napi_env env, napi_callback_info info) {
    size_t argc = 5;
    napi_value argv[5] = {nullptr, nullptr, nullptr, nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    int32_t handle = 0;
    int32_t frame = 0;
    int32_t width = 0;
    int32_t height = 0;
    if (argc < 5 || !ReadInt32(env, argv[0], handle) || !ReadInt32(env, argv[1], frame) ||
        !ReadInt32(env, argv[2], width) || !ReadInt32(env, argv[3], height) ||
        width <= 0 || height <= 0 || width > MAX_SURFACE_EDGE || height > MAX_SURFACE_EDGE) {
        napi_throw_type_error(env, nullptr, "Invalid renderFrame arguments");
        return nullptr;
    }

    napi_typedarray_type arrayType;
    size_t elementCount = 0;
    void *data = nullptr;
    napi_value arrayBuffer = nullptr;
    size_t byteOffset = 0;
    if (napi_get_typedarray_info(env, argv[4], &arrayType, &elementCount, &data, &arrayBuffer, &byteOffset) != napi_ok ||
        arrayType != napi_uint8_clamped_array || data == nullptr) {
        napi_throw_type_error(env, nullptr, "renderFrame output must be Uint8ClampedArray");
        return nullptr;
    }
    const size_t pixelCount = static_cast<size_t>(width) * static_cast<size_t>(height);
    if (elementCount < pixelCount * 4 || (reinterpret_cast<uintptr_t>(data) & 0x3U) != 0) {
        napi_throw_range_error(env, nullptr, "renderFrame output buffer is too small or unaligned");
        return nullptr;
    }

    const auto entry = FindAnimation(handle);
    if (!entry) {
        return Boolean(env, false);
    }
    const size_t normalizedFrame = static_cast<size_t>(std::max(frame, 0)) % entry->frameCount;
    bool rendered = false;
    {
        std::lock_guard<std::mutex> lock(entry->renderMutex);
        rlottie::Surface surface(reinterpret_cast<uint32_t *>(data), static_cast<size_t>(width),
            static_cast<size_t>(height), static_cast<size_t>(width) * 4);
        entry->animation->renderSync(normalizedFrame, surface, true, &rendered);
    }
    if (!rendered) {
        return Boolean(env, false);
    }
    ConvertRgbaPremultipliedToStraight(reinterpret_cast<uint32_t *>(data), pixelCount);
    return Boolean(env, true);
}

napi_value DestroyAnimation(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    int32_t handle = 0;
    if (argc < 1 || !ReadInt32(env, argv[0], handle)) {
        napi_throw_type_error(env, nullptr, "destroyAnimation(handle) requires an integer handle");
        return nullptr;
    }
    bool erased = false;
    {
        std::lock_guard<std::mutex> lock(gAnimationsMutex);
        erased = gAnimations.erase(handle) > 0;
    }
    OH_LOG_Print(LOG_APP, LOG_INFO, TG_LOG_DOMAIN, TG_LOG_TAG,
        "animation destroyed handle=%{public}d existed=%{public}d", handle, erased ? 1 : 0);
    return Undefined(env);
}

napi_value GetRendererInfo(napi_env env, napi_callback_info) {
    const std::string json = std::string("{\"renderer\":\"telegram-rlottie\",\"source\":\"") +
        SOURCE_REVISION + "\"}";
    napi_value value = nullptr;
    napi_create_string_utf8(env, json.c_str(), json.size(), &value);
    return value;
}

napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor descriptors[] = {
        {"createAnimation", nullptr, CreateAnimation, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"renderFrame", nullptr, RenderFrame, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"destroyAnimation", nullptr, DestroyAnimation, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getRendererInfo", nullptr, GetRendererInfo, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(descriptors) / sizeof(descriptors[0]), descriptors);
    return exports;
}

} // namespace

EXTERN_C_START
static napi_module tgRlottieModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "tg_rlottie",
    .nm_priv = nullptr,
    .reserved = {0},
};

__attribute__((constructor))
void RegisterTgRlottieModule() {
    napi_module_register(&tgRlottieModule);
}
EXTERN_C_END
