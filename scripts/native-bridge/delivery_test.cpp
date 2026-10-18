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
#include <map>
#include <system_error>
#include "uv.h"
#include "napi/native_api.h"

namespace oracle {
static std::atomic<bool> enabled{false};
static std::atomic<bool> fail_next{false};
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
    if (!oracle::host_depth && oracle::fail_next.exchange(false)) throw std::bad_alloc();
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
struct Invocation { napi_value callback; std::string batch; double epoch, id, bytes; };
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
static size_t peak_wakes = 0, executing_wakes = 0, peak_physical_wakes = 0;
static bool callback_accepts = true, callback_boolean = true, pending_exception = false;
static bool fail_epoch = false, fail_uv = false, fail_hook = false, fail_tsfn = false, fail_copy = false;
static bool fail_release = false, fail_hook_remove = false;
static bool fail_promise = false, receive_gate = false, receiver_parked = false, stop_returned = false;
static napi_env expected_api_env = env_handle;
static bool batch_separator_enabled = true, fail_thread_start = false;
static bool uv_queue_failure = false, uv_cancel = false;
static bool pause_before_submit = false, before_submit_parked = false, resume_before_submit = false;
static void BeforeNativeSubmit() {
    std::unique_lock<std::mutex> lock(boundary_mutex);
    if (!pause_before_submit) return;
    before_submit_parked = true; changed.notify_all();
    changed.wait(lock, []{ return resume_before_submit; });
    pause_before_submit = false;
}
struct Value { napi_valuetype type; double number = 0; bool boolean = false; std::map<std::string, napi_value> fields; };
static std::vector<std::unique_ptr<Value>> values;
static std::vector<napi_value> args_override;
static Value* NewValue(napi_valuetype type) { oracle::Host host; values.emplace_back(new Value{type}); return values.back().get(); }
static napi_async_cleanup_hook cleanup_callback = nullptr;
static void* cleanup_data = nullptr;
static napi_async_cleanup_hook_handle cleanup_handle = reinterpret_cast<void*>(9);
static int cleanup_removes = 0;
struct UvWork { uv_work_t* req; void (*after)(uv_work_t*, int); std::thread thread; bool cancel; };
static std::vector<UvWork*> uv_works;
static uv_loop_t uv_loop;
napi_status napi_create_double(napi_env, double n, napi_value* v) { if (fail_epoch) return napi_generic_failure; auto* value=NewValue(napi_number); value->number=n; *v=value; return napi_ok; }
napi_status napi_get_boolean(napi_env, bool b, napi_value* v) { auto* value=NewValue(napi_boolean); value->boolean=b; *v=value; return napi_ok; }
napi_status napi_get_value_bool(napi_env, napi_value v, bool* b) { if (!v || static_cast<Value*>(v)->type != napi_boolean) return napi_invalid_arg; *b=static_cast<Value*>(v)->boolean; return napi_ok; }
napi_status napi_create_object(napi_env, napi_value* v) { *v=NewValue(napi_object); return napi_ok; }
napi_status napi_set_named_property(napi_env, napi_value v, const char* key, napi_value child) { oracle::Host host; static_cast<Value*>(v)->fields[key]=child; return napi_ok; }
napi_status napi_is_exception_pending(napi_env, bool* p) { *p=pending_exception; return napi_ok; }
napi_status napi_get_uv_event_loop(napi_env, uv_loop_t** loop) { if (fail_uv) return napi_generic_failure; *loop=&uv_loop; return napi_ok; }
napi_status napi_add_async_cleanup_hook(napi_env, napi_async_cleanup_hook cb, void* data, napi_async_cleanup_hook_handle* handle) { if (fail_hook) return napi_generic_failure; cleanup_callback=cb; cleanup_data=data; *handle=cleanup_handle; return napi_ok; }
napi_status napi_remove_async_cleanup_hook(napi_async_cleanup_hook_handle) { if (fail_hook_remove) return napi_generic_failure; ++cleanup_removes; return napi_ok; }
int uv_queue_work(uv_loop_t*, uv_work_t* req, void (*run)(uv_work_t*), void (*after)(uv_work_t*, int)) {
    oracle::Host host;
    if (uv_queue_failure) return -1;
    auto* work=new UvWork{req,after,std::thread(),uv_cancel};
    if (!uv_cancel) work->thread=std::thread([run,req]{run(req);});
    uv_works.push_back(work);return 0;
}
template<typename F> static std::thread MakeReceiveThread(F&& f) {
    if (fail_thread_start) throw std::system_error(std::make_error_code(std::errc::resource_unavailable_try_again));
    return std::thread(std::forward<F>(f));
}


static void Check(bool ok, const char* label) {
    std::printf("%s %s\n", ok ? "PASS" : "FAIL", label);
    ok ? ++passed : ++failed;
}
static void OnArk(napi_env env) {
    if (env != expected_api_env || std::this_thread::get_id() != main_thread) ++invalid_api;
}
napi_status napi_throw_error(napi_env env, const char*, const char*) { OnArk(env); ++throws; return napi_ok; }
napi_status napi_typeof(napi_env, napi_value value, napi_valuetype* v) { *v = value == next_callback ? napi_function : static_cast<Value*>(value)->type; return napi_ok; }
napi_status napi_create_int32(napi_env env, int32_t n, napi_value* v) { return napi_create_double(env,n,v); }
napi_status napi_get_cb_info(napi_env, napi_callback_info, size_t* n, napi_value* args, napi_value*, void**) {
    if (!args_override.empty()) { *n=args_override.size(); for(size_t i=0;i<*n;++i) args[i]=args_override[i]; } else { *n=1; args[0]=next_callback; } return napi_ok;
}
napi_status napi_get_value_int32(napi_env, napi_value, int32_t* v) { *v = 1; return napi_ok; }
napi_status napi_get_value_double(napi_env, napi_value value, double* v) { *v=static_cast<Value*>(value)->number; return napi_ok; }
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
    size_t argc, const napi_value* argv, napi_value* result) {
    oracle::Host host;
    OnArk(env); ++function_calls;
    if (receiver != env_handle || argc != 4 || !argv || argv[0] != string_handle) ++invalid_api;
    // A failing JS call may have performed side effects: count attempts, not
    // successful JS execution, and demand that they are never replayed.
    invocations.push_back({callback, marshalled, static_cast<Value*>(argv[1])->number, static_cast<Value*>(argv[2])->number, static_cast<Value*>(argv[3])->number});
    if (result) { if (callback_boolean) napi_get_boolean(env, callback_accepts, result); else napi_create_double(env, 1, result); }
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
    if (fail_tsfn) return napi_generic_failure;
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
    if (inserted) { wakes.push_back({f, data}); peak_wakes=std::max(peak_wakes,wakes.size()); peak_physical_wakes=std::max(peak_physical_wakes,wakes.size()+executing_wakes); }
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
    changed.notify_all(); return fail_release ? napi_generic_failure : napi_ok;
}
napi_status napi_create_promise(napi_env env, napi_deferred* d, napi_value* v) {
    oracle::Host host;
    if (fail_promise) return napi_generic_failure;
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
    if (receive_gate) { receiver_parked = true; changed.notify_all(); changed.wait(lock, [] { return !receive_gate; }); }
    if (batch_separator_enabled && batch_separator) { batch_separator = false; return nullptr; }
    if (input.empty()) {
        receiver_idle = true; changed.notify_all();
        changed.wait_for(lock, std::chrono::milliseconds(2), [] { return !input.empty(); });
        return nullptr;
    }
    receiver_idle = false;
    response = std::move(input.front()); input.pop_front();
    ++responses; batch_separator = true;
    if (fail_copy) { fail_copy = false; oracle::fail_next = true; }
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
    oracle::Host host;
    auto pending=std::move(uv_works); uv_works.clear();
    for(auto* work: pending) {
        if(work->thread.joinable()) work->thread.join();
        { oracle::Native native; work->after(work->req,work->cancel ? -1 : 0); }
        delete work;
    }
}
static void Stop() {
    const auto value = tdlib_napi::StopReceiveLoop(env_handle, nullptr);
    CompleteWork();
    auto* promise = static_cast<Promise*>(value);
    Check(promise && promise->resolved == 1 && promise->rejected == 0, "actual StopReceiveLoop join barrier resolves");
}
static void ReenterStopFromJs() {
    oracle::Native native;
    reentrant_promise=static_cast<Promise*>(tdlib_napi::StopReceiveLoop(env_handle,nullptr));
    Check(reentrant_promise && !reentrant_promise->resolved, "reentrant stop returns without joining on owner");
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
    { std::lock_guard<std::mutex> lock(boundary_mutex); ++executing_wakes; peak_physical_wakes=std::max(peak_physical_wakes,wakes.size()+executing_wakes); }
    wake.function->call(env, null_callback ? nullptr : wake.function->js, context, wake.data);
    { std::lock_guard<std::mutex> lock(boundary_mutex); --executing_wakes; }
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

static double Number(napi_value value) { return static_cast<Value*>(value)->number; }
static napi_value Num(double number) { napi_value value; napi_create_double(env_handle, number, &value); return value; }
static bool Ack(double epoch, double id, napi_env env = env_handle) {
    oracle::Host host;
    args_override = {Num(epoch), Num(id)};
    napi_value value;
    { oracle::Native native; value = tdlib_napi::AckReceiveBatch(env, nullptr); }
    args_override.clear();
    return static_cast<Value*>(value)->boolean;
}
static double Stat(const char* name) {
    auto value = tdlib_napi::GetReceiveLoopStats(env_handle, nullptr);
    return static_cast<Value*>(static_cast<Value*>(value)->fields.at(name))->number;
}
static bool Flag(const char* name) {
    auto value = tdlib_napi::GetReceiveLoopStats(env_handle, nullptr);
    return static_cast<Value*>(static_cast<Value*>(value)->fields.at(name))->boolean;
}
static int Status() { return static_cast<int>(Number(tdlib_napi::GetReceiveLoopStatus(env_handle, nullptr))); }
static void Pause(unsigned ms = 120) { std::this_thread::sleep_for(std::chrono::milliseconds(ms)); }
static void Finish(Function* f, bool finalizeFirst = false) {
    auto* promise = static_cast<Promise*>(tdlib_napi::StopReceiveLoop(env_handle, nullptr));
    Check(promise && promise->resolved == 0, "stop is asynchronous before its completion gate");
    if (finalizeFirst) {
        Wait([f] { return f->releases > 0 || f->closing; });
        Drain(); Finalize(f); CompleteWork();
    } else {
        CompleteWork();
        Check(promise->resolved == 0, "joined producer cannot resolve before TSFN finalization");
        Drain(); Finalize(f);
    }
    Check(promise->resolved == 1 && promise->rejected == 0, "stop resolves exactly once after join and finalization");
    Check(Stat("outstandingBatches") == 0 && Stat("outstandingBytes") == 0 && Flag("producerJoined") && Flag("tsfnFinalized"),
        "retirement cancels every credit and publishes both lifecycle gates");
}
static void Pump(unsigned count, bool acknowledge = true) {
    const auto target = invocations.size() + count;
    for (unsigned i = 0; i < count * 20 + 500 && invocations.size() < target && Status() == 1; ++i) {
        Wake wake{};
        if (Pop(wake)) {
            const auto before = invocations.size(); Deliver(wake);
            if (acknowledge && invocations.size() > before) {
                const auto call = invocations.back();
                Check(Ack(call.epoch, call.id), "ACK releases a fully transferred live batch");
            }
        } else Pause(2);
    }
}
static void Bounds() {
    Check(Stat("peakOutstandingBatches") <= 4 && Stat("peakOutstandingBytes") <= 16777216,
        "actual native high-water remains within four batches and 16MiB");
    Check(Stat("peakBuilderBytes") <= 8388608 && Stat("peakLookaheadBytes") <= 8388606,
        "actual builder and copied lookahead remain separately bounded");
    Check(peak_wakes <= 1 && peak_physical_wakes <= 2 && Stat("peakPendingNotifications") <= 1,
        "physical queued+executing notifications and native wake counter are bounded independently");
}
int main(int argc, char** argv) {
    std::setvbuf(stdout, nullptr, _IONBF, 0);
#ifdef RECEIVE_LIFECYCLE_DEFAULT
    const std::string scenario = argc == 1 ? "lifecycle" : argv[1];
#else
    if (argc != 2) return 2;
    const std::string scenario = argv[1];
#endif
    Calibrate(); oracle::enabled = true;
    if (scenario == "api-guards") {
        receive_gate = true;
        auto* f = Start();
        Check(Wait([] { return receiver_parked; }), "receive worker reached the controlled blocking call");
        fail_promise = true;
        Check(tdlib_napi::StopReceiveLoop(env_handle, nullptr) == nullptr && Status() == 1 && uv_works.empty(),
            "Promise creation failure leaves a running receiver owned and retryable");
        fail_promise = false;
        const auto before_foreign = throws;
        expected_api_env = reinterpret_cast<napi_env>(3);
        const auto foreign_start = tdlib_napi::StartReceiveLoop(expected_api_env, nullptr);
        const auto foreign_stop = tdlib_napi::StopReceiveLoop(expected_api_env, nullptr);
        expected_api_env = env_handle;
        Check(!foreign_start && !foreign_stop && throws == before_foreign + 2 && Status() == 1 && uv_works.empty(),
            "foreign environment cannot start or stop the current owner's receiver");
        throws = 0;
        std::thread watchdog;
        { oracle::Host host; watchdog = std::thread([] {
            std::unique_lock<std::mutex> lock(boundary_mutex);
            changed.wait_for(lock, std::chrono::seconds(2), [] { return stop_returned; });
            receive_gate = false; changed.notify_all();
        }); }
        auto* first = static_cast<Promise*>(tdlib_napi::StopReceiveLoop(env_handle, nullptr));
        bool returned_before_receive;
        { std::lock_guard<std::mutex> lock(boundary_mutex); returned_before_receive = receive_gate; stop_returned = true; changed.notify_all(); }
        Check(returned_before_receive && first && !first->resolved && !first->rejected,
            "stop returns a pending Promise while TDLib receive is blocked");
        auto* second = static_cast<Promise*>(tdlib_napi::StopReceiveLoop(env_handle, nullptr));
        Check(second && second != first && uv_works.size() == 1 && !second->resolved,
            "concurrent stops share one async join and keep both waiters");
        watchdog.join(); CompleteWork();
        Check(Flag("producerJoined") && !first->resolved, "worker exit alone cannot publish Stopped or resolve the barrier");
        auto* late = static_cast<Promise*>(tdlib_napi::StopReceiveLoop(env_handle, nullptr));
        Check(late && !late->resolved && uv_works.empty(),
            "a stop after join but before completion still waits on the original barrier");
        Finalize(f);
        Check(first->resolved == 1 && second->resolved == 1 && late->resolved == 1 && Status() == 0,
            "main completion resolves every waiter only after off-thread join and finalization");
        auto* idle = static_cast<Promise*>(tdlib_napi::StopReceiveLoop(env_handle, nullptr));
        Check(idle && idle->resolved == 1 && uv_works.empty(), "stopped stop resolves without an async job");
    } else if (scenario == "startup-failures") {
        for (int boundary=0;boundary<5;++boundary) {
            fail_epoch=boundary==0; string_status=boundary==1 ? napi_generic_failure : napi_ok;
            fail_uv=boundary==2; fail_hook=boundary==3; fail_tsfn=boundary==4;
            const auto value=tdlib_napi::StartReceiveLoop(env_handle,nullptr);
            Check(value==nullptr && functions.empty() && responses==0,
                "epoch/resource/control/hook/TSFN start failure consumes no TDLib response");
            fail_epoch=fail_uv=fail_hook=fail_tsfn=false; string_status=napi_ok; throws=0;
        }
        auto* f=Start(); Finish(f);
    } else if (scenario == "release-failure") {
        auto* f=Start(); fail_release=true;
        auto* promise=static_cast<Promise*>(tdlib_napi::StopReceiveLoop(env_handle,nullptr));
        CompleteWork();
        Check(Status()==107 && promise->resolved==0 && f->releases==1 && !Flag("tsfnFinalized"),
            "ambiguous release failure latches Environment without double release or false stop completion");
        fail_release=false; Finalize(f);
        Check(promise->resolved==1 && f->releases==1 && Status()==107,
            "later finalizer can retire failed release while preserving first fault");
    } else if (scenario == "startup-hook-remove-failure") {
        fail_tsfn=fail_hook_remove=true;
        Check(tdlib_napi::StartReceiveLoop(env_handle,nullptr)==nullptr && responses==0,
            "failed TSFN creation never consumes TDLib even if cleanup removal fails");
        fail_tsfn=false;
        auto* promise=static_cast<Promise*>(tdlib_napi::StopReceiveLoop(env_handle,nullptr));
        Check(Status()==107 && promise->resolved==0 && cleanup_removes==0,
            "failed hook removal retains owner instead of dangling cleanup context");
        fail_hook_remove=false;
        auto* retry=static_cast<Promise*>(tdlib_napi::StopReceiveLoop(env_handle,nullptr));
        Check(promise->resolved==1 && retry->resolved==1 && cleanup_removes==1,
            "explicit stop retries cleanup removal and settles retained waiters once");
    } else if (scenario == "allocation-failure") {
        fail_copy=true; { oracle::Host host; Feed(1,1); } auto* f=Start(); Pause();
        Check(Status()==101 && responses==1 && invocations.empty(), "actual native copied-string allocation failure latches Allocation without replay");
        Finish(f);
    } else if (scenario == "success" || scenario == "stress" || scenario == "pause-js" || scenario == "pause-ack") {
        const unsigned fixture_count = scenario == "stress" ? 512 : 24;
        { oracle::Host host; Feed(1, fixture_count); }
        auto* f = Start();
        Check(Wait([] { return !wakes.empty(); }), "producer reaches notification boundary");
        Pause();
        Check(Stat("outstandingBatches") == 4 && Stat("nativeQueuedBatches") == 4,
            "paused JS fills four authoritative outstanding credits");
        { std::lock_guard<std::mutex> lock(boundary_mutex);
          Check(responses == 4 && wakes.size() == 1, "paused JS stops receive and holds one physical notification"); }
        { oracle::Host host; args_override = {Num(0.001)}; }
        Check(tdlib_napi::Receive(env_handle, nullptr) == nullptr, "public receive rejects while dedicated loop owns TDLib reception");
        args_override.clear(); throws=0;
        Pump(4, false); Pause();
        Check(invocations.size() == 4 && Stat("admittedBatches") == 4 && Stat("outstandingBatches") == 4,
            "successful admission retains all credits until consumption ACK");
        const auto first = invocations.front();
        Check(!Ack(first.epoch + 1, first.id) && !Ack(first.epoch, first.id + 100) &&
            !Ack(first.epoch, 0) && !Ack(first.epoch, 1.5) && !Ack(first.epoch, 9007199254740992.0),
            "wrong epoch id and unsafe numeric ACK do not alter ledger");
        Check(Stat("outstandingBatches") == 4, "invalid ACK retains four charges");
        for (const auto& call : invocations) Check(Ack(call.epoch, call.id), "consumption returns one admitted credit");
        Check(!Ack(first.epoch, first.id), "duplicate ACK never returns credit twice");
        Pump(fixture_count - 4);
        bool exact = invocations.size() == fixture_count;
        for (size_t i = 0; exact && i < invocations.size(); ++i) exact &= invocations[i].batch == Batch(static_cast<unsigned>(i + 1));
        Check(exact, "success: exact once and FIFO long JSON batches");
        Bounds(); Finish(f, scenario == "pause-ack");
        Check(!Ack(first.epoch, first.id), "ACK after stop cannot revive a retired charge");
    } else if (scenario == "submit-lease") {
        pause_before_submit = true;
        { oracle::Host host; Feed(1, 8); }
        auto* f = Start();
        Check(Wait([]{ return before_submit_parked; }), "producer admitted a submission before entering NAPI");
        auto* promise = static_cast<Promise*>(tdlib_napi::StopReceiveLoop(env_handle, nullptr));
        cleanup_callback(cleanup_handle, cleanup_data);
        Check(cleanup_removes == 0 && promise->resolved == 0 && uv_works.size() == 1 && !Flag("producerJoined"),
            "close returns without waiting but cannot retire an admitted submission lease");
        { std::lock_guard<std::mutex> lock(boundary_mutex); resume_before_submit = true; changed.notify_all(); }
        CompleteWork(); Drain(); Finalize(f);
        Check(attempts.size() == 1 && invocations.empty() && responses == 1,
            "only pre-close admitted NAPI call completes; no new submission or JS admission follows close");
        Check(cleanup_removes == 1 && promise->resolved == 0 && Flag("producerJoined") && Flag("tsfnFinalized"),
            "cleanup retires once after admitted submission producer and callbacks retire without JS settlement");
    } else if (scenario == "batch-count" || scenario == "target-bytes") {
        batch_separator_enabled = false;
        { oracle::Host host; std::lock_guard<std::mutex> lock(boundary_mutex);
          if (scenario == "batch-count") for (int i=0;i<51;++i) input.push_back("0");
          else for (int i=0;i<3;++i) input.push_back("\"" + std::string(150000,'x') + "\""); }
        auto* f=Start(); Pump(scenario == "batch-count" ? 2 : 3);
        if(scenario == "batch-count") Check(invocations.size()==2 && invocations[0].bytes==101 && invocations[1].bytes==3,
            "fifty-response bound includes all commas and brackets without losing response51");
        else Check(invocations.size()==3 && invocations[0].bytes==150004 && invocations[1].bytes==150004 && Stat("peakLookaheadBytes")==150002,
            "target crossing flushes builder while retaining exactly one owned next response");
        Bounds(); Finish(f);
    } else if (scenario == "bytes" || scenario == "oversize" || scenario == "unicode") {
        { oracle::Host host; std::lock_guard<std::mutex> lock(boundary_mutex);
          if (scenario == "bytes") for (int i = 0; i < 3; ++i) input.push_back("\"" + std::string(8388604, 'x') + "\"");
          else if (scenario == "oversize") input.push_back("\"" + std::string(8388605, 'x') + "\"");
          else { input.push_back("{\"text\":\"\xF0\x9F\x98\x80\xC3\xA9\"}"); batch_separator_enabled = false; }
        }
        auto* f = Start();
        // Wait for the observable production state, not a machine-speed sleep.
        // Instrumented 8MiB copies can exceed the old 180ms fixture delay.
        for (unsigned spin=0; spin<1500 && Status()==1 &&
            (scenario=="bytes" ? Stat("outstandingBytes")<16777216 : scenario=="oversize"); ++spin) Pause(2);
        if (scenario == "bytes") {
            Check(Stat("outstandingBytes") == 16777216 && Stat("outstandingBatches") == 2,
                "8MiB framed batches stop precisely at 16MiB byte window");
            Check(responses == 2, "byte-window pause performs no third TDLib receive");
            Pump(3); Check(invocations.size() == 3, "byte-window resumes losslessly after ACK");
        } else if (scenario == "oversize") {
            Check(Status() == 100 && invocations.empty() && Stat("peakLookaheadBytes") == 0,
                "one byte over framed response limit faults before copying or invoking JS");
        } else {
            Pump(1); Check(invocations.size() == 1 && invocations[0].bytes == 19 && invocations[0].batch.size() == 19,
                "Unicode metadata counts UTF8 bytes and both framing brackets");
        }
        Bounds(); Finish(f);
    } else if (scenario == "string-failure" || scenario == "receiver-failure" || scenario == "marshal-permanent" || scenario == "pending-exception") {
        { oracle::Host host; Feed(1, 2); }
        auto* f = Start(); Check(Wait([] { return !wakes.empty(); }), "marshalling fixture receives first wake");
        if (scenario == "receiver-failure") receiver_status = napi_generic_failure;
        else string_status = napi_generic_failure;
        pending_exception = scenario == "pending-exception";
        Wake wake{}; Pop(wake); Deliver(wake);
        Check(invocations.empty(), "pre-JS conversion failure has no callback side effect");
        if (scenario == "pending-exception") Check(Status() == 102, "pending exception is terminal and never cleared for retry");
        else if (scenario == "marshal-permanent") {
            for (int i = 0; i < 2; ++i) { Check(Wait([] { return !wakes.empty(); }), "paced retry schedules retained front"); Pop(wake); Deliver(wake); }
            Check(Status() == 102 && Stat("marshalRetries") == 2, "third failed marshalling attempt latches terminal fault");
            Pause(); Check(attempts.size() == 3, "permanent conversion failure cannot retry a fourth time");
        } else {
            Check(Stat("outstandingBatches") >= 1 && Stat("marshalRetries") == 1, "transient conversion retains front charge");
            string_status = receiver_status = napi_ok;
            Pump(2);
            Check(invocations.size() == 2 && invocations[0].batch == Batch(1) && invocations[1].batch == Batch(2),
                "transient conversion preserves exact FIFO payload instead of dropping first batch");
            if (attempts.size() >= 2) Check(std::chrono::duration_cast<std::chrono::milliseconds>(attempts[1].time-attempts[0].time).count() >= 40,
                "pre-JS retry is paced by non-owner producer");
        }
        string_status = receiver_status = napi_ok; pending_exception = false;
        Bounds(); Finish(f);
    } else if (scenario == "reject-before" || scenario == "reject-after" || scenario == "reject-after-drain" || scenario == "reject-always" || scenario == "queue-full" || scenario == "closing" || scenario == "invalid-handle") {
        mode = scenario == "reject-after" || scenario == "reject-after-drain" ? Mode::RejectAfter : Mode::RejectBefore;
        if (scenario == "queue-full") rejection_status = napi_queue_full;
        if (scenario == "reject-always") mode = Mode::RejectAlways;
        if (scenario == "closing" || scenario == "invalid-handle") { mode = Mode::Closing; terminal_status = scenario == "closing" ? napi_closing : napi_invalid_arg; }
        park_after_insert = scenario == "reject-after-drain";
        { oracle::Host host; Feed(1, 8); }
        auto* f = Start();
        if (park_after_insert) {
            Check(Wait([] { return insertion_parked; }), "ambiguous insertion can execute before enqueue returns");
            Wake wake{}; Check(Pop(wake), "ambiguous insertion physically queued a wake"); Deliver(wake);
            { std::lock_guard<std::mutex> lock(boundary_mutex); resume_insert = true; changed.notify_all(); }
        }
        Pause();
        if (scenario == "queue-full") {
            Pump(8); Check(invocations.size() == 8 && Stat("notifyRetries") == 1, "known queue-full retries cancellably without payload loss");
        } else {
            Check(Status() == 103 && attempts.size() == 1, "ambiguous or terminal notification fault never resubmits uncertain wake");
            Check(invocations.size() <= 1 && responses <= 1, "notification fault stops consumption without replay or read-ahead");
        }
        Bounds(); Finish(f);
        Check(after_close == 0 && releases_after_close == 0, "terminal status ends handle use and extra release");
    } else if (scenario == "js-failure" || scenario == "js-false" || scenario == "js-nonboolean" || scenario == "js-reentry") {
        { oracle::Host host; Feed(1, 4); }
        auto* f = Start(); Check(Wait([] { return !wakes.empty(); }), "JS fault fixture reaches admission");
        function_status = scenario == "js-failure" ? napi_generic_failure : napi_ok;
        callback_accepts = scenario != "js-false";
        callback_boolean = scenario != "js-nonboolean";
        reenter_from_js = scenario == "js-reentry";
        Wake wake{}; Pop(wake); Deliver(wake); Pause();
        if (scenario == "js-reentry") {
            Check(Stat("nativeQueuedBatches") == 0 && Stat("admittedBatches") == 0 && Stat("admittedBytes") == 0,
                "callback return after stop cannot transiently resurrect cancelled ledger counters");
            Check(reentrant_promise && !reentrant_promise->resolved, "callback stop reentry keeps finalization barrier pending");
            CompleteWork(); Drain(); Finalize(f);
            Check(reentrant_promise->resolved == 1 && Stat("outstandingBatches") == 0, "admission return cannot resurrect cancelled owner");
        } else {
            Check(Status() == (scenario == "js-failure" ? 105 : 104), "JS throw false or nonboolean latches distinct admission fault");
            Drain(); Check(invocations.size() == 1, "partly effective JS invocation is never replayed"); Finish(f);
        }
        Bounds();
    } else if (scenario == "null-env" || scenario == "restart" || scenario == "lifecycle" || scenario == "cleanup" || scenario == "queue-failure" || scenario == "cancel-work" || scenario == "thread-failure") {
        if (scenario == "thread-failure") fail_thread_start = true;
        if (scenario == "thread-failure") {
            const auto value = tdlib_napi::StartReceiveLoop(env_handle, nullptr);
            Check(!value && throws == 1 && responses == 0, "native thread constructor failure never starts TDLib consumption");
            fail_thread_start = false;
            Finalize(functions.back().get());
            Check(Flag("producerJoined") && Flag("tsfnFinalized"), "constructor rollback still requires TSFN finalizer retirement");
        } else {
            { oracle::Host host; Feed(1, 8); } auto* f = Start(); Pause();
            const double epoch = Stat("epoch");
            if (scenario == "cleanup") {
                auto* p = static_cast<Promise*>(tdlib_napi::StopReceiveLoop(env_handle, nullptr));
                cleanup_callback(cleanup_handle, cleanup_data);
                CompleteWork(); Drain(); Finalize(f);
                Check(p->resolved == 0 && p->rejected == 0 && cleanup_removes == 1, "env cleanup shares join/finalizer gate without settling dying JS waiters");
            } else if (scenario == "queue-failure" || scenario == "cancel-work") {
                uv_queue_failure = scenario == "queue-failure"; uv_cancel = scenario == "cancel-work";
                auto* p = static_cast<Promise*>(tdlib_napi::StopReceiveLoop(env_handle, nullptr));
                CompleteWork();
                Check(p->rejected == 1 && Status() == 107 && cleanup_removes == 0, "control queue failure or cancellation retains owner and cleanup barrier");
                uv_queue_failure = uv_cancel = false; Finish(f);
            } else {
                auto* p = static_cast<Promise*>(tdlib_napi::StopReceiveLoop(env_handle, nullptr));
                auto* second = static_cast<Promise*>(tdlib_napi::StopReceiveLoop(env_handle, nullptr));
                Check(uv_works.size() == 1 && !p->resolved && !second->resolved, "concurrent stops share exactly one off-owner join");
                const auto busy = tdlib_napi::StartReceiveLoop(env_handle, nullptr);
                Check(!busy, "restart cannot bypass pending owner barrier"); throws = 0;
                CompleteWork(); Check(!p->resolved, "join completion alone cannot retire callbacks");
                Drain(); Finalize(f);
                Check(p->resolved == 1 && second->resolved == 1, "both stop waiters resolve after finalizer");
                const auto before = invalid_api;
                Deliver({f, nullptr}, nullptr, false, true); Deliver({f, nullptr}, env_handle, true, true);
                Check(invalid_api == before, "null env/callback never dereferences finalized context");
                if (scenario == "restart") {
                    { oracle::Host host; input.clear(); Feed(20, 1); }
                    auto* fresh = Start(); Pump(1);
                    Check(Stat("epoch") > epoch && !Ack(epoch, 1), "restart advances epoch and rejects stale ACK"); Finish(fresh);
                }
            }
        }
    } else return 2;
    if (!attempts.empty()) TransportContract();
    Check(invalid_api == 0, "all marshalling and completion APIs run on fixture owner thread");
    HeapCheck(); oracle::enabled = false;
    std::printf("SUMMARY %u passed, %u failed\n", passed, failed);
    return failed ? 1 : 0;
}
