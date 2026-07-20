// SearchChatMessages use case — searches messages in a chat via TDLib
// Returns found message IDs for navigation in the timeline.
// iOS ref: 0.2s debounce, auto-navigate to first result, limit=100.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createSearchChatMessagesCommand, createDownloadFileCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdObject } from '../../models/TdTypes';
import { tdGetNumber } from '../../core/utils/tdAccessors';

const TAG = 'SearchChatMessages';
const DOMAIN = 0x0013;

export class SearchChatMessagesResult {
  messageIds: MessageId[] = [];
  totalCount: number = 0;
  // Exact TDLib continuation cursor from foundChatMessages. Never infer the
  // next page from the last visible timeline item: albums and deleted results
  // make that fallback ambiguous.
  nextFromMessageId: MessageId = '0';
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
  linkUrl: string = '';
}

function normalizeDetectedLink(value: string): string {
  const link = value.trim();
  if (link.startsWith('www.')) {
    return 'https://' + link;
  }
  return link;
}

function extractFirstFormattedTextLink(formattedText: TdObject): string {
  const text = formattedText.getString('text');
  const entities = formattedText.getArray('entities');
  for (let i = 0; i < entities.length; i++) {
    const entity = entities[i];
    const type = entity.getObject('type');
    const typeName = type.getType();
    if (typeName === 'textEntityTypeTextUrl') {
      const target = type.getString('url');
      if (target.trim().length > 0) {
        return normalizeDetectedLink(target);
      }
    }
    if (typeName === 'textEntityTypeUrl') {
      const offset = Math.max(0, entity.getTopLevelNumber('offset'));
      const length = Math.max(0, entity.getTopLevelNumber('length'));
      const target = text.substring(offset, Math.min(text.length, offset + length));
      if (target.trim().length > 0) {
        return normalizeDetectedLink(target);
      }
    }
  }
  const detected = text.match(/(?:https?:\/\/|tg:\/\/|www\.)[^\s<>()]+/i);
  return detected && detected.length > 0 ? normalizeDetectedLink(detected[0]) : '';
}

function extractSharedMediaLink(content: TdObject, formattedText: TdObject): string {
  const preview = content.getObject('link_preview');
  const previewUrl = preview.getString('url');
  if (previewUrl.trim().length > 0) {
    return normalizeDetectedLink(previewUrl);
  }
  const legacyPreviewUrl = content.getObject('web_page').getString('url');
  if (legacyPreviewUrl.trim().length > 0) {
    return normalizeDetectedLink(legacyPreviewUrl);
  }
  return extractFirstFormattedTextLink(formattedText);
}

function parseSharedMediaItem(msg: TdObject, filterType: string): SharedMediaItem | undefined {
  const item = new SharedMediaItem();
  item.messageId = msg.getInt64String('id');
  const content = msg.getObject('content');
  const ctype = content.getType();
  if (filterType === 'Url' && ctype !== 'messageText') {
    // searchMessagesFilterUrl also returns media whose caption contains a URL.
    // Treat those as link rows before the photo/video/file branches.
    item.kind = 'link';
    const formattedCaption = content.getObject('caption');
    const caption = formattedCaption.getString('text');
    item.linkText = caption.length > 120 ? caption.substring(0, 120) : caption;
    item.linkUrl = extractSharedMediaLink(content, formattedCaption);
    return item;
  }
  if (ctype === 'messagePhoto') {
    // pick the last (largest) photo size that has a file
    const sizes = content.getObject('photo').getArray('sizes');
    if (sizes.length === 0) {
      return undefined;
    }
    const mid = sizes[Math.min(1, sizes.length - 1)];
    const file = mid.getObject('photo');
    // A TDLib file also contains remote.id (string). Generic nested lookup can
    // hit that value first and silently coerce the real numeric file id to 0.
    item.thumbFileId = file.getTopLevelNumber('id');
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
    item.thumbFileId = thumbFile.getTopLevelNumber('id');
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
    const formattedText = content.getObject('text');
    const text = formattedText.getString('text');
    item.linkText = text.length > 120 ? text.substring(0, 120) : text;
    item.linkUrl = extractSharedMediaLink(content, formattedText);
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

  // Starts a non-blocking thumbnail download. Completion normally arrives via
  // updateFile/FilesState; an already-local response can return its path now.
  async requestThumbDownload(fileId: number, priority: number = 16): Promise<string> {
    if (fileId <= 0) {
      return '';
    }
    try {
      const response = await this.gateway.send(createDownloadFileCommand(fileId, priority, false)) as TdObject;
      const local = response.getObject('local');
      if (local.getBool('is_downloading_completed')) {
        return local.getString('path');
      }
    } catch (error) {
      throw new Error(`requestThumbDownload(${fileId}): ${String(error)}`);
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
      result.nextFromMessageId = response.getInt64String('next_from_message_id');
      if (result.nextFromMessageId.length === 0) {
        result.nextFromMessageId = '0';
      }

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
        // message.id is an int64 number — tdGetString returns '' for it
        const id = msg.getInt64String('id');
        if (id.length > 0 && id !== '0') {
          ids.push(id);
        }
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'extract failed: %{public}s', String(e));
    }
    return ids;
  }
}

export function createSearchChatMessagesUseCase(gateway: TdGatewayPort): SearchChatMessagesUseCase {
  return new SearchChatMessagesUseCase(gateway);
}
