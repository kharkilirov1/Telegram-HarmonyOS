// Hydrates the original message referenced by a visible reply row.
// TDLib getRepliedMessage expects the replying message id, not the target id.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { createGetRepliedMessageCommand } from '../../core/model/AppCommand';
import { createReplyMessageHydratedEvent } from '../../core/model/AppEvent';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createMessageDtoFromTd, MessageDto } from '../../core/model/dto/MessageDto';
import { AppStore } from '../../core/store/AppStore';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { LoadChatHistoryUseCase } from './loadChatHistory';

const DOMAIN = 0x0021;
const TAG = 'LoadRepliedMessage';

export function parseRepliedMessageResponse(
  response: TdObject,
  expectedMessageId: MessageId = '0'
): MessageDto | undefined {
  if (response.getType() !== 'message') {
    return undefined;
  }

  const message = createMessageDtoFromTd(response);
  if (message.id === '0' || message.id.length === 0 ||
    (expectedMessageId !== '0' && message.id !== expectedMessageId)) {
    return undefined;
  }
  return message;
}

export class LoadRepliedMessageUseCase {
  private store: AppStore;
  private gateway: TdGatewayPort;
  private userHydrator?: LoadChatHistoryUseCase;

  constructor(store: AppStore, gateway: TdGatewayPort, userHydrator?: LoadChatHistoryUseCase) {
    this.store = store;
    this.gateway = gateway;
    this.userHydrator = userHydrator;
  }

  async execute(
    chatId: ChatId,
    replyingMessageId: MessageId,
    targetMessageId: MessageId,
    targetChatId: ChatId
  ): Promise<boolean> {
    if (chatId === 0 || replyingMessageId === '0' || targetMessageId === '0') {
      return false;
    }

    try {
      const response = await this.gateway.send(
        createGetRepliedMessageCommand(chatId, replyingMessageId)
      ) as TdObject;
      if (!(response instanceof TdObject)) {
        return false;
      }

      const message = parseRepliedMessageResponse(response, targetMessageId);
      if (!message) {
        hilog.debug(DOMAIN, TAG,
          'Reply hydration rejected response type=%{public}s id=%{public}s responseChat=%{public}d expectedTarget=%{public}s replying=%{public}s',
          response.getType(), response.getInt64String('id'), response.getNumber('chat_id'),
          targetMessageId, replyingMessageId);
        return false;
      }

      await this.store.dispatch(createReplyMessageHydratedEvent(chatId, targetChatId, message.id, message));
      hilog.info(DOMAIN, TAG,
        'Hydrated reply original contextChat=%{public}d relationChat=%{public}d originChat=%{public}d replying=%{public}s target=%{public}s',
        chatId, targetChatId, message.chatId, replyingMessageId, message.id);
      if (this.userHydrator && message.senderId > 0) {
        this.userHydrator.hydrateUsersIfMissing([message.senderId])
          .catch((error: Error): void => {
            hilog.debug(DOMAIN, TAG,
              'Reply author hydration deferred user=%{public}d: %{public}s',
              message.senderId, error.message);
          });
      }
      return true;
    } catch (error) {
      hilog.debug(DOMAIN, TAG,
        'Reply hydration failed chat=%{public}d replying=%{public}s: %{public}s',
        chatId, replyingMessageId, String(error));
      return false;
    }
  }
}

export function createLoadRepliedMessageUseCase(
  store: AppStore,
  gateway: TdGatewayPort,
  userHydrator?: LoadChatHistoryUseCase
): LoadRepliedMessageUseCase {
  return new LoadRepliedMessageUseCase(store, gateway, userHydrator);
}
