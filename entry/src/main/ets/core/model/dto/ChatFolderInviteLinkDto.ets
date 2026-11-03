// Chat folder invite links — folder editor "Invite Links" section (B7 / S13e).
// TDLib: chatFolderInviteLink (td_api.tl:3121), getChatFolderInviteLinks (:12090),
// createChatFolderInviteLink (:12087), editChatFolderInviteLink (:12097),
// deleteChatFolderInviteLink (:12102).

import { TdObject as TdObjectType } from '../../../models/TdTypes';

export class ChatFolderInviteLinkDto {
  inviteLink: string = '';
  name: string = '';
  chatIds: number[] = [];
}

function readChatIds(td: TdObjectType): number[] {
  const ids: number[] = [];
  const rawItems = td.getTopLevelRawItemArrayStrict('chat_ids');
  if (rawItems === undefined) {
    return ids;
  }
  for (const raw of rawItems) {
    if (raw === null) {
      continue;
    }
    const value = Number(raw);
    if (Number.isSafeInteger(value) && value !== 0) {
      ids.push(value);
    }
  }
  return ids;
}

export function createChatFolderInviteLinkFromTd(td: TdObjectType): ChatFolderInviteLinkDto | undefined {
  if (td.getTopLevelStringStrict('@type') !== 'chatFolderInviteLink') {
    return undefined;
  }
  const dto = new ChatFolderInviteLinkDto();
  dto.inviteLink = td.getTopLevelStringStrict('invite_link') ?? '';
  dto.name = td.getTopLevelStringStrict('name') ?? '';
  dto.chatIds = readChatIds(td);
  return dto.inviteLink.length > 0 ? dto : undefined;
}

export class ChatFolderInviteLinksDto {
  links: ChatFolderInviteLinkDto[] = [];
}

export function createChatFolderInviteLinksFromTd(td: TdObjectType): ChatFolderInviteLinksDto {
  const dto = new ChatFolderInviteLinksDto();
  if (td.getTopLevelStringStrict('@type') !== 'chatFolderInviteLinks') {
    return dto;
  }
  const rawItems = td.getTopLevelRawItemArrayStrict('invite_links');
  if (rawItems === undefined) {
    return dto;
  }
  for (const raw of rawItems) {
    if (raw === null) {
      continue;
    }
    const link = createChatFolderInviteLinkFromTd(TdObjectType.fromJSON(raw));
    if (link !== undefined) {
      dto.links.push(link);
    }
  }
  return dto;
}
