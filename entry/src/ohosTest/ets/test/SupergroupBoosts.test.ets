import { describe, it, expect } from '@ohos/hypium';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { Chat } from '../../../main/ets/core/model/AppState';
import {
  GroupAccessDto, GroupSendPermissionsDto, SupergroupBoostsDto, createSupergroupBoostsDtoFromTd
} from '../../../main/ets/core/model/dto/GroupAccessDto';
import { selectChatInputPanel } from '../../../main/ets/ui/pages/chat/ChatInputPanelPolicy';

function supergroupChat(): Chat {
  const chat = new Chat(); chat.id = -77; chat.supergroupId = 77; chat.type = 'supergroup';
  chat.canSendBasicMessages = false; chat.sendPermissions = new GroupSendPermissionsDto();
  return chat;
}
function member(): GroupAccessDto {
  const access = new GroupAccessDto(); access.kind = 'supergroup'; access.groupId = 77;
  access.role = 'member'; access.isMember = true;
  return access;
}
function boostSnapshot(my: number, threshold: number, groupId: number = 77): SupergroupBoostsDto {
  const boosts = new SupergroupBoostsDto(); boosts.groupId = groupId;
  boosts.myBoostCount = my; boosts.unrestrictBoostCount = threshold;
  return boosts;
}

export default function supergroupBoostsTest() {
  describe('SupergroupBoosts', () => {
    it('strict full-info DTO accepts only own numeric counts and a safe positive group identity', 0, () => {
      const zero = createSupergroupBoostsDtoFromTd(TdObject.fromJSON(
        '{"@type":"supergroupFullInfo","my_boost_count":0,"unrestrict_boost_count":0}'), 77);
      expect(zero?.groupId).assertEqual(77);
      expect(zero?.myBoostCount).assertEqual(0);
      expect(zero?.unrestrictBoostCount).assertEqual(0);
      const maximum = createSupergroupBoostsDtoFromTd(TdObject.fromJSON(
        '{"@type":"supergroupFullInfo","my_boost_count":2147483647,"unrestrict_boost_count":2147483647}'), 9007199254740991);
      expect(maximum?.groupId).assertEqual(9007199254740991);
      expect(maximum?.myBoostCount).assertEqual(2147483647);
      expect(maximum?.unrestrictBoostCount).assertEqual(2147483647);

      const invalidShapes: string[] = [
        '{"@type":"supergroup","my_boost_count":2,"unrestrict_boost_count":1}',
        '{"nested":{"@type":"supergroupFullInfo"},"my_boost_count":2,"unrestrict_boost_count":1}',
        '{"@type":"supergroupFullInfo","nested":{"my_boost_count":2,"unrestrict_boost_count":1}}',
        '{"@type":"supergroupFullInfo","my_boost_count":2,"nested":{"unrestrict_boost_count":1}}',
        '{"@type":"supergroupFullInfo","nested":{"my_boost_count":2},"unrestrict_boost_count":1}',
        '{"@type":"supergroupFullInfo","my_boost_count":2}',
        '{"@type":"supergroupFullInfo","unrestrict_boost_count":1}',
        '{"nested":{"@type":"supergroupFullInfo"},"@type":"error","my_boost_count":2,"unrestrict_boost_count":1}'
      ];
      for (const json of invalidShapes) {
        expect(createSupergroupBoostsDtoFromTd(TdObject.fromJSON(json), 77)).assertEqual(undefined);
      }
      const invalidCounts: string[] = ['"2"', 'true', 'null', '-1', '0.5', '2147483648', '1e309', '{}', '[]'];
      for (const value of invalidCounts) {
        expect(createSupergroupBoostsDtoFromTd(TdObject.fromJSON(
          '{"@type":"supergroupFullInfo","my_boost_count":' + value + ',"unrestrict_boost_count":1}'), 77)).assertEqual(undefined);
        expect(createSupergroupBoostsDtoFromTd(TdObject.fromJSON(
          '{"@type":"supergroupFullInfo","my_boost_count":2,"unrestrict_boost_count":' + value + '}'), 77)).assertEqual(undefined);
      }
      const invalidIds: number[] = [0, -77, 1.5, 9007199254740992, Number.NaN, Number.POSITIVE_INFINITY];
      for (const groupId of invalidIds) {
        expect(createSupergroupBoostsDtoFromTd(TdObject.fromJSON(
          '{"@type":"supergroupFullInfo","id":77,"my_boost_count":2,"unrestrict_boost_count":1}'), groupId)).assertEqual(undefined);
      }
      const authoritative = createSupergroupBoostsDtoFromTd(TdObject.fromJSON(
        '{"nested":{"my_boost_count":99,"unrestrict_boost_count":1},"@type":"supergroupFullInfo",' +
        '"my_boost_count":0,"unrestrict_boost_count":3}'), 77);
      expect(authoritative?.myBoostCount).assertEqual(0);
      expect(authoritative?.unrestrictBoostCount).assertEqual(3);
    });

    it('initializes zero fields and clones all boost fields without aliasing', 0, () => {
      const empty = new SupergroupBoostsDto();
      expect(empty.groupId).assertEqual(0);
      expect(empty.myBoostCount).assertEqual(0);
      expect(empty.unrestrictBoostCount).assertEqual(0);
      const original = createSupergroupBoostsDtoFromTd(TdObject.fromJSON(
        '{"@type":"supergroupFullInfo","my_boost_count":2,"unrestrict_boost_count":3}'), 77)!;
      const copy = original.clone();
      expect(copy === original).assertEqual(false);
      expect(copy.groupId).assertEqual(77);
      expect(copy.myBoostCount).assertEqual(2);
      expect(copy.unrestrictBoostCount).assertEqual(3);
      copy.groupId = 88; copy.myBoostCount = 9; copy.unrestrictBoostCount = 1;
      expect(original.groupId).assertEqual(77);
      expect(original.myBoostCount).assertEqual(2);
      expect(original.unrestrictBoostCount).assertEqual(3);
      original.groupId = 99; original.myBoostCount = 0; original.unrestrictBoostCount = 5;
      expect(copy.groupId).assertEqual(88);
      expect(copy.myBoostCount).assertEqual(9);
      expect(copy.unrestrictBoostCount).assertEqual(1);
    });

    it('ordinary members use each default bit and restricted members intersect individual bits', 0, () => {
      const chat = supergroupChat(); const access = member(); const zero = boostSnapshot(0, 2);
      const kinds: string[] = ['text', 'audio', 'document', 'photo', 'video', 'videoNote', 'voice', 'poll', 'other'];
      const fields: string[] = ['can_send_basic_messages', 'can_send_audios', 'can_send_documents',
        'can_send_photos', 'can_send_videos', 'can_send_video_notes', 'can_send_voice_notes', 'can_send_polls', 'can_send_other_messages'];
      // One enabled default at a time catches cross-kind grants, not just a shared text gate.
      for (let i = 0; i < kinds.length; i++) {
        chat.sendPermissions = GroupSendPermissionsDto.fromTd(TdObject.fromJSON('{"' + fields[i] + '":true}'));
        expect(selectChatInputPanel(chat, access, false, kinds[i])).assertEqual('composer');
        for (let j = 0; j < kinds.length; j++) {
          expect(selectChatInputPanel(chat, access, false, kinds[j], zero)).assertEqual(i === j ? 'composer' : 'restricted');
        }
        access.role = 'restricted'; access.permissions = new GroupSendPermissionsDto();
        expect(selectChatInputPanel(chat, access, false, kinds[i], zero)).assertEqual('restricted');
        access.permissions = chat.sendPermissions.clone();
        expect(selectChatInputPanel(chat, access, false, kinds[i], zero)).assertEqual('composer');
        chat.sendPermissions = new GroupSendPermissionsDto();
        expect(selectChatInputPanel(chat, access, false, kinds[i], zero)).assertEqual('restricted');
        access.role = 'member'; access.permissions = undefined;
      }
      chat.sendPermissions = new GroupSendPermissionsDto(); chat.sendPermissions.canSendPhotos = true;
      access.role = 'restricted'; access.permissions = new GroupSendPermissionsDto();
      access.permissions.canSendVideos = true;
      expect(selectChatInputPanel(chat, access, false, '', zero)).assertEqual('restricted');
      access.permissions.canSendPhotos = true;
      expect(selectChatInputPanel(chat, access, false, '', zero)).assertEqual('composer');
      expect(selectChatInputPanel(chat, access, false, 'video', zero)).assertEqual('restricted');
    });

    it('unrestricts at a positive threshold but never treats a zero threshold as a booster', 0, () => {
      const chat = supergroupChat(); const access = member();
      expect(selectChatInputPanel(chat, access, false, 'photo', boostSnapshot(0, 0))).assertEqual('restricted');
      expect(selectChatInputPanel(chat, access, false, 'photo', boostSnapshot(3, 0))).assertEqual('restricted');
      expect(selectChatInputPanel(chat, access, false, 'photo', boostSnapshot(0, 2))).assertEqual('restricted');
      expect(selectChatInputPanel(chat, access, false, 'photo', boostSnapshot(1, 2))).assertEqual('restricted');
      expect(selectChatInputPanel(chat, access, false, 'photo', boostSnapshot(2, 2))).assertEqual('composer');
      expect(selectChatInputPanel(chat, access, false, 'photo', boostSnapshot(3, 2))).assertEqual('composer');
      expect(selectChatInputPanel(chat, access, false, 'text', boostSnapshot(2147483647, 2147483647))).assertEqual('composer');
      expect(selectChatInputPanel(chat, access, false, '', boostSnapshot(2, 2))).assertEqual('composer');
    });

    it('a booster bypasses defaults but cannot override individual denies or missing individual permissions', 0, () => {
      const chat = supergroupChat(); const access = member(); const boosts = boostSnapshot(2, 2);
      access.role = 'restricted'; access.permissions = new GroupSendPermissionsDto();
      access.permissions.canSendPhotos = true;
      expect(selectChatInputPanel(chat, access, false, 'photo', boosts)).assertEqual('composer');
      expect(selectChatInputPanel(chat, access, false, 'text', boosts)).assertEqual('restricted');
      expect(selectChatInputPanel(chat, access, false, 'voice', boosts)).assertEqual('restricted');
      expect(selectChatInputPanel(chat, access, false, '', boosts)).assertEqual('composer');
      expect(selectChatInputPanel(chat, access, false, 'text')).assertEqual('restricted');
      chat.sendPermissions = undefined;
      expect(selectChatInputPanel(chat, access, false, 'photo', boosts)).assertEqual('composer');
      expect(selectChatInputPanel(chat, access, false, 'text', boosts)).assertEqual('restricted');
      chat.sendPermissions = new GroupSendPermissionsDto();
      access.permissions.canSendPhotos = false;
      expect(selectChatInputPanel(chat, access, false, '', boosts)).assertEqual('restricted');
      access.permissions = undefined;
      expect(selectChatInputPanel(chat, access, false, 'photo', boosts)).assertEqual('restricted');
      expect(selectChatInputPanel(chat, access, false, '', boosts)).assertEqual('restricted');
    });

    it('distinguishes unknown boosts from known zero and rejects foreign or invalid snapshots', 0, () => {
      const chat = supergroupChat(); const access = member();
      expect(selectChatInputPanel(chat, access, false, 'text')).assertEqual('unknown');
      expect(selectChatInputPanel(chat, access)).assertEqual('unknown');
      expect(selectChatInputPanel(chat, access, false, 'text', boostSnapshot(0, 0))).assertEqual('restricted');
      expect(selectChatInputPanel(chat, access, false, 'text', boostSnapshot(2, 2, 88))).assertEqual('unknown');
      expect(selectChatInputPanel(chat, access, false, 'text', new SupergroupBoostsDto())).assertEqual('unknown');
      const invalidCounts: number[] = [-1, 0.5, 2147483648, Number.NaN, Number.POSITIVE_INFINITY];
      for (const value of invalidCounts) {
        expect(selectChatInputPanel(chat, access, false, 'text', boostSnapshot(value, 2))).assertEqual('unknown');
        expect(selectChatInputPanel(chat, access, false, 'text', boostSnapshot(2, value))).assertEqual('unknown');
      }
      chat.sendPermissions!.canSendPhotos = true;
      expect(selectChatInputPanel(chat, access, false, 'photo')).assertEqual('composer');
      expect(selectChatInputPanel(chat, access, false, 'photo', boostSnapshot(2, 2, 88))).assertEqual('composer');
      expect(selectChatInputPanel(chat, access, false, 'text', boostSnapshot(2, 2, 88))).assertEqual('unknown');
      access.role = 'restricted'; access.permissions = new GroupSendPermissionsDto();
      access.permissions.canSendBasicMessages = true;
      expect(selectChatInputPanel(chat, access, false, 'text')).assertEqual('unknown');
      expect(selectChatInputPanel(chat, access, false, 'text', boostSnapshot(0, 2))).assertEqual('restricted');
      access.role = 'member'; access.permissions = undefined;
      chat.sendPermissions = undefined; chat.canSendBasicMessages = true;
      expect(selectChatInputPanel(chat, access, false, 'text')).assertEqual('unknown');
      expect(selectChatInputPanel(chat, access, false, 'text', boostSnapshot(0, 2))).assertEqual('unknown');
      expect(selectChatInputPanel(chat, access, false, 'text', boostSnapshot(2, 2))).assertEqual('composer');
    });

    it('requires exact supergroup access before membership and creator or administrator exemptions', 0, () => {
      const chat = supergroupChat(); const access = member(); const boosts = boostSnapshot(2, 2);
      expect(selectChatInputPanel(chat, undefined, false, 'text', boosts)).assertEqual('unknown');
      access.role = 'administrator'; access.groupId = 88;
      expect(selectChatInputPanel(chat, access, false, 'text', boosts)).assertEqual('unknown');
      access.groupId = 77; access.kind = 'basicGroup';
      expect(selectChatInputPanel(chat, access, false, 'text', boosts)).assertEqual('unknown');
      access.kind = 'supergroup'; access.role = 'unknown';
      expect(selectChatInputPanel(chat, access, false, 'text', boosts)).assertEqual('unknown');
      access.role = 'member';
      const invalidIds: number[] = [0, -77, 1.5, 9007199254740992];
      for (const groupId of invalidIds) {
        chat.supergroupId = groupId; access.groupId = groupId;
        expect(selectChatInputPanel(chat, access, false, 'text', boostSnapshot(2, 2, groupId))).assertEqual('unknown');
      }
      chat.supergroupId = 77; access.groupId = 77; access.role = 'banned';
      expect(selectChatInputPanel(chat, access, true, 'text', boosts)).assertEqual('banned');
      access.isMember = false;
      expect(selectChatInputPanel(chat, access, false, 'text', boosts)).assertEqual('banned');
      access.role = 'left';
      expect(selectChatInputPanel(chat, access, false, 'text', boosts)).assertEqual('join');
      access.role = 'restricted';
      expect(selectChatInputPanel(chat, access, false, 'text', boosts)).assertEqual('join');
      access.role = 'administrator';
      expect(selectChatInputPanel(chat, access, false, 'text', boosts)).assertEqual('join');
      access.role = 'creator';
      expect(selectChatInputPanel(chat, access, false, 'text', boosts)).assertEqual('join');
      access.isMember = true;
      expect(selectChatInputPanel(chat, access, false, 'text')).assertEqual('composer');
      access.role = 'administrator'; access.canPostMessages = false; access.canEditMessages = false;
      expect(selectChatInputPanel(chat, access, false, 'photo')).assertEqual('composer');
      chat.sendPermissions = undefined;
      expect(selectChatInputPanel(chat, access, false, 'text')).assertEqual('composer');
      access.role = 'creator';
      expect(selectChatInputPanel(chat, access, false, 'text')).assertEqual('composer');
    });

    it('keeps a media-only composer and attachment groups without granting text or other media', 0, () => {
      const chat = supergroupChat(); const access = member(); const zero = boostSnapshot(0, 2);
      chat.sendPermissions!.canSendPhotos = true;
      expect(selectChatInputPanel(chat, access, false, '', zero)).assertEqual('composer');
      expect(selectChatInputPanel(chat, access, false, 'photo', zero)).assertEqual('composer');
      expect(selectChatInputPanel(chat, access, false, 'attachment', zero)).assertEqual('composer');
      expect(selectChatInputPanel(chat, access, false, 'media', zero)).assertEqual('composer');
      expect(selectChatInputPanel(chat, access, false, 'text', zero)).assertEqual('restricted');
      expect(selectChatInputPanel(chat, access, false, 'video', zero)).assertEqual('restricted');
      expect(selectChatInputPanel(chat, access, false, 'document', zero)).assertEqual('restricted');
      expect(selectChatInputPanel(chat, access, false, 'voice', zero)).assertEqual('restricted');
      expect(selectChatInputPanel(chat, access)).assertEqual('composer');
      access.role = 'restricted'; access.permissions = new GroupSendPermissionsDto();
      access.permissions.canSendPhotos = true;
      expect(selectChatInputPanel(chat, access)).assertEqual('composer');
      expect(selectChatInputPanel(chat, access, false, 'text')).assertEqual('restricted');
    });

    it('does not apply supergroup booster exemptions to basic groups channels or private chats', 0, () => {
      const chat = supergroupChat(); const access = member(); const boosts = boostSnapshot(2, 2);
      chat.type = 'group'; chat.basicGroupId = 77; access.kind = 'basicGroup';
      expect(selectChatInputPanel(chat, access, false, 'text', boosts)).assertEqual('restricted');
      chat.sendPermissions!.canSendPhotos = true;
      expect(selectChatInputPanel(chat, access, false, 'photo', boosts)).assertEqual('composer');
      access.isMember = false;
      expect(selectChatInputPanel(chat, access, false, 'photo', boosts)).assertEqual('banned');
      chat.type = 'channel'; access.kind = 'supergroup'; access.isMember = true; chat.muteForSeconds = 0;
      expect(selectChatInputPanel(chat, access, false, 'text', boosts)).assertEqual('mute');
      chat.muteForSeconds = 10;
      expect(selectChatInputPanel(chat, access, false, 'text', boosts)).assertEqual('unmute');
      access.role = 'administrator'; access.canEditMessages = true; access.canPostMessages = false;
      expect(selectChatInputPanel(chat, access, false, 'text', boosts)).assertEqual('unmute');
      expect(selectChatInputPanel(chat, access, true, 'text', boosts)).assertEqual('composer');
      access.role = 'banned'; access.isMember = false; chat.type = 'private';
      expect(selectChatInputPanel(chat, access, false, 'text', boosts)).assertEqual('composer');
      chat.type = 'secret';
      expect(selectChatInputPanel(chat, access, false, 'text', boosts)).assertEqual('composer');
    });
  });
}
