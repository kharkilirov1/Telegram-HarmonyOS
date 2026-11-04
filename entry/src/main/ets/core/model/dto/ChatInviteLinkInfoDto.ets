// Chat invite link info — preview before joining a chat by t.me/+... link (S14c).
// TDLib: checkChatInviteLink (td_api.tl:12846), chatInviteLinkInfo (:2374), joinChatByInviteLink (:12849).

import { TdObject as TdObjectType } from '../../../models/TdTypes';

export class ChatInviteLinkInfoDto {
  // 0 when the user is not a member yet.
  chatId: number = 0;
  title: string = '';
  description: string = '';
  memberCount: number = 0;
  subscriberCount: number = 0;
  isPublic: boolean = false;
  createsJoinRequest: boolean = false;
  isChannel: boolean = false;
  isGroup: boolean = false;
}

export function createChatInviteLinkInfoFromTd(td: TdObjectType): ChatInviteLinkInfoDto | undefined {
  if (td.getTopLevelStringStrict('@type') !== 'chatInviteLinkInfo') {
    return undefined;
  }
  const dto = new ChatInviteLinkInfoDto();
  const chatId = td.getTopLevelNumberStrict('chat_id');
  dto.chatId = chatId !== undefined && Number.isSafeInteger(chatId) && chatId > 0 ? chatId : 0;
  dto.title = td.getTopLevelStringStrict('title') ?? '';
  dto.description = td.getTopLevelStringStrict('description') ?? '';
  const memberCount = td.getTopLevelNumberStrict('member_count');
  dto.memberCount = memberCount !== undefined && Number.isSafeInteger(memberCount) && memberCount >= 0
    ? memberCount : 0;
  dto.isPublic = td.getTopLevelBooleanStrict('is_public') ?? false;
  dto.createsJoinRequest = td.getTopLevelBooleanStrict('creates_join_request') ?? false;
  const type = td.getTopLevelObjectStrict('type');
  const typeName = type === undefined ? '' : (type.getTopLevelStringStrict('@type') ?? '');
  dto.isChannel = typeName === 'inviteLinkChatTypeChannel';
  dto.isGroup = typeName !== '';
  return dto;
}
