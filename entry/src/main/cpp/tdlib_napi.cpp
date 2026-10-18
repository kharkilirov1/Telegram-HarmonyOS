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
#include <condition_variable>
#include <algorithm>
#include <cmath>
#include <uv.h>
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

// Receive contract: mirrored by ReceiveDeliveryProtocol.ets and the public d.ts.
static constexpr size_t MAX_BATCH_RESPONSES = 50;
static constexpr size_t TARGET_BATCH_BYTES = 256 * 1024;
static constexpr size_t MAX_BATCH_BYTES = 8 * 1024 * 1024;
static constexpr size_t MAX_RESPONSE_BYTES = MAX_BATCH_BYTES - 2;
static constexpr size_t MAX_OUTSTANDING_BATCHES = 4;
static constexpr size_t MAX_OUTSTANDING_BYTES = 16 * 1024 * 1024;
static constexpr uint64_t MAX_SAFE_ID = 9007199254740991ULL;
static constexpr unsigned MAX_MARSHAL_ATTEMPTS = 3;
static constexpr auto RETRY_DELAY = std::chrono::milliseconds(50);
enum ReceiveStatus { Stopped = 0, Running = 1, Stopping = 2, Oversize = 100,
    Allocation = 101, Marshalling = 102, Notification = 103, Admission = 104,
    JsInvocation = 105, Protocol = 106, Environment = 107 };

struct ReceiveStats {
    uint64_t epoch = 0;
    int status = Stopped;
    size_t outstandingBatches = 0, outstandingBytes = 0;
    size_t nativeQueuedBatches = 0, nativeQueuedBytes = 0;
    size_t admittedBatches = 0, admittedBytes = 0;
    size_t builderBytes = 0, lookaheadBytes = 0, pendingNotifications = 0;
    size_t peakOutstandingBatches = 0, peakOutstandingBytes = 0;
    size_t peakBuilderBytes = 0, peakLookaheadBytes = 0, peakPendingNotifications = 0;
    size_t marshalRetries = 0, notifyRetries = 0;
    bool producerExited = false, producerJoined = false, tsfnFinalized = false;
};
struct ReceiveBatch {
    uint64_t id;
    std::string json;
    size_t bytes;
    bool admitted = false;
    unsigned marshalAttempts = 0;
};
struct ReceiveOwner {
    napi_env env = nullptr;
    std::mutex mutex;
    std::condition_variable changed;
    std::deque<std::shared_ptr<ReceiveBatch>> ledger;
    ReceiveStats stats;
    uint64_t nextBatch = 1;
    bool stop = false, cleanup = false, controlPending = false, finished = false;
    bool wake = false, submitting = false;
    std::chrono::steady_clock::time_point retryAt{};
    napi_threadsafe_function callback = nullptr;
    napi_async_cleanup_hook_handle cleanupHook = nullptr;
    uv_loop_t* loop = nullptr;
    uv_work_t joinWork{};
    std::thread producer;
    std::vector<napi_deferred> waiters;
};
using DeliveryOwner = std::shared_ptr<ReceiveOwner>;
static std::mutex owner_mutex;
static DeliveryOwner active_owner;
static ReceiveStats retired_stats;
static uint64_t next_epoch = 1;
// The JSON C pointer is copied before any exported execute can invalidate it.
static std::mutex td_json_mutex;

static DeliveryOwner CurrentOwner() {
    std::lock_guard<std::mutex> lock(owner_mutex);
    return active_owner;
}
static void CancelLocked(ReceiveOwner& o) {
    o.ledger.clear();
    o.stats.outstandingBatches = o.stats.outstandingBytes = 0;
    o.stats.nativeQueuedBatches = o.stats.nativeQueuedBytes = 0;
    o.stats.admittedBatches = o.stats.admittedBytes = 0;
}
static void FaultLocked(ReceiveOwner& o, int code) {
    if (o.stats.status < Oversize) o.stats.status = code;
    o.stop = true;
    CancelLocked(o);
    o.changed.notify_all();
}
static void Fault(const DeliveryOwner& o, int code) {
    std::lock_guard<std::mutex> lock(o->mutex);
    FaultLocked(*o, code);
}
static void RequestStop(const DeliveryOwner& o) {
    std::lock_guard<std::mutex> lock(o->mutex);
    o->stop = true;
    if (o->stats.status < Oversize) o->stats.status = Stopping;
    CancelLocked(*o);
    o->changed.notify_all();
}
static void RejectStop(napi_env env, napi_deferred deferred, const char* message) {
    napi_value text = nullptr, error = nullptr;
    if (napi_create_string_utf8(env, message, NAPI_AUTO_LENGTH, &text) != napi_ok ||
        napi_create_error(env, nullptr, text, &error) != napi_ok) return;
    napi_reject_deferred(env, deferred, error);
}
static void ResolveStop(napi_env env, napi_deferred deferred) {
    napi_value value = nullptr;
    if (napi_get_undefined(env, &value) == napi_ok) napi_resolve_deferred(env, deferred, value);
}
static void TryFinish(const DeliveryOwner& o) {
    // Owner-thread only. Neither join nor finalizer alone retires this epoch.
    {
        std::lock_guard<std::mutex> lock(o->mutex);
        if (o->finished || !o->stats.producerJoined || !o->stats.tsfnFinalized || o->controlPending || o->submitting) return;
        o->finished = true;
    }
    {
        std::lock_guard<std::mutex> lock(o->mutex);
        CancelLocked(*o);
        o->stats.builderBytes = o->stats.lookaheadBytes = o->stats.pendingNotifications = 0;
        if (o->stats.status < Oversize) o->stats.status = Stopped;
    }
    const auto hook = o->cleanupHook;
    o->cleanupHook = nullptr;
    if (hook && napi_remove_async_cleanup_hook(hook) != napi_ok) {
        // Failed completion is not a safe env retirement. Keep the owner pinned.
        o->finished = false;
        o->cleanupHook = hook;
        Fault(o, Environment);
        return;
    }
    {
        std::lock_guard<std::mutex> lock(owner_mutex);
        retired_stats = o->stats;
        if (active_owner == o) active_owner.reset();
    }
    if (!o->cleanup) {
        for (auto waiter : o->waiters) ResolveStop(o->env, waiter);
    }
    o->waiters.clear();
}
static void JoinProducer(uv_work_t* work) {
    auto* o = static_cast<ReceiveOwner*>(work->data);
    try {
        if (o->producer.joinable()) o->producer.join();
        std::lock_guard<std::mutex> lock(o->mutex);
        o->stats.producerJoined = true;
    } catch (...) { /* Retain owner/barrier; completion reports failure. */ }
}
static void JoinComplete(uv_work_t* work, int status) {
    auto o = CurrentOwner();
    if (!o || o.get() != work->data) return;
    o->controlPending = false;
    if (status != 0 || !o->stats.producerJoined) {
        Fault(o, Environment);
        if (!o->cleanup) {
            for (auto waiter : o->waiters) RejectStop(o->env, waiter, "TDLib receive stop is incomplete; retry stop");
            o->waiters.clear();
        }
        return;
    }
    TryFinish(o);
}
static bool QueueJoin(const DeliveryOwner& o) {
    if (o->controlPending || o->stats.producerJoined) return true;
    o->joinWork.data = o.get();
    o->controlPending = true;
    if (uv_queue_work(o->loop, &o->joinWork, JoinProducer, JoinComplete) != 0) {
        o->controlPending = false;
        Fault(o, Environment);
        return false;
    }
    return true;
}
static void CleanupReceive(napi_async_cleanup_hook_handle, void* data) {
    auto o = CurrentOwner();
    if (!o || o.get() != data) return;
    o->cleanup = true;
    RequestStop(o);
    // Never join, settle promises, or remove an incomplete barrier in this hook.
    if (QueueJoin(o)) TryFinish(o);
}
static void FinalizeDelivery(napi_env env, void* data, void*) {
    std::unique_ptr<DeliveryOwner> holder(static_cast<DeliveryOwner*>(data));
    auto o = *holder;
    if (env == nullptr) o->cleanup = true;
    {
        std::lock_guard<std::mutex> lock(o->mutex);
        o->callback = nullptr;
        o->stats.tsfnFinalized = true;
        o->stats.pendingNotifications = 0;
        o->wake = false;
        if (!o->stop) FaultLocked(*o, Environment);
    }
    TryFinish(o);
}
static void RetireWake(const DeliveryOwner& o) {
    std::lock_guard<std::mutex> lock(o->mutex);
    o->wake = false;
    o->stats.pendingNotifications = 0;
    o->changed.notify_all();
}
static void CallJs(napi_env env, napi_value js_callback, void* context, void*) {
    // Null-env callbacks may run after finalizer destroyed the holder.
    if (env == nullptr || js_callback == nullptr || context == nullptr) return;
    auto o = *static_cast<DeliveryOwner*>(context);
    std::shared_ptr<ReceiveBatch> batch;
    {
        std::lock_guard<std::mutex> lock(o->mutex);
        if (!o->stop) {
            for (const auto& item : o->ledger) if (!item->admitted) { batch = item; break; }
        }
        if (batch) ++batch->marshalAttempts;
    }
    if (!batch) { RetireWake(o); return; }
    napi_value argv[4]{}, receiver = nullptr, result = nullptr;
    bool marshalled = napi_create_string_utf8(env, batch->json.data(), batch->bytes, &argv[0]) == napi_ok &&
        napi_create_double(env, static_cast<double>(o->stats.epoch), &argv[1]) == napi_ok &&
        napi_create_double(env, static_cast<double>(batch->id), &argv[2]) == napi_ok &&
        napi_create_double(env, static_cast<double>(batch->bytes), &argv[3]) == napi_ok &&
        napi_get_undefined(env, &receiver) == napi_ok;
    if (!marshalled) {
        bool pending = true;
        const auto checked = napi_is_exception_pending(env, &pending);
        std::lock_guard<std::mutex> lock(o->mutex);
        if (!o->stop) {
            if (checked != napi_ok || pending || batch->marshalAttempts >= MAX_MARSHAL_ATTEMPTS) {
                FaultLocked(*o, Marshalling);
            } else {
                ++o->stats.marshalRetries;
                o->retryAt = std::chrono::steady_clock::now() + RETRY_DELAY;
            }
        }
        o->wake = false;
        o->stats.pendingNotifications = 0;
        o->changed.notify_all();
        return;
    }
    // Admission may reenter stop. No native mutex is held across arbitrary JS.
    const auto call = napi_call_function(env, receiver, js_callback, 4, argv, &result);
    bool accepted = false;
    const bool valid = call == napi_ok && napi_get_value_bool(env, result, &accepted) == napi_ok;
    {
        std::lock_guard<std::mutex> lock(o->mutex);
        if (!o->stop) {
            if (call != napi_ok) FaultLocked(*o, JsInvocation);
            else if (!valid || !accepted) FaultLocked(*o, Admission);
            else {
                batch->admitted = true;
                std::string().swap(batch->json);
                --o->stats.nativeQueuedBatches;
                o->stats.nativeQueuedBytes -= batch->bytes;
                ++o->stats.admittedBatches;
                o->stats.admittedBytes += batch->bytes;
            }
        }
    }
    RetireWake(o);
}
static void Notify(const DeliveryOwner& o) {
    napi_threadsafe_function callback;
    {
        std::lock_guard<std::mutex> lock(o->mutex);
        if (o->stop || o->wake || o->stats.nativeQueuedBatches == 0 ||
            std::chrono::steady_clock::now() < o->retryAt) return;
        callback = o->callback;
        if (!callback) { FaultLocked(*o, Environment); return; }
        // Admission lease: closing forbids new admissions. A call admitted here
        // may enter/return after close is requested; producer join and the explicit
        // submitting gate prevent completion/control release until it retires.
        o->wake = o->submitting = true;
        o->stats.pendingNotifications = 1;
        o->stats.peakPendingNotifications = std::max(o->stats.peakPendingNotifications, size_t(1));
    }
    const auto status = napi_call_threadsafe_function(callback, nullptr, napi_tsfn_nonblocking);
    std::lock_guard<std::mutex> lock(o->mutex);
    o->submitting = false;
    if (status == napi_queue_full) {
        // Known no-insertion result: pace the same wake, without reading ahead.
        o->wake = false;
        o->stats.pendingNotifications = 0;
        ++o->stats.notifyRetries;
        o->retryAt = std::chrono::steady_clock::now() + RETRY_DELAY;
    } else if (status != napi_ok) {
        if (status == napi_closing || status == napi_invalid_arg) o->callback = nullptr;
        // Ambiguous insertion is terminal. Never accumulate uncertain wakeups.
        FaultLocked(*o, Notification);
    }
}
static bool WaitCapacity(const DeliveryOwner& o, size_t bytes) {
    for (;;) {
        Notify(o);
        std::unique_lock<std::mutex> lock(o->mutex);
        if (o->stop) return false;
        if (o->stats.outstandingBatches < MAX_OUTSTANDING_BATCHES &&
            bytes <= MAX_OUTSTANDING_BYTES - o->stats.outstandingBytes &&
            std::chrono::steady_clock::now() >= o->retryAt) return true;
        o->changed.wait_for(lock, RETRY_DELAY);
    }
}
static bool CopyResponse(const DeliveryOwner& o, double timeout, std::string& response) {
    std::lock_guard<std::mutex> jsonLock(td_json_mutex);
    const char* raw = td_receive(timeout);
    if (!raw) return false;
    size_t bytes = 0;
    while (bytes <= MAX_RESPONSE_BYTES && raw[bytes] != '\0') ++bytes;
    if (bytes > MAX_RESPONSE_BYTES) { Fault(o, Oversize); return false; }
    response.assign(raw, bytes);
    {
        std::lock_guard<std::mutex> lock(o->mutex);
        o->stats.lookaheadBytes = bytes;
        o->stats.peakLookaheadBytes = std::max(o->stats.peakLookaheadBytes, bytes);
    }
    return true;
}
static void ReceiveProducer(const DeliveryOwner& o) {
    try {
        std::string staging;
        while (WaitCapacity(o, 2)) {
            if (staging.empty() && !CopyResponse(o, 0.05, staging)) continue;
            std::string builder("[");
            size_t count = 0;
            for (;;) {
                if (count) builder += ',';
                builder += staging;
                std::string().swap(staging);
                ++count;
                {
                    std::lock_guard<std::mutex> lock(o->mutex);
                    o->stats.lookaheadBytes = 0;
                    o->stats.builderBytes = builder.size() + 1;
                    o->stats.peakBuilderBytes = std::max(o->stats.peakBuilderBytes, builder.size() + 1);
                    if (o->stop) break;
                }
                if (count == MAX_BATCH_RESPONSES || builder.size() + 1 >= TARGET_BATCH_BYTES ||
                    !CopyResponse(o, 0.05, staging)) break;
                if (staging.size() + 2 > TARGET_BATCH_BYTES - builder.size()) break;
            }
            builder += ']';
            if (!WaitCapacity(o, builder.size())) break;
            auto batch = std::make_shared<ReceiveBatch>();
            batch->json = std::move(builder);
            batch->bytes = batch->json.size();
            {
                std::lock_guard<std::mutex> lock(o->mutex);
                if (o->stop) break;
                if (o->nextBatch > MAX_SAFE_ID) { FaultLocked(*o, Protocol); break; }
                batch->id = o->nextBatch++;
                o->ledger.push_back(batch);
                ++o->stats.outstandingBatches; o->stats.outstandingBytes += batch->bytes;
                ++o->stats.nativeQueuedBatches; o->stats.nativeQueuedBytes += batch->bytes;
                o->stats.builderBytes = 0;
                o->stats.peakOutstandingBatches = std::max(o->stats.peakOutstandingBatches, o->stats.outstandingBatches);
                o->stats.peakOutstandingBytes = std::max(o->stats.peakOutstandingBytes, o->stats.outstandingBytes);
            }
            Notify(o);
        }
    } catch (...) { Fault(o, Allocation); }
    napi_threadsafe_function callback;
    {
        std::lock_guard<std::mutex> lock(o->mutex);
        o->stats.producerExited = true;
        o->stats.builderBytes = o->stats.lookaheadBytes = 0;
        callback = o->callback;
        o->callback = nullptr;
    }
    if (callback && napi_release_threadsafe_function(callback, napi_tsfn_release) != napi_ok) Fault(o, Environment);
    o->changed.notify_all();
}

napi_value StartReceiveLoop(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (!napi_check_argc(env, "startReceiveLoop", argc, 1) ||
        !napi_check_type(env, "startReceiveLoop", argv[0], napi_function, "callback")) return nullptr;
    std::lock_guard<std::mutex> ownerLock(owner_mutex);
    if (active_owner || next_epoch > MAX_SAFE_ID) {
        napi_throw_error(env, "ERR_TDLIB_RECEIVE_BUSY", "TDLib receive owner is not retired"); return nullptr;
    }
    napi_value epoch = nullptr, resource = nullptr;
    if (napi_create_double(env, static_cast<double>(next_epoch), &epoch) != napi_ok ||
        napi_create_string_utf8(env, "TDLibReceiveLoop", NAPI_AUTO_LENGTH, &resource) != napi_ok) return nullptr;
    DeliveryOwner o; std::unique_ptr<DeliveryOwner> holder;
    try { o = std::make_shared<ReceiveOwner>(); holder = std::make_unique<DeliveryOwner>(o); }
    catch (...) { napi_throw_error(env, "ERR_TDLIB_RECEIVE_START", "Cannot allocate receive owner"); return nullptr; }
    o->env = env; o->stats.epoch = next_epoch;
    if (napi_get_uv_event_loop(env, &o->loop) != napi_ok ||
        napi_add_async_cleanup_hook(env, CleanupReceive, o.get(), &o->cleanupHook) != napi_ok) {
        napi_throw_error(env, "ERR_TDLIB_RECEIVE_START", "Cannot reserve receive cleanup"); return nullptr;
    }
    if (napi_create_threadsafe_function(env, argv[0], nullptr, resource, 1, 1,
        holder.get(), FinalizeDelivery, holder.get(), CallJs, &o->callback) != napi_ok) {
        if (napi_remove_async_cleanup_hook(o->cleanupHook) != napi_ok) {
            // Registration still owns raw hook data. Retain it for explicit stop
            // or env cleanup; never leave the hook pointing into a freed owner.
            active_owner = o;
            ++next_epoch;
            o->stats.producerExited = o->stats.producerJoined = o->stats.tsfnFinalized = true;
            Fault(o, Environment);
        }
        napi_throw_error(env, "ERR_TDLIB_RECEIVE_START", "Cannot create receive callback"); return nullptr;
    }
    holder.release();
    active_owner = o;
    ++next_epoch;
    o->stats.status = Running;
    try { o->producer = std::thread([o] { ReceiveProducer(o); }); }
    catch (...) {
        o->stats.producerExited = o->stats.producerJoined = true;
        Fault(o, Environment);
        auto callback = o->callback; o->callback = nullptr;
        if (napi_release_threadsafe_function(callback, napi_tsfn_release) != napi_ok) Fault(o, Environment);
        napi_throw_error(env, "ERR_TDLIB_RECEIVE_START", "Cannot start receive producer"); return nullptr;
    }
    return epoch;
}
napi_value StopReceiveLoop(napi_env env, napi_callback_info) {
    auto o = CurrentOwner();
    if (o && o->env != env) { napi_throw_error(env, "ERR_TDLIB_RECEIVE_BUSY", "Receive owner belongs to another env"); return nullptr; }
    napi_deferred deferred = nullptr; napi_value promise = nullptr;
    if (napi_create_promise(env, &deferred, &promise) != napi_ok) return nullptr;
    if (!o) { ResolveStop(env, deferred); return promise; }
    RequestStop(o);
    try { o->waiters.push_back(deferred); }
    catch (...) { RejectStop(env, deferred, "Cannot register receive stop waiter"); return promise; }
    if (!QueueJoin(o)) {
        for (auto waiter : o->waiters) RejectStop(env, waiter, "Cannot queue receive join; retry stop");
        o->waiters.clear();
    } else TryFinish(o);
    return promise;
}
static bool ReadId(napi_env env, napi_value value, uint64_t& id) {
    napi_valuetype type; double number;
    if (napi_typeof(env, value, &type) != napi_ok || type != napi_number ||
        napi_get_value_double(env, value, &number) != napi_ok || !std::isfinite(number) ||
        number < 1 || number > static_cast<double>(MAX_SAFE_ID) || std::floor(number) != number) return false;
    id = static_cast<uint64_t>(number); return true;
}
napi_value AckReceiveBatch(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2], result = nullptr;
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    uint64_t epoch = 0, id = 0;
    bool accepted = false;
    auto o = CurrentOwner();
    if (argc == 2 && ReadId(env, argv[0], epoch) && ReadId(env, argv[1], id) && o && o->env == env) {
        std::lock_guard<std::mutex> lock(o->mutex);
        if (!o->stop && epoch == o->stats.epoch) {
            for (auto it = o->ledger.begin(); it != o->ledger.end(); ++it) {
                if ((*it)->id != id || !(*it)->admitted) continue;
                const auto bytes = (*it)->bytes;
                o->ledger.erase(it);
                --o->stats.outstandingBatches; o->stats.outstandingBytes -= bytes;
                --o->stats.admittedBatches; o->stats.admittedBytes -= bytes;
                accepted = true; o->changed.notify_all(); break;
            }
        }
    }
    napi_get_boolean(env, accepted, &result); return result;
}
static ReceiveStats Snapshot(napi_env env) {
    auto o = CurrentOwner();
    if (!o) { std::lock_guard<std::mutex> lock(owner_mutex); return retired_stats; }
    if (o->env != env) return ReceiveStats{};
    std::lock_guard<std::mutex> lock(o->mutex); return o->stats;
}
napi_value GetReceiveLoopStatus(napi_env env, napi_callback_info) {
    napi_value value = nullptr;
    napi_create_int32(env, Snapshot(env).status, &value); return value;
}
napi_value GetReceiveLoopStats(napi_env env, napi_callback_info) {
    const auto s = Snapshot(env); napi_value object = nullptr, value = nullptr;
    if (napi_create_object(env, &object) != napi_ok) return nullptr;
#define NUMBER_FIELD(name) if (napi_create_double(env, static_cast<double>(s.name), &value) != napi_ok || napi_set_named_property(env, object, #name, value) != napi_ok) return nullptr;
    NUMBER_FIELD(epoch) NUMBER_FIELD(status) NUMBER_FIELD(outstandingBatches) NUMBER_FIELD(outstandingBytes)
    NUMBER_FIELD(nativeQueuedBatches) NUMBER_FIELD(nativeQueuedBytes) NUMBER_FIELD(admittedBatches) NUMBER_FIELD(admittedBytes)
    NUMBER_FIELD(builderBytes) NUMBER_FIELD(lookaheadBytes) NUMBER_FIELD(pendingNotifications)
    NUMBER_FIELD(peakOutstandingBatches) NUMBER_FIELD(peakOutstandingBytes) NUMBER_FIELD(peakBuilderBytes)
    NUMBER_FIELD(peakLookaheadBytes) NUMBER_FIELD(peakPendingNotifications) NUMBER_FIELD(marshalRetries) NUMBER_FIELD(notifyRetries)
#undef NUMBER_FIELD
#define BOOL_FIELD(name) if (napi_get_boolean(env, s.name, &value) != napi_ok || napi_set_named_property(env, object, #name, value) != napi_ok) return nullptr;
    BOOL_FIELD(producerExited) BOOL_FIELD(producerJoined) BOOL_FIELD(tsfnFinalized)
#undef BOOL_FIELD
    return object;
}


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
    std::lock_guard<std::mutex> receptionLock(owner_mutex);
    if (active_owner) {
        napi_throw_error(env, "ERR_TDLIB_RECEIVE_BUSY", "Dedicated receive owner is active");
        return nullptr;
    }
    std::lock_guard<std::mutex> jsonLock(td_json_mutex);
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

    std::lock_guard<std::mutex> jsonLock(td_json_mutex);
    const char* response = td_execute(request.c_str());

    napi_value result;
    if (response != nullptr) {
        napi_create_string_utf8(env, response, NAPI_AUTO_LENGTH, &result);
    } else {
        napi_get_null(env, &result);
    }
    return result;
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
