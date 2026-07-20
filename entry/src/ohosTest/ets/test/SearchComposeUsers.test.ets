import { describe, expect, it } from '@ohos/hypium';
import {
  AnyAppCommand,
  GetChatCommand,
  GetUserCommand
} from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import {
  SearchComposeUsersUseCase,
  parseComposeChatIdsResponse,
  parseComposeUserIdsResponse
} from '../../../main/ets/domain/usecases/searchComposeUsers';
import { TdObject } from '../../../main/ets/models/TdTypes';

function userJson(id: number, name: string, username: string, type: string = 'userTypeRegular'): string {
  return '{"@type":"user","id":' + id + ',"first_name":"' + name + '","last_name":"",' +
    '"usernames":{"@type":"usernames","editable_username":"' + username + '"},' +
    '"phone_number":"","status":{"@type":"userStatusOffline"},' +
    '"type":{"@type":"' + type + '"},"is_contact":false}';
}

function privateChatJson(chatId: number, userId: number): string {
  return '{"@type":"chat","id":' + chatId + ',"title":"Private",' +
    '"type":{"@type":"chatTypePrivate","user_id":' + userId + '},"positions":[]}';
}

class FakeComposeSearchGateway implements TdGatewayPort {
  sentCommands: AnyAppCommand[] = [];
  failPublic: boolean = false;

  initialize(): Promise<void> {
    return Promise.resolve();
  }

  send(command: AnyAppCommand): Promise<Object> {
    this.sentCommands.push(command);
    switch (command.type) {
      case 'searchContacts':
        return Promise.resolve(TdObject.fromJSON(
          '{"@type":"users","total_count":4,"user_ids":[2,2,3,0]}'
        ));
      case 'searchChatsOnServer':
        return Promise.resolve(TdObject.fromJSON(
          '{"@type":"chats","total_count":3,"chat_ids":[100,101,102]}'
        ));
      case 'searchPublicChats':
        if (this.failPublic) {
          return Promise.reject(new Error('public search unavailable'));
        }
        return Promise.resolve(TdObject.fromJSON(
          '{"@type":"chats","total_count":4,"chat_ids":[102,103,104,105]}'
        ));
      case 'getChat':
        return this.getChatResponse((command as GetChatCommand).payload.chatId);
      case 'getUser':
        return this.getUserResponse((command as GetUserCommand).payload.userId);
      default:
        return Promise.resolve(TdObject.fromJSON('{"@type":"error","code":400}'));
    }
  }

  private getChatResponse(chatId: number): Promise<Object> {
    switch (chatId) {
      case 100:
        return Promise.resolve(TdObject.fromJSON(privateChatJson(100, 3)));
      case 101:
        return Promise.resolve(TdObject.fromJSON(
          '{"@type":"chat","id":101,"title":"Group",' +
          '"type":{"@type":"chatTypeSupergroup","supergroup_id":7,"is_channel":false},"positions":[]}'
        ));
      case 102:
        return Promise.resolve(TdObject.fromJSON(privateChatJson(102, 4)));
      case 103:
        return Promise.resolve(TdObject.fromJSON(privateChatJson(103, 4)));
      case 104:
        return Promise.resolve(TdObject.fromJSON(privateChatJson(104, 5)));
      case 105:
        return Promise.resolve(TdObject.fromJSON(privateChatJson(105, 6)));
      default:
        return Promise.resolve(TdObject.fromJSON('{"@type":"error","code":404}'));
    }
  }

  private getUserResponse(userId: number): Promise<Object> {
    switch (userId) {
      case 2:
        return Promise.resolve(TdObject.fromJSON(userJson(2, 'Alice', 'alice')));
      case 3:
        return Promise.resolve(TdObject.fromJSON(userJson(3, 'Helper', 'helper_bot', 'userTypeBot')));
      case 4:
        return Promise.resolve(TdObject.fromJSON(userJson(4, 'Known', 'known')));
      case 5:
        return Promise.resolve(TdObject.fromJSON(userJson(5, 'Deleted', '', 'userTypeDeleted')));
      case 6:
        return Promise.resolve(TdObject.fromJSON(userJson(6, 'Global', 'global_user')));
      default:
        return Promise.resolve(TdObject.fromJSON('{"@type":"error","code":404}'));
    }
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

export default function searchComposeUsersTest() {
  describe('SearchComposeUsers', () => {
    it('parses primitive id vectors strictly and removes invalid duplicates', 0, () => {
      const users = parseComposeUserIdsResponse(TdObject.fromJSON(
        '{"@type":"users","user_ids":[3,3,0,-1,4]}'
      ));
      const chats = parseComposeChatIdsResponse(TdObject.fromJSON(
        '{"@type":"chats","chat_ids":[10,10,0,11]}'
      ));
      const userIds: number[] = users ?? [];
      const chatIds: number[] = chats ?? [];

      expect(userIds.length).assertEqual(2);
      expect(userIds[0]).assertEqual(3);
      expect(userIds[1]).assertEqual(4);
      expect(chatIds.length).assertEqual(2);
      expect(parseComposeUserIdsResponse(TdObject.fromJSON('{"@type":"chats"')) === undefined)
        .assertTrue();
      expect(parseComposeChatIdsResponse(TdObject.fromJSON('{"@type":"users"')) === undefined)
        .assertTrue();
    });

    it('hydrates users, filters non-private and deleted peers, and preserves source precedence', 0, async () => {
      const gateway = new FakeComposeSearchGateway();
      const result = await new SearchComposeUsersUseCase(gateway).execute('user', 20);

      expect(result.cloudContacts.length).assertEqual(2);
      expect(result.cloudContacts[0].id).assertEqual(2);
      expect(result.cloudContacts[1].id).assertEqual(3);
      expect(result.cloudContacts[1].isBot).assertTrue();
      expect(result.knownUsers.length).assertEqual(1);
      expect(result.knownUsers[0].id).assertEqual(4);
      expect(result.globalUsers.length).assertEqual(1);
      expect(result.globalUsers[0].id).assertEqual(6);

      const groupHydration = gateway.sentCommands.some((command: AnyAppCommand): boolean =>
        command.type === 'getUser' && (command as GetUserCommand).payload.userId === 7);
      expect(groupHydration).assertFalse();
    });

    it('keeps successful sources when public search fails', 0, async () => {
      const gateway = new FakeComposeSearchGateway();
      gateway.failPublic = true;
      const result = await new SearchComposeUsersUseCase(gateway).execute('user');

      expect(result.cloudContacts.length).assertEqual(2);
      expect(result.knownUsers.length).assertEqual(1);
      expect(result.globalUsers.length).assertEqual(0);
    });

    it('limits chat ids per source before getChat hydration', 0, async () => {
      const gateway = new FakeComposeSearchGateway();
      await new SearchComposeUsersUseCase(gateway).execute('user', 2);

      const hydratedChatIds: number[] = gateway.sentCommands
        .filter((command: AnyAppCommand): boolean => command.type === 'getChat')
        .map((command: AnyAppCommand): number => (command as GetChatCommand).payload.chatId);

      // known: [100, 101], global: [102, 103]; 104/105 are beyond safeLimit.
      expect(hydratedChatIds.length).assertEqual(4);
      expect(hydratedChatIds.indexOf(100) >= 0).assertTrue();
      expect(hydratedChatIds.indexOf(101) >= 0).assertTrue();
      expect(hydratedChatIds.indexOf(102) >= 0).assertTrue();
      expect(hydratedChatIds.indexOf(103) >= 0).assertTrue();
      expect(hydratedChatIds.indexOf(104) >= 0).assertFalse();
      expect(hydratedChatIds.indexOf(105) >= 0).assertFalse();

      expect(gateway.sentCommands.some((command: AnyAppCommand): boolean =>
        command.type === 'searchContacts')).assertTrue();
      expect(gateway.sentCommands.some((command: AnyAppCommand): boolean =>
        command.type === 'searchChatsOnServer')).assertTrue();
      expect(gateway.sentCommands.some((command: AnyAppCommand): boolean =>
        command.type === 'searchPublicChats')).assertTrue();
    });

    it('does not send TDLib requests for an empty query', 0, async () => {
      const gateway = new FakeComposeSearchGateway();
      const result = await new SearchComposeUsersUseCase(gateway).execute('   ');

      expect(gateway.sentCommands.length).assertEqual(0);
      expect(result.cloudContacts.length).assertEqual(0);
      expect(result.globalUsers.length).assertEqual(0);
    });
  });
}
