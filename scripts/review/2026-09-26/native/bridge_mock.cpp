// Historical audit reproduction for baseline 2d2f683 (2026-09-26).
// Compiles the production implementation unchanged with minimal host mocks.
// Assertions expect the reported defects; they must change after production fixes.
// This establishes C++ control flow/ownership, not HarmonyOS ABI integration,
// SDK failure frequency, a live-device latency bound, or a queue-full deadlock.
#include <atomic>
#include <cassert>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <thread>
#include "napi/native_api.h"

static bool fail_create = false;
static void* tracked_allocation = nullptr;
static bool tracked_deleted = false;
static std::atomic<bool> slow_stream{false};
static std::atomic<bool> entered_receive{false};
static std::atomic<bool> begin_timed_receive{false};
static std::atomic<int> receive_calls{0};
static std::atomic<int> enqueue_calls{0};
static size_t queue_limit = 1;
static void* marker = reinterpret_cast<void*>(1);

// Used only by the single-threaded null-env probe. The harness then frees the
// payload explicitly, so reproducing production's missing delete leaks nothing.
void operator delete(void* pointer) noexcept {
    if (pointer == tracked_allocation) tracked_deleted = true;
    std::free(pointer);
}
void operator delete(void* pointer, std::size_t) noexcept {
    if (pointer == tracked_allocation) tracked_deleted = true;
    std::free(pointer);
}

napi_status napi_throw_error(napi_env, const char*, const char*) { return napi_ok; }
napi_status napi_typeof(napi_env, napi_value, napi_valuetype* value) {
    *value = napi_function;
    return napi_ok;
}
napi_status napi_create_int32(napi_env, int32_t, napi_value* value) {
    *value = marker;
    return napi_ok;
}
napi_status napi_get_cb_info(napi_env, napi_callback_info, size_t* argc,
                            napi_value* argv, napi_value*, void**) {
    *argc = 1;
    argv[0] = marker;
    return napi_ok;
}
napi_status napi_get_value_int32(napi_env, napi_value, int32_t* value) {
    *value = 1;
    return napi_ok;
}
napi_status napi_get_value_double(napi_env, napi_value, double* value) {
    *value = 0;
    return napi_ok;
}
napi_status napi_get_value_string_utf8(napi_env, napi_value, char*, size_t, size_t* length) {
    *length = 0;
    return napi_ok;
}
napi_status napi_get_undefined(napi_env, napi_value* value) {
    *value = marker;
    return napi_ok;
}
napi_status napi_get_null(napi_env, napi_value* value) {
    *value = nullptr;
    return napi_ok;
}
napi_status napi_create_string_utf8(napi_env, const char*, size_t, napi_value* value) {
    *value = marker;
    return napi_ok;
}
napi_status napi_call_function(napi_env, napi_value, napi_value, size_t,
                               const napi_value*, napi_value*) { return napi_ok; }
napi_status napi_create_threadsafe_function(
    napi_env, napi_value, napi_value, napi_value, size_t max_queue_size, size_t,
    void*, void*, void*, void (*)(napi_env, napi_value, void*, void*),
    napi_threadsafe_function* callback) {
    queue_limit = max_queue_size;
    if (fail_create) return napi_generic_failure;
    *callback = marker;
    return napi_ok;
}
napi_status napi_call_threadsafe_function(napi_threadsafe_function, void* data,
                                         napi_threadsafe_function_call_mode) {
    ++enqueue_calls;
    // Model successful ownership transfer only; no real SDK callback queue.
    delete static_cast<std::string*>(data);
    return napi_ok;
}
napi_status napi_release_threadsafe_function(
    napi_threadsafe_function, napi_threadsafe_function_release_mode) { return napi_ok; }

int td_create_client_id() { return 1; }
void td_send(int, const char*) {}
const char* td_execute(const char*) { return nullptr; }
const char* td_receive(double timeout) {
    const int call = ++receive_calls;
    entered_receive = true;
    if (slow_stream) {
        if (call == 1) {
            // Align the model with the caller's stop timer, regardless of how
            // long the host takes to schedule that caller initially.
            while (!begin_timed_receive.load()) std::this_thread::yield();
        }
        // Model one update arriving just before each requested poll timeout.
        std::this_thread::sleep_for(
            std::chrono::milliseconds(static_cast<int>(timeout * 1000) - 1));
    } else {
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    return "{}";
}

#include "../../../../entry/src/main/cpp/tdlib_napi.cpp"

static void ReproduceNullEnvPayloadLeak() {
    auto* payload = new std::string(4096, 'x');
    tracked_allocation = payload;
    tracked_deleted = false;
    tdlib_napi::CallJs(nullptr, nullptr, nullptr, payload);
    std::printf("Null-env callback deleted payload: %s\n", tracked_deleted ? "yes" : "no");
    assert(!tracked_deleted);
    delete payload;
    assert(tracked_deleted);
    tracked_allocation = nullptr;
}

static void ReproduceCallbackCreationFailure() {
    fail_create = true;
    tdlib_napi::StartReceiveLoop(marker, nullptr);
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    while (receive_calls.load() < 50 && std::chrono::steady_clock::now() < deadline) {
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    const bool incorrectly_running = loop_state == LoopState::Running;
    const bool missing_callback = threadsafe_callback == nullptr;
    const int drained = receive_calls.load();
    tdlib_napi::StopReceiveLoop(marker, nullptr);
    std::printf("TSFN create failure: Running=%s, callback missing=%s; "
                "drained %d responses, enqueued %d\n",
                incorrectly_running ? "yes" : "no", missing_callback ? "yes" : "no",
                drained, enqueue_calls.load());
    assert(incorrectly_running && missing_callback);
    assert(drained >= 50 && enqueue_calls.load() == 0);
}

static void ReproduceSynchronousStopDelay() {
    fail_create = false;
    slow_stream = true;
    entered_receive = false;
    begin_timed_receive = false;
    receive_calls = 0;
    tdlib_napi::StartReceiveLoop(marker, nullptr);
    while (!entered_receive.load()) std::this_thread::yield();
    const auto start = std::chrono::steady_clock::now();
    begin_timed_receive = true;
    tdlib_napi::StopReceiveLoop(marker, nullptr);
    const auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now() - start).count();
    std::printf("StopReceiveLoop caller blocked %lld ms; total receives=%d; "
                "TSFN max queue size=%zu (unbounded, not a queue-full deadlock)\n",
                static_cast<long long>(elapsed), receive_calls.load(), queue_limit);
    assert(elapsed >= 3300);
    assert(receive_calls.load() == 50 && queue_limit == 0);
}

int main() {
    ReproduceNullEnvPayloadLeak();
    ReproduceCallbackCreationFailure();
    ReproduceSynchronousStopDelay();
    std::puts("Historical native defect reproductions matched the reviewed baseline.");
}
