// Actual production C++ against host-only N-API/TDLib boundaries.
// A non-ok status AFTER enqueue is intentionally adversarial. This fixture does
// not establish its reachability on HarmonyOS, target ABI, or env cleanup order.
// No test knows the delivery class/member names or reads native loop globals.
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <memory>
#include <mutex>
#include <new>
#include <string>
#include <thread>
#include <vector>
#include "napi/native_api.h"

namespace oracle {
static std::atomic<bool> enabled{false};
static thread_local unsigned host_depth = 0;
struct Host { Host() { ++host_depth; } ~Host() { --host_depth; } };
// A fake JS callback can synchronously enter real native code again. Do not
// accidentally hide that reentrant native allocation path under its Host scope.
struct Native {
    unsigned saved = host_depth;
    Native() { host_depth = 0; }
    ~Native() { host_depth = saved; }
};
#ifdef DELIVERY_HEAP_ORACLE
struct Slot { void* pointer; size_t bytes; };
static Slot slots[32768]{};
static std::atomic_flag lock = ATOMIC_FLAG_INIT;
static size_t allocated = 0, freed = 0;
static void Lock() { while (lock.test_and_set(std::memory_order_acquire)) {} }
static void Unlock() { lock.clear(std::memory_order_release); }
static void Add(void* p, size_t bytes) {
    if (!enabled.load() || host_depth) return;
    Lock();
    for (auto& slot : slots) if (!slot.pointer) {
        slot = {p, bytes}; ++allocated; Unlock(); return;
    }
    Unlock(); std::abort();
}
static void Remove(void* p) {
    if (!p) return;
    Lock();
    for (auto& slot : slots) if (slot.pointer == p) {
        slot = {}; ++freed; break;
    }
    Unlock();
}
static size_t Live(size_t* bytes = nullptr) {
    size_t count = 0, total = 0;
    Lock();
    for (const auto& slot : slots) if (slot.pointer) { ++count; total += slot.bytes; }
    Unlock();
    if (bytes) *bytes = total;
    return count;
}
#endif
}

#ifdef DELIVERY_HEAP_ORACLE
// This instrumentation is ONLY in the host executable. All production source
// bytes are untouched. Host fake allocations are excluded via Host scopes;
// frees are always observed, including destruction on another native thread.
// This counts tracked C++ allocations, not malloc, OS resources or SDK heaps.
void* operator new(size_t size) {
    void* p = std::malloc(size ? size : 1);
    if (!p) throw std::bad_alloc();
    oracle::Add(p, size); return p;
}
void operator delete(void* p) noexcept { oracle::Remove(p); std::free(p); }
void operator delete(void* p, size_t) noexcept { ::operator delete(p); }
void* operator new[](size_t size) { return ::operator new(size); }
void operator delete[](void* p) noexcept { ::operator delete(p); }
void operator delete[](void* p, size_t) noexcept { ::operator delete(p); }
void* operator new(size_t size, const std::nothrow_t&) noexcept {
    try { return ::operator new(size); } catch (...) { return nullptr; }
}
void operator delete(void* p, const std::nothrow_t&) noexcept { ::operator delete(p); }
#endif

static void* const env_handle = reinterpret_cast<void*>(1);
static void* const string_handle = reinterpret_cast<void*>(2);
static napi_value next_callback = reinterpret_cast<void*>(3);
static const std::thread::id main_thread = std::this_thread::get_id();
using DeliveryFinalize = napi_finalize;
using DeliveryCallback = void (*)(napi_env, napi_value, void*, void*);
struct Function {
    napi_value js;
    void* context;
    void* finalize_data;
    DeliveryFinalize finalize;
    DeliveryCallback call;
    bool finalized = false;
    bool closing = false;
    unsigned releases = 0;
};
struct Wake { Function* function; void* data; };
struct Attempt {
    void* data;
    size_t responses;
    bool inserted;
    napi_status status;
    std::chrono::steady_clock::time_point time;
};
struct Invocation { napi_value callback; std::string batch; };
struct Promise { unsigned resolved = 0, rejected = 0; };
struct Work {
    napi_async_execute_callback execute;
    napi_async_complete_callback complete;
    void* data;
    std::thread worker;
};
static std::vector<std::unique_ptr<Function>> functions;
static std::vector<std::unique_ptr<Promise>> promises;
static std::vector<Work*> works;
static std::mutex boundary_mutex;
static std::condition_variable changed;
static std::deque<std::string> input;
static std::deque<Wake> wakes;
static std::vector<Attempt> attempts;
static std::vector<Invocation> invocations;
static std::string marshalled;
static bool batch_separator = false, receiver_idle = false;
static bool park_after_insert = false, insertion_parked = false, resume_insert = false;
static bool reenter_from_js = false, reentered = false;
static Promise* reentrant_promise = nullptr;
static size_t responses = 0;
static unsigned invalid_api = 0, after_close = 0, releases_after_close = 0;
static unsigned string_calls = 0, receiver_calls = 0, function_calls = 0;
static unsigned throws = 0, passed = 0, failed = 0;
static napi_status string_status = napi_ok, receiver_status = napi_ok, function_status = napi_ok;
static napi_status rejection_status = napi_generic_failure, terminal_status = napi_closing;
enum class Mode { Success, RejectBefore, RejectAfter, RejectAlways, Closing };
static Mode mode = Mode::Success;
static void ReenterStopFromJs();

static void Check(bool ok, const char* label) {
    std::printf("%s %s\n", ok ? "PASS" : "FAIL", label);
    ok ? ++passed : ++failed;
}
static void OnArk(napi_env env) {
    if (env != env_handle || std::this_thread::get_id() != main_thread) ++invalid_api;
}
napi_status napi_throw_error(napi_env env, const char*, const char*) { OnArk(env); ++throws; return napi_ok; }
napi_status napi_typeof(napi_env, napi_value, napi_valuetype* v) { *v = napi_function; return napi_ok; }
napi_status napi_create_int32(napi_env, int32_t, napi_value* v) { *v = env_handle; return napi_ok; }
napi_status napi_get_cb_info(napi_env, napi_callback_info, size_t* n, napi_value* args, napi_value*, void**) {
    *n = 1; args[0] = next_callback; return napi_ok;
}
napi_status napi_get_value_int32(napi_env, napi_value, int32_t* v) { *v = 1; return napi_ok; }
napi_status napi_get_value_double(napi_env, napi_value, double* v) { *v = 0; return napi_ok; }
napi_status napi_get_value_string_utf8(napi_env, napi_value, char*, size_t, size_t* len) { *len = 0; return napi_ok; }
napi_status napi_get_undefined(napi_env env, napi_value* v) {
    OnArk(env); ++receiver_calls; *v = env_handle; return receiver_status;
}
napi_status napi_get_null(napi_env, napi_value* v) { *v = nullptr; return napi_ok; }
napi_status napi_create_string_utf8(napi_env env, const char* s, size_t len, napi_value* v) {
    oracle::Host host;
    OnArk(env); ++string_calls;
    if (string_status != napi_ok) return string_status;
    marshalled = len == NAPI_AUTO_LENGTH ? std::string(s) : std::string(s, len);
    *v = string_handle; return napi_ok;
}
napi_status napi_call_function(napi_env env, napi_value receiver, napi_value callback,
    size_t argc, const napi_value* argv, napi_value*) {
    oracle::Host host;
    OnArk(env); ++function_calls;
    if (receiver != env_handle || argc != 1 || !argv || argv[0] != string_handle) ++invalid_api;
    // A failing JS call may have performed side effects: count attempts, not
    // successful JS execution, and demand that they are never replayed.
    invocations.push_back({callback, marshalled});
    if (reenter_from_js && !reentered) {
        reentered = true;
        ReenterStopFromJs();
    }
    return function_status;
}
// Signature is the typed napi_finalize contract from the shared host header.
// No production declaration, function name or delivery statement is rewritten.
napi_status napi_create_threadsafe_function(napi_env env, napi_value js, napi_value,
    napi_value, size_t, size_t, void* finalize_data, DeliveryFinalize finalize, void* context,
    DeliveryCallback call, napi_threadsafe_function* result) {
    oracle::Host host;
    OnArk(env);
    functions.emplace_back(new Function{js, context, finalize_data, finalize, call});
    *result = functions.back().get(); return napi_ok;
}
napi_status napi_call_threadsafe_function(napi_threadsafe_function handle, void* data,
    napi_threadsafe_function_call_mode) {
    oracle::Host host;
    std::unique_lock<std::mutex> lock(boundary_mutex);
    auto* f = static_cast<Function*>(handle);
    if (f->closing) ++after_close;
    const bool first = attempts.empty();
    napi_status status = napi_ok;
    bool inserted = true;
    if ((mode == Mode::RejectBefore && first) || mode == Mode::RejectAlways) {
        status = rejection_status; inserted = false;
    } else if (mode == Mode::RejectAfter && first) {
        status = rejection_status; // Deliberately inserted despite non-ok.
    } else if (mode == Mode::Closing) {
        status = terminal_status; inserted = false; f->closing = true;
    }
    if (inserted) wakes.push_back({f, data});
    attempts.push_back({data, responses, inserted, status, std::chrono::steady_clock::now()});
    if (park_after_insert && first) {
        insertion_parked = true;
        changed.notify_all();
        // The ArkTS fixture thread drains this wake before the producer gets
        // the non-ok return. This is another adversarial schedule, not an OS
        // assertion. No N-API callback is invoked on the producer thread.
        changed.wait(lock, [] { return resume_insert; });
    }
    changed.notify_all();
    return status;
}
napi_status napi_release_threadsafe_function(napi_threadsafe_function handle,
    napi_threadsafe_function_release_mode) {
    oracle::Host host;
    std::lock_guard<std::mutex> lock(boundary_mutex);
    auto* f = static_cast<Function*>(handle);
    ++f->releases;
    if (f->closing) ++releases_after_close;
    changed.notify_all(); return napi_ok;
}
napi_status napi_create_promise(napi_env env, napi_deferred* d, napi_value* v) {
    oracle::Host host;
    OnArk(env); promises.emplace_back(new Promise()); *d = *v = promises.back().get(); return napi_ok;
}
napi_status napi_resolve_deferred(napi_env env, napi_deferred d, napi_value) {
    OnArk(env); ++static_cast<Promise*>(d)->resolved; return napi_ok;
}
napi_status napi_reject_deferred(napi_env env, napi_deferred d, napi_value) {
    OnArk(env); ++static_cast<Promise*>(d)->rejected; return napi_ok;
}
napi_status napi_create_error(napi_env env, napi_value, napi_value, napi_value* v) {
    OnArk(env); *v = env_handle; return napi_ok;
}
napi_status napi_create_async_work(napi_env env, napi_value, napi_value, napi_async_execute_callback execute,
    napi_async_complete_callback complete, void* data, napi_async_work* w) {
    oracle::Host host;
    OnArk(env); *w = new Work{execute, complete, data, std::thread()}; return napi_ok;
}
napi_status napi_queue_async_work(napi_env env, napi_async_work w) {
    oracle::Host host;
    OnArk(env); auto* work = static_cast<Work*>(w); works.push_back(work);
    work->worker = std::thread([work, env] { work->execute(env, work->data); }); return napi_ok;
}
napi_status napi_delete_async_work(napi_env env, napi_async_work w) {
    oracle::Host host;
    OnArk(env); auto* work = static_cast<Work*>(w);
    if (work->worker.joinable()) std::abort();
    delete work; return napi_ok;
}
int td_create_client_id() { return 1; }
void td_send(int, const char*) {}
const char* td_execute(const char*) { return nullptr; }
const char* td_receive(double) {
    oracle::Host host;
    static thread_local std::string response;
    std::unique_lock<std::mutex> lock(boundary_mutex);
    if (batch_separator) { batch_separator = false; return nullptr; }
    if (input.empty()) {
        receiver_idle = true; changed.notify_all();
        changed.wait_for(lock, std::chrono::milliseconds(2), [] { return !input.empty(); });
        return nullptr;
    }
    receiver_idle = false;
    response = std::move(input.front()); input.pop_front();
    ++responses; batch_separator = true;
    return response.c_str();
}

#ifndef BRIDGE_SOURCE
#define BRIDGE_SOURCE "../../entry/src/main/cpp/tdlib_napi.cpp"
#endif
#include BRIDGE_SOURCE

template<class Predicate> static bool Wait(Predicate predicate, unsigned ms = 1500) {
    std::unique_lock<std::mutex> lock(boundary_mutex);
    return changed.wait_for(lock, std::chrono::milliseconds(ms), predicate);
}
static std::string Json(unsigned id) {
    return "{\"id\":" + std::to_string(id) + ",\"text\":\"" + std::string(4096, 'x') + "\"}";
}
static std::string Batch(unsigned id) { return "[" + Json(id) + "]"; }
static void Feed(unsigned first, unsigned count) {
    std::lock_guard<std::mutex> lock(boundary_mutex);
    receiver_idle = false;
    for (unsigned i = first; i < first + count; ++i) input.push_back(Json(i));
    changed.notify_all();
}
static Function* Start() {
    const auto before = functions.size();
    const auto value = tdlib_napi::StartReceiveLoop(env_handle, nullptr);
    Check(value != nullptr && functions.size() == before + 1 && throws == 0, "actual StartReceiveLoop creates one TSFN");
    if (functions.size() != before + 1) std::exit(2);
    return functions.back().get();
}
static void CompleteWork() {
    for (auto* work : works) {
        if (work->worker.joinable()) work->worker.join();
        work->complete(env_handle, napi_ok, work->data);
    }
    works.clear();
}
static void Stop() {
    const auto value = tdlib_napi::StopReceiveLoop(env_handle, nullptr);
    CompleteWork();
    auto* promise = static_cast<Promise*>(value);
    Check(promise && promise->resolved == 1 && promise->rejected == 0, "actual StopReceiveLoop join barrier resolves");
}
static void ReenterStopFromJs() {
    size_t before = 0;
    { std::lock_guard<std::mutex> lock(boundary_mutex); before = attempts.size(); }
    Feed(50, 1);
    // Wait with JS still on the stack, not after callback return. Holding the
    // delivery queue mutex across JS prevents this producer notification.
    Check(Wait([before] { return attempts.size() > before; }),
        "producer reaches next notification while JS callback is paused");
    oracle::Native native;
    reentrant_promise = static_cast<Promise*>(tdlib_napi::StopReceiveLoop(env_handle, nullptr));
    Check(reentrant_promise && reentrant_promise->resolved == 0 && reentrant_promise->rejected == 0,
        "JS reentrant stop returns a pending Promise during callback");
    const auto before_functions = functions.size();
    const auto before_throws = throws;
    const auto restart = tdlib_napi::StartReceiveLoop(env_handle, nullptr);
    Check(restart == nullptr && throws == before_throws + 1 && functions.size() == before_functions,
        "JS reentry cannot restart before stop main completion");
}
static void Finalize(Function* f) {
    if (f->finalized) std::abort();
    f->finalized = true;
    if (f->finalize) f->finalize(env_handle, f->finalize_data, nullptr);
}
static void Deliver(Wake wake, napi_env env = env_handle, bool null_callback = false, bool poison = false) {
    const auto before = function_calls;
    // An intentionally invalid context is a guard probe, NOT an OS lifetime
    // model: with null env/callback even a finalized context must not be read.
    void* context = poison ? reinterpret_cast<void*>(1) : wake.function->context;
    wake.function->call(env, null_callback ? nullptr : wake.function->js, context, wake.data);
    Check(function_calls - before <= 1, "one native callback invokes at most one JS batch");
}
static bool Pop(Wake& wake) {
    std::lock_guard<std::mutex> lock(boundary_mutex);
    if (wakes.empty()) return false;
    wake = wakes.front(); wakes.pop_front(); return true;
}
static void Drain() { Wake wake{}; while (Pop(wake)) Deliver(wake); }
static void TransportContract() {
    std::lock_guard<std::mutex> lock(boundary_mutex);
    bool only_null = !attempts.empty();
    for (const auto& attempt : attempts) only_null &= attempt.data == nullptr;
    Check(only_null, "TSFN carries ONLY nullptr wakeups, never payload ownership");
}
static void Exact(const std::vector<unsigned>& ids, napi_value callback, const char* label) {
    bool exact = invocations.size() == ids.size();
    for (size_t i = 0; exact && i < ids.size(); ++i)
        exact = invocations[i].batch == Batch(ids[i]) && invocations[i].callback == callback;
    Check(exact, label);
}
static void HeapCheck() {
#ifdef DELIVERY_HEAP_ORACLE
    size_t bytes = 0;
    const size_t live = oracle::Live(&bytes);
    std::printf("HEAP native tracked allocations=%zu frees=%zu live=%zu bytes=%zu\n",
        oracle::allocated, oracle::freed, live, bytes);
    Check(oracle::allocated > 0 && live == 0, "native tracked C++ heap is empty after join/finalize/delivery");
#else
    std::puts("HEAP uninstrumented variant: no allocation-count claim");
#endif
}
static void Calibrate() {
#ifdef DELIVERY_HEAP_ORACLE
    oracle::enabled = true;
    const auto baseline = oracle::Live();
    void* p = ::operator new(4096);
    Check(oracle::Live() == baseline + 1, "heap oracle null twin detects a retained allocation");
    std::thread releaser([p] { ::operator delete(p); });
    releaser.join();
    Check(oracle::Live() == baseline, "heap oracle observes cross-thread destruction");
    oracle::enabled = false;
    oracle::allocated = oracle::freed = 0; // Calibration cannot fake native engagement.
#endif
}

int main(int argc, char** argv) {
    std::setvbuf(stdout, nullptr, _IONBF, 0);
    if (argc != 2) return 2;
    const std::string scenario = argv[1];
    Calibrate();
    // Fixture allocation sites use Host scopes. Native entry points, producer,
    // callbacks and finalizers run outside them, so allocations are measurable.
    oracle::enabled = true;
    if (scenario == "reject-before") mode = Mode::RejectBefore;
    if (scenario == "queue-full") { mode = Mode::RejectBefore; rejection_status = napi_queue_full; }
    if (scenario == "reject-after" || scenario == "reject-after-drain") mode = Mode::RejectAfter;
    park_after_insert = scenario == "reject-after-drain";
    if (scenario == "reject-always") mode = Mode::RejectAlways;
    if (scenario == "closing") mode = Mode::Closing;
    if (scenario == "invalid-handle") { mode = Mode::Closing; terminal_status = napi_invalid_arg; }
    reenter_from_js = scenario == "js-reentry";
    { oracle::Host host; Feed(1, scenario == "success" ? 3 : 2); }
    auto* f = Start();
    if (park_after_insert) {
        Check(Wait([] { return insertion_parked; }), "post-insert non-ok is paused before returning to producer");
        Wake first{};
        Check(Pop(first), "adversarial insertion produced a wake before its non-ok return");
        Deliver(first);
        { oracle::Host host; Exact({1}, f->js, "first batch drains while rejected TSFN call is still pending"); }
        { std::lock_guard<std::mutex> lock(boundary_mutex); resume_insert = true; changed.notify_all(); }
    }
    if (mode == Mode::RejectAlways) {
        Check(Wait([] { return attempts.size() >= 3; }, 400), "persistent non-ok wake is retried without another TD response");
        Stop();
        { std::lock_guard<std::mutex> lock(boundary_mutex);
          Check(responses == 1 && wakes.empty(), "rejection bounds read-ahead to the retained batch");
          const auto elapsed = attempts.size() < 3 ? 0 : std::chrono::duration_cast<std::chrono::milliseconds>(
              attempts[2].time - attempts[0].time).count();
          std::printf("RETRY first-to-third=%lldms\n", static_cast<long long>(elapsed));
          // Scheduling can delay retries. This lower bound catches hot spinning,
          // not an exact real-time timing/latency guarantee on a target device.
          Check(attempts.size() >= 3 && elapsed >= 80, "persistent retry is paced rather than a hot spin"); }
        Finalize(f);
    } else if (mode == Mode::Closing) {
        Check(Wait([] { return !attempts.empty(); }), "terminal handle fault engaged");
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
        const auto busy = tdlib_napi::StartReceiveLoop(env_handle, nullptr);
        Check(busy == nullptr && throws == 1 && functions.size() == 1,
            "terminal handle requires stop completion before restart instead of silent idempotent start");
        Stop();
        { std::lock_guard<std::mutex> lock(boundary_mutex);
          Check(responses == 1 && attempts.size() == 1 && after_close == 0 && releases_after_close == 0,
              "terminal status ends handle use, read-ahead and extra release"); }
        Finalize(f);
    } else {
        Check(Wait([] { return receiver_idle && input.empty(); }), "producer finished fixture input without blocked delivery");
        if (mode == Mode::RejectBefore || mode == Mode::RejectAfter) {
            std::lock_guard<std::mutex> lock(boundary_mutex);
            Check(attempts.size() >= 3 && attempts[0].status == rejection_status &&
                attempts[1].responses == attempts[0].responses && attempts[0].data == nullptr && attempts[1].data == nullptr,
                "non-ok retries the same null wake before td_receive read-ahead");
            Check(attempts[0].inserted == (mode == Mode::RejectAfter), "selected pre/post-enqueue fault actually engaged");
        }
        if (scenario == "null-env") {
            Stop(); Finalize(f);
            const auto api_before = string_calls + receiver_calls + function_calls;
            Wake wake{};
            while (Pop(wake)) Deliver(wake, nullptr, true, true);
            std::puts("PROBE null-env/poisoned-context");
            Deliver({f, nullptr}, nullptr, false, true); // Env guard independently.
            std::puts("PROBE null-callback/poisoned-context");
            Deliver({f, nullptr}, env_handle, true, true);
            Check(string_calls + receiver_calls + function_calls == api_before && invalid_api == 0,
                "null env/callback returns before finalized-context dereference and N-API");
        } else if (scenario == "restart") {
            Stop(); // Keep the old TSFN holder alive for its queued valid callback.
            { oracle::Host host; Feed(10, 2); }
            next_callback = reinterpret_cast<void*>(4);
            auto* fresh = Start();
            Check(Wait([] { return receiver_idle && input.empty(); }), "new producer has pending data before old callback");
            Wake old{};
            Check(Pop(old) && old.function == f, "old callback saved across restart");
            Deliver(old);
            const auto before = invocations.size();
            Deliver({f, nullptr}); // May drain only another OLD batch, never new.
            bool isolated = true;
            { oracle::Host host;
              for (size_t i = before; i < invocations.size(); ++i)
                  isolated &= invocations[i].callback == f->js && invocations[i].batch != Batch(10) && invocations[i].batch != Batch(11); }
            Check(isolated, "late old null wake cannot consume new-loop queue");
            Drain(); Stop(); Finalize(f); Finalize(fresh);
            { oracle::Host host;
              std::vector<unsigned> old_ids, new_ids;
              bool order = true;
              for (const auto& call : invocations) {
                  if (call.callback == f->js) {
                      const unsigned id = static_cast<unsigned>(old_ids.size() + 1);
                      order &= call.batch == Batch(id); old_ids.push_back(id);
                  } else if (call.callback == fresh->js) {
                      const unsigned id = static_cast<unsigned>(new_ids.size() + 10);
                      order &= call.batch == Batch(id); new_ids.push_back(id);
                  } else order = false;
              }
              Check(order && old_ids.size() == 2 && new_ids.size() == 2,
                  "old/new callbacks each deliver their own batches exactly once in order"); }
        } else {
            const bool failure = scenario == "string-failure" || scenario == "receiver-failure" || scenario == "js-failure";
            if (failure) {
                Wake first{}; Check(Pop(first), "callback failure has a queued batch");
                if (scenario == "string-failure") string_status = napi_generic_failure;
                if (scenario == "receiver-failure") receiver_status = napi_generic_failure;
                if (scenario == "js-failure") function_status = napi_generic_failure;
                const auto before = function_calls;
                Deliver(first);
                Check(function_calls - before == (scenario == "js-failure" ? 1U : 0U), "callback failure engages its intended boundary");
                string_status = receiver_status = function_status = napi_ok;
            }
            Drain();
            { oracle::Host host;
              if (scenario == "success") Exact({1, 2, 3}, f->js, "success: exact once and FIFO long JSON batches");
              else if (scenario == "js-reentry") Exact({1, 2, 50}, f->js, "JS reentry preserves pending and concurrently produced batches exactly once");
              else if (failure && scenario != "js-failure") Exact({2}, f->js, "failed conversion drops one batch, later batch still delivers once");
              else Exact({1, 2}, f->js, "accepted batches are attempted exactly once in order, including JS failure"); }
            const auto before = function_calls;
            Deliver({f, nullptr});
            Check(function_calls == before, "duplicate null wake on empty queue is harmless");
            if (scenario == "js-reentry") {
                Check(reentered && reentrant_promise && reentrant_promise->resolved == 0 && reentrant_promise->rejected == 0,
                    "reentrant stop remains pending until explicit main completion");
                CompleteWork();
                Check(reentrant_promise && reentrant_promise->resolved == 1 && reentrant_promise->rejected == 0,
                    "reentrant stop resolves exactly once after main completion");
            } else Stop();
            Finalize(f);
        }
    }
    TransportContract();
    Check(invalid_api == 0, "callback N-API runs only with valid env on the ArkTS fixture thread");
    HeapCheck();
    oracle::enabled = false;
    std::printf("SUMMARY %u passed, %u failed\n", passed, failed);
    return failed ? 1 : 0;
}
