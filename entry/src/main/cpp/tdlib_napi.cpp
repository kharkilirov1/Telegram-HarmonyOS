#include "tdlib_napi.h"
#include <string>
#include <vector>
#include <deque>
#include <chrono>
#include <thread>
#include <atomic>
#include <mutex>
#include <memory>
#include <new>
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
// Huawei Best Practice: использовать atomic для thread-safe доступа
enum class LoopState { Stopped, Starting, Running, Stopping };
static std::atomic<LoopState> loop_state{LoopState::Stopped};
static std::thread receive_thread;
static std::mutex loop_mutex;
// The joining worker owns the moved thread. Only its main-thread completion may
// publish Stopped; a receive worker that merely exited is still joinable.
struct StopWork {
    napi_async_work work = nullptr;
    std::thread thread;
    std::vector<napi_deferred> waiters;
    bool joined = false;
};
static StopWork* pending_stop = nullptr;
static napi_env receive_env = nullptr;

// Thread-safe callback wrapper с mutex защитой
// napi_threadsafe_function не может быть atomic, поэтому используем отдельный mutex
static napi_threadsafe_function threadsafe_callback = nullptr;
static std::mutex callback_mutex;  // Защита для threadsafe_callback

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

// Huawei Best Practice: constexpr для compile-time bounds check
static constexpr const char* type_names[] = {
    "undefined", "null", "boolean", "number", "string", "symbol", "object", "function", "external", "bigint"
};
static constexpr size_t TYPE_NAMES_COUNT = sizeof(type_names) / sizeof(type_names[0]);

static bool napi_check_type(napi_env env, const char* func, napi_value val,
                            napi_valuetype expected, const char* argName) {
    napi_valuetype actual;
    napi_typeof(env, val, &actual);
    if (actual != expected) {
        // Bounds check для будущих версий NAPI
        const char* actual_name = (static_cast<size_t>(actual) < TYPE_NAMES_COUNT)
            ? type_names[actual] : "unknown";
        const char* expected_name = (static_cast<size_t>(expected) < TYPE_NAMES_COUNT)
            ? type_names[expected] : "unknown";
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

// Batching constants
static constexpr size_t BATCH_MAX_SIZE = 50;       // Max responses per batch
static constexpr double RECEIVE_TIMEOUT = 0.05;    // 50ms — short poll for batching
static constexpr auto NOTIFY_RETRY_DELAY = std::chrono::milliseconds(50);

// Payload ownership is independent of N-API's enqueue result. In particular,
// non-ok does not universally guarantee that a notification was not inserted.
struct ReceiveDelivery {
    std::mutex mutex;
    std::deque<std::string> batches;
};
using DeliveryOwner = std::shared_ptr<ReceiveDelivery>;

static void FinalizeDelivery(napi_env, void* data, void*) {
    delete static_cast<DeliveryOwner*>(data);
}

// TSFN carries only nullptr wakeups. A finalizer can precede null-env cleanup
// callbacks: never dereference their context, which may already be destroyed.
static void CallJs(napi_env env, napi_value js_callback, void* context, void*) {
    if (env == nullptr || js_callback == nullptr || context == nullptr) return;
    DeliveryOwner delivery = *static_cast<DeliveryOwner*>(context);
    if (!delivery) return;
    std::string batch;
    {
        std::lock_guard<std::mutex> guard(delivery->mutex);
        if (delivery->batches.empty()) return; // Duplicate/retried wakeup.
        batch = std::move(delivery->batches.front());
        delivery->batches.pop_front();
    }
    // One wakeup consumes at most one batch; do not drain an unbounded queue on
    // ArkTS. Hold the local owner across JS reentry, but never its queue mutex.

    napi_value argv[1];
    if (napi_create_string_utf8(env, batch.c_str(), batch.length(), &argv[0]) != napi_ok) {
        OH_LOG_ERROR(LogType::LOG_APP, "TDLib callback string creation failed");
        return;
    }

    napi_value undefined;
    if (napi_get_undefined(env, &undefined) != napi_ok) {
        OH_LOG_ERROR(LogType::LOG_APP, "TDLib callback receiver creation failed");
        return;
    }
    if (napi_call_function(env, undefined, js_callback, 1, argv, nullptr) != napi_ok) {
        // Preserve any pending JS exception; do not retry a partly handled batch.
        OH_LOG_ERROR(LogType::LOG_APP, "TDLib callback invocation failed");
    }
}

static bool NotifyReceiveBatch() {
    bool warned = false;
    while (loop_state == LoopState::Running) {
        napi_status status;
        {
            std::lock_guard<std::mutex> guard(callback_mutex);
            if (threadsafe_callback == nullptr) return false;
            status = napi_call_threadsafe_function(threadsafe_callback, nullptr, napi_tsfn_nonblocking);
            if (status == napi_closing || status == napi_invalid_arg) {
                // Closing can consume the producer lease. Do not access this
                // opaque handle again, including an extra terminal release.
                threadsafe_callback = nullptr;
                loop_state = LoopState::Stopping;
                OH_LOG_WARN(LogType::LOG_APP, "TDLib receive notification is closing");
                return false;
            }
        }
        if (status == napi_ok) return true;
        if (!warned) {
            OH_LOG_WARN(LogType::LOG_APP, "TDLib receive notification failed; retaining batch and retrying wakeup");
            warned = true;
        }
        // No read-ahead while delivery is stalled. Retrying nullptr is safe
        // whether a failed call inserted a wakeup or not; payloads are not replayed.
        std::this_thread::sleep_for(NOTIFY_RETRY_DELAY);
    }
    return false;
}

napi_value StartReceiveLoop(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    // Strict validation: 1 arg (function)
    if (!napi_check_argc(env, "startReceiveLoop", argc, 1)) return nullptr;
    if (!napi_check_type(env, "startReceiveLoop", argv[0], napi_function, "callback")) return nullptr;

    std::lock_guard<std::mutex> guard(loop_mutex);

    // Never join on the ArkTS thread or let a new gateway bypass a stop barrier.
    if (loop_state == LoopState::Stopping || pending_stop != nullptr ||
        (receive_env != nullptr && receive_env != env) ||
        (loop_state == LoopState::Stopped && receive_thread.joinable())) {
        napi_throw_error(env, "ERR_TDLIB_RECEIVE_BUSY", "TDLib receive loop has not completed its stop barrier");
        return nullptr;
    }
    // Preserve idempotent start for the current owner only.
    LoopState expected = LoopState::Stopped;
    if (!loop_state.compare_exchange_strong(expected, LoopState::Starting)) {
        OH_LOG_WARN(LogType::LOG_APP, "StartReceiveLoop called while state=%d, ignoring",
                    static_cast<int>(loop_state.load()));
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        return undefined;
    }

    napi_value resource_name;
    if (napi_create_string_utf8(env, "TDLibReceiveLoop", NAPI_AUTO_LENGTH, &resource_name) != napi_ok) {
        loop_state = LoopState::Stopped;
        napi_throw_error(env, "ERR_TDLIB_RECEIVE_START", "Cannot create TDLib receive resource name");
        return nullptr;
    }

    DeliveryOwner delivery;
    std::unique_ptr<DeliveryOwner> context;
    try {
        delivery = std::make_shared<ReceiveDelivery>();
        context = std::make_unique<DeliveryOwner>(delivery);
    } catch (...) {
        loop_state = LoopState::Stopped;
        napi_throw_error(env, "ERR_TDLIB_RECEIVE_START", "Cannot allocate TDLib receive delivery queue");
        return nullptr;
    }

    // Thread-safe создание callback с mutex защитой
    napi_status callback_status;
    {
        std::lock_guard<std::mutex> cb_guard(callback_mutex);
        callback_status = napi_create_threadsafe_function(
            env, argv[0], nullptr, resource_name,
            0, 1, context.get(), FinalizeDelivery, context.get(),
            CallJs, &threadsafe_callback
        );
        if (callback_status != napi_ok) {
            threadsafe_callback = nullptr;
        }
    }
    if (callback_status != napi_ok) {
        loop_state = LoopState::Stopped;
        napi_throw_error(env, "ERR_TDLIB_RECEIVE_START", "Cannot create TDLib receive callback");
        return nullptr;
    }
    context.release(); // The TSFN finalizer owns this shared-pointer holder.

    loop_state = LoopState::Running;
    receive_env = env;

    try {
        receive_thread = std::thread([delivery]() {
        OH_LOG_INFO(LogType::LOG_APP, "TDLib receive loop started (batched, max=%{public}zu)", BATCH_MAX_SIZE);

        try {
        while (loop_state == LoopState::Running) {
            // Phase 1: blocking wait for first response (up to 1s)
            const char* first = td_receive(1.0);
            if (first == nullptr) continue;

            // Phase 2: drain available responses with short timeout
            std::string batch = "[";
            batch += first;
            size_t count = 1;

            while (count < BATCH_MAX_SIZE && loop_state == LoopState::Running) {
                const char* next = td_receive(RECEIVE_TIMEOUT);
                if (next == nullptr) break;
                batch += ',';
                batch += next;
                count++;
            }
            batch += ']';

            // Store payload before notifying. No owning pointer crosses TSFN;
            // producer and finalizer independently hold this loop's queue alive.
            {
                std::lock_guard<std::mutex> guard(delivery->mutex);
                delivery->batches.push_back(std::move(batch));
            }
            if (!NotifyReceiveBatch()) break;

            if (count > 1) {
                OH_LOG_INFO(LogType::LOG_APP, "TDLib batch queued: %{public}zu responses", count);
            }
        }
        } catch (...) {
            loop_state = LoopState::Stopping;
            OH_LOG_ERROR(LogType::LOG_APP, "TDLib receive delivery allocation failed");
        }
        OH_LOG_INFO(LogType::LOG_APP, "TDLib receive loop stopped");
        // Thread-safe cleanup с mutex защитой
        {
            std::lock_guard<std::mutex> cb_guard(callback_mutex);
            if (threadsafe_callback != nullptr) {
                napi_release_threadsafe_function(threadsafe_callback, napi_tsfn_release);
                threadsafe_callback = nullptr;
            }
        }
        });
    } catch (...) {
        // std::thread construction can fail before a producer exists. Do not
        // leak its sole TSFN lease or let a C++ exception cross the N-API entry.
        std::lock_guard<std::mutex> cb_guard(callback_mutex);
        napi_release_threadsafe_function(threadsafe_callback, napi_tsfn_release);
        threadsafe_callback = nullptr;
        receive_env = nullptr;
        loop_state = LoopState::Stopped;
        napi_throw_error(env, "ERR_TDLIB_RECEIVE_START", "Cannot start TDLib receive thread");
        return nullptr;
    }

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

static void RejectStop(napi_env env, napi_deferred deferred, const char* message) {
    napi_value text = nullptr;
    napi_value error = nullptr;
    if (napi_create_string_utf8(env, message, NAPI_AUTO_LENGTH, &text) != napi_ok ||
        napi_create_error(env, nullptr, text, &error) != napi_ok) {
        if (napi_get_undefined(env, &error) != napi_ok) {
            OH_LOG_ERROR(LogType::LOG_APP, "Cannot construct TDLib stop rejection");
            return;
        }
    }
    if (napi_reject_deferred(env, deferred, error) != napi_ok) {
        OH_LOG_ERROR(LogType::LOG_APP, "Cannot reject TDLib stop Promise");
    }
}

static void ResolveStop(napi_env env, napi_deferred deferred) {
    napi_value undefined = nullptr;
    if (napi_get_undefined(env, &undefined) != napi_ok) {
        RejectStop(env, deferred, "Cannot create TDLib stop result");
        return;
    }
    if (napi_resolve_deferred(env, deferred, undefined) != napi_ok) {
        OH_LOG_ERROR(LogType::LOG_APP, "Cannot resolve TDLib stop Promise");
    }
}

static void ExecuteStop(napi_env, void* data) {
    auto* stop = static_cast<StopWork*>(data);
    // No loop mutex or N-API on the joining thread. A concurrent stop remains
    // cheap on ArkTS and appends a waiter to this same work item.
    try {
        if (stop->thread.joinable()) stop->thread.join();
        stop->joined = true;
    } catch (...) {
        // Completion restores ownership so a failed join can be retried.
    }
}

static void CompleteStop(napi_env env, napi_status status, void* data) {
    std::unique_ptr<StopWork> stop(static_cast<StopWork*>(data));
    {
        std::lock_guard<std::mutex> lock(loop_mutex);
        pending_stop = nullptr;
        if (stop->joined) {
            loop_state = LoopState::Stopped;
            receive_env = nullptr;
        } else {
            // Cancellation can skip ExecuteStop entirely. Destroying a joinable
            // std::thread would terminate the process; keep it for another stop.
            receive_thread = std::move(stop->thread);
        }
    }
    for (auto deferred : stop->waiters) {
        if (status == napi_ok && stop->joined) ResolveStop(env, deferred);
        else RejectStop(env, deferred, "TDLib receive stop did not complete; retry stop before start");
    }
    if (napi_delete_async_work(env, stop->work) != napi_ok) {
        OH_LOG_ERROR(LogType::LOG_APP, "Cannot delete TDLib stop async work");
    }
}

napi_value StopReceiveLoop(napi_env env, napi_callback_info) {
    std::lock_guard<std::mutex> lock(loop_mutex);
    if (receive_env != nullptr && receive_env != env) {
        napi_throw_error(env, "ERR_TDLIB_RECEIVE_BUSY", "TDLib receive loop belongs to another environment");
        return nullptr;
    }
    napi_deferred deferred = nullptr;
    napi_value promise = nullptr;
    if (napi_create_promise(env, &deferred, &promise) != napi_ok) {
        napi_throw_error(env, "ERR_TDLIB_RECEIVE_STOP", "Cannot create TDLib stop Promise");
        return nullptr;
    }
    if (pending_stop != nullptr) {
        try { pending_stop->waiters.push_back(deferred); }
        catch (...) { RejectStop(env, deferred, "Cannot register TDLib stop waiter"); }
        return promise;
    }
    if (loop_state == LoopState::Stopped && !receive_thread.joinable()) {
        ResolveStop(env, deferred);
        return promise;
    }
    std::unique_ptr<StopWork> stop(new (std::nothrow) StopWork());
    if (!stop) {
        RejectStop(env, deferred, "Cannot allocate TDLib stop work");
        return promise;
    }
    try { stop->waiters.push_back(deferred); }
    catch (...) {
        RejectStop(env, deferred, "Cannot register TDLib stop waiter");
        return promise;
    }
    napi_value resource = nullptr;
    if (napi_create_string_utf8(env, "TDLibReceiveStop", NAPI_AUTO_LENGTH, &resource) != napi_ok ||
        napi_create_async_work(env, nullptr, resource, ExecuteStop, CompleteStop, stop.get(), &stop->work) != napi_ok) {
        RejectStop(env, deferred, "Cannot create TDLib stop work");
        return promise;
    }
    loop_state = LoopState::Stopping;
    stop->thread = std::move(receive_thread);
    pending_stop = stop.get();
    if (napi_queue_async_work(env, stop->work) != napi_ok) {
        receive_thread = std::move(stop->thread);
        pending_stop = nullptr;
        // The producer may already have observed Stopping: never restore Running.
        napi_delete_async_work(env, stop->work);
        RejectStop(env, deferred, "Cannot queue TDLib stop work; retry stop before start");
        return promise;
    }
    stop.release(); // CompleteStop owns it from now on.
    return promise;
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
