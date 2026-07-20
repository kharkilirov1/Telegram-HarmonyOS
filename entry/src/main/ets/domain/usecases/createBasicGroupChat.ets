// Creates a TDLib basic group, preserves partial member failures, then hydrates
// the resulting chat through getChat before returning it to the UI layer.

import {
  createGetChatCommand,
  createNewBasicGroupChatCommand
} from '../../core/model/AppCommand';
import { UserId } from '../../core/model/EntityId';
import { ChatDto, ChatType, createChatDtoFromTd } from '../../core/model/dto/ChatDto';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const MAX_GROUP_TITLE_LENGTH = 128;
export const MAX_BASIC_GROUP_MEMBER_COUNT = 200;

export class BasicGroupFailedMember {
  userId: UserId = 0;
  premiumWouldAllowInvite: boolean = false;
  premiumRequiredToSendMessages: boolean = false;
}

export class CreatedBasicGroupChatResponse {
  chatId: number = 0;
  failedMembers: BasicGroupFailedMember[] = [];
}

export class CreateBasicGroupChatResult {
  chat: ChatDto = new ChatDto();
  failedMembers: BasicGroupFailedMember[] = [];
  isHydrated: boolean = true;

  constructor(chat: ChatDto, failedMembers: BasicGroupFailedMember[], isHydrated: boolean = true) {
    this.chat = chat;
    this.failedMembers = failedMembers;
    this.isHydrated = isHydrated;
  }
}

export function uniquePositiveGroupMemberIds(userIds: UserId[]): UserId[] {
  const result: UserId[] = [];
  const seen: Set<number> = new Set<number>();
  for (const rawId of userIds) {
    const userId: number = Math.trunc(rawId);
    if (!Number.isFinite(userId) || userId <= 0 || seen.has(userId)) {
      continue;
    }
    seen.add(userId);
    result.push(userId);
  }
  return result;
}

export function normalizeBasicGroupTitle(title: string): string {
  const normalizedTitle: string = title.trim();
  if (normalizedTitle.length === 0 || normalizedTitle.length > MAX_GROUP_TITLE_LENGTH) {
    throw new Error('CreateBasicGroupChatUseCase: title must contain 1-128 characters');
  }
  return normalizedTitle;
}

export function parseCreatedBasicGroupChatResponse(
  response: TdObject
): CreatedBasicGroupChatResponse | undefined {
  if (response.getType() !== 'createdBasicGroupChat') {
    return undefined;
  }

  const chatId: number = response.getTopLevelNumber('chat_id');
  if (chatId <= 0) {
    return undefined;
  }

  const result = new CreatedBasicGroupChatResponse();
  result.chatId = chatId;
  const failedContainer: TdObject = response.getObject('failed_to_add_members');
  const seen: Set<number> = new Set<number>();
  for (const entry of failedContainer.getArray('failed_to_add_members')) {
    if (entry.getType() !== 'failedToAddMember') {
      continue;
    }
    const userId: number = entry.getTopLevelNumber('user_id');
    if (userId <= 0 || seen.has(userId)) {
      continue;
    }
    seen.add(userId);
    const failedMember = new BasicGroupFailedMember();
    failedMember.userId = userId;
    failedMember.premiumWouldAllowInvite = entry.getBool('premium_would_allow_invite');
    failedMember.premiumRequiredToSendMessages = entry.getBool('premium_required_to_send_messages');
    result.failedMembers.push(failedMember);
  }
  return result;
}

export class CreateBasicGroupChatUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async execute(userIds: UserId[], title: string): Promise<CreateBasicGroupChatResult> {
    const uniqueUserIds: UserId[] = uniquePositiveGroupMemberIds(userIds);
    if (uniqueUserIds.length > MAX_BASIC_GROUP_MEMBER_COUNT) {
      throw new Error('CreateBasicGroupChatUseCase: too many members');
    }
    const normalizedTitle: string = normalizeBasicGroupTitle(title);

    const createResponse = await this.gateway.send(
      createNewBasicGroupChatCommand(uniqueUserIds, normalizedTitle, 0)
    );
    if (!(createResponse instanceof TdObject)) {
      throw new Error('Group creation failed');
    }
    const created: CreatedBasicGroupChatResponse | undefined =
      parseCreatedBasicGroupChatResponse(createResponse);
    if (created === undefined) {
      throw new Error('Group creation failed');
    }

    try {
      const chatResponse = await this.gateway.send(createGetChatCommand(created.chatId));
      if (chatResponse instanceof TdObject && chatResponse.getType() === 'chat') {
        const chat: ChatDto = createChatDtoFromTd(chatResponse);
        if (chat.id === created.chatId && chat.type === ChatType.GROUP) {
          return new CreateBasicGroupChatResult(chat, created.failedMembers);
        }
      }
    } catch (_error) {
    }

    // createdBasicGroupChat is the authoritative commit witness. If the
    // follow-up hydration fails, return the committed identity instead of
    // inviting the UI to repeat createNewBasicGroupChat and duplicate it.
    const committedChat = new ChatDto();
    committedChat.id = created.chatId;
    committedChat.type = ChatType.GROUP;
    committedChat.title = normalizedTitle;
    return new CreateBasicGroupChatResult(committedChat, created.failedMembers, false);
  }
}

export function createBasicGroupChatUseCase(gateway: TdGatewayPort): CreateBasicGroupChatUseCase {
  return new CreateBasicGroupChatUseCase(gateway);
}
