// Scheduled messages DTO (D21).
// TDLib: getChatScheduledMessages (td_api.tl:10973) returns Messages; each message carries the scheduled
// send date in `scheduling_state` and the content in `content`. Message ids are int64 and stay strings.

import { TdObject as TdObjectType } from '../../../models/TdTypes';

export class ScheduledMessageDto {
  messageId: string = '0';
  sendDate: number = 0;
  // Plain-text preview of the scheduled content; empty for media without a caption.
  text: string = '';
}

export class ScheduledMessagesDto {
  messages: ScheduledMessageDto[] = [];
}

function previewText(message: TdObjectType): string {
  const content = message.getTopLevelObjectStrict('content');
  if (content === undefined) {
    return '';
  }
  const type = content.getTopLevelStringStrict('@type') ?? '';
  if (type === 'messageText') {
    const textObject = content.getTopLevelObjectStrict('text');
    return textObject === undefined ? '' : (textObject.getTopLevelStringStrict('text') ?? '');
  }
  if (type === 'messagePhoto') {
    const caption = content.getTopLevelObjectStrict('caption');
    return caption === undefined ? '' : (caption.getTopLevelStringStrict('text') ?? '');
  }
  if (type === 'messageVideo') {
    const caption = content.getTopLevelObjectStrict('caption');
    return caption === undefined ? '' : (caption.getTopLevelStringStrict('text') ?? '');
  }
  return '';
}

export function createScheduledMessagesFromTd(td: TdObjectType): ScheduledMessagesDto | undefined {
  if (td.getTopLevelStringStrict('@type') !== 'messages') {
    return undefined;
  }
  const result = new ScheduledMessagesDto();
  const raw = td.getTopLevelRawItemArrayStrict('messages');
  if (raw === undefined) {
    return result;
  }
  for (const entry of raw) {
    if (entry === null) {
      continue;
    }
    const message = TdObjectType.fromJSON(entry);
    const messageId = message.getTopLevelInt64StringStrict('id');
    if (messageId === undefined || messageId === '0') {
      continue;
    }
    const scheduling = message.getTopLevelObjectStrict('scheduling_state');
    const sendDate = scheduling === undefined
      ? 0 : (scheduling.getTopLevelNumberStrict('send_date') ?? 0);
    if (!Number.isSafeInteger(sendDate) || sendDate <= 0) {
      continue;
    }
    const dto = new ScheduledMessageDto();
    dto.messageId = messageId;
    dto.sendDate = sendDate;
    dto.text = previewText(message);
    result.messages.push(dto);
  }
  // Newest scheduled time first, matching TDLib's reverse chronological order.
  result.messages.sort((left: ScheduledMessageDto, right: ScheduledMessageDto): number =>
    right.sendDate - left.sendDate);
  return result;
}
