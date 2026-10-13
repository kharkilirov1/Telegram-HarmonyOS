import { describe, it, expect } from '@ohos/hypium';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { Chat, createInitialAppState } from '../../../main/ets/core/model/AppState';
import { GroupAccessDto, GroupSendPermissionsDto } from '../../../main/ets/core/model/dto/GroupAccessDto';
import { ChatUpdateDto, createChatDtoFromTd, applyChatUpdate } from '../../../main/ets/core/model/dto/ChatDto';
import { cloneChat } from '../../../main/ets/core/utils/stateClone';
import { EventNormalizerImpl } from '../../../main/ets/core/events/EventNormalizer';
import { appReducer } from '../../../main/ets/core/reducers/index';
import { AppStore } from '../../../main/ets/core/store/AppStore';
import { ChatUpdatedEvent } from '../../../main/ets/core/model/AppEvent';
import { selectChatInputPanel } from '../../../main/ets/ui/pages/chat/ChatInputPanelPolicy';

function mediaChat(): Chat {
  const chat = new Chat(); chat.id = -77; chat.basicGroupId = 77; chat.type = 'group';
  chat.canSendBasicMessages = false; chat.sendPermissions = new GroupSendPermissionsDto();
  chat.sendPermissions.canSendPhotos = true;
  return chat;
}
function member(): GroupAccessDto {
  const access = new GroupAccessDto(); access.kind = 'basicGroup'; access.groupId = 77;
  access.role = 'member'; access.isMember = true; access.isActive = true;
  return access;
}
export default function basicGroupMediaTest() {
  describe('BasicGroupMedia', () => {
    it('photo-only retains composer and caption permission without text or video', 0, () => {
      const chat = mediaChat(); const access = member();
      expect(selectChatInputPanel(chat, access)).assertEqual('composer');
      expect(selectChatInputPanel(chat, access, false, 'photo')).assertEqual('composer');
      expect(selectChatInputPanel(chat, access, false, 'text')).assertEqual('restricted');
      expect(selectChatInputPanel(chat, access, false, 'video')).assertEqual('restricted');
    });
    it('missing defaults are unknown but an active administrator does not need them', 0, () => {
      const chat = mediaChat(); chat.sendPermissions = undefined; const access = member();
      expect(selectChatInputPanel(chat, access)).assertEqual('unknown');
      access.role = 'administrator'; expect(selectChatInputPanel(chat, access)).assertEqual('composer');
      access.isActive = false; expect(selectChatInputPanel(chat, access)).assertEqual('banned');
    });
    it('individual restrictions intersect each default bit', 0, () => {
      const chat = mediaChat(); const access = member(); access.role = 'restricted';
      access.permissions = new GroupSendPermissionsDto(); access.permissions.canSendVideos = true;
      expect(selectChatInputPanel(chat, access)).assertEqual('restricted');
      access.permissions.canSendPhotos = true;
      expect(selectChatInputPanel(chat, access, false, 'photo')).assertEqual('composer');
      expect(selectChatInputPanel(chat, access, false, 'video')).assertEqual('restricted');
    });
    it('clone and unrelated updates retain independent snapshots', 0, () => {
      const chat = mediaChat(); const copy = cloneChat(chat);
      expect(copy.sendPermissions === chat.sendPermissions).assertEqual(false);
      if (copy.sendPermissions) copy.sendPermissions.canSendPhotos = false;
      expect(chat.sendPermissions?.canSendPhotos).assertEqual(true);
      const dto = createChatDtoFromTd(TdObject.fromJSON('{"@type":"chat","id":-77,"permissions":{"can_send_basic_messages":false,"can_send_photos":true}}'));
      const update = new ChatUpdateDto(); update.title = 'renamed';
      const changed = applyChatUpdate(dto, update);
      expect(changed.sendPermissions?.canSendPhotos).assertEqual(true);
      expect(changed.sendPermissions === dto.sendPermissions).assertEqual(false);
    });
    it('live permissions survive normalizer/reducer and do not alias the event DTO', 0, async () => {
      const store = new AppStore(appReducer, createInitialAppState(), false);
      const events = new EventNormalizerImpl().normalize(TdObject.fromJSON('{"@type":"updateChatPermissions","chat_id":-77,"permissions":{"can_send_basic_messages":false,"can_send_voice_notes":true,"can_send_other_messages":true}}'));
      expect(events.length).assertEqual(1); await store.dispatchBatch(events);
      const chat = store.getState().chats.chats.get(-77);
      expect(chat?.sendPermissions?.canSendVoiceNotes).assertEqual(true);
      expect(chat?.sendPermissions?.canSendOtherMessages).assertEqual(true);
      expect(chat?.sendPermissions?.canSendPhotos).assertEqual(false);
      const event = events[0] as ChatUpdatedEvent;
      if (event.updates.sendPermissions) event.updates.sendPermissions.canSendVoiceNotes = false;
      expect(chat?.sendPermissions?.canSendVoiceNotes).assertEqual(true);
    });
    it('invalid and nested media bits cannot grant capability', 0, () => {
      const dto = createChatDtoFromTd(TdObject.fromJSON('{"@type":"chat","id":-77,"permissions":{"can_send_basic_messages":false,"can_send_photos":"true","nested":{"can_send_videos":true}}}'));
      expect(dto.sendPermissions?.canSendPhotos).assertEqual(false);
      expect(dto.sendPermissions?.canSendVideos).assertEqual(false);
    });
  });
}
