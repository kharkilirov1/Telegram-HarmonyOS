// SearchChatMessages use case — searches messages in a chat via TDLib
// Returns found message IDs for navigation in the timeline.
// iOS ref: 0.2s debounce, auto-navigate to first result, limit=100.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createSearchChatMessagesCommand, createDownloadFileCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdObject } from '../../models/TdTypes';
import { tdGetNumber, tdGetString } from '../../core/utils/tdAccessors';

const TAG = 'SearchChatMessages';
const DOMAIN = 0x0013;

export class SearchChatMessagesResult {
  messageIds: MessageId[] = [];
  totalCount: number = 0;
}

// One tile/row of the profile Shared Media page
export class SharedMediaItem {
  messageId: string = '0';
  kind: string = 'photo'; // photo | video | file | link | voice
  isVideo: boolean = false;
  thumbFileId: number = 0;
  thumbPath: string = '';
  duration: number = 0;
  fileName: string = '';
  fileSize: number = 0;
  linkText: string = '';
}

function parseSharedMediaItem(msg: TdObject, filterType: string): SharedMediaItem | undefined {
  const item = new SharedMediaItem();
  item.messageId = msg.getInt64String('id');
  const content = msg.getObject('content');
  const ctype = content.getType();
  if (ctype === 'messagePhoto') {
    // pick the last (largest) photo size that has a file
    const sizes = content.getObject('photo').getArray('sizes');
    if (sizes.length === 0) {
      return undefined;
    }
    const mid = sizes[Math.min(1, sizes.length - 1)];
    const file = mid.getObject('photo');
    item.thumbFileId = file.getNumber('id');
    const local = file.getObject('local');
    if (local.getBool('is_downloading_completed')) {
      item.thumbPath = local.getString('path');
    }
    return item;
  }
  if (ctype === 'messageVideo') {
    item.kind = 'video';
    item.isVideo = true;
    const video = content.getObject('video');
    item.duration = video.getNumber('duration');
    const thumbFile = video.getObject('thumbnail').getObject('file');
    item.thumbFileId = thumbFile.getNumber('id');
    const local = thumbFile.getObject('local');
    if (local.getBool('is_downloading_completed')) {
      item.thumbPath = local.getString('path');
    }
    return item;
  }
  if (ctype === 'messageDocument') {
    item.kind = 'file';
    const doc = content.getObject('document');
    item.fileName = doc.getString('file_name');
    item.fileSize = doc.getObject('document').getNumber('size');
    return item;
  }
  if (ctype === 'messageVoiceNote') {
    item.kind = 'voice';
    item.duration = content.getObject('voice_note').getNumber('duration');
    return item;
  }
  if (ctype === 'messageText') {
    // Url filter returns text messages containing links
    item.kind = 'link';
    const text = content.getObject('text').getString('text');
    item.linkText = text.length > 120 ? text.substring(0, 120) : text;
    return item;
  }
  if (filterType === 'Url') {
    // The Url filter also matches media whose CAPTION carries the link
    item.kind = 'link';
    const caption = content.getObject('caption').getString('text');
    item.linkText = caption.length > 120 ? caption.substring(0, 120) : caption;
    return item;
  }
  return undefined;
}

export class SearchChatMessagesUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  // Shared Media grid: photo/video messages of the chat (newest first)
  async searchChatMedia(chatId: ChatId, filterType: string = 'PhotoAndVideo',
    fromMessageId: MessageId = '0', limit: number = 60): Promise<SharedMediaItem[]> {
    const command = createSearchChatMessagesCommand(chatId, '', fromMessageId, 0, limit);
    command.payload.filterType = filterType;
    const response = await this.gateway.send(command) as TdObject;
    const messages = response.getArray('messages');
    const items: SharedMediaItem[] = [];
    for (let i = 0; i < messages.length; i++) {
      const item = parseSharedMediaItem(messages[i], filterType);
      if (item !== undefined) {
        items.push(item);
      }
    }
    hilog.info(DOMAIN, TAG, 'Shared media loaded: %{public}d of %{public}d msgs',
      items.length, messages.length);
    return items;
  }

  // Downloads one thumbnail synchronously, returns sandbox path ('' on failure)
  async downloadThumb(fileId: number): Promise<string> {
    if (fileId <= 0) {
      return '';
    }
    try {
      const response = await this.gateway.send(createDownloadFileCommand(fileId, 1, true)) as TdObject;
      const local = response.getObject('local');
      if (local.getBool('is_downloading_completed')) {
        return local.getString('path');
      }
    } catch (_e) {
    }
    return '';
  }

  async execute(chatId: ChatId, query: string, fromMessageId: MessageId = '0'): Promise<SearchChatMessagesResult> {
    if (!chatId || chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }
    if (!query || query.trim().length === 0) {
      const empty = new SearchChatMessagesResult();
      return empty;
    }

    try {
      hilog.info(DOMAIN, TAG, 'Searching in chat %{public}d for "%{public}s"', chatId, query);
      const command = createSearchChatMessagesCommand(chatId, query, fromMessageId);
      const response = await this.gateway.send(command) as TdObject;

      const result = new SearchChatMessagesResult();
      result.totalCount = tdGetNumber(response, 'total_count');

      // foundChatMessages carries a plain messages array — extract ids directly
      result.messageIds = this.extractMessageIds(response);

      hilog.info(DOMAIN, TAG, 'Found %{public}d messages (total=%{public}d)',
        result.messageIds.length, result.totalCount);
      return result;
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Search failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Search failed', err.message, 0, true);
    }
  }

  private extractMessageIds(response: TdObject): MessageId[] {
    const ids: MessageId[] = [];
    try {
      const messages = response.getArray('messages');
      for (let i = 0; i < messages.length; i++) {
        const msg = messages[i] as TdObject;
        const id = tdGetString(msg, 'id');
        if (id.length > 0 && id !== '0') {
          ids.push(id);
        }
      }
    } catch (_e) {
      // Response format may vary — return what we have
    }
    return ids;
  }
}

export function createSearchChatMessagesUseCase(gateway: TdGatewayPort): SearchChatMessagesUseCase {
  return new SearchChatMessagesUseCase(gateway);
}
