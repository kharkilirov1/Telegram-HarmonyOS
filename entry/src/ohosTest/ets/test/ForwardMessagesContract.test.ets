import { describe, it, expect } from '@ohos/hypium';
import { AnyAppCommand, GetChatCommand, GetMessagePropertiesCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { ForwardMessagesParams, ForwardMessagesUseCase, ForwardMessagesResultError } from '../../../main/ets/domain/usecases/forwardMessages';

class ForwardContractGateway implements TdGatewayPort {
  commands: AnyAppCommand[] = [];
  response: TdObject = TdObject.fromJSON('{"@type":"messages","messages":[{"@type":"message","id":900,"chat_id":7}]}');
  async initialize(): Promise<void> {}
  async destroy(): Promise<void> {}
  getConnectionState(): 'ready' { return 'ready'; }
  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void { return (): void => {}; }
  async send(command: AnyAppCommand): Promise<Object> {
    this.commands.push(command);
    if (command.type === 'getChat') {
      const target = command as GetChatCommand;
      return TdObject.fromJSON(`{"@type":"chat","id":${target.payload.chatId},"type":{"@type":"chatTypePrivate"}}`);
    }
    if (command.type === 'getMessageProperties') {
      return TdObject.fromJSON('{"@type":"messageProperties","can_be_forwarded":true,"can_be_copied":true,"can_be_copied_to_secret_chat":true}');
    }
    return this.response;
  }
}

function forwardParams(ids: string[]): ForwardMessagesParams {
  const params = new ForwardMessagesParams();
  params.chatId = 7; params.fromChatId = -12; params.messageIds = ids;
  return params;
}

export default function forwardMessagesContractTest() {
  describe('ForwardMessagesContract', () => {
    it('prepares numeric ordering, distinct IDs and an independent snapshot', 0, () => {
      const params = forwardParams(['10', '2', '10']);
      const prepared = new ForwardMessagesUseCase(new ForwardContractGateway()).prepare(params);
      expect(prepared.messageIds.join(',')).assertEqual('2,10');
      expect(params.messageIds.join(',')).assertEqual('10,2,10');
      params.messageIds[0] = '99';
      expect(prepared.messageIds.join(',')).assertEqual('2,10');
    });
    it('rejects raw JSON fragments before dispatch', 0, async () => {
      const gateway = new ForwardContractGateway(); let rejected = false;
      try { await new ForwardMessagesUseCase(gateway).execute(forwardParams(['2,3'])); } catch (_error) { rejected = true; }
      expect(rejected).assertEqual(true); expect(gateway.commands.length).assertEqual(0);
    });
    it('rejects more than 100 distinct IDs before dispatch', 0, async () => {
      const gateway = new ForwardContractGateway(); const ids: string[] = [];
      for (let i = 1; i <= 101; i++) ids.push(String(i));
      let rejected = false;
      try { await new ForwardMessagesUseCase(gateway).execute(forwardParams(ids)); } catch (_error) { rejected = true; }
      expect(rejected).assertEqual(true); expect(gateway.commands.length).assertEqual(0);
    });
    it('accepts a real Messages response without claiming server delivery', 0, async () => {
      const gateway = new ForwardContractGateway();
      await new ForwardMessagesUseCase(gateway).execute(forwardParams(['2']));
      expect(gateway.commands.length).assertEqual(3);
      expect(gateway.commands[0].type).assertEqual('getChat');
      expect((gateway.commands[0] as GetChatCommand).payload.chatId).assertEqual(7);
      expect(gateway.commands[1].type).assertEqual('getMessageProperties');
      expect((gateway.commands[1] as GetMessagePropertiesCommand).payload.chatId).assertEqual(-12);
      expect((gateway.commands[1] as GetMessagePropertiesCommand).payload.messageId).assertEqual('2');
      expect(gateway.commands[2].type).assertEqual('forwardMessages');
    });
    it('keeps null slot aligned with sorted source ID', 0, async () => {
      const gateway = new ForwardContractGateway();
      gateway.response = TdObject.fromJSON('{"@type":"messages","messages":[{"@type":"message","id":900,"chat_id":7},null]}');
      let checked = false;
      try { await new ForwardMessagesUseCase(gateway).execute(forwardParams(['10', '2'])); } catch (error) {
        if (error instanceof ForwardMessagesResultError) {
          checked = true; expect(error.outcomeKnown).assertEqual(true); expect(error.acceptedCount).assertEqual(1);
          expect(error.retryMessageIds.join(',')).assertEqual('10');
        }
      }
      expect(checked).assertEqual(true);
    });
    it('does not treat all null slots as success', 0, async () => {
      const gateway = new ForwardContractGateway(); gateway.response = TdObject.fromJSON('{"@type":"messages","messages":[null]}');
      let checked = false;
      try { await new ForwardMessagesUseCase(gateway).execute(forwardParams(['2'])); } catch (error) {
        if (error instanceof ForwardMessagesResultError) {
          checked = true; expect(error.acceptedCount).assertEqual(0); expect(error.retryMessageIds.join(',')).assertEqual('2');
        }
      }
      expect(checked).assertEqual(true);
    });
    it('nested or wrong-destination result is uncertain with no replay list', 0, async () => {
      const gateway = new ForwardContractGateway();
      gateway.response = TdObject.fromJSON('{"@type":"messages","messages":[{"@type":"message","id":900,"chat_id":8}]}');
      let checked = false;
      try { await new ForwardMessagesUseCase(gateway).execute(forwardParams(['2'])); } catch (error) {
        if (error instanceof ForwardMessagesResultError) {
          checked = true; expect(error.outcomeKnown).assertEqual(false); expect(error.retryMessageIds.length).assertEqual(0);
        }
      }
      expect(checked).assertEqual(true);
    });
    it('strict array accessor keeps null and ignores nested shadow arrays', 0, () => {
      const value = TdObject.fromJSON('{"nested":{"messages":[{"@type":"message"}]},"messages":[null,{"@type":"message"}]}');
      const items = value.getTopLevelObjectArrayStrict('messages');
      expect(items?.length).assertEqual(2); expect(items?.[0] === null).assertEqual(true);
      expect(items?.[1]?.getTopLevelStringStrict('@type')).assertEqual('message');
      expect(TdObject.fromJSON('{"messages":[1]}').getTopLevelObjectArrayStrict('messages') === undefined).assertEqual(true);
    });
  });
}
