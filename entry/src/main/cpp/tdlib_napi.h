#ifndef TDLIB_NAPI_H
#define TDLIB_NAPI_H

#include "napi/native_api.h"

// TDLib JSON client interface
// When TDLib is built and available, these call the real td_json_client functions.
// In stub mode, they return mock responses for development.

namespace tdlib_napi {

// Create a new TDLib client instance, returns client_id
napi_value CreateClient(napi_env env, napi_callback_info info);

// Send a JSON request to TDLib
// Args: (string request_json)
napi_value Send(napi_env env, napi_callback_info info);

// Receive a JSON response from TDLib (blocking with timeout)
// Args: (double timeout_seconds)
// Returns: string | null
napi_value Receive(napi_env env, napi_callback_info info);

// Execute a synchronous TDLib request
// Args: (string request_json)
// Returns: string
napi_value Execute(napi_env env, napi_callback_info info);

// Start the receive loop on a background thread.
// Calls a threadsafe callback for each response.
// Args: (function callback)
napi_value StartReceiveLoop(napi_env env, napi_callback_info info);

// Stop the receive loop
napi_value StopReceiveLoop(napi_env env, napi_callback_info info);

} // namespace tdlib_napi

#endif // TDLIB_NAPI_H
