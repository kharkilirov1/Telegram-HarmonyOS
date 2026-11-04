// Chat default permissions (S12j).
// TDLib: chatPermissions (td_api.tl:925), setChatPermissions (:12160). The object is written back whole,
// so every field is kept even when the screen only edits a few of them.

import { TdObject as TdObjectType } from '../../../models/TdTypes';

export type ChatPermissionKey = 'canSendBasicMessages' | 'canSendAudios' | 'canSendDocuments' |
  'canSendPhotos' | 'canSendVideos' | 'canSendVideoNotes' | 'canSendVoiceNotes' | 'canSendPolls' |
  'canSendOtherMessages' | 'canAddLinkPreviews' | 'canChangeInfo' | 'canInviteUsers' |
  'canPinMessages' | 'canCreateTopics';

export class ChatPermissionsDto {
  canSendBasicMessages: boolean = false;
  canSendAudios: boolean = false;
  canSendDocuments: boolean = false;
  canSendPhotos: boolean = false;
  canSendVideos: boolean = false;
  canSendVideoNotes: boolean = false;
  canSendVoiceNotes: boolean = false;
  canSendPolls: boolean = false;
  canSendOtherMessages: boolean = false;
  canAddLinkPreviews: boolean = false;
  canChangeInfo: boolean = false;
  canInviteUsers: boolean = false;
  canPinMessages: boolean = false;
  canCreateTopics: boolean = false;

  clone(): ChatPermissionsDto {
    const copy = new ChatPermissionsDto();
    copy.canSendBasicMessages = this.canSendBasicMessages;
    copy.canSendAudios = this.canSendAudios;
    copy.canSendDocuments = this.canSendDocuments;
    copy.canSendPhotos = this.canSendPhotos;
    copy.canSendVideos = this.canSendVideos;
    copy.canSendVideoNotes = this.canSendVideoNotes;
    copy.canSendVoiceNotes = this.canSendVoiceNotes;
    copy.canSendPolls = this.canSendPolls;
    copy.canSendOtherMessages = this.canSendOtherMessages;
    copy.canAddLinkPreviews = this.canAddLinkPreviews;
    copy.canChangeInfo = this.canChangeInfo;
    copy.canInviteUsers = this.canInviteUsers;
    copy.canPinMessages = this.canPinMessages;
    copy.canCreateTopics = this.canCreateTopics;
    return copy;
  }
}

// Absent bits stay false: a permission that TDLib did not send never grants anything.
export function createChatPermissionsFromTd(td: TdObjectType): ChatPermissionsDto | undefined {
  if (td.getTopLevelStringStrict('@type') !== 'chatPermissions') {
    return undefined;
  }
  const dto = new ChatPermissionsDto();
  dto.canSendBasicMessages = td.getTopLevelBooleanStrict('can_send_basic_messages') === true;
  dto.canSendAudios = td.getTopLevelBooleanStrict('can_send_audios') === true;
  dto.canSendDocuments = td.getTopLevelBooleanStrict('can_send_documents') === true;
  dto.canSendPhotos = td.getTopLevelBooleanStrict('can_send_photos') === true;
  dto.canSendVideos = td.getTopLevelBooleanStrict('can_send_videos') === true;
  dto.canSendVideoNotes = td.getTopLevelBooleanStrict('can_send_video_notes') === true;
  dto.canSendVoiceNotes = td.getTopLevelBooleanStrict('can_send_voice_notes') === true;
  dto.canSendPolls = td.getTopLevelBooleanStrict('can_send_polls') === true;
  dto.canSendOtherMessages = td.getTopLevelBooleanStrict('can_send_other_messages') === true;
  dto.canAddLinkPreviews = td.getTopLevelBooleanStrict('can_add_link_previews') === true;
  dto.canChangeInfo = td.getTopLevelBooleanStrict('can_change_info') === true;
  dto.canInviteUsers = td.getTopLevelBooleanStrict('can_invite_users') === true;
  dto.canPinMessages = td.getTopLevelBooleanStrict('can_pin_messages') === true;
  dto.canCreateTopics = td.getTopLevelBooleanStrict('can_create_topics') === true;
  return dto;
}

export function chatPermissionsToJson(permissions: ChatPermissionsDto): string {
  return '{"@type":"chatPermissions"' +
    ',"can_send_basic_messages":' + (permissions.canSendBasicMessages ? 'true' : 'false') +
    ',"can_send_audios":' + (permissions.canSendAudios ? 'true' : 'false') +
    ',"can_send_documents":' + (permissions.canSendDocuments ? 'true' : 'false') +
    ',"can_send_photos":' + (permissions.canSendPhotos ? 'true' : 'false') +
    ',"can_send_videos":' + (permissions.canSendVideos ? 'true' : 'false') +
    ',"can_send_video_notes":' + (permissions.canSendVideoNotes ? 'true' : 'false') +
    ',"can_send_voice_notes":' + (permissions.canSendVoiceNotes ? 'true' : 'false') +
    ',"can_send_polls":' + (permissions.canSendPolls ? 'true' : 'false') +
    ',"can_send_other_messages":' + (permissions.canSendOtherMessages ? 'true' : 'false') +
    ',"can_add_link_previews":' + (permissions.canAddLinkPreviews ? 'true' : 'false') +
    ',"can_change_info":' + (permissions.canChangeInfo ? 'true' : 'false') +
    ',"can_invite_users":' + (permissions.canInviteUsers ? 'true' : 'false') +
    ',"can_pin_messages":' + (permissions.canPinMessages ? 'true' : 'false') +
    ',"can_create_topics":' + (permissions.canCreateTopics ? 'true' : 'false') + '}';
}
