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

        // Determine which chat to generate history for
        int chat_id = -1001;
        auto cid_pos = request.find("\"chat_id\"");
        if (cid_pos != std::string::npos) {
            auto colon = request.find(':', cid_pos);
            chat_id = std::stoi(request.substr(colon + 1));
        }

        // Generate diverse messages for the first private chat
        if (chat_id == -1001) {
            stub_enqueue("{\"@type\":\"messages\",\"total_count\":10,\"messages\":["
                // 1. Text message with reply
                "{\"@type\":\"message\",\"id\":9001,\"chat_id\":-1001,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":100001},\"date\":1700000100,\"is_outgoing\":false,\"content\":{\"@type\":\"messageText\",\"text\":{\"@type\":\"formattedText\",\"text\":\"Hey! Have you seen the new HarmonyOS update?\"}}},"
                // 2. Reply
                "{\"@type\":\"message\",\"id\":9002,\"chat_id\":-1001,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":0},\"date\":1700000200,\"is_outgoing\":true,\"reply_to\":{\"@type\":\"messageReplyToMessage\",\"message_id\":9001},\"content\":{\"@type\":\"messageText\",\"text\":{\"@type\":\"formattedText\",\"text\":\"Yes! The Liquid Glass UI looks amazing.\"}}},"
                // 3. Photo message
                "{\"@type\":\"message\",\"id\":9003,\"chat_id\":-1001,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":100001},\"date\":1700000300,\"is_outgoing\":false,\"content\":{\"@type\":\"messagePhoto\",\"photo\":{\"@type\":\"photo\",\"sizes\":[{\"@type\":\"photoSize\",\"type\":\"m\",\"width\":320,\"height\":240}]},\"caption\":{\"@type\":\"formattedText\",\"text\":\"Check out this screenshot!\"}}},"
                // 4. Voice message
                "{\"@type\":\"message\",\"id\":9004,\"chat_id\":-1001,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":0},\"date\":1700000400,\"is_outgoing\":true,\"content\":{\"@type\":\"messageVoiceNote\",\"voice_note\":{\"@type\":\"voiceNote\",\"duration\":12,\"waveform\":\"AQID\"},\"caption\":{\"@type\":\"formattedText\",\"text\":\"\"}}},"
                // 5. Document
                "{\"@type\":\"message\",\"id\":9005,\"chat_id\":-1001,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":100001},\"date\":1700000500,\"is_outgoing\":false,\"content\":{\"@type\":\"messageDocument\",\"document\":{\"@type\":\"document\",\"file_name\":\"HarmonyOS_API22_Guide.pdf\",\"mime_type\":\"application/pdf\"},\"caption\":{\"@type\":\"formattedText\",\"text\":\"\"}}},"
                // 6. Video
                "{\"@type\":\"message\",\"id\":9006,\"chat_id\":-1001,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":100001},\"date\":1700000600,\"is_outgoing\":false,\"content\":{\"@type\":\"messageVideo\",\"video\":{\"@type\":\"video\",\"duration\":45,\"width\":1920,\"height\":1080},\"caption\":{\"@type\":\"formattedText\",\"text\":\"Demo video of the new features\"}}},"
                // 7. Sticker
                "{\"@type\":\"message\",\"id\":9007,\"chat_id\":-1001,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":0},\"date\":1700000700,\"is_outgoing\":true,\"content\":{\"@type\":\"messageSticker\",\"sticker\":{\"@type\":\"sticker\",\"emoji\":\"\\ud83d\\ude0e\"}}},"
                // 8. Forwarded message
                "{\"@type\":\"message\",\"id\":9008,\"chat_id\":-1001,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":100001},\"date\":1700000800,\"is_outgoing\":false,\"forward_info\":{\"@type\":\"messageForwardInfo\",\"origin\":{\"@type\":\"messageOriginUser\",\"sender_name\":\"Tech News Channel\"}},\"content\":{\"@type\":\"messageText\",\"text\":{\"@type\":\"formattedText\",\"text\":\"HarmonyOS NEXT now supports WebGL 2.0 and advanced Canvas rendering.\"}}},"
                // 9. Link message
                "{\"@type\":\"message\",\"id\":9009,\"chat_id\":-1001,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":0},\"date\":1700000900,\"is_outgoing\":true,\"content\":{\"@type\":\"messageText\",\"text\":{\"@type\":\"formattedText\",\"text\":\"Check this out: https://developer.huawei.com/harmonyos\"}}},"
                // 10. Text
                "{\"@type\":\"message\",\"id\":9010,\"chat_id\":-1001,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":100001},\"date\":1700001000,\"is_outgoing\":false,\"content\":{\"@type\":\"messageText\",\"text\":{\"@type\":\"formattedText\",\"text\":\"That's awesome! Let me know when you want to test it together.\"}}}"
                "],\"@extra\":" + extra_str + "}");
        }
        // Group chat — messages from multiple senders
        else if (chat_id == -1003) {
            stub_enqueue("{\"@type\":\"messages\",\"total_count\":6,\"messages\":["
                "{\"@type\":\"message\",\"id\":3101,\"chat_id\":-1003,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":100001},\"date\":1700000100,\"is_outgoing\":false,\"content\":{\"@type\":\"messageText\",\"text\":{\"@type\":\"formattedText\",\"text\":\"Anyone tried the new API 22 canvas features?\"}}},"
                "{\"@type\":\"message\",\"id\":3102,\"chat_id\":-1003,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":100002},\"date\":1700000200,\"is_outgoing\":false,\"content\":{\"@type\":\"messageText\",\"text\":{\"@type\":\"formattedText\",\"text\":\"Yes! The Liquid Glass blur effects are incredible.\"}}},"
                "{\"@type\":\"message\",\"id\":3103,\"chat_id\":-1003,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":100003},\"date\":1700000300,\"is_outgoing\":false,\"content\":{\"@type\":\"messageText\",\"text\":{\"@type\":\"formattedText\",\"text\":\"I'm working on a Telegram client using it right now!\"}}},"
                "{\"@type\":\"message\",\"id\":3104,\"chat_id\":-1003,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":0},\"date\":1700000400,\"is_outgoing\":true,\"content\":{\"@type\":\"messageText\",\"text\":{\"@type\":\"formattedText\",\"text\":\"Same here! The backgroundBlurStyle works great.\"}}},"
                "{\"@type\":\"message\",\"id\":3105,\"chat_id\":-1003,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":100001},\"date\":1700000500,\"is_outgoing\":false,\"content\":{\"@type\":\"messageDocument\",\"document\":{\"@type\":\"document\",\"file_name\":\"api22_samples.zip\",\"mime_type\":\"application/zip\"},\"caption\":{\"@type\":\"formattedText\",\"text\":\"Here are some sample projects\"}}},"
                "{\"@type\":\"message\",\"id\":3106,\"chat_id\":-1003,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":100002},\"date\":1700000600,\"is_outgoing\":false,\"content\":{\"@type\":\"messageText\",\"text\":{\"@type\":\"formattedText\",\"text\":\"Thanks! Very helpful.\"}}}"
                "],\"@extra\":" + extra_str + "}");
        }
        // Default: basic messages for other chats
        else {
            stub_enqueue("{\"@type\":\"messages\",\"total_count\":2,\"messages\":["
                "{\"@type\":\"message\",\"id\":9001,\"chat_id\":" + std::to_string(chat_id) + ",\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":100002},\"date\":1700000900,\"is_outgoing\":false,\"content\":{\"@type\":\"messageText\",\"text\":{\"@type\":\"formattedText\",\"text\":\"Hello!\"}}},"
                "{\"@type\":\"message\",\"id\":9002,\"chat_id\":" + std::to_string(chat_id) + ",\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":0},\"date\":1700000950,\"is_outgoing\":true,\"content\":{\"@type\":\"messageText\",\"text\":{\"@type\":\"formattedText\",\"text\":\"Hi there!\"}}}"
                "],\"@extra\":" + extra_str + "}");
        }
    }
    else if (request.find("\"sendMessage\"") != std::string::npos) {
        std::string extra_str;
        auto pos = request.find("\"@extra\"");
        if (pos != std::string::npos) {
            auto colon = request.find(':', pos);
            auto comma = request.find(',', colon);
            auto brace = request.find('}', colon);
            auto end = (comma != std::string::npos && comma < brace) ? comma : brace;
            extra_str = request.substr(colon + 1, end - colon - 1);
        }
        // Extract chat_id and text
        int send_chat_id = -1001;
        auto scid = request.find("\"chat_id\"");
        if (scid != std::string::npos) {
            auto colon = request.find(':', scid);
            send_chat_id = std::stoi(request.substr(colon + 1));
        }
        // Extract the message text
        std::string send_text = "Message";
        auto text_pos = request.find("\"text\":{\"@type\":\"formattedText\",\"text\":\"");
        if (text_pos != std::string::npos) {
            auto start = text_pos + 39;
            auto end = request.find("\"", start);
            if (end != std::string::npos) {
                send_text = request.substr(start, end - start);
            }
        }
        static int stub_msg_id = 20000;
        int msg_id = ++stub_msg_id;
        long now = 1700001000 + msg_id;

        // Reply with the sent message as updateNewMessage
        stub_enqueue("{\"@type\":\"ok\",\"@extra\":" + extra_str + "}");
        stub_enqueue("{\"@type\":\"updateNewMessage\",\"message\":{\"@type\":\"message\",\"id\":" +
            std::to_string(msg_id) + ",\"chat_id\":" + std::to_string(send_chat_id) +
            ",\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":0},\"date\":" +
            std::to_string(now) + ",\"is_outgoing\":true,\"content\":{\"@type\":\"messageText\",\"text\":{\"@type\":\"formattedText\",\"text\":\"" +
            send_text + "\"}}}}");

        // Simulate a reply after 2 seconds
        std::thread([send_chat_id, msg_id]() {
            std::this_thread::sleep_for(std::chrono::seconds(2));
            // Typing indicator
            stub_enqueue("{\"@type\":\"updateChatAction\",\"chat_id\":" + std::to_string(send_chat_id) +
                ",\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":100001},\"action\":{\"@type\":\"chatActionTyping\"}}");
            std::this_thread::sleep_for(std::chrono::seconds(2));
            stub_enqueue("{\"@type\":\"updateChatAction\",\"chat_id\":" + std::to_string(send_chat_id) +
                ",\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":100001},\"action\":{\"@type\":\"chatActionCancel\"}}");
            // Auto-reply
            int reply_id = msg_id + 1000;
            long reply_time = 1700001000 + reply_id;
            stub_enqueue("{\"@type\":\"updateNewMessage\",\"message\":{\"@type\":\"message\",\"id\":" +
                std::to_string(reply_id) + ",\"chat_id\":" + std::to_string(send_chat_id) +
                ",\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":100001},\"date\":" +
                std::to_string(reply_time) + ",\"is_outgoing\":false,\"content\":{\"@type\":\"messageText\",\"text\":{\"@type\":\"formattedText\",\"text\":\"Got your message! \\ud83d\\udc4d\"}}}}");
        }).detach();
    }
    else if (request.find("\"searchMessages\"") != std::string::npos) {
        std::string extra_str;
        auto pos = request.find("\"@extra\"");
        if (pos != std::string::npos) {
            auto colon = request.find(':', pos);
            auto comma = request.find(',', colon);
            auto brace = request.find('}', colon);
            auto end = (comma != std::string::npos && comma < brace) ? comma : brace;
            extra_str = request.substr(colon + 1, end - colon - 1);
        }
        stub_enqueue("{\"@type\":\"foundMessages\",\"total_count\":2,\"messages\":["
            "{\"@type\":\"message\",\"id\":9001,\"chat_id\":-1001,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":100001},\"date\":1700000100,\"is_outgoing\":false,\"content\":{\"@type\":\"messageText\",\"text\":{\"@type\":\"formattedText\",\"text\":\"Hey! Have you seen the new HarmonyOS update?\"}}},"
            "{\"@type\":\"message\",\"id\":3104,\"chat_id\":-1003,\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":0},\"date\":1700000400,\"is_outgoing\":true,\"content\":{\"@type\":\"messageText\",\"text\":{\"@type\":\"formattedText\",\"text\":\"Same here! The backgroundBlurStyle works great.\"}}}"
            "],\"@extra\":" + extra_str + "}");
    }
    else if (request.find("\"createPrivateChat\"") != std::string::npos) {
        std::string extra_str;
        auto pos = request.find("\"@extra\"");
        if (pos != std::string::npos) {
            auto colon = request.find(':', pos);
            auto comma = request.find(',', colon);
            auto brace = request.find('}', colon);
            auto end = (comma != std::string::npos && comma < brace) ? comma : brace;
            extra_str = request.substr(colon + 1, end - colon - 1);
        }
        int user_id = 100001;
        auto uid_pos = request.find("\"user_id\"");
        if (uid_pos != std::string::npos) {
            auto colon = request.find(':', uid_pos);
            user_id = std::stoi(request.substr(colon + 1));
        }
        // Return the chat_id (negative of user_id range)
        int result_chat_id = -(user_id - 100000 + 1000);
        stub_enqueue("{\"@type\":\"chat\",\"id\":" + std::to_string(result_chat_id) +
            ",\"@extra\":" + extra_str + "}");
    }
    else if (request.find("\"editMessageText\"") != std::string::npos) {
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
    else if (request.find("\"createNewBasicGroupChat\"") != std::string::npos) {
        std::string extra_str;
        auto pos = request.find("\"@extra\"");
        if (pos != std::string::npos) {
            auto colon = request.find(':', pos);
            auto comma = request.find(',', colon);
            auto brace = request.find('}', colon);
            auto end = (comma != std::string::npos && comma < brace) ? comma : brace;
            extra_str = request.substr(colon + 1, end - colon - 1);
        }
        // Extract title
        std::string title = "New Group";
        auto title_pos = request.find("\"title\":\"");
        if (title_pos != std::string::npos) {
            auto start = title_pos + 9;
            auto end = request.find("\"", start);
            if (end != std::string::npos) title = request.substr(start, end - start);
        }
        static int stub_group_id = -2001;
        int group_chat_id = stub_group_id--;
        stub_enqueue("{\"@type\":\"chat\",\"id\":" + std::to_string(group_chat_id) +
            ",\"title\":\"" + title + "\",\"type\":{\"@type\":\"chatTypeBasicGroup\",\"basic_group_id\":" +
            std::to_string(-group_chat_id) + "},\"@extra\":" + extra_str + "}");
        // Also push updateNewChat so the chat appears in the list
        stub_enqueue("{\"@type\":\"updateNewChat\",\"chat\":{\"@type\":\"chat\",\"id\":" +
            std::to_string(group_chat_id) + ",\"title\":\"" + title +
            "\",\"type\":{\"@type\":\"chatTypeBasicGroup\",\"basic_group_id\":" +
            std::to_string(-group_chat_id) +
            "},\"last_message\":null,\"unread_count\":0,\"positions\":[{\"@type\":\"chatPosition\",\"list\":{\"@type\":\"chatListMain\"},\"order\":\"6900002000\",\"is_pinned\":false}],\"notification_settings\":{\"@type\":\"chatNotificationSettings\",\"mute_for\":0}}}");
    }
    else if (request.find("\"createNewSupergroupChat\"") != std::string::npos) {
        std::string extra_str;
        auto pos = request.find("\"@extra\"");
        if (pos != std::string::npos) {
            auto colon = request.find(':', pos);
            auto comma = request.find(',', colon);
            auto brace = request.find('}', colon);
            auto end = (comma != std::string::npos && comma < brace) ? comma : brace;
            extra_str = request.substr(colon + 1, end - colon - 1);
        }
        std::string title = "New Channel";
        auto title_pos = request.find("\"title\":\"");
        if (title_pos != std::string::npos) {
            auto start = title_pos + 9;
            auto end = request.find("\"", start);
            if (end != std::string::npos) title = request.substr(start, end - start);
        }
        bool is_channel = request.find("\"is_channel\":true") != std::string::npos;
        static int stub_supergroup_id = -3001;
        int sg_chat_id = stub_supergroup_id--;
        int sg_id = -sg_chat_id;
        stub_enqueue("{\"@type\":\"chat\",\"id\":" + std::to_string(sg_chat_id) +
            ",\"title\":\"" + title + "\",\"type\":{\"@type\":\"chatTypeSupergroup\",\"supergroup_id\":" +
            std::to_string(sg_id) + ",\"is_channel\":" + (is_channel ? "true" : "false") +
            "},\"@extra\":" + extra_str + "}");
        stub_enqueue("{\"@type\":\"updateNewChat\",\"chat\":{\"@type\":\"chat\",\"id\":" +
            std::to_string(sg_chat_id) + ",\"title\":\"" + title +
            "\",\"type\":{\"@type\":\"chatTypeSupergroup\",\"supergroup_id\":" +
            std::to_string(sg_id) + ",\"is_channel\":" + (is_channel ? "true" : "false") +
            "},\"last_message\":null,\"unread_count\":0,\"positions\":[{\"@type\":\"chatPosition\",\"list\":{\"@type\":\"chatListMain\"},\"order\":\"6900002000\",\"is_pinned\":false}],\"notification_settings\":{\"@type\":\"chatNotificationSettings\",\"mute_for\":0}}}");
    }
    else if (request.find("\"forwardMessages\"") != std::string::npos) {
        std::string extra_str;
        auto pos = request.find("\"@extra\"");
        if (pos != std::string::npos) {
            auto colon = request.find(':', pos);
            auto comma = request.find(',', colon);
            auto brace = request.find('}', colon);
            auto end = (comma != std::string::npos && comma < brace) ? comma : brace;
            extra_str = request.substr(colon + 1, end - colon - 1);
        }
        // Extract target chat_id
        int target_chat_id = -1001;
        auto tcid = request.find("\"chat_id\"");
        if (tcid != std::string::npos) {
            auto colon = request.find(':', tcid);
            target_chat_id = std::stoi(request.substr(colon + 1));
        }
        static int stub_fwd_id = 30000;
        int fwd_id = ++stub_fwd_id;
        long fwd_time = 1700001000 + fwd_id;
        // Return ok + updateNewMessage with forwarded content
        stub_enqueue("{\"@type\":\"messages\",\"total_count\":1,\"messages\":[{\"@type\":\"message\",\"id\":" +
            std::to_string(fwd_id) + ",\"chat_id\":" + std::to_string(target_chat_id) +
            ",\"sender_id\":{\"@type\":\"messageSenderUser\",\"user_id\":0},\"date\":" +
            std::to_string(fwd_time) +
            ",\"is_outgoing\":true,\"forward_info\":{\"@type\":\"messageForwardInfo\",\"origin\":{\"@type\":\"messageOriginUser\",\"sender_name\":\"You\"}},\"content\":{\"@type\":\"messageText\",\"text\":{\"@type\":\"formattedText\",\"text\":\"[Forwarded message]\"}}}],\"@extra\":" +
            extra_str + "}");
    }
    else if (request.find("\"setName\"") != std::string::npos) {
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
    else if (request.find("\"setBio\"") != std::string::npos) {
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
    else if (request.find("\"setUsername\"") != std::string::npos) {
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
    else if (request.find("\"getUserFullInfo\"") != std::string::npos) {
        std::string extra_str;
        auto pos = request.find("\"@extra\"");
        if (pos != std::string::npos) {
            auto colon = request.find(':', pos);
            auto comma = request.find(',', colon);
            auto brace = request.find('}', colon);
            auto end = (comma != std::string::npos && comma < brace) ? comma : brace;
            extra_str = request.substr(colon + 1, end - colon - 1);
        }
        stub_enqueue("{\"@type\":\"userFullInfo\",\"bio\":\"Life is what happens when you are busy making other plans.\",\"group_in_common_count\":3,\"@extra\":" + extra_str + "}");
    }
    else if (request.find("\"getSupergroupFullInfo\"") != std::string::npos) {
        std::string extra_str;
        auto pos = request.find("\"@extra\"");
        if (pos != std::string::npos) {
            auto colon = request.find(':', pos);
            auto comma = request.find(',', colon);
            auto brace = request.find('}', colon);
            auto end = (comma != std::string::npos && comma < brace) ? comma : brace;
            extra_str = request.substr(colon + 1, end - colon - 1);
        }
        stub_enqueue("{\"@type\":\"supergroupFullInfo\",\"description\":\"A group for friends and colleagues\",\"member_count\":15,\"@extra\":" + extra_str + "}");
    }
    else if (request.find("\"addChatToList\"") != std::string::npos) {
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
    else if (request.find("\"createCall\"") != std::string::npos) {
        std::string extra_str;
        auto pos = request.find("\"@extra\"");
        if (pos != std::string::npos) {
            auto colon = request.find(':', pos);
            auto comma = request.find(',', colon);
            auto brace = request.find('}', colon);
            auto end = (comma != std::string::npos && comma < brace) ? comma : brace;
            extra_str = request.substr(colon + 1, end - colon - 1);
        }
        static int stub_call_id = 5000;
        int call_id = ++stub_call_id;
        stub_enqueue("{\"@type\":\"callId\",\"id\":" + std::to_string(call_id) + ",\"@extra\":" + extra_str + "}");
        // Simulate call state transitions
        stub_enqueue("{\"@type\":\"updateCall\",\"call\":{\"@type\":\"call\",\"id\":" + std::to_string(call_id) +
            ",\"state\":{\"@type\":\"callStatePending\"},\"is_outgoing\":true,\"is_video\":false}}");
    }
    else if (request.find("\"discardCall\"") != std::string::npos) {
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

// --- Receive loop state machine ---
enum class LoopState { Stopped, Starting, Running, Stopping };
static std::atomic<LoopState> loop_state{LoopState::Stopped};
static std::thread receive_thread;
static std::mutex loop_mutex;
static napi_threadsafe_function threadsafe_callback = nullptr;

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

static bool napi_check_type(napi_env env, const char* func, napi_value val,
                            napi_valuetype expected, const char* argName) {
    napi_valuetype actual;
    napi_typeof(env, val, &actual);
    if (actual != expected) {
        const char* type_names[] = {
            "undefined", "null", "boolean", "number", "string", "symbol", "object", "function", "external", "bigint"
        };
        const char* actual_name = (actual >= 0 && actual <= 9) ? type_names[actual] : "unknown";
        const char* expected_name = (expected >= 0 && expected <= 9) ? type_names[expected] : "unknown";
        std::string msg = std::string(argName) + " must be " + expected_name + ", got " + actual_name;
        napi_throw_arg_error(env, func, msg.c_str());
        return false;
    }
    return true;
}

namespace tdlib_napi {

napi_value CreateClient(napi_env env, napi_callback_info info) {
    // No arguments required
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

    // Strict validation: 1 arg (number)
    if (!napi_check_argc(env, "receive", argc, 1)) return nullptr;
    if (!napi_check_type(env, "receive", argv[0], napi_number, "timeoutSeconds")) return nullptr;

    double timeout;
    napi_get_value_double(env, argv[0], &timeout);

    const char* response = nullptr;
#ifndef TDLIB_STUB
    response = td_receive(timeout);
#else
    std::string resp = stub_dequeue();
    if (!resp.empty()) {
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

    // Strict validation: 1 arg (string)
    if (!napi_check_argc(env, "execute", argc, 1)) return nullptr;
    if (!napi_check_type(env, "execute", argv[0], napi_string, "requestJson")) return nullptr;

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

    // Strict validation: 1 arg (function)
    if (!napi_check_argc(env, "startReceiveLoop", argc, 1)) return nullptr;
    if (!napi_check_type(env, "startReceiveLoop", argv[0], napi_function, "callback")) return nullptr;

    std::lock_guard<std::mutex> guard(loop_mutex);

    // Prevent double-start
    LoopState expected = LoopState::Stopped;
    if (!loop_state.compare_exchange_strong(expected, LoopState::Starting)) {
        OH_LOG_WARN(LogType::LOG_APP, "StartReceiveLoop called while state=%d, ignoring",
                    static_cast<int>(loop_state.load()));
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        return undefined;
    }

    // Join previous thread if still joinable (defensive)
    if (receive_thread.joinable()) {
        receive_thread.join();
    }

    napi_value resource_name;
    napi_create_string_utf8(env, "TDLibReceiveLoop", NAPI_AUTO_LENGTH, &resource_name);

    napi_create_threadsafe_function(
        env, argv[0], nullptr, resource_name,
        0, 1, nullptr, nullptr, nullptr,
        CallJs, &threadsafe_callback
    );

    loop_state = LoopState::Running;

    receive_thread = std::thread([]() {
        OH_LOG_INFO(LogType::LOG_APP, "TDLib receive loop started");

#ifdef TDLIB_STUB
        // In stub mode, send initial auth state after a short delay
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
        stub_send_initial_auth();
#endif

        while (loop_state == LoopState::Running) {
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
        if (threadsafe_callback != nullptr) {
            napi_release_threadsafe_function(threadsafe_callback, napi_tsfn_release);
            threadsafe_callback = nullptr;
        }
        loop_state = LoopState::Stopped;
    });

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value StopReceiveLoop(napi_env env, napi_callback_info info) {
    std::lock_guard<std::mutex> guard(loop_mutex);

    LoopState current = loop_state.load();
    if (current != LoopState::Running) {
        OH_LOG_WARN(LogType::LOG_APP, "StopReceiveLoop called while state=%d, ignoring",
                    static_cast<int>(current));
        napi_value undefined;
        napi_get_undefined(env, &undefined);
        return undefined;
    }

    loop_state = LoopState::Stopping;
    OH_LOG_INFO(LogType::LOG_APP, "TDLib receive loop stop requested");

    // Join the receive thread to ensure clean shutdown
    if (receive_thread.joinable()) {
        receive_thread.join();
    }

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

napi_value GetTdlibInfo(napi_env env, napi_callback_info info) {
    // Build a JSON string with compile-time diagnostics
    const char* mode =
#if TDLIB_STUB
        "STUB";
#else
        "REAL";
#endif

    const char* tdlib_dir = XSTR(TDLIB_DIR_PATH);
    const char* soname = XSTR(TDLIB_SONAME);

    std::string json = "{\"mode\":\"" + std::string(mode) +
                       "\",\"tdlibDir\":\"" + std::string(tdlib_dir) +
                       "\",\"soname\":\"" + std::string(soname) + "\"}";

    OH_LOG_INFO(LogType::LOG_APP,
        "┌─ TDLib Runtime Info ─────────────────────────");
    OH_LOG_INFO(LogType::LOG_APP,
        "│ MODE:      %{public}s", mode);
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
