#include "tdlib_napi.h"
#include <string>
#include <thread>
#include <atomic>
#include <mutex>
#include <hilog/log.h>
#include <td/telegram/td_json_client.h>

// --- Stringify macros for compile-time defines ---
#define XSTR(x) STR(x)
#define STR(x) #x

#ifndef TDLIB_DIR_PATH
#define TDLIB_DIR_PATH unknown
#endif
#ifndef TDLIB_SONAME
#define TDLIB_SONAME unknown
#endif

#define LOG_TAG "TDLibNAPI"
#define LOG_DOMAIN 0x0001

// --- Receive loop state machine ---
enum class LoopState { Stopped, Starting, Running, Stopping };
static std::atomic<LoopState> loop_state{LoopState::Stopped};
static std::thread receive_thread;
static std::mutex loop_mutex;
static napi_threadsafe_function threadsafe_callback = nullptr;

// --- NAPI argument validation helpers ---
// Throws a JS TypeError and returns nullptr on failure.

static napi_value napi_throw_arg_error(napi_env env, const char* func, const char* msg) {
    std::string full = std::string(func) + ": " + msg;
    OH_LOG_ERROR(LogType::LOG_APP, "NAPI arg error: %{public}s", full.c_str());
    napi_throw_error(env, "ERR_INVALID_ARG", full.c_str());
    return nullptr;
}

static bool napi_check_argc(napi_env env, const char* func, size_t actual, size_t expected) {
    if (actual < expected) {
        std::string msg = "expected " + std::to_string(expected) +
                          " argument(s), got " + std::to_string(actual);
        napi_throw_arg_error(env, func, msg.c_str());
        return false;
    }
    return true;
}

static bool napi_check_type(napi_env env, const char* func, napi_value val,
                            napi_valuetype expected, const char* argName) {
    napi_valuetype actual;
    napi_typeof(env, val, &actual);
    if (actual != expected) {
        const char* type_names[] = {
            "undefined", "null", "boolean", "number", "string", "symbol", "object", "function", "external", "bigint"
        };
        const char* actual_name = (actual >= 0 && actual <= 9) ? type_names[actual] : "unknown";
        const char* expected_name = (expected >= 0 && expected <= 9) ? type_names[expected] : "unknown";
        std::string msg = std::string(argName) + " must be " + expected_name + ", got " + actual_name;
        napi_throw_arg_error(env, func, msg.c_str());
        return false;
    }
    return true;
}

// Escape a string for safe embedding in a JSON value.
static std::string json_escape(const std::string& s) {
    std::string out;
    out.reserve(s.size());
    for (char c : s) {
        switch (c) {
            case '"':  out += "\\\""; break;
            case '\\': out += "\\\\"; break;
            case '\b': out += "\\b";  break;
            case '\f': out += "\\f";  break;
            case '\n': out += "\\n";  break;
            case '\r': out += "\\r";  break;
            case '\t': out += "\\t";  break;
            default:
                if (static_cast<unsigned char>(c) < 0x20) {
                    char buf[8];
                    snprintf(buf, sizeof(buf), "\\u%04x", static_cast<unsigned char>(c));
                    out += buf;
                } else {
                    out += c;
                }
        }
    }
    return out;
}

namespace tdlib_napi {

napi_value CreateClient(napi_env env, napi_callback_info info) {
    int client_id = td_create_client_id();
    OH_LOG_INFO(LogType::LOG_APP, "TDLib client created: %{public}d", client_id);

    napi_value result;
    napi_create_int32(env, client_id, &result);
    return result;
}

napi_value Send(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value argv[2];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    // Strict validation: 2 args (number, string)
    if (!napi_check_argc(env, "send", argc, 2)) return nullptr;
    if (!napi_check_type(env, "send", argv[0], napi_number, "clientId")) return nullptr;
    if (!napi_check_type(env, "send", argv[1], napi_string, "requestJson")) return nullptr;

    // Get client_id
    int32_t client_id;
    napi_get_value_int32(env, argv[0], &client_id);

    // Get JSON request string
    size_t str_len;
    napi_get_value_string_utf8(env, argv[1], nullptr, 0, &str_len);
    std::string request(str_len, '\0');
    napi_get_value_string_utf8(env, argv[1], &request[0], str_len + 1, &str_len);

    // Log only the method name — never raw JSON (contains phone numbers, codes, etc.)
    {
        std::string method = "unknown";
        auto type_pos = request.find("\"@type\":\"");
        if (type_pos != std::string::npos) {
            auto start = type_pos + 9;
            auto end = request.find('"', start);
            if (end != std::string::npos) {
                method = request.substr(start, end - start);
            }
        }
        OH_LOG_INFO(LogType::LOG_APP, "TDLib send: %{public}s", method.c_str());
    }

    td_send(client_id, request.c_str());

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value Receive(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    // Strict validation: 1 arg (number)
    if (!napi_check_argc(env, "receive", argc, 1)) return nullptr;
    if (!napi_check_type(env, "receive", argv[0], napi_number, "timeoutSeconds")) return nullptr;

    double timeout;
    napi_get_value_double(env, argv[0], &timeout);

    const char* response = td_receive(timeout);

    napi_value result;
    if (response != nullptr) {
        napi_create_string_utf8(env, response, NAPI_AUTO_LENGTH, &result);
    } else {
        napi_get_null(env, &result);
    }
    return result;
}

napi_value Execute(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    // Strict validation: 1 arg (string)
    if (!napi_check_argc(env, "execute", argc, 1)) return nullptr;
    if (!napi_check_type(env, "execute", argv[0], napi_string, "requestJson")) return nullptr;

    size_t str_len;
    napi_get_value_string_utf8(env, argv[0], nullptr, 0, &str_len);
    std::string request(str_len, '\0');
    napi_get_value_string_utf8(env, argv[0], &request[0], str_len + 1, &str_len);

    const char* response = td_execute(request.c_str());

    napi_value result;
    if (response != nullptr) {
        napi_create_string_utf8(env, response, NAPI_AUTO_LENGTH, &result);
    } else {
        napi_get_null(env, &result);
    }
    return result;
}

// Called from the receive thread to forward response to ArkTS
static void CallJs(napi_env env, napi_value js_callback, void* context, void* data) {
    if (env == nullptr || data == nullptr) return;

    std::string* response = static_cast<std::string*>(data);
    napi_value argv[1];
    napi_create_string_utf8(env, response->c_str(), response->length(), &argv[0]);

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    napi_call_function(env, undefined, js_callback, 1, argv, nullptr);

    delete response;
}

napi_value StartReceiveLoop(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    // Strict validation: 1 arg (function)
    if (!napi_check_argc(env, "startReceiveLoop", argc, 1)) return nullptr;
    if (!napi_check_type(env, "startReceiveLoop", argv[0], napi_function, "callback")) return nullptr;

    std::lock_guard<std::mutex> guard(loop_mutex);

    // Prevent double-start
    LoopState expected = LoopState::Stopped;
    if (!loop_state.compare_exchange_strong(expected, LoopState::Starting)) {
        OH_LOG_WARN(LogType::LOG_APP, "StartReceiveLoop called while state=%d, ignoring",
                    static_cast<int>(loop_state.load()));
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        return undefined;
    }

    // Join previous thread if still joinable (defensive)
    if (receive_thread.joinable()) {
        receive_thread.join();
    }

    napi_value resource_name;
    napi_create_string_utf8(env, "TDLibReceiveLoop", NAPI_AUTO_LENGTH, &resource_name);

    napi_create_threadsafe_function(
        env, argv[0], nullptr, resource_name,
        0, 1, nullptr, nullptr, nullptr,
        CallJs, &threadsafe_callback
    );

    loop_state = LoopState::Running;

    receive_thread = std::thread([]() {
        OH_LOG_INFO(LogType::LOG_APP, "TDLib receive loop started");

        while (loop_state == LoopState::Running) {
            const char* response = td_receive(1.0);
            if (response != nullptr) {
                auto* data = new std::string(response);
                napi_call_threadsafe_function(threadsafe_callback, data, napi_tsfn_blocking);
            }
        }
        OH_LOG_INFO(LogType::LOG_APP, "TDLib receive loop stopped");
        if (threadsafe_callback != nullptr) {
            napi_release_threadsafe_function(threadsafe_callback, napi_tsfn_release);
            threadsafe_callback = nullptr;
        }
        loop_state = LoopState::Stopped;
    });

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value StopReceiveLoop(napi_env env, napi_callback_info info) {
    std::lock_guard<std::mutex> guard(loop_mutex);

    LoopState current = loop_state.load();
    if (current != LoopState::Running) {
        OH_LOG_WARN(LogType::LOG_APP, "StopReceiveLoop called while state=%d, ignoring",
                    static_cast<int>(current));
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        return undefined;
    }

    loop_state = LoopState::Stopping;
    OH_LOG_INFO(LogType::LOG_APP, "TDLib receive loop stop requested");

    // Join the receive thread to ensure clean shutdown
    if (receive_thread.joinable()) {
        receive_thread.join();
    }

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value GetTdlibInfo(napi_env env, napi_callback_info info) {
    const char* tdlib_dir = XSTR(TDLIB_DIR_PATH);
    const char* soname = XSTR(TDLIB_SONAME);

    std::string json = "{\"mode\":\"REAL\",\"tdlibDir\":\"" + json_escape(tdlib_dir) +
                       "\",\"soname\":\"" + json_escape(soname) + "\"}";

    OH_LOG_INFO(LogType::LOG_APP,
        "┌─ TDLib Runtime Info ─────────────────────────");
    OH_LOG_INFO(LogType::LOG_APP,
        "│ MODE:      REAL");
    OH_LOG_INFO(LogType::LOG_APP,
        "│ TDLIB_DIR: %{public}s", tdlib_dir);
    OH_LOG_INFO(LogType::LOG_APP,
        "│ SONAME:    %{public}s", soname);
    OH_LOG_INFO(LogType::LOG_APP,
        "└──────────────────────────────────────────────");

    napi_value result;
    napi_create_string_utf8(env, json.c_str(), json.length(), &result);
    return result;
}

} // namespace tdlib_napi
