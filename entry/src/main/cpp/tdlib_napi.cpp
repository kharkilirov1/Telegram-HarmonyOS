#include "tdlib_napi.h"
#include <string>
#include <thread>
#include <atomic>
#include <queue>
#include <mutex>
#include <hilog/log.h>

#ifndef TDLIB_STUB
#include <td/telegram/td_json_client.h>
#else
// Stub mode: simulates TDLib responses for development without the real binary
static int stub_client_id = 0;
static std::queue<std::string> stub_response_queue;
static std::mutex stub_queue_mutex;
static std::atomic<bool> stub_auth_sent{false};

// Push a mock response into the queue
static void stub_enqueue(const std::string& json) {
    std::lock_guard<std::mutex> lock(stub_queue_mutex);
    stub_response_queue.push(json);
}

// Pop a mock response (returns empty if none)
static std::string stub_dequeue() {
    std::lock_guard<std::mutex> lock(stub_queue_mutex);
    if (stub_response_queue.empty()) return "";
    std::string front = stub_response_queue.front();
    stub_response_queue.pop();
    return front;
}

// Generate initial auth state update
static void stub_send_initial_auth() {
    if (stub_auth_sent.exchange(true)) return;
    stub_enqueue(R"({"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateWaitTdlibParameters"}})");
}

// Handle stub send: parse the request type and queue appropriate mock responses
static void stub_handle_send(const std::string& request) {
    // Simple pattern matching for method types
    if (request.find("\"setTdlibParameters\"") != std::string::npos) {
        stub_enqueue(R"({"@type":"ok"})");
        stub_enqueue(R"({"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateWaitPhoneNumber"}})");
    }
    else if (request.find("\"setAuthenticationPhoneNumber\"") != std::string::npos) {
        // Extract @extra for request-response correlation
        std::string extra_str;
        auto pos = request.find("\"@extra\"");
        if (pos != std::string::npos) {
            auto colon = request.find(':', pos);
            auto comma = request.find(',', colon);
            auto brace = request.find('}', colon);
            auto end = (comma != std::string::npos && comma < brace) ? comma : brace;
            extra_str = request.substr(colon + 1, end - colon - 1);
        }
        stub_enqueue("{\"@type\":\"ok\",\"@extra\":" + extra_str + "}");
        stub_enqueue(R"({"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateWaitCode","code_info":{"@type":"authenticationCodeInfo","phone_number":"+1234567890","type":{"@type":"authenticationCodeTypeSms","length":5}}}})");
    }
    else if (request.find("\"checkAuthenticationCode\"") != std::string::npos) {
        std::string extra_str;
        auto pos = request.find("\"@extra\"");
        if (pos != std::string::npos) {
            auto colon = request.find(':', pos);
            auto comma = request.find(',', colon);
            auto brace = request.find('}', colon);
            auto end = (comma != std::string::npos && comma < brace) ? comma : brace;
            extra_str = request.substr(colon + 1, end - colon - 1);
        }
        stub_enqueue("{\"@type\":\"ok\",\"@extra\":" + extra_str + "}");
        stub_enqueue(R"({"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateReady"}})");
        // After auth: send mock user and chats
        stub_enqueue(R"({"@type":"updateUser","user":{"@type":"user","id":100001,"first_name":"Alice","last_name":"Smith","username":"alice","phone_number":"1234567890","status":{"@type":"userStatusOnline"}}})");
        stub_enqueue(R"({"@type":"updateUser","user":{"@type":"user","id":100002,"first_name":"Bob","last_name":"Johnson","username":"bob_j","phone_number":"9876543210","status":{"@type":"userStatusOffline","was_online":1700000000}}})");
        stub_enqueue(R"({"@type":"updateUser","user":{"@type":"user","id":100003,"first_name":"Charlie","last_name":"Brown","username":"charlie","phone_number":"5551234567","status":{"@type":"userStatusRecently"}}})");
        stub_enqueue(R"({"@type":"updateNewChat","chat":{"@type":"chat","id":-1001,"title":"Alice Smith","type":{"@type":"chatTypePrivate","user_id":100001},"last_message":{"@type":"message","id":1001,"sender_id":{"@type":"messageSenderUser","user_id":100001},"date":1700001000,"content":{"@type":"messageText","text":{"@type":"formattedText","text":"Hey! How are you?"}}},"unread_count":2,"positions":[{"@type":"chatPosition","list":{"@type":"chatListMain"},"order":"6900001000","is_pinned":false}],"notification_settings":{"@type":"chatNotificationSettings","mute_for":0}}})");
        stub_enqueue(R"({"@type":"updateNewChat","chat":{"@type":"chat","id":-1002,"title":"Bob Johnson","type":{"@type":"chatTypePrivate","user_id":100002},"last_message":{"@type":"message","id":2001,"sender_id":{"@type":"messageSenderUser","user_id":100002},"date":1700000500,"content":{"@type":"messageText","text":{"@type":"formattedText","text":"See you tomorrow!"}}},"unread_count":0,"positions":[{"@type":"chatPosition","list":{"@type":"chatListMain"},"order":"6900000500","is_pinned":false}],"notification_settings":{"@type":"chatNotificationSettings","mute_for":0}}})");
        stub_enqueue(R"({"@type":"updateNewChat","chat":{"@type":"chat","id":-1003,"title":"HarmonyOS Devs","type":{"@type":"chatTypeSupergroup","supergroup_id":5001,"is_channel":false},"last_message":{"@type":"message","id":3001,"sender_id":{"@type":"messageSenderUser","user_id":100003},"date":1700000800,"content":{"@type":"messageText","text":{"@type":"formattedText","text":"Has anyone tried the new API 22?"}}},"unread_count":15,"positions":[{"@type":"chatPosition","list":{"@type":"chatListMain"},"order":"6900000800","is_pinned":true}],"notification_settings":{"@type":"chatNotificationSettings","mute_for":0}}})");
        stub_enqueue(R"({"@type":"updateNewChat","chat":{"@type":"chat","id":-1004,"title":"Tech News","type":{"@type":"chatTypeSupergroup","supergroup_id":5002,"is_channel":true},"last_message":{"@type":"message","id":4001,"sender_id":{"@type":"messageSenderUser","user_id":0},"date":1700000200,"content":{"@type":"messageText","text":{"@type":"formattedText","text":"Breaking: HarmonyOS 6.0 officially released worldwide"}}},"unread_count":5,"positions":[{"@type":"chatPosition","list":{"@type":"chatListMain"},"order":"6900000200","is_pinned":false}],"notification_settings":{"@type":"chatNotificationSettings","mute_for":604800}}})");
    }
    else if (request.find("\"loadChats\"") != std::string::npos) {
        std::string extra_str;
        auto pos = request.find("\"@extra\"");
        if (pos != std::string::npos) {
            auto colon = request.find(':', pos);
            auto comma = request.find(',', colon);
            auto brace = request.find('}', colon);
            auto end = (comma != std::string::npos && comma < brace) ? comma : brace;
            extra_str = request.substr(colon + 1, end - colon - 1);
        }
        stub_enqueue("{\"@type\":\"ok\",\"@extra\":" + extra_str + "}");
    }
    else if (request.find("\"getContacts\"") != std::string::npos) {
        std::string extra_str;
        auto pos = request.find("\"@extra\"");
        if (pos != std::string::npos) {
            auto colon = request.find(':', pos);
            auto comma = request.find(',', colon);
            auto brace = request.find('}', colon);
            auto end = (comma != std::string::npos && comma < brace) ? comma : brace;
            extra_str = request.substr(colon + 1, end - colon - 1);
        }
        stub_enqueue("{\"@type\":\"users\",\"total_count\":3,\"user_ids\":[100001,100002,100003],\"@extra\":" + extra_str + "}");
    }
    else if (request.find("\"getUser\"") != std::string::npos) {
        std::string extra_str;
        auto pos = request.find("\"@extra\"");
        if (pos != std::string::npos) {
            auto colon = request.find(':', pos);
            auto comma = request.find(',', colon);
            auto brace = request.find('}', colon);
            auto end = (comma != std::string::npos && comma < brace) ? comma : brace;
            extra_str = request.substr(colon + 1, end - colon - 1);
        }
        // Return a generic user; real ID-based lookup would be more complex
        int user_id = 100001;
        auto uid_pos = request.find("\"user_id\"");
        if (uid_pos != std::string::npos) {
            auto colon = request.find(':', uid_pos);
            user_id = std::stoi(request.substr(colon + 1));
        }
        std::string name = "User";
        if (user_id == 100001) name = "Alice";
        else if (user_id == 100002) name = "Bob";
        else if (user_id == 100003) name = "Charlie";
        stub_enqueue("{\"@type\":\"user\",\"id\":" + std::to_string(user_id) +
            ",\"first_name\":\"" + name + "\",\"last_name\":\"Mock\",\"username\":\"" +
            name + "_mock\",\"phone_number\":\"1234567890\",\"status\":{\"@type\":\"userStatusOffline\",\"was_online\":1700000000},\"@extra\":" +
            extra_str + "}");
    }
    else if (request.find("\"getChatHistory\"") != std::string::npos) {
        std::string extra_str;
        auto pos = request.find("\"@extra\"");
        if (pos != std::string::npos) {
            auto colon = request.find(':', pos);
            auto comma = request.find(',', colon);
            auto brace = request.find('}', colon);
            auto end = (comma != std::string::npos && comma < brace) ? comma : brace;
            extra_str = request.substr(colon + 1, end - colon - 1);
        }
        stub_enqueue("{\"@type\":\"messages\",\"total_count\":2,\"messages\":[{\"@type\":\"message\",\"id\":9001,\"chat_id\":-1001,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":100001},\"date\":1700000900,\"is_outgoing\":false,\"content\":{\"@type\":\"messageText\",\"text\":{\"@type\":\"formattedText\",\"text\":\"Hello from stub!\"}}},{\"@type\":\"message\",\"id\":9002,\"chat_id\":-1001,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":0},\"date\":1700000950,\"is_outgoing\":true,\"content\":{\"@type\":\"messageText\",\"text\":{\"@type\":\"formattedText\",\"text\":\"Hi! Stub reply.\"}}}],\"@extra\":" + extra_str + "}");
    }
    else if (request.find("\"searchCallMessages\"") != std::string::npos) {
        std::string extra_str;
        auto pos = request.find("\"@extra\"");
        if (pos != std::string::npos) {
            auto colon = request.find(':', pos);
            auto comma = request.find(',', colon);
            auto brace = request.find('}', colon);
            auto end = (comma != std::string::npos && comma < brace) ? comma : brace;
            extra_str = request.substr(colon + 1, end - colon - 1);
        }
        stub_enqueue("{\"@type\":\"messages\",\"total_count\":2,\"messages\":[{\"@type\":\"message\",\"id\":8001,\"chat_id\":-1001,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":100001},\"date\":1700000600,\"is_outgoing\":false,\"content\":{\"@type\":\"messageCall\",\"is_video\":false,\"duration\":120,\"discard_reason\":{\"@type\":\"callDiscardReasonHungUp\"}}},{\"@type\":\"message\",\"id\":8002,\"chat_id\":-1002,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":100002},\"date\":1700000100,\"is_outgoing\":true,\"content\":{\"@type\":\"messageCall\",\"is_video\":true,\"duration\":0,\"discard_reason\":{\"@type\":\"callDiscardReasonMissed\"}}}],\"@extra\":" + extra_str + "}");
    }
    else {
        // Default: send ok for any unhandled request
        std::string extra_str;
        auto pos = request.find("\"@extra\"");
        if (pos != std::string::npos) {
            auto colon = request.find(':', pos);
            auto comma = request.find(',', colon);
            auto brace = request.find('}', colon);
            auto end = (comma != std::string::npos && comma < brace) ? comma : brace;
            extra_str = request.substr(colon + 1, end - colon - 1);
        }
        if (!extra_str.empty()) {
            stub_enqueue("{\"@type\":\"ok\",\"@extra\":" + extra_str + "}");
        }
    }
}
#endif

#define LOG_TAG "TDLibNAPI"
#define LOG_DOMAIN 0x0001

static std::atomic<bool> receive_loop_running{false};
static napi_threadsafe_function threadsafe_callback = nullptr;

namespace tdlib_napi {

napi_value CreateClient(napi_env env, napi_callback_info info) {
    int client_id;
#ifndef TDLIB_STUB
    client_id = td_create_client_id();
#else
    client_id = ++stub_client_id;
#endif
    OH_LOG_INFO(LogType::LOG_APP, "TDLib client created: %{public}d", client_id);

    napi_value result;
    napi_create_int32(env, client_id, &result);
    return result;
}

napi_value Send(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value argv[2];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    // Get client_id
    int32_t client_id;
    napi_get_value_int32(env, argv[0], &client_id);

    // Get JSON request string
    size_t str_len;
    napi_get_value_string_utf8(env, argv[1], nullptr, 0, &str_len);
    std::string request(str_len, '\0');
    napi_get_value_string_utf8(env, argv[1], &request[0], str_len + 1, &str_len);

    OH_LOG_INFO(LogType::LOG_APP, "TDLib send: %{public}s", request.c_str());

#ifndef TDLIB_STUB
    td_send(client_id, request.c_str());
#else
    stub_handle_send(request);
#endif

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value Receive(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    double timeout;
    napi_get_value_double(env, argv[0], &timeout);

    const char* response = nullptr;
#ifndef TDLIB_STUB
    response = td_receive(timeout);
#else
    std::string resp = stub_dequeue();
    if (!resp.empty()) {
        // Return the stub response
        napi_value result;
        napi_create_string_utf8(env, resp.c_str(), resp.length(), &result);
        return result;
    }
#endif

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

    size_t str_len;
    napi_get_value_string_utf8(env, argv[0], nullptr, 0, &str_len);
    std::string request(str_len, '\0');
    napi_get_value_string_utf8(env, argv[0], &request[0], str_len + 1, &str_len);

    const char* response = nullptr;
#ifndef TDLIB_STUB
    response = td_execute(request.c_str());
#endif

    napi_value result;
    if (response != nullptr) {
        napi_create_string_utf8(env, response, NAPI_AUTO_LENGTH, &result);
    } else {
        napi_get_null(env, &result);
    }
    return result;
}

// Called from the receive thread to forward response to ArkTS
static void CallJs(napi_env env, napi_value js_callback, void* context, void* data) {
    if (env == nullptr || data == nullptr) return;

    std::string* response = static_cast<std::string*>(data);
    napi_value argv[1];
    napi_create_string_utf8(env, response->c_str(), response->length(), &argv[0]);

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    napi_call_function(env, undefined, js_callback, 1, argv, nullptr);

    delete response;
}

napi_value StartReceiveLoop(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    napi_value resource_name;
    napi_create_string_utf8(env, "TDLibReceiveLoop", NAPI_AUTO_LENGTH, &resource_name);

    napi_create_threadsafe_function(
        env, argv[0], nullptr, resource_name,
        0, 1, nullptr, nullptr, nullptr,
        CallJs, &threadsafe_callback
    );

    receive_loop_running = true;

    std::thread([]() {
        OH_LOG_INFO(LogType::LOG_APP, "TDLib receive loop started");

#ifdef TDLIB_STUB
        // In stub mode, send initial auth state after a short delay
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
        stub_send_initial_auth();
#endif

        while (receive_loop_running) {
#ifndef TDLIB_STUB
            const char* response = td_receive(1.0);
            if (response != nullptr) {
                auto* data = new std::string(response);
                napi_call_threadsafe_function(threadsafe_callback, data, napi_tsfn_blocking);
            }
#else
            std::string resp = stub_dequeue();
            if (!resp.empty()) {
                auto* data = new std::string(resp);
                napi_call_threadsafe_function(threadsafe_callback, data, napi_tsfn_blocking);
            } else {
                std::this_thread::sleep_for(std::chrono::milliseconds(50));
            }
#endif
        }
        OH_LOG_INFO(LogType::LOG_APP, "TDLib receive loop stopped");
        napi_release_threadsafe_function(threadsafe_callback, napi_tsfn_release);
        threadsafe_callback = nullptr;
    }).detach();

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value StopReceiveLoop(napi_env env, napi_callback_info info) {
    receive_loop_running = false;
    OH_LOG_INFO(LogType::LOG_APP, "TDLib receive loop stop requested");

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

} // namespace tdlib_napi
