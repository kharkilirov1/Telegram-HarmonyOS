import { describe, expect, it } from '@ohos/hypium';
import { AppState, Chat, User, createInitialAppState } from '../../../main/ets/core/model/AppState';
import { AnyAppEvent, MessageSendFailedEvent, FileDownloadedEvent } from '../../../main/ets/core/model/AppEvent';
import { MessageDto, MessageUpdateDto, createMessageDtoFromTd, applyMessageUpdate } from '../../../main/ets/core/model/dto/MessageDto';
import { registerMessageHandlers } from '../../../main/ets/core/events/normalizers/MessageNormalizer';
import { messagesReducer } from '../../../main/ets/core/reducers/messagesReducer';
import { filesReducer } from '../../../main/ets/core/reducers/filesReducer';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { buildChatTimeline } from '../../../main/ets/ui/pages/chat/ChatTimelineVO';
import { TgMessageSendStatus } from '../../../main/ets/ui/tg_ui/atoms/TgMessageMeta';

export function stabilizationMessageJson(id: number, sending: string = 'null', chatId: number = 42,
  text: string = 'controlled draft', senderChatId: number = 0): string {
  const sender = senderChatId === 0 ? '{"@type":"messageSenderUser","user_id":7}' :
    '{"@type":"messageSenderChat","chat_id":' + senderChatId.toString() + '}';
  return '{"@type":"message","id":' + id.toString() + ',"sender_id":' + sender + ',"chat_id":' + chatId.toString() +
    ',"sending_state":' + sending + ',"is_outgoing":true,"date":1700000000,"content":{"@type":"messageText","text":' +
    '{"@type":"formattedText","text":' + JSON.stringify(text) + ',"entities":[]}}}';
}
export const STABILIZATION_PENDING = '{"@type":"messageSendingStatePending","sending_id":3}';
export function stabilizationFailedJson(code: number = 429, text: string = 'SLOWMODE_WAIT_7'): string {
  return '{"@type":"messageSendingStateFailed","error":{"@type":"error","code":' + code.toString() + ',"message":' +
    JSON.stringify(text) + '},"can_retry":true,"retry_after":7}';
}
export class StabilizationMessagePipeline {
  state: AppState = createInitialAppState();
  private handlers: Map<string, (events: AnyAppEvent[], update: TdObject) => void> = new Map();
  constructor() {
    registerMessageHandlers(this.handlers);
    const chat = new Chat(); chat.id = 42; chat.title = 'Controlled timeline'; this.state.chats.chats.set(42, chat);
    const user = new User(); user.id = 7; user.firstName = 'Controlled user'; this.state.users.users.set(7, user);
  }
  ingest(json: string): AnyAppEvent[] {
    const update = TdObject.fromJSON(json); const handler = this.handlers.get(update.getType());
    if (handler === undefined) throw new Error('Message fixture handler is absent');
    const events: AnyAppEvent[] = []; handler(events, update);
    for (const event of events) this.state = messagesReducer(this.state, event);
    return events;
  }
  add(id: number, sending: string = STABILIZATION_PENDING): void {
    this.ingest('{"@type":"updateNewMessage","message":' + stabilizationMessageJson(id, sending) + '}');
  }
  fail(code: number = 429): MessageSendFailedEvent {
    const events = this.ingest('{"@type":"updateMessageSendFailed","old_message_id":100,"message":' +
      stabilizationMessageJson(101, stabilizationFailedJson(code, code === 406 ? 'CONTROLLED_SECRET' : 'SLOWMODE_WAIT_7'), 42, 'authoritative failed body') +
      ',"error":{"@type":"error","code":' + code.toString() + ',"message":"CONTROLLED_UPDATE_ERROR"}}');
    return events[0] as MessageSendFailedEvent;
  }
  status(id: string): TgMessageSendStatus {
    const entries = buildChatTimeline(42, this.state).entries;
    for (const entry of entries) if (entry.kind === 'message' && entry.message.messageId === id) return entry.message.sendStatus;
    throw new Error('Actual timeline Message row is absent id=' + id);
  }
}

export default function stabilizationMessagesTest() {
  describe('StabilizationMessages', () => {
    it('TDLib pending state reaches actual Sending VO', 0, () => {
      const f = new StabilizationMessagePipeline(); f.add(100);
      expect(f.state.messages.messages.get(42)?.get('100')?.isPending).assertEqual(true);
      expect(f.status('100')).assertEqual(TgMessageSendStatus.Sending);
    });
    it('messages history retains pending and failure states', 0, () => {
      const f = new StabilizationMessagePipeline();
      f.ingest('{"@type":"messages","total_count":2,"messages":[' + stabilizationMessageJson(100, STABILIZATION_PENDING) + ',' +
        stabilizationMessageJson(101, stabilizationFailedJson()) + ']}');
      expect(f.status('100')).assertEqual(TgMessageSendStatus.Sending); expect(f.status('101')).assertEqual(TgMessageSendStatus.Failed);
    });
    it('failure replaces temporary identity and authoritative content', 0, () => {
      const f = new StabilizationMessagePipeline(); f.add(100); f.fail();
      expect(f.state.messages.messages.get(42)?.has('100')).assertEqual(false);
      expect(f.state.messages.messages.get(42)?.get('101')?.content.text).assertEqual('authoritative failed body');
      expect(f.status('101')).assertEqual(TgMessageSendStatus.Failed);
    });
    it('permanent delete by failed identity leaves no ghost', 0, () => {
      const f = new StabilizationMessagePipeline(); f.add(100); const pendingSnapshot = f.state;
      f.fail(); const failedSnapshot = f.state;
      f.ingest('{"@type":"updateDeleteMessages","chat_id":42,"message_ids":[101],"is_permanent":true,"from_cache":false}');
      expect(f.state.messages.messages.has(42)).assertFalse();
      for (const messages of f.state.messages.messages.values()) {
        expect(messages.has('100')).assertFalse(); expect(messages.has('101')).assertFalse();
      }
      expect(buildChatTimeline(42, f.state).entries.filter((entry) => entry.kind === 'message').length).assertEqual(0);
      expect(pendingSnapshot.messages.messages.get(42)?.has('100')).assertTrue();
      expect(failedSnapshot.messages.messages.get(42)?.has('101')).assertTrue();
      expect(failedSnapshot.messages.messages.get(42)?.has('100')).assertFalse();
    });
    it('failure without loaded pending row still publishes canonical Message', 0, () => {
      const f = new StabilizationMessagePipeline(); f.fail();
      expect(f.state.messages.messages.get(42)?.get('101')?.content.text).assertEqual('authoritative failed body');
    });
    it('failure repeats and history reload keep exactly one failed row', 0, () => {
      const f = new StabilizationMessagePipeline(); f.add(100); f.fail(); f.fail();
      f.ingest('{"@type":"messages","total_count":1,"messages":[' + stabilizationMessageJson(101, stabilizationFailedJson()) + ']}');
      expect(f.state.messages.messages.get(42)?.size).assertEqual(1); expect(f.status('101')).assertEqual(TgMessageSendStatus.Failed);
    });
    it('success clears pending state and publishes server identity', 0, () => {
      const f = new StabilizationMessagePipeline(); f.add(100);
      f.ingest('{"@type":"updateMessageSendSucceeded","old_message_id":100,"message":' + stabilizationMessageJson(201) + '}');
      expect(f.state.messages.messages.get(42)?.has('100')).assertEqual(false);
      expect(f.state.messages.messages.get(42)?.get('201')?.isPending).assertEqual(false);
      expect(f.status('201')).assertEqual(TgMessageSendStatus.Sent);
    });
    for (const type of ['updateNewMessage', 'messages', 'updateMessageSendSucceeded', 'updateMessageSendFailed']) {
      it(type + ' uses containing target chat and separate sender chat', 0, () => {
        const f = new StabilizationMessagePipeline(); const message = stabilizationMessageJson(200, STABILIZATION_PENDING, -100200, 'target', -100100);
        const json = type === 'messages' ? '{"@type":"messages","messages":[' + message + ']}' :
          '{"@type":' + JSON.stringify(type) + ',"old_message_id":100,"message":' + message + ',"error":{"@type":"error","code":400,"message":"FAILED"}}';
        f.ingest(json);
        expect(f.state.messages.messages.has(-100100)).assertFalse();
        expect(f.state.messages.messages.get(-100200)?.get('200')?.senderChatId).assertEqual(-100100);
      });
    }
    it('missing top-level chat identity never borrows nested sender', 0, () => {
      const f = new StabilizationMessagePipeline(); const message = stabilizationMessageJson(200, STABILIZATION_PENDING, -100200, 'target', -100100)
        .replace(',"chat_id":-100200', '');
      const events = f.ingest('{"@type":"updateNewMessage","message":' + message + '}');
      expect(events.length).assertEqual(0); expect(f.state.messages.messages.size).assertEqual(0);
    });
    it('DTO update clone retains failure state and safe fields', 0, () => {
      const before: MessageDto = createMessageDtoFromTd(TdObject.fromJSON(stabilizationMessageJson(100, stabilizationFailedJson())));
      const update = new MessageUpdateDto(); update.editDate = 33; const after = applyMessageUpdate(before, update);
      expect(after.sendingState).assertEqual('failed'); expect(after.sendErrorCode).assertEqual(429); expect(after.editDate).assertEqual(33);
    });
    it('file completion preserves failure while updating actual content', 0, () => {
      const f = new StabilizationMessagePipeline(); f.add(100, stabilizationFailedJson());
      const message = f.state.messages.messages.get(42)?.get('100');
      if (message === undefined) throw new Error('Actual reduced message absent'); message.content.documentFileId = 77;
      const event = new FileDownloadedEvent(); event.fileId = 77; event.localPath = '/fixture/download'; event.isComplete = true;
      const next = filesReducer(f.state, event);
      expect(next.messages.messages.get(42)?.get('100')?.content.documentPath).assertEqual('/fixture/download');
      expect(next.messages.messages.get(42)?.get('100')?.sendStatus).assertEqual('failed');
      expect(next.messages.messages.get(42)?.get('100')?.sendErrorCode).assertEqual(429);
    });
    it('406 live and hydrated failure preserve code without application text', 0, () => {
      const f = new StabilizationMessagePipeline(); f.add(100); const event = f.fail(406);
      expect(event.errorMessage).assertEqual(''); expect(event.message.sendErrorMessage).assertEqual('');
      expect(f.state.messages.messages.get(42)?.get('101')?.sendErrorCode).assertEqual(406);
      const reloaded = new StabilizationMessagePipeline(); reloaded.add(101, stabilizationFailedJson(406, 'CONTROLLED_SECRET'));
      expect(reloaded.state.messages.messages.get(42)?.get('101')?.sendErrorMessage).assertEqual('');
    });
    // Broader opaque decimal IDs are internal parser compatibility, not TDLib
    // wire validity; all values stay strings and never pass through Number.
    for (const quoted of [false, true]) {
      const id = '9223372036854775001'; const nextId = '9223372036854775002';
      const literal = quoted ? JSON.stringify(id) : id; const nextLiteral = quoted ? JSON.stringify(nextId) : nextId;
      it((quoted ? 'quoted' : 'raw') + ' exact large ID ignores rounded or builder cache', 0, () => {
        const json = stabilizationMessageJson(100).replace('"id":100', '"id":' + literal);
        const object = TdObject.fromJSON(json); object.getNumber('id');
        expect(createMessageDtoFromTd(object).id).assertEqual(id);
        object.setNumber('id', 100); expect(createMessageDtoFromTd(object).id).assertEqual(id);
      });
      it((quoted ? 'quoted' : 'raw') + ' adjacent large IDs stay distinct in actual history', 0, () => {
        const f = new StabilizationMessagePipeline();
        const first = stabilizationMessageJson(100).replace('"id":100', '"id":' + literal);
        const second = stabilizationMessageJson(100).replace('"id":100', '"id":' + nextLiteral);
        f.ingest('{"@type":"messages","messages":[' + first + ',' + second + ']}');
        expect(f.state.messages.messages.get(42)?.size).assertEqual(2);
        expect(f.state.messages.messages.get(42)?.has(id)).assertTrue(); expect(f.state.messages.messages.get(42)?.has(nextId)).assertTrue();
      });
      it((quoted ? 'quoted' : 'raw') + ' failure rekeys exact old and authoritative IDs', 0, () => {
        const f = new StabilizationMessagePipeline();
        f.ingest('{"@type":"updateNewMessage","message":' + stabilizationMessageJson(100, STABILIZATION_PENDING).replace('"id":100', '"id":' + literal) + '}');
        f.ingest('{"@type":"updateMessageSendFailed","old_message_id":' + literal + ',"message":' +
          stabilizationMessageJson(100, stabilizationFailedJson(406, 'CONTROLLED_SECRET')).replace('"id":100', '"id":' + nextLiteral) +
          ',"error":{"@type":"error","code":406,"message":"CONTROLLED_SECRET"}}');
        expect(f.state.messages.messages.get(42)?.has(id)).assertFalse(); expect(f.state.messages.messages.get(42)?.has(nextId)).assertTrue();
        expect(f.state.messages.messages.get(42)?.get(nextId)?.sendErrorMessage).assertEqual('');
      });
    }
    it('lexical malformed and duplicate IDs never borrow or truncate identity', 0, () => {
      for (const literal of ['100.0', '1e2', '"0100"', 'true', '{}', '[100]', '100xyz']) {
        const f = new StabilizationMessagePipeline();
        const message = stabilizationMessageJson(100).replace('"id":100', '"id":' + literal);
        expect(createMessageDtoFromTd(TdObject.fromJSON(message)).id).assertEqual('0');
        expect(f.ingest('{"@type":"updateNewMessage","message":' + message + '}').length).assertEqual(0);
      }
      const ambiguous = stabilizationMessageJson(100).replace('"id":100', '"id":100,"\\u0069d":101');
      expect(createMessageDtoFromTd(TdObject.fromJSON(ambiguous)).id).assertEqual('0');
    });
    it('quoted id values and nested decoys before containing id are positive controls', 0, () => {
      for (const prefix of ['"other":"id",', '"other":{"id":101},', '"other":["id",{"id":101}],']) {
        const message = stabilizationMessageJson(42).replace('"id":42', prefix + '"id":42');
        expect(createMessageDtoFromTd(TdObject.fromJSON(message)).id).assertEqual('42');
      }
    });
  });
}
