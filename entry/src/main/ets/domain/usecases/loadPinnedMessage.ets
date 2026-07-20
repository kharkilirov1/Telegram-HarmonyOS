// Read-only pinned-message metadata for the custom Telegram chat panel.

import {
  createGetChatPinnedMessageCommand,
  createSearchChatMessagesCommand
} from '../../core/model/AppCommand';
import {
  createMessageDtoFromTd,
  MessageContentDto,
  MessageContentType,
  MessageDto
} from '../../core/model/dto/MessageDto';
import { tdGetNumber, tdGetString } from '../../core/utils/tdAccessors';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { getTdGatewayAdapter } from '../../infra/td/adapter/TdGatewayAdapter';
import { TdObject } from '../../models/TdTypes';

export class PinnedMessageInfo {
  isAvailable: boolean = false;
  messageId: string = '0';
  preview: string = '';
  hasThumbnail: boolean = false;
  thumbnailPath: string = '';
}

export class PinnedMessagesPage {
  items: PinnedMessageInfo[] = [];
  totalCount: number = 0;
  nextFromMessageId: string = '0';
}

function resolvePinnedThumbnailPath(content: MessageContentDto): string {
  if (content.type === MessageContentType.PHOTO) {
    return content.photoThumbPath.length > 0 ? content.photoThumbPath : content.photoPath;
  }
  if (content.type === MessageContentType.VIDEO ||
    content.type === MessageContentType.ANIMATION ||
    content.type === MessageContentType.VIDEO_NOTE) {
    return content.videoThumbPath;
  }
  if (content.type === MessageContentType.STICKER) {
    return content.stickerThumbnailPath.length > 0
      ? content.stickerThumbnailPath
      : content.stickerPath;
  }
  return '';
}

export function parsePinnedMessageInfo(response: TdObject): PinnedMessageInfo {
  const result = new PinnedMessageInfo();
  if (tdGetString(response, '@type') !== 'message') {
    return result;
  }

  const message: MessageDto = createMessageDtoFromTd(response);
  if (message.id === '0') {
    return result;
  }

  const preview: string = message.content.text.trim();
  const thumbnailPath: string = resolvePinnedThumbnailPath(message.content);
  result.isAvailable = true;
  result.messageId = message.id;
  result.preview = preview.length > 0 ? preview : 'Message';
  result.thumbnailPath = thumbnailPath;
  result.hasThumbnail = thumbnailPath.length > 0;
  return result;
}

export function parsePinnedMessagesPage(response: TdObject): PinnedMessagesPage {
  const result = new PinnedMessagesPage();
  if (tdGetString(response, '@type') !== 'foundChatMessages') {
    return result;
  }

  const seenIds: Set<string> = new Set<string>();
  const messages: TdObject[] = response.getArray('messages');
  for (let i = 0; i < messages.length; i++) {
    const item: PinnedMessageInfo = parsePinnedMessageInfo(messages[i]);
    if (!item.isAvailable || seenIds.has(item.messageId)) {
      continue;
    }
    seenIds.add(item.messageId);
    result.items.push(item);
  }

  result.totalCount = Math.max(result.items.length, tdGetNumber(response, 'total_count'));
  const nextCursor: string = response.getInt64String('next_from_message_id');
  result.nextFromMessageId = nextCursor.length > 0 ? nextCursor : '0';
  return result;
}

export class LoadPinnedMessagesUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async execute(chatId: number, fromMessageId: string = '0', limit: number = 100): Promise<PinnedMessagesPage> {
    if (chatId === 0) {
      return new PinnedMessagesPage();
    }

    const safeLimit: number = Math.max(1, Math.min(100, limit));
    const command = createSearchChatMessagesCommand(chatId, '', fromMessageId, 0, safeLimit);
    command.payload.filterType = 'Pinned';
    const response = await this.gateway.send(command) as TdObject;
    return parsePinnedMessagesPage(response);
  }
}

export function createLoadPinnedMessagesUseCase(gateway: TdGatewayPort): LoadPinnedMessagesUseCase {
  return new LoadPinnedMessagesUseCase(gateway);
}

export async function loadPinnedMessageInfo(chatId: number): Promise<PinnedMessageInfo> {
  if (chatId === 0) {
    return new PinnedMessageInfo();
  }
  const response = await getTdGatewayAdapter().send(createGetChatPinnedMessageCommand(chatId)) as TdObject;
  return parsePinnedMessageInfo(response);
}

export async function loadPinnedMessagesPage(
  chatId: number,
  fromMessageId: string = '0',
  limit: number = 100
): Promise<PinnedMessagesPage> {
  return new LoadPinnedMessagesUseCase(getTdGatewayAdapter()).execute(chatId, fromMessageId, limit);
}
