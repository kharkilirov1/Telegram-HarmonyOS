// Real production C++ with deterministic N-API/TDLib fault injection.
// Proves host ownership/control flow, NOT target ABI, device teardown or timing.
#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <memory>
#include <system_error>
#include <vector>
#include "napi/native_api.h"

static void* const marker = reinterpret_cast<void*>(1);
static void* const string_handle = reinterpret_cast<void*>(2);
static napi_status string_status = napi_ok;
static napi_status undefined_status = napi_ok;
static napi_status create_status = napi_ok;
static napi_status call_status = napi_ok;
static std::atomic<int> receives{0};
static int creates = 0, releases = 0, throws = 0, strings = 0, undefineds = 0, calls = 0;
static std::string marshalled;
static std::string delivered;
static bool invalid_call = false;
static const std::thread::id main_thread = std::this_thread::get_id();
static void (*registered_callback)(napi_env, napi_value, void*, void*) = nullptr;
static void* registered_context = nullptr;
struct Finalizer { napi_finalize callback; void* data; };
static std::vector<Finalizer> finalizers;
static std::mutex queue_mutex;
static std::vector<void*> accepted_payloads;
static std::atomic<bool> emit_response{false};
static std::atomic<int> enqueued{0};
static void* tracked = nullptr;
static int deleted = 0;
static const void* tracked_chars = nullptr;
static int chars_deleted = 0;
static int passed = 0, failed = 0;
static const std::string long_batch = "[{\"@type\":\"text\",\"text\":\"" + std::string(4096, 'x') + "\"}]";

struct HostPromise { int resolved = 0; int rejected = 0; };
struct HostWork {
    napi_async_execute_callback execute;
    napi_async_complete_callback complete;
    void* data;
    std::thread worker;
};
static std::vector<std::unique_ptr<HostPromise>> promises;
static std::vector<HostWork*> queued_work;
static napi_status promise_status = napi_ok, work_status = napi_ok, queue_status = napi_ok;
static int work_created = 0, work_deleted = 0;
static bool cancel_next_work = false, fail_thread_start = false;
static bool async_wrong_thread = false;
static std::mutex gate_mutex;
static std::condition_variable gate_cv;
static bool gate_closed = false, receiver_waiting = false, stop_returned = false;

static HostPromise* AsPromise(napi_value value) {
    for (const auto& p : promises) if (p.get() == value) return p.get();
    return nullptr;
}

// Pair allocation/deallocation through the same C allocator (including MinGW).
// Tracking is enabled only in single-threaded callback cases.
void* operator new(std::size_t size) {
    if (void* p = std::malloc(size == 0 ? 1 : size)) return p;
    throw std::bad_alloc();
}
void operator delete(void* p) noexcept {
    if (p != nullptr && p == tracked) ++deleted;
    if (p != nullptr && p == tracked_chars) ++chars_deleted;
    std::free(p);
}
void operator delete(void* p, std::size_t) noexcept { ::operator delete(p); }

napi_status napi_throw_error(napi_env, const char*, const char*) { ++throws; return napi_ok; }
napi_status napi_typeof(napi_env, napi_value, napi_valuetype* v) { *v = napi_function; return napi_ok; }
napi_status napi_create_int32(napi_env, int32_t, napi_value* v) { *v = marker; return napi_ok; }
napi_status napi_get_cb_info(napi_env, napi_callback_info, size_t* n, napi_value* args, napi_value*, void**) {
    *n = 1; args[0] = marker; return napi_ok;
}
napi_status napi_get_value_int32(napi_env, napi_value, int32_t* v) { *v = 1; return napi_ok; }
napi_status napi_get_value_double(napi_env, napi_value, double* v) { *v = 0; return napi_ok; }
napi_status napi_get_value_string_utf8(napi_env, napi_value, char*, size_t, size_t* len) { *len = 0; return napi_ok; }
napi_status napi_get_undefined(napi_env, napi_value* v) { ++undefineds; *v = marker; return undefined_status; }
napi_status napi_get_null(napi_env, napi_value* v) { *v = nullptr; return napi_ok; }
napi_status napi_create_string_utf8(napi_env, const char* s, size_t len, napi_value* v) {
    ++strings; marshalled = len == NAPI_AUTO_LENGTH ? std::string(s) : std::string(s, len);
    *v = string_handle; return string_status;
}
napi_status napi_call_function(napi_env env, napi_value receiver, napi_value callback,
                               size_t argc, const napi_value* argv, napi_value*) {
    const bool valid = env == marker && receiver == marker && callback == marker &&
        argc == 1 && argv != nullptr && argv[0] == string_handle && std::this_thread::get_id() == main_thread;
    invalid_call = invalid_call || !valid;
    if (valid) delivered = marshalled;
    ++calls; return call_status;
}
napi_status napi_create_threadsafe_function(napi_env, napi_value, napi_value, napi_value, size_t,
    size_t, void* data, napi_finalize finalize, void* context,
    void (*call_js)(napi_env, napi_value, void*, void*), napi_threadsafe_function* callback) {
    ++creates; if (create_status != napi_ok) return create_status;
    registered_callback = call_js;
    registered_context = context;
    if (finalize != nullptr) finalizers.push_back({finalize, data});
    *callback = marker; return napi_ok;
}
napi_status napi_call_threadsafe_function(napi_threadsafe_function, void* data, napi_threadsafe_function_call_mode) {
    // Model accepted asynchronous notification; run callbacks later on the main thread.
    std::lock_guard<std::mutex> lock(queue_mutex);
    accepted_payloads.push_back(data);
    ++enqueued;
    return napi_ok;
}
napi_status napi_release_threadsafe_function(napi_threadsafe_function, napi_threadsafe_function_release_mode) {
    ++releases; return napi_ok;
}
napi_status napi_create_promise(napi_env, napi_deferred* d, napi_value* v) {
    if (promise_status != napi_ok) return promise_status;
    promises.emplace_back(new HostPromise());
    *d = *v = promises.back().get();
    return napi_ok;
}
napi_status napi_resolve_deferred(napi_env, napi_deferred d, napi_value) {
    async_wrong_thread |= std::this_thread::get_id() != main_thread;
    ++static_cast<HostPromise*>(d)->resolved;
    return napi_ok;
}
napi_status napi_reject_deferred(napi_env, napi_deferred d, napi_value) {
    async_wrong_thread |= std::this_thread::get_id() != main_thread;
    ++static_cast<HostPromise*>(d)->rejected;
    return napi_ok;
}
napi_status napi_create_error(napi_env, napi_value, napi_value, napi_value* v) { *v = marker; return napi_ok; }
napi_status napi_create_async_work(napi_env, napi_value, napi_value, napi_async_execute_callback execute,
    napi_async_complete_callback complete, void* data, napi_async_work* w) {
    if (work_status != napi_ok) return work_status;
    *w = new HostWork{execute, complete, data, std::thread()};
    ++work_created;
    return napi_ok;
}
napi_status napi_queue_async_work(napi_env env, napi_async_work w) {
    if (queue_status != napi_ok) return queue_status;
    auto* work = static_cast<HostWork*>(w);
    queued_work.push_back(work);
    if (!cancel_next_work) work->worker = std::thread([work, env]() { work->execute(env, work->data); });
    return napi_ok;
}
napi_status napi_delete_async_work(napi_env, napi_async_work w) {
    auto* work = static_cast<HostWork*>(w);
    if (work->worker.joinable()) std::abort(); // Completion must follow execute.
    ++work_deleted;
    delete work;
    return napi_ok;
}
static void CompleteWork() {
    while (!queued_work.empty()) {
        auto* work = queued_work.front();
        queued_work.erase(queued_work.begin());
        if (work->worker.joinable()) work->worker.join();
        const auto status = cancel_next_work ? napi_cancelled : napi_ok;
        cancel_next_work = false;
        work->complete(marker, status, work->data);
    }
}
int td_create_client_id() { return 1; }
void td_send(int, const char*) {}
const char* td_execute(const char*) { return nullptr; }
const char* td_receive(double) {
    ++receives;
    {
        std::unique_lock<std::mutex> lock(gate_mutex);
        if (gate_closed) {
            receiver_waiting = true;
            gate_cv.notify_all();
            gate_cv.wait(lock, [] { return !gate_closed; });
        }
    }
    if (emit_response.exchange(false)) return "{\"@type\":\"ok\"}";
    std::this_thread::sleep_for(std::chrono::milliseconds(1)); return nullptr;
}

template<typename F> static std::thread MakeReceiveThread(F&& f) {
    if (fail_thread_start) throw std::system_error(std::make_error_code(std::errc::resource_unavailable_try_again));
    return std::thread(std::forward<F>(f));
}
#ifndef BRIDGE_SOURCE
#define BRIDGE_SOURCE "../../entry/src/main/cpp/tdlib_napi.cpp"
#endif
#include BRIDGE_SOURCE

static void Check(bool ok, const char* name) {
    std::printf("%s %s\n", ok ? "PASS" : "FAIL", name);
    ok ? ++passed : ++failed;
}
static void CallbackCase(napi_env env, napi_value callback, napi_status str, napi_status undef,
                         napi_status call, int want_calls, int want_strings, int want_undefineds, const char* name) {
    string_status = str; undefined_status = undef; call_status = call;
    calls = strings = undefineds = deleted = chars_deleted = 0;
    invalid_call = false;
    delivered.clear();
    auto* owner = new tdlib_napi::DeliveryOwner(std::make_shared<tdlib_napi::ReceiveDelivery>());
    (*owner)->batches.push_back(long_batch);
    tracked = owner;
    tracked_chars = (*owner)->batches.front().data();
    tdlib_napi::CallJs(env, callback, owner, nullptr);
    tdlib_napi::FinalizeDelivery(nullptr, owner, nullptr);
    Check(deleted == 1 && chars_deleted == 1 && !invalid_call && calls == want_calls &&
          strings == want_strings && undefineds == want_undefineds &&
          (want_calls == 0 || delivered == long_batch), name);
    if (deleted == 0) delete owner; // A negative control must not leave a test-process leak.
    if (chars_deleted == 0) ::operator delete(const_cast<void*>(tracked_chars));
    tracked = nullptr;
    tracked_chars = nullptr;
    string_status = undefined_status = call_status = napi_ok;
}
static void FinalizeCallbacks() {
    // Model the main-thread finalization separately from producer release/join.
    // Delayed finalization does not silently stand in for stop completion.
    for (const auto& item : finalizers) item.callback(nullptr, item.data, nullptr);
    finalizers.clear();
    registered_context = nullptr;
}
static void StopAndJoin() {
    tdlib_napi::StopReceiveLoop(marker, nullptr);
    CompleteWork();
    if (receive_thread.joinable()) receive_thread.join();
}
static void StartupCase(bool fail_name, const char* name) {
    string_status = fail_name ? napi_generic_failure : napi_ok;
    create_status = fail_name ? napi_ok : napi_generic_failure;
    const int before_creates = creates;
    receives = throws = 0;
    const auto result = tdlib_napi::StartReceiveLoop(marker, nullptr);
    const bool rollback = result == nullptr && throws == 1 && loop_state == LoopState::Stopped &&
        threadsafe_callback == nullptr && !receive_thread.joinable() && receives == 0 &&
        creates == before_creates + (fail_name ? 0 : 1);
    StopAndJoin();
    Check(rollback, name);
    string_status = create_status = napi_ok;
}
int main() {
    CallbackCase(nullptr, nullptr, napi_ok, napi_ok, napi_ok, 0, 0, 0, "null env skips N-API; finalizer frees its queued payload");
    CallbackCase(marker, nullptr, napi_ok, napi_ok, napi_ok, 0, 0, 0, "null callback skips N-API; finalizer frees its queued payload");
    CallbackCase(marker, marker, napi_generic_failure, napi_ok, napi_ok, 0, 1, 0, "string failure frees and does not call JS");
    CallbackCase(marker, marker, napi_ok, napi_generic_failure, napi_ok, 0, 1, 1, "undefined failure frees and does not call JS");
    CallbackCase(marker, marker, napi_ok, napi_ok, napi_generic_failure, 1, 1, 1, "JS failure still frees payload");
    CallbackCase(marker, marker, napi_ok, napi_ok, napi_ok, 1, 1, 1, "success calls JS and frees once");
    Check(delivered == long_batch, "JS receives the exact long batch");
    calls = strings = undefineds = 0;
    tdlib_napi::CallJs(marker, marker, nullptr, nullptr);
    Check(calls == 0 && strings == 0 && undefineds == 0, "null delivery context is a no-op");
    StartupCase(true, "resource name failure rolls startup back without receiving");
    StartupCase(false, "TSFN failure rolls startup back without receiving");
    const int before_creates = creates, before_releases = releases;
    receives = throws = 0;
    emit_response = true;
    enqueued = 0;
    calls = 0;
    invalid_call = false;
    delivered.clear();
    const auto result = tdlib_napi::StartReceiveLoop(marker, nullptr);
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    while (enqueued == 0 && std::chrono::steady_clock::now() < deadline) std::this_thread::yield();
    Check(registered_callback == tdlib_napi::CallJs && result == marker && throws == 0 &&
          receives > 0 && loop_state == LoopState::Running,
          "retry after failures starts the real receive loop");
    tdlib_napi::StartReceiveLoop(marker, nullptr);
    Check(creates == before_creates + 1, "duplicate start does not create a second TSFN");
    StopAndJoin();
    Check(loop_state == LoopState::Stopped && threadsafe_callback == nullptr && releases == before_releases + 1,
          "successful receiver stop releases its TSFN once");
    // Only successful-queue semantics are modeled; enqueue failures remain out of scope.
    for (void* payload : accepted_payloads) {
        if (registered_callback != nullptr) registered_callback(marker, marker, registered_context, payload);
    }
    accepted_payloads.clear();
    Check(enqueued == 1 && calls == 1 && !invalid_call && delivered == "[{\"@type\":\"ok\"}]",
          "native receive batch reaches the registered callback with its JS argument");
    FinalizeCallbacks();

    // Deterministic nonblocking witness: the old synchronous stop can return only
    // after the watchdog opens the TDLib gate. The async stop returns with it closed.
    {
        std::lock_guard<std::mutex> lock(gate_mutex);
        gate_closed = true; receiver_waiting = false; stop_returned = false;
    }
    tdlib_napi::StartReceiveLoop(marker, nullptr);
    {
        std::unique_lock<std::mutex> lock(gate_mutex);
        Check(gate_cv.wait_for(lock, std::chrono::seconds(2), [] { return receiver_waiting; }),
              "receive worker reached the controlled blocking call");
    }
    std::thread watchdog([] {
        {
            std::unique_lock<std::mutex> lock(gate_mutex);
            gate_cv.wait_for(lock, std::chrono::seconds(2), [] { return stop_returned; });
            gate_closed = false;
        }
        gate_cv.notify_all();
    });
    auto* first_stop = AsPromise(tdlib_napi::StopReceiveLoop(marker, nullptr));
    bool returned_before_receive;
    {
        std::lock_guard<std::mutex> lock(gate_mutex);
        returned_before_receive = gate_closed;
        stop_returned = true;
    }
    gate_cv.notify_all();
    Check(returned_before_receive && first_stop && first_stop->resolved == 0 && first_stop->rejected == 0,
          "stop returns a pending Promise while TDLib receive is blocked");
    auto* second_stop = AsPromise(tdlib_napi::StopReceiveLoop(marker, nullptr));
    Check(first_stop && second_stop && first_stop != second_stop && queued_work.size() == 1,
          "concurrent stops share one async join and keep both waiters");
    const int before_busy = creates, before_busy_throws = throws;
    const auto busy = tdlib_napi::StartReceiveLoop(marker, nullptr);
    Check(busy == nullptr && throws == before_busy_throws + 1 && creates == before_busy &&
          loop_state == LoopState::Stopping, "start rejects while stop barrier is pending");
    watchdog.join();
    if (!queued_work.empty() && queued_work.front()->worker.joinable()) queued_work.front()->worker.join();
    Check(loop_state == LoopState::Stopping && first_stop && first_stop->resolved == 0,
          "worker exit alone cannot publish Stopped or resolve the barrier");
    auto* late_stop = AsPromise(tdlib_napi::StopReceiveLoop(marker, nullptr));
    Check(late_stop && late_stop->resolved == 0 && queued_work.size() == 1,
          "a stop after join but before completion still waits on the original barrier");
    CompleteWork();
    Check(first_stop && second_stop && first_stop->resolved == 1 && second_stop->resolved == 1 &&
          late_stop && late_stop->resolved == 1 && loop_state == LoopState::Stopped && !async_wrong_thread,
          "main completion resolves every waiter only after off-thread join");
    StopAndJoin();

    // All later failure tests require the Promise implementation. On the old
    // source the checks above are the RED witness, without orphaning a thread.
    if (first_stop) {
        auto* idle = AsPromise(tdlib_napi::StopReceiveLoop(marker, nullptr));
        Check(idle && idle->resolved == 1 && queued_work.empty(), "stopped stop resolves without an async job");
        tdlib_napi::StartReceiveLoop(marker, nullptr);
        const int before_foreign = throws;
        const auto foreign_env = reinterpret_cast<napi_env>(3);
        const auto foreign_start = tdlib_napi::StartReceiveLoop(foreign_env, nullptr);
        const auto foreign_stop = tdlib_napi::StopReceiveLoop(foreign_env, nullptr);
        Check(foreign_start == nullptr && foreign_stop == nullptr && throws == before_foreign + 2 &&
              loop_state == LoopState::Running && queued_work.empty(),
              "foreign environment cannot start or stop the current owner's receiver");
        promise_status = napi_generic_failure;
        const int before_promise_throw = throws;
        auto promise_fail = tdlib_napi::StopReceiveLoop(marker, nullptr);
        Check(promise_fail == nullptr && throws == before_promise_throw + 1 && loop_state == LoopState::Running,
              "Promise creation failure leaves a running receiver owned and retryable");
        promise_status = napi_ok;
        string_status = napi_generic_failure;
        auto* resource_fail = AsPromise(tdlib_napi::StopReceiveLoop(marker, nullptr));
        Check(resource_fail && resource_fail->rejected == 1 && loop_state == LoopState::Running,
              "stop resource failure rejects without losing the running thread");
        string_status = napi_ok;
        work_status = napi_generic_failure;
        auto* create_fail = AsPromise(tdlib_napi::StopReceiveLoop(marker, nullptr));
        Check(create_fail && create_fail->rejected == 1 && loop_state == LoopState::Running,
              "async work creation failure leaves the running loop retryable");
        work_status = napi_ok;
        queue_status = napi_generic_failure;
        auto* queue_fail = AsPromise(tdlib_napi::StopReceiveLoop(marker, nullptr));
        Check(queue_fail && queue_fail->rejected == 1 && loop_state == LoopState::Stopping && receive_thread.joinable(),
              "queue failure restores thread ownership without falsely restoring Running");
        queue_status = napi_ok;
        const int before_queue_busy = throws;
        Check(tdlib_napi::StartReceiveLoop(marker, nullptr) == nullptr && throws == before_queue_busy + 1,
              "start cannot bypass a failed stop queue");
        StopAndJoin();
        Check(loop_state == LoopState::Stopped && !receive_thread.joinable(), "stop retry joins after queue failure");
        tdlib_napi::StartReceiveLoop(marker, nullptr);
        cancel_next_work = true;
        auto* cancelled = AsPromise(tdlib_napi::StopReceiveLoop(marker, nullptr));
        CompleteWork();
        Check(cancelled && cancelled->rejected == 1 && loop_state == LoopState::Stopping && receive_thread.joinable(),
              "cancelled async work returns its unjoined thread for retry");
        StopAndJoin();
        Check(loop_state == LoopState::Stopped && !receive_thread.joinable(), "stop retry joins after cancellation");
#ifdef BRIDGE_THREAD_INJECTION
        fail_thread_start = true;
        const int before_thread_releases = releases, before_thread_throws = throws;
        bool escaped = false;
        napi_value failed_start = marker;
        try { failed_start = tdlib_napi::StartReceiveLoop(marker, nullptr); } catch (...) { escaped = true; }
        fail_thread_start = false;
        Check(!escaped && failed_start == nullptr && throws == before_thread_throws + 1 &&
              releases == before_thread_releases + 1 && threadsafe_callback == nullptr &&
              loop_state == LoopState::Stopped && !receive_thread.joinable(),
              "thread constructor failure rolls back state and releases TSFN without crossing N-API");
        // Keep a deliberately broken mutation safely recoverable in this fixture.
        if (escaped) { loop_state = LoopState::Stopped; threadsafe_callback = nullptr; }
        tdlib_napi::StartReceiveLoop(marker, nullptr);
        StopAndJoin();
        Check(loop_state == LoopState::Stopped && work_created == work_deleted,
              "retry after constructor failure succeeds and every async work is deleted");
#endif
        Check(work_created == work_deleted && !async_wrong_thread,
              "all async work is cleaned up and Promise settlements stay on the main thread");
    }
    FinalizeCallbacks();
    std::printf("Native bridge: %d passed, %d failed\n", passed, failed);
    return failed == 0 ? 0 : 1;
}
