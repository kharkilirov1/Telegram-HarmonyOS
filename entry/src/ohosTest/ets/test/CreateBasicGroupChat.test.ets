import { describe, expect, it } from '@ohos/hypium';
import {
  AnyAppCommand,
  CreateNewBasicGroupChatCommand,
  GetChatCommand
} from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { ChatType } from '../../../main/ets/core/model/dto/ChatDto';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import {
  CreateBasicGroupChatUseCase,
  parseCreatedBasicGroupChatResponse,
  uniquePositiveGroupMemberIds
} from '../../../main/ets/domain/usecases/createBasicGroupChat';
import { TdObject } from '../../../main/ets/models/TdTypes';

class FakeBasicGroupGateway implements TdGatewayPort {
  sentCommands: AnyAppCommand[] = [];
  private responses: Object[];
  private responseIndex: number = 0;

  constructor(responses: Object[]) {
    this.responses = responses;
  }

  initialize(): Promise<void> {
    return Promise.resolve();
  }

  send(command: AnyAppCommand): Promise<Object> {
    this.sentCommands.push(command);
    const response: Object = this.responses[this.responseIndex];
    this.responseIndex++;
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

const CREATED_GROUP_JSON = '{"@type":"createdBasicGroupChat","chat_id":7001,' +
  '"failed_to_add_members":{"@type":"failedToAddMembers","failed_to_add_members":[' +
  '{"@type":"failedToAddMember","user_id":12,"premium_would_allow_invite":true,' +
  '"premium_required_to_send_messages":false}]}}';

const BASIC_GROUP_CHAT_JSON = '{"@type":"chat","id":7001,' +
  '"type":{"@type":"chatTypeBasicGroup","basic_group_id":90},' +
  '"title":"Family","positions":[],"unread_count":0}';

export default function createBasicGroupChatTest() {
  describe('CreateBasicGroupChat', () => {
    it('deduplicates and removes invalid member ids in stable order', 0, () => {
      const ids = uniquePositiveGroupMemberIds([3, 0, 3, -1, 4, 4]);
      expect(ids.length).assertEqual(2);
      expect(ids[0]).assertEqual(3);
      expect(ids[1]).assertEqual(4);
    });

    it('parses the created chat id and partial member failures', 0, () => {
      const parsed = parseCreatedBasicGroupChatResponse(TdObject.fromJSON(CREATED_GROUP_JSON));
      expect(parsed?.chatId ?? 0).assertEqual(7001);
      expect(parsed?.failedMembers.length ?? 0).assertEqual(1);
      expect(parsed?.failedMembers[0].userId ?? 0).assertEqual(12);
      expect(parsed?.failedMembers[0].premiumWouldAllowInvite ?? false).assertTrue();
    });

    it('creates, hydrates and validates a basic-group Chat', 0, async () => {
      const gateway = new FakeBasicGroupGateway([
        TdObject.fromJSON(CREATED_GROUP_JSON),
        TdObject.fromJSON(BASIC_GROUP_CHAT_JSON)
      ]);
      const result = await new CreateBasicGroupChatUseCase(gateway).execute([11, 11, -1, 12], ' Family ');

      expect(result.chat.id).assertEqual(7001);
      expect(result.chat.type).assertEqual(ChatType.GROUP);
      expect(result.isHydrated).assertTrue();
      expect(result.failedMembers.length).assertEqual(1);
      expect(gateway.sentCommands.length).assertEqual(2);

      const createCommand = gateway.sentCommands[0] as CreateNewBasicGroupChatCommand;
      expect(createCommand.type).assertEqual('createNewBasicGroupChat');
      expect(createCommand.payload.userIds.length).assertEqual(2);
      expect(createCommand.payload.userIds[0]).assertEqual(11);
      expect(createCommand.payload.userIds[1]).assertEqual(12);
      expect(createCommand.payload.title).assertEqual('Family');
      expect(createCommand.payload.messageAutoDeleteTime).assertEqual(0);

      const getChatCommand = gateway.sentCommands[1] as GetChatCommand;
      expect(getChatCommand.type).assertEqual('getChat');
      expect(getChatCommand.payload.chatId).assertEqual(7001);
    });

    it('returns the committed group identity when hydration is inconsistent', 0, async () => {
      const privateChat = TdObject.fromJSON('{"@type":"chat","id":7001,' +
        '"type":{"@type":"chatTypePrivate","user_id":11},"title":"Alice","positions":[]}');
      const gateway = new FakeBasicGroupGateway([
        TdObject.fromJSON(CREATED_GROUP_JSON),
        privateChat
      ]);
      const result = await new CreateBasicGroupChatUseCase(gateway).execute([11], 'Family');
      expect(result.chat.id).assertEqual(7001);
      expect(result.chat.title).assertEqual('Family');
      expect(result.chat.type).assertEqual(ChatType.GROUP);
      expect(result.isHydrated).assertFalse();
      expect(gateway.sentCommands.length).assertEqual(2);
    });

    it('rejects an empty title before TDLib', 0, async () => {
      const gateway = new FakeBasicGroupGateway([]);
      let failed = false;
      try {
        await new CreateBasicGroupChatUseCase(gateway).execute([11], '   ');
      } catch (_error) {
        failed = true;
      }
      expect(failed).assertTrue();
      expect(gateway.sentCommands.length).assertEqual(0);
    });
  });
}
