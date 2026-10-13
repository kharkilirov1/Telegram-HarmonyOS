import { describe, it, expect } from '@ohos/hypium';
import { EventNormalizerImpl } from '../../../main/ets/core/events/EventNormalizer';
import { Chat, createInitialAppState } from '../../../main/ets/core/model/AppState';
import { ChatDto, ChatUpdateDto, applyChatUpdate } from '../../../main/ets/core/model/dto/ChatDto';
import { appReducer } from '../../../main/ets/core/reducers/index';
import { AppStore } from '../../../main/ets/core/store/AppStore';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { selectChatInputPanel } from '../../../main/ets/ui/pages/chat/ChatInputPanelPolicy';

export default function liveChatPermissionsTest() {
  describe('LiveChatPermissions', () => {
    it('routes live revoke and grant through combined reducer to group input policy', 0, async () => {
      const state = createInitialAppState();
      const chat = new Chat();
      chat.id = -100123;
      chat.type = 'supergroup';
      chat.supergroupId = 123;
      state.chats.chats.set(chat.id, chat);
      const store = new AppStore(appReducer, state, false);
      const normalizer = new EventNormalizerImpl();
      await store.dispatchBatch(normalizer.normalize(TdObject.fromJSON(
        '{"@type":"updateSupergroup","supergroup":{"@type":"supergroup","id":123,' +
          '"status":{"@type":"chatMemberStatusMember"}}}')));
      await store.dispatchBatch(normalizer.normalize(TdObject.fromJSON(
        '{"@type":"updateSupergroupFullInfo","supergroup_id":123,"supergroup_full_info":' +
          '{"@type":"supergroupFullInfo","my_boost_count":0,"unrestrict_boost_count":0}}')));
      const revoke = normalizer.normalize(TdObject.fromJSON(
        '{"@type":"updateChatPermissions","chat_id":-100123,' +
          '"permissions":{"@type":"chatPermissions","can_send_basic_messages":false}}'));
      expect(revoke.length).assertEqual(1);
      await store.dispatchBatch(revoke);
      expect(store.getState().chats.chats.get(chat.id)?.canSendBasicMessages).assertEqual(false);
      expect(selectChatInputPanel(store.getState().chats.chats.get(chat.id)!,
        store.getState().chats.supergroupAccess.get(123), false, '', store.getState().chats.supergroupBoosts.get(123))).assertEqual('restricted');
      expect(chat.canSendBasicMessages).assertEqual(true);
      const grant = normalizer.normalize(TdObject.fromJSON(
        '{"@type":"updateChatPermissions","chat_id":-100123,' +
          '"permissions":{"@type":"chatPermissions","can_send_basic_messages":true}}'));
      await store.dispatchBatch(grant);
      expect(selectChatInputPanel(store.getState().chats.chats.get(chat.id)!,
        store.getState().chats.supergroupAccess.get(123), false, '', store.getState().chats.supergroupBoosts.get(123))).assertEqual('composer');
    });

    it('rejects malformed IDs and missing or string permissions', 0, () => {
      const normalizer = new EventNormalizerImpl();
      const malformed: string[] = [
        '{"@type":"updateChatPermissions","chat_id":-100.5,"permissions":{"can_send_basic_messages":false}}',
        '{"@type":"updateChatPermissions","chat_id":"-100123","permissions":{"can_send_basic_messages":false}}',
        '{"@type":"updateChatPermissions","chat_id":-100123,"permissions":{"can_send_basic_messages":"false"}}',
        '{"@type":"updateChatPermissions","chat_id":-100123,"permissions":{}}',
        '{"@type":"updateChatPermissions","nested":{"chat_id":-100123},"permissions":{"can_send_basic_messages":false}}'
      ];
      for (const json of malformed) {
        expect(normalizer.normalize(TdObject.fromJSON(json)).length).assertEqual(0);
      }
    });

    it('reads explicit top-level booleans instead of nested lookalikes', 0, () => {
      const raw = TdObject.fromJSON('{"nested":{"permissions":{"can_send_basic_messages":false}},' +
        '"permissions":{"nested":{"can_send_basic_messages":false},"can_send_basic_messages":true}}');
      expect(raw.getTopLevelObjectStrict('permissions')?.getTopLevelBooleanStrict('can_send_basic_messages'))
        .assertEqual(true);
      expect(TdObject.fromJSON('{"nested":{"permissions":{}}}').getTopLevelObjectStrict('permissions'))
        .assertEqual(undefined);
    });

    it('retains revoked permission through unrelated DTO patches and applies explicit grant', 0, () => {
      const chat = new ChatDto();
      chat.canSendBasicMessages = false;
      const rename = new ChatUpdateDto();
      rename.title = 'Renamed';
      const renamed = applyChatUpdate(chat, rename);
      expect(renamed.canSendBasicMessages).assertEqual(false);
      const grant = new ChatUpdateDto();
      grant.canSendBasicMessages = true;
      expect(applyChatUpdate(renamed, grant).canSendBasicMessages).assertEqual(true);
      expect(renamed.canSendBasicMessages).assertEqual(false);
    });

    it('does not replace a private composer with a group restriction panel', 0, () => {
      const chat = new Chat();
      chat.id = 7;
      chat.type = 'private';
      chat.canSendBasicMessages = false;
      expect(selectChatInputPanel(chat)).assertEqual('composer');
    });

    it('drops queued permission events owned by the previous account', 0, async () => {
      const root = new AppStore(appReducer, undefined, false);
      const scope = root.createScope();
      const normalizer = new EventNormalizerImpl();
      const events = normalizer.normalize(TdObject.fromJSON(
        '{"@type":"updateChatPermissions","chat_id":-100123,' +
          '"permissions":{"can_send_basic_messages":false}}'));
      expect(events.length).assertEqual(1);
      const queued = scope.dispatchBatch(events);
      const reset = root.resetStateQueued();
      await queued;
      await reset;
      await scope.dispatchBatch(events);
      expect(root.getState().chats.chats.size).assertEqual(0);
    });
  });
}
