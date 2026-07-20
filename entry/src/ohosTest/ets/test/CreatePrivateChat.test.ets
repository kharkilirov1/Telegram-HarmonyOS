import { describe, expect, it } from '@ohos/hypium';
import { AnyAppCommand, CreatePrivateChatCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { ChatType } from '../../../main/ets/core/model/dto/ChatDto';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import {
  CreatePrivateChatUseCase,
  parsePrivateChatResponse
} from '../../../main/ets/domain/usecases/createPrivateChat';
import { TdObject } from '../../../main/ets/models/TdTypes';

class FakePrivateChatGateway implements TdGatewayPort {
  sentCommands: AnyAppCommand[] = [];
  private response: Object;

  constructor(response: Object) {
    this.response = response;
  }

  initialize(): Promise<void> {
    return Promise.resolve();
  }

  send(command: AnyAppCommand): Promise<Object> {
    this.sentCommands.push(command);
    return Promise.resolve(this.response);
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

const PRIVATE_CHAT_JSON = '{"@type":"chat","id":7001,' +
  '"type":{"@type":"chatTypePrivate","user_id":42},' +
  '"title":"Alice","positions":[],"unread_count":3}';

export default function createPrivateChatTest() {
  describe('CreatePrivateChat', () => {
    it('parses the requested private Chat response', 0, () => {
      const chat = parsePrivateChatResponse(TdObject.fromJSON(PRIVATE_CHAT_JSON), 42);

      expect(chat !== undefined).assertTrue();
      expect(chat?.id ?? 0).assertEqual(7001);
      expect(chat?.peerUserId ?? 0).assertEqual(42);
      expect(chat?.type ?? ChatType.GROUP).assertEqual(ChatType.PRIVATE);
      expect(chat?.title ?? '').assertEqual('Alice');
    });

    it('sends createPrivateChat with force=false and returns a typed ChatDto', 0, async () => {
      const gateway = new FakePrivateChatGateway(TdObject.fromJSON(PRIVATE_CHAT_JSON));
      const chat = await new CreatePrivateChatUseCase(gateway).execute(42);

      expect(chat.id).assertEqual(7001);
      expect(gateway.sentCommands.length).assertEqual(1);
      const command = gateway.sentCommands[0] as CreatePrivateChatCommand;
      expect(command.type).assertEqual('createPrivateChat');
      expect(command.payload.userId).assertEqual(42);
      expect(command.payload.force).assertFalse();
    });

    it('preserves force=true for the explicit offline path', 0, async () => {
      const gateway = new FakePrivateChatGateway(TdObject.fromJSON(PRIVATE_CHAT_JSON));
      await new CreatePrivateChatUseCase(gateway).execute(42, true);

      const command = gateway.sentCommands[0] as CreatePrivateChatCommand;
      expect(command.payload.force).assertTrue();
    });

    it('rejects invalid user ids before calling TDLib', 0, async () => {
      const gateway = new FakePrivateChatGateway(TdObject.fromJSON(PRIVATE_CHAT_JSON));
      let failed = false;
      try {
        await new CreatePrivateChatUseCase(gateway).execute(0);
      } catch (_error) {
        failed = true;
      }

      expect(failed).assertTrue();
      expect(gateway.sentCommands.length).assertEqual(0);
    });

    it('rejects a Chat for a different user', 0, async () => {
      const gateway = new FakePrivateChatGateway(TdObject.fromJSON(PRIVATE_CHAT_JSON));
      let failed = false;
      try {
        await new CreatePrivateChatUseCase(gateway).execute(43);
      } catch (_error) {
        failed = true;
      }

      expect(failed).assertTrue();
    });
  });
}
