import { describe, it, expect } from '@ohos/hypium';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { createGroupAccessDtoFromTd } from '../../../main/ets/core/model/dto/GroupAccessDto';
import { cloneGroupAccess } from '../../../main/ets/core/utils/stateClone';
import { EventNormalizerImpl } from '../../../main/ets/core/events/EventNormalizer';
import { Chat, createInitialAppState } from '../../../main/ets/core/model/AppState';
import { appReducer } from '../../../main/ets/core/reducers/index';
import { AppStore } from '../../../main/ets/core/store/AppStore';
import { selectChatInputPanel } from '../../../main/ets/ui/pages/chat/ChatInputPanelPolicy';

export default function groupPermissionPayloadTest() {
  describe('GroupPermissionPayload', () => {
    it('retains independent text and media restrictions through the live pipeline', 0, async () => {
      const normalizer = new EventNormalizerImpl();
      const store = new AppStore(appReducer, createInitialAppState(), false);
      await store.dispatchBatch(normalizer.normalize(TdObject.fromJSON(
        '{"@type":"updateSupergroup","supergroup":{"@type":"supergroup","id":77,' +
        '"status":{"@type":"chatMemberStatusRestricted","is_member":true,"permissions":{' +
        '"can_send_basic_messages":false,"can_send_photos":true,"can_send_voice_notes":true,' +
        '"can_send_documents":false,"can_send_other_messages":false}}}}')));
      const access = store.getState().chats.supergroupAccess.get(77);
      expect(access?.permissions?.canSendBasicMessages).assertEqual(false);
      expect(access?.permissions?.canSendPhotos).assertEqual(true);
      expect(access?.permissions?.canSendVoiceNotes).assertEqual(true);
      expect(access?.permissions?.canSendDocuments).assertEqual(false);
      expect(access?.permissions?.canSendOtherMessages).assertEqual(false);
    });

    it('copies nested rights instead of aliasing the producer', 0, () => {
      const access = createGroupAccessDtoFromTd(TdObject.fromJSON(
        '{"@type":"supergroup","id":77,"status":{"@type":"chatMemberStatusRestricted",' +
        '"is_member":true,"permissions":{"can_send_photos":true,"can_send_audios":true}}}'), 'supergroup')!;
      const cloned = cloneGroupAccess(access);
      expect(cloned.permissions === access.permissions).assertEqual(false);
      access.permissions!.canSendPhotos = false;
      access.permissions!.canSendAudios = false;
      expect(cloned.permissions?.canSendPhotos).assertEqual(true);
      expect(cloned.permissions?.canSendAudios).assertEqual(true);
    });

    it('distinguishes unknown permission object from explicit denied fields', 0, () => {
      const unknown = createGroupAccessDtoFromTd(TdObject.fromJSON(
        '{"@type":"supergroup","id":77,"status":{"@type":"chatMemberStatusRestricted",' +
        '"is_member":true,"nested":{"permissions":{"can_send_photos":true}}}}'), 'supergroup');
      expect(unknown?.permissions).assertEqual(undefined);
      const denied = createGroupAccessDtoFromTd(TdObject.fromJSON(
        '{"@type":"supergroup","id":77,"status":{"@type":"chatMemberStatusRestricted",' +
        '"is_member":true,"permissions":{"nested":{"can_send_photos":true},' +
        '"can_send_photos":false,"can_send_voice_notes":"true"}}}'), 'supergroup');
      expect(denied?.permissions?.canSendPhotos).assertEqual(false);
      expect(denied?.permissions?.canSendVoiceNotes).assertEqual(false);
      expect(denied?.permissions?.canSendBasicMessages).assertEqual(false);
    });

    it('does not turn a banned channel into a composer using a nested creator lookalike', 0, () => {
      const normalizer = new EventNormalizerImpl();
      const events = normalizer.normalize(TdObject.fromJSON(
        '{"@type":"updateSupergroup","supergroup":{"@type":"supergroup","id":77,' +
        '"nested":{"status":{"@type":"chatMemberStatusCreator","is_member":true}},' +
        '"status":{"@type":"chatMemberStatusBanned"}}}'));
      expect(events.length).assertEqual(1);
      const state = appReducer(createInitialAppState(), events[0]);
      const chat = new Chat();
      chat.type = 'channel';
      chat.supergroupId = 77;
      expect(selectChatInputPanel(chat, state.chats.supergroupAccess.get(77))).assertEqual('banned');
    });

    it('rejects nested-only group wrappers for both update types', 0, () => {
      const normalizer = new EventNormalizerImpl();
      const inputs: string[] = [
        '{"@type":"updateSupergroup","nested":{"supergroup":{"@type":"supergroup","id":77,"status":{"@type":"chatMemberStatusMember"}}}}',
        '{"@type":"updateBasicGroup","nested":{"basic_group":{"@type":"basicGroup","id":77,"is_active":true,"status":{"@type":"chatMemberStatusMember"}}}}'
      ];
      for (const json of inputs) expect(normalizer.normalize(TdObject.fromJSON(json)).length).assertEqual(0);
    });

    it('reads authoritative status type despite legacy cache and nested membership', 0, () => {
      const typed = TdObject.fromJSON('{"nested":{"@type":"chatMemberStatusCreator"},"@type":"chatMemberStatusBanned"}');
      typed.getString('@type');
      expect(typed.getTopLevelStringStrict('@type')).assertEqual('chatMemberStatusBanned');
      const creator = createGroupAccessDtoFromTd(TdObject.fromJSON(
        '{"@type":"supergroup","id":77,"status":{"@type":"chatMemberStatusCreator",' +
        '"nested":{"is_member":true},"is_member":false}}'), 'supergroup');
      expect(creator?.isMember).assertEqual(false);
      expect(creator?.canPostMessages).assertEqual(false);
    });
  });
}
