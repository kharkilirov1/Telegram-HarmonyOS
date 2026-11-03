// Blocked message senders DTO — getBlockedMessageSenders (td_api.tl:13188) / MessageSenders (:2528).
// MessageSender is messageSenderUser (:2521) or messageSenderChat (:2524); names are resolved by the
// page from AppState because the list payload carries identifiers only.

import { TdObject as TdObjectType } from '../../../models/TdTypes';

export class BlockedSenderDto {
  senderType: 'user' | 'chat' = 'user';
  senderId: number = 0;
}

export function createBlockedSenderFromTd(td: TdObjectType): BlockedSenderDto | undefined {
  const type = td.getTopLevelStringStrict('@type');
  if (type === 'messageSenderUser') {
    const userId = td.getTopLevelNumberStrict('user_id');
    if (userId === undefined || !Number.isSafeInteger(userId) || userId === 0) {
      return undefined;
    }
    const dto = new BlockedSenderDto();
    dto.senderType = 'user';
    dto.senderId = userId;
    return dto;
  }
  if (type === 'messageSenderChat') {
    const chatId = td.getTopLevelNumberStrict('chat_id');
    if (chatId === undefined || !Number.isSafeInteger(chatId) || chatId === 0) {
      return undefined;
    }
    const dto = new BlockedSenderDto();
    dto.senderType = 'chat';
    dto.senderId = chatId;
    return dto;
  }
  return undefined;
}

export class BlockedSendersPage {
  totalCount: number = 0;
  senders: BlockedSenderDto[] = [];
}

export function createBlockedSendersPageFromTd(td: TdObjectType): BlockedSendersPage {
  const page = new BlockedSendersPage();
  if (td.getTopLevelStringStrict('@type') !== 'messageSenders') {
    return page;
  }
  const total = td.getTopLevelNumberStrict('total_count');
  page.totalCount = total !== undefined && Number.isSafeInteger(total) && total >= 0 ? total : 0;
  // Raw slices keep every nested int53 lexeme exact; parsed children would be re-serialized.
  const rawSenders = td.getTopLevelRawObjectArrayStrict('senders');
  if (rawSenders === undefined) {
    return page;
  }
  for (const rawText of rawSenders) {
    const sender = createBlockedSenderFromTd(TdObjectType.fromJSON(rawText));
    if (sender !== undefined) {
      page.senders.push(sender);
    }
  }
  return page;
}
