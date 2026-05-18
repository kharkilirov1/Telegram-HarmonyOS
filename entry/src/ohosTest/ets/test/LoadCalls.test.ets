import { describe, it, expect } from '@ohos/hypium';
import {
  LoadCallsParams,
  LoadCallsResult,
  CallHistoryRecord,
  LoadCallsUseCase
} from '../../../main/ets/domain/usecases/loadCalls';
import { AnyAppCommand, createSearchCallMessagesCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { AppStore } from '../../../main/ets/core/store/AppStore';
import { appReducer } from '../../../main/ets/core/reducers/index';
import { AppState, Chat, User, createInitialAppState } from '../../../main/ets/core/model/AppState';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import { TdObject } from '../../../main/ets/models/TdTypes';

/**
 * Unit tests for LoadCalls model/command surface and TDLib-backed parser path.
 */
class FakeCallsGateway implements TdGatewayPort {
  sentCommands: AnyAppCommand[] = [];
  private responses: Object[] = [];
  private responseIndex: number = 0;

  constructor(responses: Object[]) {
    this.responses = responses;
  }

  initialize(): Promise<void> {
    return Promise.resolve();
  }

  send(command: AnyAppCommand): Promise<Object> {
    this.sentCommands.push(command);
    if (this.responseIndex >= this.responses.length) {
      return Promise.resolve(TdObject.empty());
    }
    const response = this.responses[this.responseIndex] as Object;
    this.responseIndex += 1;
    return Promise.resolve(response);
  }

  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void {
    return (): void => {};
  }

  getConnectionState(): 'connecting' | 'ready' | 'updating' | 'waitingForNetwork' {
    return 'ready';
  }

  destroy(): Promise<void> {
    return Promise.resolve();
  }
}

function makeStore(state?: AppState): AppStore {
  return new AppStore(appReducer, state !== undefined ? state : createInitialAppState(), false);
}

function makeChat(chatId: number, peerUserId: number, title: string, photoSmall: string = ''): Chat {
  const chat = new Chat();
  chat.id = chatId;
  chat.peerUserId = peerUserId;
  chat.title = title;
  chat.photoSmall = photoSmall;
  return chat;
}

function makeUser(userId: number, firstName: string, lastName: string, username: string = '',
  photoSmall: string = ''): User {
  const user = new User();
  user.id = userId;
  user.firstName = firstName;
  user.lastName = lastName;
  user.username = username;
  user.photoSmall = photoSmall;
  return user;
}

export default function loadCallsTest() {
  describe('LoadCalls', () => {

    describe('LoadCallsParams', () => {
      it('should default to first page of all calls', 0, () => {
        const params = new LoadCallsParams();
        expect(params.offset).assertEqual('');
        expect(params.limit).assertEqual(50);
        expect(params.onlyMissed).assertFalse();
      });

      it('should allow TDLib offset pagination and missed-only overrides', 0, () => {
        const params = new LoadCallsParams();
        params.offset = 'opaque-next-offset';
        params.limit = 25;
        params.onlyMissed = true;

        expect(params.offset).assertEqual('opaque-next-offset');
        expect(params.limit).assertEqual(25);
        expect(params.onlyMissed).assertTrue();
      });
    });

    describe('CallHistoryRecord', () => {
      it('should default to an outgoing voice call record shell', 0, () => {
        const record = new CallHistoryRecord();
        expect(record.messageId).assertEqual('0');
        expect(record.chatId).assertEqual(0);
        expect(record.peerUserId).assertEqual(0);
        expect(record.senderUserId).assertEqual(0);
        expect(record.fallbackTitle).assertEqual('');
        expect(record.fallbackAvatarPath).assertEqual('');
        expect(record.timestamp).assertEqual(0);
        expect(record.direction).assertEqual('outgoing');
        expect(record.isVideo).assertFalse();
        expect(record.discardReasonType).assertEqual('');
        expect(record.contentType).assertEqual('messageCall');
      });

      it('should represent missed video and group-call variants', 0, () => {
        const record = new CallHistoryRecord();
        record.messageId = '42';
        record.chatId = 100;
        record.peerUserId = 200;
        record.senderUserId = 300;
        record.fallbackTitle = 'Alice';
        record.fallbackAvatarPath = '/avatar.jpg';
        record.timestamp = 1700000000;
        record.direction = 'missed';
        record.isVideo = true;
        record.discardReasonType = 'callDiscardReasonMissed';
        record.contentType = 'messageGroupCall';

        expect(record.messageId).assertEqual('42');
        expect(record.chatId).assertEqual(100);
        expect(record.peerUserId).assertEqual(200);
        expect(record.senderUserId).assertEqual(300);
        expect(record.fallbackTitle).assertEqual('Alice');
        expect(record.fallbackAvatarPath).assertEqual('/avatar.jpg');
        expect(record.timestamp).assertEqual(1700000000);
        expect(record.direction).assertEqual('missed');
        expect(record.isVideo).assertTrue();
        expect(record.discardReasonType).assertEqual('callDiscardReasonMissed');
        expect(record.contentType).assertEqual('messageGroupCall');
      });
    });

    describe('LoadCallsResult', () => {
      it('should default to empty terminal page', 0, () => {
        const result = new LoadCallsResult();
        expect(result.records.length).assertEqual(0);
        expect(result.nextOffset).assertEqual('');
        expect(result.hasMore).assertFalse();
      });
    });

    describe('search call messages command', () => {
      it('should create command payload from current LoadCalls params', 0, () => {
        const command = createSearchCallMessagesCommand('next-page', 20, true);
        expect(command.type).assertEqual('searchCallMessages');
        expect(command.payload.offset).assertEqual('next-page');
        expect(command.payload.limit).assertEqual(20);
        expect(command.payload.onlyMissed).assertTrue();
      });
    });

    describe('LoadCallsUseCase', () => {
      it('should parse FoundMessages call records and next_offset', async 0, async () => {
        const state = createInitialAppState();
        state.auth.userId = 1;
        state.chats.chats.set(10, makeChat(10, 2, 'Alice chat', '/chat/alice.jpg'));
        state.chats.chats.set(11, makeChat(11, 3, 'Carol chat'));
        state.users.users.set(2, makeUser(2, 'Alice', 'Smith', 'alice', '/user/alice.jpg'));

        const gateway = new FakeCallsGateway([
          TdObject.fromJSON(
            '{"@type":"foundMessages","total_count":2,"next_offset":"opaque-next",' +
              '"messages":[' +
              '{"@type":"message","id":"1000","chat_id":10,' +
              '"sender_id":{"@type":"messageSenderUser","user_id":1},' +
              '"is_outgoing":true,"date":1700000000,' +
              '"content":{"@type":"messageCall","is_video":true,' +
              '"discard_reason":{"@type":"callDiscardReasonHungUp"},"duration":12}},' +
              '{"@type":"message","id":"999","chat_id":11,' +
              '"sender_id":{"@type":"messageSenderUser","user_id":3},' +
              '"is_outgoing":false,"date":1700000100,' +
              '"content":{"@type":"messageCall","is_video":false,' +
              '"discard_reason":{"@type":"callDiscardReasonMissed"},"duration":0}},' +
              '{"@type":"message","id":"998","chat_id":11,' +
              '"sender_id":{"@type":"messageSenderUser","user_id":3},' +
              '"is_outgoing":false,"date":1700000200,' +
              '"content":{"@type":"messageText","text":{"@type":"formattedText","text":"skip","entities":[]}}}' +
              ']}'
          )
        ]);
        const useCase = new LoadCallsUseCase(makeStore(state), gateway);

        const params = new LoadCallsParams();
        params.offset = '';
        params.limit = 40;
        const result = await useCase.execute(params);

        expect(gateway.sentCommands.length).assertEqual(1);
        expect(gateway.sentCommands[0].type).assertEqual('searchCallMessages');
        expect(result.records.length).assertEqual(2);
        expect(result.nextOffset).assertEqual('opaque-next');
        expect(result.hasMore).assertTrue();

        expect(result.records[0].messageId).assertEqual('1000');
        expect(result.records[0].peerUserId).assertEqual(2);
        expect(result.records[0].direction).assertEqual('outgoing');
        expect(result.records[0].isVideo).assertTrue();
        expect(result.records[0].fallbackTitle).assertEqual('Alice Smith');
        expect(result.records[0].fallbackAvatarPath).assertEqual('/user/alice.jpg');

        expect(result.records[1].messageId).assertEqual('999');
        expect(result.records[1].peerUserId).assertEqual(3);
        expect(result.records[1].direction).assertEqual('missed');
        expect(result.records[1].discardReasonType).assertEqual('callDiscardReasonMissed');
        expect(result.records[1].fallbackTitle).assertEqual('Carol chat');
      });

      it('should hydrate missing chat and user direct TDLib responses', async 0, async () => {
        const state = createInitialAppState();
        state.auth.userId = 1;
        const store = makeStore(state);
        const gateway = new FakeCallsGateway([
          TdObject.fromJSON(
            '{"@type":"foundMessages","total_count":1,"next_offset":"",' +
              '"messages":[{"@type":"message","id":"500","chat_id":20,' +
              '"sender_id":{"@type":"messageSenderUser","user_id":5},' +
              '"is_outgoing":false,"date":1700000300,' +
              '"content":{"@type":"messageCall","is_video":false,' +
              '"discard_reason":{"@type":"callDiscardReasonHungUp"},"duration":30}}]}'
          ),
          TdObject.fromJSON(
            '{"@type":"chat","id":20,"title":"Bob chat",' +
              '"type":{"@type":"chatTypePrivate","user_id":5},' +
              '"unread_count":0,"last_read_outbox_message_id":"0","last_read_inbox_message_id":"0"}'
          ),
          TdObject.fromJSON(
            '{"@type":"user","id":5,"first_name":"Bob","last_name":"Jones","username":"bobj",' +
              '"phone_number":"","is_contact":true,"is_verified":false,"is_scam":false,' +
              '"is_fake":false,"is_premium":false,"status":{"@type":"userStatusRecently"}}'
          )
        ]);
        const useCase = new LoadCallsUseCase(store, gateway);

        const result = await useCase.execute(new LoadCallsParams());

        expect(gateway.sentCommands.length).assertEqual(3);
        expect(gateway.sentCommands[0].type).assertEqual('searchCallMessages');
        expect(gateway.sentCommands[1].type).assertEqual('getChat');
        expect(gateway.sentCommands[2].type).assertEqual('getUser');
        expect(result.records.length).assertEqual(1);
        expect(result.records[0].peerUserId).assertEqual(5);
        expect(result.records[0].direction).assertEqual('incoming');
        expect(result.nextOffset).assertEqual('');
        expect(result.hasMore).assertFalse();
        expect(store.getState().chats.chats.has(20)).assertTrue();
        expect(store.getState().users.users.has(5)).assertTrue();
      });
    });
  });
}
