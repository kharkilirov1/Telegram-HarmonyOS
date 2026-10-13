// Creates the minimal private-channel entity. Public/private selection,
// username assignment and subscriber invitation remain separate follow-up flows.

import { createNewSupergroupChatCommand } from '../../core/model/AppCommand';
import { ChatDto, createChatDtoFromTd } from '../../core/model/dto/ChatDto';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const MAX_CHANNEL_TITLE_LENGTH = 128;
const MAX_CHANNEL_DESCRIPTION_LENGTH = 255;

export function normalizeChannelTitle(title: string): string {
  const normalizedTitle: string = title.trim();
  if (normalizedTitle.length === 0 || normalizedTitle.length > MAX_CHANNEL_TITLE_LENGTH) {
    throw new Error('CreateChannelChatUseCase: title must contain 1-128 characters');
  }
  return normalizedTitle;
}

export function normalizeChannelDescription(description: string): string {
  const normalizedDescription: string = description.trim();
  if (normalizedDescription.length > MAX_CHANNEL_DESCRIPTION_LENGTH) {
    throw new Error('CreateChannelChatUseCase: description must contain at most 255 characters');
  }
  return normalizedDescription;
}

export function parseCreatedChannelChat(response: TdObject): ChatDto | undefined {
  if (response.getTopLevelStringStrict('@type') !== 'chat') {
    return undefined;
  }
  // Chat IDs are signed int53 values; the separate supergroup ID is positive.
  const chatId = response.getTopLevelNumberStrict('id');
  const chatType = response.getTopLevelObjectStrict('type');
  if (typeof chatId !== 'number' || !Number.isSafeInteger(chatId) || chatId === 0 ||
    chatType === undefined || chatType.getTopLevelStringStrict('@type') !== 'chatTypeSupergroup' ||
    chatType.getTopLevelBooleanStrict('is_channel') !== true) {
    return undefined;
  }
  const supergroupId = chatType.getTopLevelNumberStrict('supergroup_id');
  if (typeof supergroupId !== 'number' || !Number.isSafeInteger(supergroupId) || supergroupId <= 0) {
    return undefined;
  }
  const chat: ChatDto = createChatDtoFromTd(response);
  chat.id = chatId;
  chat.supergroupId = supergroupId;
  return chat;
}

export class CreateChannelChatUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async execute(title: string, description: string = ''): Promise<ChatDto> {
    const normalizedTitle: string = normalizeChannelTitle(title);
    const normalizedDescription: string = normalizeChannelDescription(description);
    const response = await this.gateway.send(createNewSupergroupChatCommand(
      normalizedTitle,
      false,
      true,
      normalizedDescription,
      0,
      false
    ));
    if (!(response instanceof TdObject)) {
      throw new Error('Channel creation failed');
    }
    const chat: ChatDto | undefined = parseCreatedChannelChat(response);
    if (chat === undefined) {
      throw new Error('Channel creation failed');
    }
    return chat;
  }
}

export function createChannelChatUseCase(gateway: TdGatewayPort): CreateChannelChatUseCase {
  return new CreateChannelChatUseCase(gateway);
}
