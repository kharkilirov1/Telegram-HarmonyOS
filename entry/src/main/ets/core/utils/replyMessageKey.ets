import { ChatId, MessageId } from '../model/EntityId';

export function resolveReplyTargetChatId(contextChatId: ChatId, replyToChatId: ChatId): ChatId {
  return replyToChatId !== 0 ? replyToChatId : contextChatId;
}

export function createAssociatedMessageKey(originChatId: ChatId, messageId: MessageId): string {
  return originChatId.toString() + ':' + messageId;
}

export function resolveReplyLookupKey(
  contextChatId: ChatId,
  replyToChatId: ChatId,
  messageId: MessageId
): string {
  const targetChatId = resolveReplyTargetChatId(contextChatId, replyToChatId);
  return createAssociatedMessageKey(targetChatId, messageId);
}
