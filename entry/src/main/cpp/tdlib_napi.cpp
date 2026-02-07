#include "tdlib_napi.h"
#include <string>
#include <thread>
#include <atomic>
#include <hilog/log.h>

#ifndef TDLIB_STUB
#include <td/telegram/td_json_client.h>
#else
// Stub implementations for development without TDLib binary
static int stub_client_id = 0;
#endif

#define LOG_TAG "TDLibNAPI"
#define LOG_DOMAIN 0x0001

static std::atomic<bool> receive_loop_running{false};
static napi_threadsafe_function threadsafe_callback = nullptr;

#ifdef TDLIB_STUB
static const char* stub_receive() {
    return nullptr;
}
#endif

namespace tdlib_napi {

napi_value CreateClient(napi_env env, napi_callback_info info) {
    int client_id;
#ifndef TDLIB_STUB
    client_id = td_create_client_id();
#else
    client_id = ++stub_client_id;
#endif
    OH_LOG_INFO(LogType::LOG_APP, "TDLib client created: %{public}d", client_id);

    napi_value result;
    napi_create_int32(env, client_id, &result);
    return result;
}

napi_value Send(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value argv[2];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    // Get client_id
    int32_t client_id;
    napi_get_value_int32(env, argv[0], &client_id);

    // Get JSON request string
    size_t str_len;
    napi_get_value_string_utf8(env, argv[1], nullptr, 0, &str_len);
    std::string request(str_len, '\0');
    napi_get_value_string_utf8(env, argv[1], &request[0], str_len + 1, &str_len);

    OH_LOG_INFO(LogType::LOG_APP, "TDLib send: %{public}s", request.c_str());

#ifndef TDLIB_STUB
    td_send(client_id, request.c_str());
#endif

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value Receive(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    double timeout;
    napi_get_value_double(env, argv[0], &timeout);

    const char* response = nullptr;
#ifndef TDLIB_STUB
    response = td_receive(timeout);
#else
    response = stub_receive();
#endif

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

    size_t str_len;
    napi_get_value_string_utf8(env, argv[0], nullptr, 0, &str_len);
    std::string request(str_len, '\0');
    napi_get_value_string_utf8(env, argv[0], &request[0], str_len + 1, &str_len);

    const char* response = nullptr;
#ifndef TDLIB_STUB
    response = td_execute(request.c_str());
#endif

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

    napi_value resource_name;
    napi_create_string_utf8(env, "TDLibReceiveLoop", NAPI_AUTO_LENGTH, &resource_name);

    napi_create_threadsafe_function(
        env, argv[0], nullptr, resource_name,
        0, 1, nullptr, nullptr, nullptr,
        CallJs, &threadsafe_callback
    );

    receive_loop_running = true;

    std::thread([]() {
        OH_LOG_INFO(LogType::LOG_APP, "TDLib receive loop started");
        while (receive_loop_running) {
#ifndef TDLIB_STUB
            const char* response = td_receive(1.0);
            if (response != nullptr) {
                auto* data = new std::string(response);
                napi_call_threadsafe_function(threadsafe_callback, data, napi_tsfn_blocking);
            }
#else
            std::this_thread::sleep_for(std::chrono::seconds(1));
#endif
        }
        OH_LOG_INFO(LogType::LOG_APP, "TDLib receive loop stopped");
        napi_release_threadsafe_function(threadsafe_callback, napi_tsfn_release);
        threadsafe_callback = nullptr;
    }).detach();

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value StopReceiveLoop(napi_env env, napi_callback_info info) {
    receive_loop_running = false;
    OH_LOG_INFO(LogType::LOG_APP, "TDLib receive loop stop requested");

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

} // namespace tdlib_napi
