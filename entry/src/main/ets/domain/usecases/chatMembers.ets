// Chat members use case — the Telegram custom-content side of Peer Info.
// TDLib contract:
// - getSupergroupMembers(supergroup_id, filter, offset, limit) for pageable lists
// - searchChatMembers(chat_id, query, limit, filter) for search/basic groups

import { ChatId } from '../../core/model/EntityId';
import {
  ChatMembersFilterKind,
  createGetSupergroupMembersCommand,
  createSearchChatMembersCommand
} from '../../core/model/AppCommand';
import { TdObject, tdGetArray, tdGetBoolean, tdGetNumber, tdGetObject, tdGetString } from '../../core/utils/tdAccessors';
import { TdGatewayPort } from '../ports/TdGatewayPort';

export type ChatMemberRole = 'creator' | 'administrator' | 'member' | 'restricted' | 'left' | 'banned';

export class ChatMemberDescriptor {
  senderUserId: number = 0;
  senderChatId: number = 0;
  role: ChatMemberRole = 'member';
  customTitle: string = '';
  isAnonymous: boolean = false;

  stableKey(): string {
    if (this.senderUserId !== 0) {
      return 'user_' + this.senderUserId.toString();
    }
    return 'chat_' + this.senderChatId.toString();
  }
}

export class ChatMembersResult {
  totalCount: number = 0;
  members: ChatMemberDescriptor[] = [];
  canLoadMore: boolean = false;
}

function parseRole(statusType: string): ChatMemberRole {
  switch (statusType) {
    case 'chatMemberStatusCreator':
      return 'creator';
    case 'chatMemberStatusAdministrator':
      return 'administrator';
    case 'chatMemberStatusRestricted':
      return 'restricted';
    case 'chatMemberStatusLeft':
      return 'left';
    case 'chatMemberStatusBanned':
      return 'banned';
    default:
      return 'member';
  }
}

export function parseChatMembersResponse(response: TdObject, offset: number = 0): ChatMembersResult {
  const result = new ChatMembersResult();
  if (tdGetString(response, '@type') !== 'chatMembers') {
    return result;
  }

  result.totalCount = tdGetNumber(response, 'total_count');
  const members = tdGetArray(response, 'members');
  for (let i = 0; i < members.length; i++) {
    const member = members[i];
    const sender = tdGetObject(member, 'member_id');
    const senderType = tdGetString(sender, '@type');
    const descriptor = new ChatMemberDescriptor();
    if (senderType === 'messageSenderUser') {
      descriptor.senderUserId = tdGetNumber(sender, 'user_id');
    } else if (senderType === 'messageSenderChat') {
      descriptor.senderChatId = tdGetNumber(sender, 'chat_id');
    } else {
      continue;
    }

    const status = tdGetObject(member, 'status');
    descriptor.role = parseRole(tdGetString(status, '@type'));
    descriptor.customTitle = tdGetString(status, 'custom_title');
    descriptor.isAnonymous = tdGetBoolean(status, 'is_anonymous');
    result.members.push(descriptor);
  }
  result.canLoadMore = offset + result.members.length < result.totalCount;
  return result;
}

export class ChatMembersUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async execute(
    chatId: ChatId,
    supergroupId: number,
    filterKind: ChatMembersFilterKind = 'all',
    query: string = '',
    offset: number = 0,
    limit: number = 100
  ): Promise<ChatMembersResult> {
    if (chatId === 0) {
      throw new Error('ChatMembersUseCase: invalid chatId');
    }

    const normalizedQuery = query.trim();
    const usePageableSupergroupPath = normalizedQuery.length === 0 && supergroupId > 0;
    const command = usePageableSupergroupPath
      ? createGetSupergroupMembersCommand(supergroupId, offset, limit, filterKind)
      : createSearchChatMembersCommand(chatId, normalizedQuery, 200, filterKind);
    const response = await this.gateway.send(command) as TdObject;
    if (tdGetString(response, '@type') !== 'chatMembers') {
      const message = tdGetString(response, 'message');
      throw new Error(message.length > 0 ? message : 'TDLib did not return chatMembers');
    }

    const result = parseChatMembersResponse(response, usePageableSupergroupPath ? offset : 0);
    if (!usePageableSupergroupPath) {
      result.canLoadMore = false;
    }
    return result;
  }
}

export function createChatMembersUseCase(gateway: TdGatewayPort): ChatMembersUseCase {
  return new ChatMembersUseCase(gateway);
}
