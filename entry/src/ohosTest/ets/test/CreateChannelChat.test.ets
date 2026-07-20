import { describe, expect, it } from '@ohos/hypium';
import {
  AnyAppCommand,
  CreateNewSupergroupChatCommand
} from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { ChatType } from '../../../main/ets/core/model/dto/ChatDto';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import {
  CreateChannelChatUseCase,
  parseCreatedChannelChat
} from '../../../main/ets/domain/usecases/createChannelChat';
import { TdObject } from '../../../main/ets/models/TdTypes';

class FakeChannelGateway implements TdGatewayPort {
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

const CHANNEL_CHAT_JSON = '{"@type":"chat","id":8100,' +
  '"type":{"@type":"chatTypeSupergroup","supergroup_id":91,"is_channel":true},' +
  '"title":"News","positions":[],"unread_count":0}';

export default function createChannelChatTest() {
  describe('CreateChannelChat', () => {
    it('parses only a real channel Chat', 0, () => {
      const channel = parseCreatedChannelChat(TdObject.fromJSON(CHANNEL_CHAT_JSON));
      expect(channel?.id ?? 0).assertEqual(8100);
      expect(channel?.type ?? ChatType.PRIVATE).assertEqual(ChatType.CHANNEL);
      expect(channel?.supergroupId ?? 0).assertEqual(91);

      const supergroup = parseCreatedChannelChat(TdObject.fromJSON('{"@type":"chat","id":8101,' +
        '"type":{"@type":"chatTypeSupergroup","supergroup_id":92,"is_channel":false},' +
        '"title":"Group","positions":[]}'));
      expect(supergroup === undefined).assertTrue();
    });

    it('creates a private channel with fixed safe flags', 0, async () => {
      const gateway = new FakeChannelGateway(TdObject.fromJSON(CHANNEL_CHAT_JSON));
      const chat = await new CreateChannelChatUseCase(gateway).execute(' News ', ' Updates ');

      expect(chat.id).assertEqual(8100);
      expect(chat.type).assertEqual(ChatType.CHANNEL);
      expect(gateway.sentCommands.length).assertEqual(1);
      const command = gateway.sentCommands[0] as CreateNewSupergroupChatCommand;
      expect(command.type).assertEqual('createNewSupergroupChat');
      expect(command.payload.title).assertEqual('News');
      expect(command.payload.isForum).assertFalse();
      expect(command.payload.isChannel).assertTrue();
      expect(command.payload.description).assertEqual('Updates');
      expect(command.payload.messageAutoDeleteTime).assertEqual(0);
      expect(command.payload.forImport).assertFalse();
    });

    it('rejects invalid title and description before TDLib', 0, async () => {
      const gateway = new FakeChannelGateway(TdObject.empty());
      let invalidTitle = false;
      try {
        await new CreateChannelChatUseCase(gateway).execute('   ');
      } catch (_error) {
        invalidTitle = true;
      }
      expect(invalidTitle).assertTrue();

      let invalidDescription = false;
      try {
        await new CreateChannelChatUseCase(gateway).execute('News', 'x'.repeat(256));
      } catch (_error) {
        invalidDescription = true;
      }
      expect(invalidDescription).assertTrue();
      expect(gateway.sentCommands.length).assertEqual(0);
    });
  });
}
