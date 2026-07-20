import { describe, expect, it } from '@ohos/hypium';
import {
  AnyAppCommand,
  GetSupergroupMembersCommand,
  SearchChatMembersCommand
} from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import {
  ChatMembersUseCase,
  parseChatMembersResponse
} from '../../../main/ets/domain/usecases/chatMembers';
import { TdObject } from '../../../main/ets/models/TdTypes';

class FakeMembersGateway implements TdGatewayPort {
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
    const response = this.responses[this.responseIndex];
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

const MEMBERS_JSON = '{"@type":"chatMembers","total_count":250,"members":[' +
  '{"@type":"chatMember","member_id":{"@type":"messageSenderUser","user_id":11},' +
  '"status":{"@type":"chatMemberStatusCreator","custom_title":"Founder","is_anonymous":false}},' +
  '{"@type":"chatMember","member_id":{"@type":"messageSenderChat","chat_id":-99},' +
  '"status":{"@type":"chatMemberStatusAdministrator","custom_title":"","is_anonymous":true}}' +
  ']}';

export default function chatMembersTest() {
  describe('ChatMembers', () => {
    it('parses user/chat senders and preserves Telegram role metadata', 0, () => {
      const result = parseChatMembersResponse(TdObject.fromJSON(MEMBERS_JSON), 100);

      expect(result.totalCount).assertEqual(250);
      expect(result.members.length).assertEqual(2);
      expect(result.members[0].senderUserId).assertEqual(11);
      expect(result.members[0].role).assertEqual('creator');
      expect(result.members[0].customTitle).assertEqual('Founder');
      expect(result.members[1].senderChatId).assertEqual(-99);
      expect(result.members[1].role).assertEqual('administrator');
      expect(result.members[1].isAnonymous).assertTrue();
      expect(result.canLoadMore).assertTrue();
    });

    it('uses the pageable supergroup path for the unfiltered initial list', 0, async () => {
      const gateway = new FakeMembersGateway([TdObject.fromJSON(MEMBERS_JSON)]);
      const useCase = new ChatMembersUseCase(gateway);

      const result = await useCase.execute(-1001, 77, 'administrators', '', 100, 100);

      expect(result.members.length).assertEqual(2);
      const command = gateway.sentCommands[0] as GetSupergroupMembersCommand;
      expect(command.type).assertEqual('getSupergroupMembers');
      expect(command.payload.supergroupId).assertEqual(77);
      expect(command.payload.offset).assertEqual(100);
      expect(command.payload.filterKind).assertEqual('administrators');
    });

    it('uses generic search for a query and terminates at the returned page', 0, async () => {
      const gateway = new FakeMembersGateway([TdObject.fromJSON(MEMBERS_JSON)]);
      const useCase = new ChatMembersUseCase(gateway);

      const result = await useCase.execute(-1001, 77, 'all', ' alice ', 0, 100);

      const command = gateway.sentCommands[0] as SearchChatMembersCommand;
      expect(command.type).assertEqual('searchChatMembers');
      expect(command.payload.query).assertEqual('alice');
      expect(result.canLoadMore).assertFalse();
    });
  });
}
