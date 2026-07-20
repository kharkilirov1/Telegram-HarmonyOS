import { Message } from '../../../core/model/AppState';
import { ChatId, MessageId } from '../../../core/model/EntityId';
import { compareInt64 } from '../../../core/utils/tdAccessors';
import { resolveReplyLookupKey, resolveReplyTargetChatId } from '../../../core/utils/replyMessageKey';

export const MAX_REPLY_HYDRATION_PER_PASS: number = 8;
export const MAX_REPLY_HYDRATION_PER_SESSION: number = 32;

export class ReplyHydrationRequest {
  chatId: ChatId;
  replyingMessageId: MessageId;
  targetMessageId: MessageId;
  targetChatId: ChatId;

  constructor(
    chatId: ChatId,
    replyingMessageId: MessageId,
    targetMessageId: MessageId,
    targetChatId: ChatId
  ) {
    this.chatId = chatId;
    this.replyingMessageId = replyingMessageId;
    this.targetMessageId = targetMessageId;
    this.targetChatId = targetChatId;
  }
}

/**
 * Selects newest unresolved reply rows and prevents request storms.
 * A replying message is attempted once per page session; requests sharing the
 * same missing target are collapsed while one request is in flight.
 */
export class ReplyHydrationCoordinator {
  private attemptedReplyingMessageIds: Set<MessageId> = new Set<MessageId>();
  private inFlightTargetMessageIds: Set<MessageId> = new Set<MessageId>();

  collect(
    chatId: ChatId,
    visibleMessages: Map<MessageId, Message>,
    replyLookup: Map<MessageId, Message> = visibleMessages,
    limit: number = MAX_REPLY_HYDRATION_PER_PASS
  ): ReplyHydrationRequest[] {
    if (chatId === 0 || limit <= 0 ||
      this.attemptedReplyingMessageIds.size >= MAX_REPLY_HYDRATION_PER_SESSION) {
      return [];
    }

    const remainingBudget = MAX_REPLY_HYDRATION_PER_SESSION - this.attemptedReplyingMessageIds.size;
    const boundedLimit = Math.min(limit, remainingBudget);
    const messages = Array.from(visibleMessages.values());
    messages.sort((left: Message, right: Message): number => {
      if (left.timestamp !== right.timestamp) {
        return right.timestamp - left.timestamp;
      }
      return compareInt64(right.id, left.id);
    });

    const requests: ReplyHydrationRequest[] = [];
    for (const message of messages) {
      if (requests.length >= boundedLimit) {
        break;
      }
      if (message.chatId !== chatId || message.id === '0' || message.replyToMessageId === '0') {
        continue;
      }
      const targetChatId = resolveReplyTargetChatId(chatId, message.replyToChatId);
      const targetLookupKey = resolveReplyLookupKey(chatId, targetChatId, message.replyToMessageId);
      const targetIsAvailable = replyLookup.has(targetLookupKey) ||
        (targetChatId === chatId && replyLookup.has(message.replyToMessageId));
      if (targetIsAvailable ||
        this.attemptedReplyingMessageIds.has(message.id) ||
        this.inFlightTargetMessageIds.has(targetLookupKey)) {
        continue;
      }

      this.attemptedReplyingMessageIds.add(message.id);
      this.inFlightTargetMessageIds.add(targetLookupKey);
      requests.push(new ReplyHydrationRequest(chatId, message.id, message.replyToMessageId, targetChatId));
    }
    return requests;
  }

  complete(request: ReplyHydrationRequest): void {
    this.inFlightTargetMessageIds.delete(
      resolveReplyLookupKey(request.chatId, request.targetChatId, request.targetMessageId)
    );
  }

  reset(): void {
    this.attemptedReplyingMessageIds.clear();
    this.inFlightTargetMessageIds.clear();
  }

  getAttemptedCount(): number {
    return this.attemptedReplyingMessageIds.size;
  }

  getInFlightCount(): number {
    return this.inFlightTargetMessageIds.size;
  }
}
