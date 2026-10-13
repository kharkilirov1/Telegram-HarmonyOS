import { describe, it, expect } from '@ohos/hypium';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { GroupAccessDto, GroupSendPermissionsDto, createGroupAccessDtoFromTd } from '../../../main/ets/core/model/dto/GroupAccessDto';
import { Chat, createInitialAppState } from '../../../main/ets/core/model/AppState';
import { AnyAppCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { cloneGroupAccess } from '../../../main/ets/core/utils/stateClone';
import { EventNormalizerImpl } from '../../../main/ets/core/events/EventNormalizer';
import { appReducer } from '../../../main/ets/core/reducers/index';
import { AppStore } from '../../../main/ets/core/store/AppStore';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import { LoadChatAccessUseCase } from '../../../main/ets/domain/usecases/loadChatAccess';
import { ChatAccessController } from '../../../main/ets/ui/pages/chat/ChatAccessController';
import { selectChatInputPanel } from '../../../main/ets/ui/pages/chat/ChatInputPanelPolicy';

function basicChat(): Chat {
  const chat = new Chat(); chat.id = -77; chat.type = 'group'; chat.basicGroupId = 77;
  chat.sendPermissions = new GroupSendPermissionsDto(); chat.sendPermissions.canSendBasicMessages = true;
  return chat;
}
function basicResponse(role: string = 'Member', active: boolean = true): TdObject {
  return TdObject.fromJSON(`{"@type":"basicGroup","id":77,"is_active":${active},"status":{"@type":"chatMemberStatus${role}","is_member":true}}`);
}
class BasicAccessGateway implements TdGatewayPort {
  commands: AnyAppCommand[] = [];
  response: TdObject = basicResponse();
  async initialize(): Promise<void> {}
  async destroy(): Promise<void> {}
  getConnectionState(): 'ready' { return 'ready'; }
  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void { return (): void => {}; }
  async send(command: AnyAppCommand): Promise<Object> { this.commands.push(command); return this.response; }
}

export default function basicGroupAccessTest() {
  describe('BasicGroupAccess', () => {
    it('does not borrow a channel administrator with the same numeric group ID', 0, () => {
      const channel = new GroupAccessDto(); channel.groupId = 77; channel.role = 'administrator';
      channel.isMember = true; channel.canPostMessages = true;
      expect(selectChatInputPanel(basicChat(), channel)).assertEqual('unknown');
    });
    it('inactive creator stays unavailable through actual normalizer, reducer and clone', 0, async () => {
      const store = new AppStore(appReducer, createInitialAppState(), false);
      await store.dispatchBatch(new EventNormalizerImpl().normalize(basicResponse('Creator', false)));
      const access = store.getState().chats.basicGroupAccess.get(77);
      expect(access?.isActive).assertEqual(false); expect(selectChatInputPanel(basicChat(), access)).assertEqual('banned');
      if (access) expect(cloneGroupAccess(access).isActive).assertEqual(false);
    });
    it('active administrator bypasses default basic-message restrictions', 0, () => {
      const chat = basicChat(); chat.canSendBasicMessages = false;
      const access = createGroupAccessDtoFromTd(basicResponse('Administrator'), 'basicGroup');
      expect(selectChatInputPanel(chat, access)).assertEqual('composer');
    });
    it('member follows the default basic-message permission', 0, () => {
      const chat = basicChat(); const access = createGroupAccessDtoFromTd(basicResponse(), 'basicGroup');
      expect(selectChatInputPanel(chat, access)).assertEqual('composer');
      chat.canSendBasicMessages = false;
      if (chat.sendPermissions) chat.sendPermissions.canSendBasicMessages = false;
      expect(selectChatInputPanel(chat, access)).assertEqual('restricted');
    });
    it('left and removed basic groups never expose channel Join or composer', 0, () => {
      const roles: string[] = ['Left', 'Banned'];
      for (const role of roles) {
        const access = createGroupAccessDtoFromTd(basicResponse(role), 'basicGroup');
        expect(selectChatInputPanel(basicChat(), access)).assertEqual('banned');
      }
    });
    it('missing or nested activity is not authoritative', 0, () => {
      const value = TdObject.fromJSON('{"@type":"basicGroup","id":77,"nested":{"is_active":true},"status":{"@type":"chatMemberStatusMember"}}');
      expect(createGroupAccessDtoFromTd(value, 'basicGroup') === undefined).assertEqual(true);
    });
    it('hydrates an unknown basic group once using the correct method', 0, async () => {
      const store = new AppStore(appReducer, createInitialAppState(), false); const gateway = new BasicAccessGateway();
      let notifications = 0;
      const controller = new ChatAccessController(new LoadChatAccessUseCase(store, gateway), (): void => { notifications++; });
      const chat = basicChat(); controller.observe(chat); controller.observe(chat);
      await new Promise<void>((resolve) => { setTimeout(resolve, 0); });
      expect(gateway.commands.length).assertEqual(1); expect(gateway.commands[0].type).assertEqual('getBasicGroup');
      expect(notifications).assertEqual(1); expect(selectChatInputPanel(chat, store.getState().chats.basicGroupAccess.get(77))).assertEqual('composer');
      controller.dispose();
    });
    it('a malformed basic response leaves an explicit retryable hydration failure', 0, async () => {
      const store = new AppStore(appReducer, createInitialAppState(), false); const gateway = new BasicAccessGateway();
      gateway.response = TdObject.fromJSON('{"@type":"basicGroup","id":77,"status":{"@type":"chatMemberStatusMember"}}');
      const controller = new ChatAccessController(new LoadChatAccessUseCase(store, gateway), (): void => {});
      controller.observe(basicChat()); await new Promise<void>((resolve) => { setTimeout(resolve, 0); });
      expect(controller.isUnavailable()).assertEqual(true); expect(store.getState().chats.basicGroupAccess.size).assertEqual(0);
      controller.dispose();
    });
  });
}
