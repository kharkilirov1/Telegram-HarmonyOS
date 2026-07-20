// Opens the TDLib private-chat entity for a known user.
// TDLib contract: createPrivateChat(user_id:int53, force:Bool) -> Chat.

import { createPrivateChatCommand } from '../../core/model/AppCommand';
import { UserId } from '../../core/model/EntityId';
import { ChatDto, ChatType, createChatDtoFromTd } from '../../core/model/dto/ChatDto';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

export function parsePrivateChatResponse(
  response: TdObject,
  expectedUserId: UserId
): ChatDto | undefined {
  if (response.getType() !== 'chat') {
    return undefined;
  }

  const chat = createChatDtoFromTd(response);
  if (chat.id === 0 || chat.type !== ChatType.PRIVATE || chat.peerUserId !== expectedUserId) {
    return undefined;
  }
  return chat;
}

export class CreatePrivateChatUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async execute(userId: UserId, force: boolean = false): Promise<ChatDto> {
    if (userId <= 0) {
      throw new Error('CreatePrivateChatUseCase: invalid userId');
    }

    const response = await this.gateway.send(createPrivateChatCommand(userId, force));
    if (!(response instanceof TdObject)) {
      throw new Error('TDLib did not return Chat');
    }

    const chat = parsePrivateChatResponse(response, userId);
    if (!chat) {
      const message = response.getString('message');
      throw new Error(message.length > 0 ? message : 'TDLib did not return the requested private Chat');
    }
    return chat;
  }
}

export function createPrivateChatUseCase(gateway: TdGatewayPort): CreatePrivateChatUseCase {
  return new CreatePrivateChatUseCase(gateway);
}
