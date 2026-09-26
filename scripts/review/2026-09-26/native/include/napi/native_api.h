#pragma once

// Minimal host declarations for this review harness, not an SDK compatibility layer.
#include <cstddef>
#include <cstdint>

using napi_env = void*;
using napi_value = void*;
using napi_callback_info = void*;
using napi_threadsafe_function = void*;
enum napi_status { napi_ok, napi_generic_failure, napi_closing };
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
    napi_env, napi_value, napi_value, napi_value, size_t, size_t, void*, void*, void*,
    void (*)(napi_env, napi_value, void*, void*), napi_threadsafe_function*);
napi_status napi_call_threadsafe_function(
    napi_threadsafe_function, void*, napi_threadsafe_function_call_mode);
napi_status napi_release_threadsafe_function(
    napi_threadsafe_function, napi_threadsafe_function_release_mode);
