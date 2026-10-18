#pragma once
// Host-only fault injection boundary; not an implementation of HarmonyOS N-API.
#include <cstddef>
#include <cstdint>
using napi_env = void*;
using napi_value = void*;
using napi_callback_info = void*;
using napi_threadsafe_function = void*;
using napi_deferred = void*;
using napi_async_work = void*;
enum napi_status { napi_ok, napi_generic_failure, napi_closing, napi_cancelled, napi_queue_full, napi_invalid_arg };
using napi_finalize = void (*)(napi_env, void*, void*);
using napi_async_execute_callback = void (*)(napi_env, void*);
using napi_async_complete_callback = void (*)(napi_env, napi_status, void*);
enum napi_valuetype {
    napi_undefined, napi_null, napi_boolean, napi_number, napi_string,
    napi_symbol, napi_object, napi_function
};
enum napi_threadsafe_function_call_mode { napi_tsfn_nonblocking, napi_tsfn_blocking };
enum napi_threadsafe_function_release_mode { napi_tsfn_release, napi_tsfn_abort };
#define NAPI_AUTO_LENGTH SIZE_MAX
napi_status napi_throw_error(napi_env, const char*, const char*);
napi_status napi_typeof(napi_env, napi_value, napi_valuetype*);
napi_status napi_create_int32(napi_env, int32_t, napi_value*);
napi_status napi_get_cb_info(napi_env, napi_callback_info, size_t*, napi_value*, napi_value*, void**);
napi_status napi_get_value_int32(napi_env, napi_value, int32_t*);
napi_status napi_get_value_double(napi_env, napi_value, double*);
napi_status napi_get_value_string_utf8(napi_env, napi_value, char*, size_t, size_t*);
napi_status napi_get_undefined(napi_env, napi_value*);
napi_status napi_get_null(napi_env, napi_value*);
napi_status napi_create_string_utf8(napi_env, const char*, size_t, napi_value*);
napi_status napi_call_function(napi_env, napi_value, napi_value, size_t, const napi_value*, napi_value*);
napi_status napi_create_threadsafe_function(
    napi_env, napi_value, napi_value, napi_value, size_t, size_t, void*, napi_finalize, void*,
    void (*)(napi_env, napi_value, void*, void*), napi_threadsafe_function*);
napi_status napi_call_threadsafe_function(
    napi_threadsafe_function, void*, napi_threadsafe_function_call_mode);
napi_status napi_release_threadsafe_function(
    napi_threadsafe_function, napi_threadsafe_function_release_mode);
napi_status napi_create_promise(napi_env, napi_deferred*, napi_value*);
napi_status napi_resolve_deferred(napi_env, napi_deferred, napi_value);
napi_status napi_reject_deferred(napi_env, napi_deferred, napi_value);
napi_status napi_create_error(napi_env, napi_value, napi_value, napi_value*);
napi_status napi_create_async_work(napi_env, napi_value, napi_value,
    napi_async_execute_callback, napi_async_complete_callback, void*, napi_async_work*);
napi_status napi_queue_async_work(napi_env, napi_async_work);
napi_status napi_delete_async_work(napi_env, napi_async_work);

struct uv_loop_s; using uv_loop_t = uv_loop_s;
using napi_async_cleanup_hook_handle = void*;
using napi_async_cleanup_hook = void (*)(napi_async_cleanup_hook_handle, void*);
napi_status napi_create_double(napi_env, double, napi_value*);
napi_status napi_get_boolean(napi_env, bool, napi_value*);
napi_status napi_get_value_bool(napi_env, napi_value, bool*);
napi_status napi_create_object(napi_env, napi_value*);
napi_status napi_set_named_property(napi_env, napi_value, const char*, napi_value);
napi_status napi_is_exception_pending(napi_env, bool*);
napi_status napi_get_uv_event_loop(napi_env, uv_loop_t**);
napi_status napi_add_async_cleanup_hook(napi_env, napi_async_cleanup_hook, void*, napi_async_cleanup_hook_handle*);
napi_status napi_remove_async_cleanup_hook(napi_async_cleanup_hook_handle);
