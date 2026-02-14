#include "tdlib_napi.h"
#include "napi/native_api.h"

static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        { "createClient", nullptr, tdlib_napi::CreateClient, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "send", nullptr, tdlib_napi::Send, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "receive", nullptr, tdlib_napi::Receive, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "execute", nullptr, tdlib_napi::Execute, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "startReceiveLoop", nullptr, tdlib_napi::StartReceiveLoop, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "stopReceiveLoop", nullptr, tdlib_napi::StopReceiveLoop, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getTdlibInfo", nullptr, tdlib_napi::GetTdlibInfo, nullptr, nullptr, nullptr, napi_default, nullptr },
    };

    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

EXTERN_C_START
static napi_module tdlib_module = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "tdlib_napi",
    .nm_priv = nullptr,
    .reserved = { 0 },
};

__attribute__((constructor))
void RegisterTDLibModule(void) {
    napi_module_register(&tdlib_module);
}
EXTERN_C_END
