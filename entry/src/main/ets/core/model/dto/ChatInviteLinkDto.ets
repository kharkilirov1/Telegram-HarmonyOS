// Chat invite links (S12h).
// TDLib: getChatInviteLinks (td_api.tl:12821) -> chatInviteLinks (:2320), createChatInviteLink (:12780),
// revokeChatInviteLink (:12835). There is no exportChatInviteLink in this TDLib revision: the primary
// link is the listed entry with is_primary = true.

import { TdObject as TdObjectType } from '../../../models/TdTypes';

export class ChatInviteLinkDto {
  inviteLink: string = '';
  name: string = '';
  creatorUserId: number = 0;
  date: number = 0;
  expirationDate: number = 0;
  memberLimit: number = 0;
  memberCount: number = 0;
  pendingJoinRequestCount: number = 0;
  createsJoinRequest: boolean = false;
  isPrimary: boolean = false;
  isRevoked: boolean = false;
}

export class ChatInviteLinksDto {
  totalCount: number = 0;
  links: ChatInviteLinkDto[] = [];
}

export function createChatInviteLinkFromTd(td: TdObjectType): ChatInviteLinkDto | undefined {
  if (td.getTopLevelStringStrict('@type') !== 'chatInviteLink') {
    return undefined;
  }
  const dto = new ChatInviteLinkDto();
  dto.inviteLink = td.getTopLevelStringStrict('invite_link') ?? '';
  dto.name = td.getTopLevelStringStrict('name') ?? '';
  dto.creatorUserId = td.getTopLevelNumberStrict('creator_user_id') ?? 0;
  dto.date = td.getTopLevelNumberStrict('date') ?? 0;
  dto.expirationDate = td.getTopLevelNumberStrict('expiration_date') ?? 0;
  dto.memberLimit = td.getTopLevelNumberStrict('member_limit') ?? 0;
  dto.memberCount = td.getTopLevelNumberStrict('member_count') ?? 0;
  dto.pendingJoinRequestCount = td.getTopLevelNumberStrict('pending_join_request_count') ?? 0;
  dto.createsJoinRequest = td.getTopLevelBooleanStrict('creates_join_request') ?? false;
  dto.isPrimary = td.getTopLevelBooleanStrict('is_primary') ?? false;
  dto.isRevoked = td.getTopLevelBooleanStrict('is_revoked') ?? false;
  return dto;
}

export function createChatInviteLinksFromTd(td: TdObjectType): ChatInviteLinksDto | undefined {
  if (td.getTopLevelStringStrict('@type') !== 'chatInviteLinks') {
    return undefined;
  }
  const result = new ChatInviteLinksDto();
  result.totalCount = td.getTopLevelNumberStrict('total_count') ?? 0;
  const rawLinks = td.getTopLevelRawItemArrayStrict('invite_links');
  if (rawLinks !== undefined) {
    for (const raw of rawLinks) {
      if (raw === null) {
        continue;
      }
      const link = createChatInviteLinkFromTd(TdObjectType.fromJSON(raw));
      if (link !== undefined && link.inviteLink.length > 0) {
        result.links.push(link);
      }
    }
  }
  return result;
}
