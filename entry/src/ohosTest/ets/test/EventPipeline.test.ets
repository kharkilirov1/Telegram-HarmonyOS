import { describe, it, expect } from '@ohos/hypium';
import { EventNormalizerImpl } from '../../../main/ets/core/events/EventNormalizer';
import { AppStore } from '../../../main/ets/core/store/AppStore';
import { appReducer } from '../../../main/ets/core/reducers/index';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { AppState } from '../../../main/ets/core/model/AppState';

/**
 * End-to-end pipeline test: TdObject → EventNormalizer → AppEvent[] → AppStore → AppState
 *
 * Verifies the full chain from raw TDLib JSON to final application state, catching
 * integration bugs that isolated unit tests (normalizer-only, reducer-only) miss.
 *
 * No native TDLib required — uses in-memory TdObject fixtures (TdObject.fromJSON).
 * AppStore dispatch is a promise chain, so the pipeline is awaited before asserting.
 */

// Module-level: ArkTS forbids nested functions (arkts-no-nested-funcs).
async function runPipeline(updates: TdObject[]): Promise<AppState> {
  const normalizer = new EventNormalizerImpl();
  const store = new AppStore(appReducer);

  const allEvents: AnyAppEvent[] = [];
  for (const update of updates) {
    const events: AnyAppEvent[] = normalizer.normalize(update);
    for (const event of events) {
      allEvents.push(event);
    }
  }
  await store.dispatchBatch(allEvents);
  return store.getState();
}

export default function eventPipelineTest() {
  describe('EventPipeline (end-to-end)', () => {

    // ─── Auth pipeline ───────────────────────────────────────────

    describe('auth pipeline', () => {
      it('should transition to waitPhoneNumber', 0, async () => {
        const update: TdObject = TdObject.fromJSON(
          '{"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateWaitPhoneNumber","is_registered":false}}'
        );

        const state = await runPipeline([update]);
        expect(state.auth.status).assertEqual('waitPhoneNumber');
      });

      it('should transition to waitCode', 0, async () => {
        const update: TdObject = TdObject.fromJSON(
          '{"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateWaitCode","is_registered":true,"next_type":{"@type":"authenticationCodeTypeSms"}}}'
        );

        const state = await runPipeline([update]);
        expect(state.auth.status).assertEqual('waitCode');
      });

      it('should transition to ready', 0, async () => {
        const update: TdObject = TdObject.fromJSON(
          '{"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateReady"}}'
        );

        const state = await runPipeline([update]);
        expect(state.auth.status).assertEqual('ready');
      });
    });

    // ─── Chat pipeline ───────────────────────────────────────────

    describe('chat pipeline', () => {
      it('should add a new chat to state', 0, async () => {
        const update: TdObject = TdObject.fromJSON(
          '{"@type":"updateNewChat","chat":{"@type":"chat","id":1001,' +
          '"type":{"@type":"chatTypePrivate","user_id":5001},"title":"Test Chat",' +
          '"order":"100","is_pinned":false,"unread_count":3,"unread_mention_count":0,' +
          '"notification_settings":{"@type":"chatNotificationSettings","mute_for":0,"show_preview":true}}}'
        );

        const state = await runPipeline([update]);
        expect(state.chats.chats.has(1001)).assertTrue();
        const chat = state.chats.chats.get(1001);
        if (chat === undefined) {
          expect().assertFail();
          return;
        }
        expect(chat.title).assertEqual('Test Chat');
      });

      it('should update chat title', 0, async () => {
        const newChat: TdObject = TdObject.fromJSON(
          '{"@type":"updateNewChat","chat":{"@type":"chat","id":2002,' +
          '"type":{"@type":"chatTypePrivate","user_id":5002},"title":"Old Title",' +
          '"order":"50","is_pinned":false,"unread_count":0,"unread_mention_count":0}}'
        );

        const titleUpdate: TdObject = TdObject.fromJSON(
          '{"@type":"updateChatTitle","chat_id":2002,"title":"New Title"}'
        );

        const state = await runPipeline([newChat, titleUpdate]);
        const chat = state.chats.chats.get(2002);
        if (chat === undefined) {
          expect().assertFail();
          return;
        }
        expect(chat.title).assertEqual('New Title');
      });
    });

    // ─── Message pipeline ────────────────────────────────────────

    describe('message pipeline', () => {
      it('should add a new text message to state', 0, async () => {
        const update: TdObject = TdObject.fromJSON(
          '{"@type":"updateNewMessage","message":{"@type":"message","id":10001,"chat_id":1001,' +
          '"sender_id":{"@type":"messageSenderUser","user_id":5001},' +
          '"content":{"@type":"messageText","text":{"@type":"formattedText","text":"Hello, pipeline!"}},' +
          '"date":1700000000,"is_outgoing":false,"is_edited":false,"ttl":0}}'
        );

        const state = await runPipeline([update]);
        const chatMessages = state.messages.messages.get(1001);
        expect(chatMessages === undefined).assertFalse();
        if (chatMessages !== undefined) {
          expect(chatMessages.has('10001')).assertTrue();
        }
      });

      it('should handle multiple messages in same chat', 0, async () => {
        const mkMsg = (id: number, text: string): TdObject => TdObject.fromJSON(
          '{"@type":"updateNewMessage","message":{"@type":"message","id":' + id.toString() +
          ',"chat_id":3003,"sender_id":{"@type":"messageSenderUser","user_id":5001},' +
          '"content":{"@type":"messageText","text":{"@type":"formattedText","text":"' + text +
          '"}},"date":' + (1700000000 + id).toString() + ',"is_outgoing":false,"is_edited":false,"ttl":0}}'
        );

        const state = await runPipeline([mkMsg(1, 'first'), mkMsg(2, 'second'), mkMsg(3, 'third')]);
        const chatMessages = state.messages.messages.get(3003);
        if (chatMessages === undefined) {
          expect().assertFail();
          return;
        }
        expect(chatMessages.size).assertEqual(3);
        expect(chatMessages.has('1')).assertTrue();
        expect(chatMessages.has('2')).assertTrue();
        expect(chatMessages.has('3')).assertTrue();
      });
    });

    // ─── User pipeline ───────────────────────────────────────────

    describe('user pipeline', () => {
      it('should add a new user to state', 0, async () => {
        const update: TdObject = TdObject.fromJSON(
          '{"@type":"updateUser","user":{"@type":"user","id":5001,"first_name":"Alice",' +
          '"last_name":"Smith","username":"alice","phone_number":"1234567890",' +
          '"status":{"@type":"userStatusOnline"},"is_bot":false}}'
        );

        const state = await runPipeline([update]);
        expect(state.users.users.has(5001)).assertTrue();
        const user = state.users.users.get(5001);
        if (user === undefined) {
          expect().assertFail();
          return;
        }
        expect(user.firstName).assertEqual('Alice');
      });
    });

    // ─── Combined batch pipeline ─────────────────────────────────

    describe('combined batch pipeline', () => {
      it('should process mixed updates into coherent state', 0, async () => {
        const updates: TdObject[] = [
          // 1. Auth ready
          TdObject.fromJSON(
            '{"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateReady"}}'
          ),
          // 2. User
          TdObject.fromJSON(
            '{"@type":"updateUser","user":{"@type":"user","id":5001,"first_name":"Bob",' +
            '"last_name":"","username":"bob","phone_number":"","status":{"@type":"userStatusOffline","was_online":0},"is_bot":false}}'
          ),
          // 3. Chat
          TdObject.fromJSON(
            '{"@type":"updateNewChat","chat":{"@type":"chat","id":1001,' +
            '"type":{"@type":"chatTypePrivate","user_id":5001},"title":"Bob",' +
            '"order":"100","is_pinned":false,"unread_count":1,"unread_mention_count":0}}'
          ),
          // 4. Message in that chat
          TdObject.fromJSON(
            '{"@type":"updateNewMessage","message":{"@type":"message","id":10001,"chat_id":1001,' +
            '"sender_id":{"@type":"messageSenderUser","user_id":5001},' +
            '"content":{"@type":"messageText","text":{"@type":"formattedText","text":"Hi from Bob!"}},' +
            '"date":1700000000,"is_outgoing":false,"is_edited":false,"ttl":0}}'
          )
        ];

        const state = await runPipeline(updates);

        // Auth is ready
        expect(state.auth.status).assertEqual('ready');
        // User exists
        expect(state.users.users.has(5001)).assertTrue();
        // Chat exists
        expect(state.chats.chats.has(1001)).assertTrue();
        // Message exists in chat
        const chatMessages = state.messages.messages.get(1001);
        expect(chatMessages === undefined).assertFalse();
        if (chatMessages !== undefined) {
          expect(chatMessages.has('10001')).assertTrue();
        }
      });
    });

    // ─── Resilience ──────────────────────────────────────────────

    describe('resilience', () => {
      it('should skip unknown update types without throwing', 0, async () => {
        const update: TdObject = TdObject.fromJSON(
          '{"@type":"updateSomeFutureThing","data":"unknown"}'
        );

        const state = await runPipeline([update]);
        // State should remain in initial state
        expect(state.auth.status).assertEqual('notInitialized');
      });

      it('should handle empty update array', 0, async () => {
        const state = await runPipeline([]);
        expect(state.auth.status).assertEqual('notInitialized');
      });
    });
  });
}
