// D11: comment threads (message replies in channels and linked groups).
// TDLib: getMessageThread (td_api.tl:10565) → MessageThreadInfo, getMessageThreadHistory (:10816).

import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatId } from '../../core/model/EntityId';
import {
  createGetMessageThreadCommand,
  createGetMessageThreadHistoryCommand
} from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import {
  TdObject,
  tdGetArray,
  tdGetInt64,
  tdGetNumber,
  tdGetObject,
  tdGetString
} from '../../core/utils/tdAccessors';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x004B;
const TAG = 'MessageThread';
export const MESSAGE_THREAD_MAX_LIMIT = 100;

export function isValidThreadMessageId(messageId: string): boolean {
  return /^[1-9][0-9]{0,18}$/.test(messageId);
}

// One comment row, parsed from the message object TDLib returns in the thread history.
export class MessageThreadComment {
  messageId: string = '0';
  senderUserId: number = 0;
  date: number = 0;
  text: string = '';
  isOutgoing: boolean = false;
}

function parseComment(td: TdObject): MessageThreadComment | undefined {
  const messageId = tdGetInt64(td, 'id');
  if (!isValidThreadMessageId(messageId)) {
    return undefined;
  }
  const comment = new MessageThreadComment();
  comment.messageId = messageId;
  const sender = tdGetObject(td, 'sender_id');
  if (sender !== undefined) {
    const userId = tdGetNumber(sender, 'user_id');
    comment.senderUserId = typeof userId === 'number' && Number.isSafeInteger(userId) && userId > 0 ? userId : 0;
  }
  const date = tdGetNumber(td, 'date');
  comment.date = typeof date === 'number' && Number.isSafeInteger(date) && date > 0 ? date : 0;
  const outgoing = tdGetNumber(td, 'is_outgoing');
  comment.isOutgoing = outgoing === 1;
  const content = tdGetObject(td, 'content');
  if (content !== undefined && content.getTopLevelStringStrict('@type') === 'messageText') {
    const textObject = tdGetObject(content, 'text');
    if (textObject !== undefined) {
      const text = tdGetString(textObject, 'text');
      comment.text = text ?? '';
    }
  }
  return comment;
}

// One page of replies plus the thread counters the header shows.
export class MessageThreadPage {
  chatId: number = 0;
  threadId: string = '0';
  replyCount: number = 0;
  unreadCount: number = 0;
  messageIds: string[] = [];
  nextFromMessageId: string = '0';
  comments: MessageThreadComment[] = [];
}

function parseReplyCount(td: TdObject | undefined): number {
  if (td === undefined) {
    return 0;
  }
  const count = tdGetNumber(td, 'reply_count');
  return typeof count === 'number' && Number.isSafeInteger(count) && count > 0 ? count : 0;
}

// messageThreadInfo.unread_message_count is the thread-level counter; reply_info has no unread field.
function parseUnread(td: TdObject): number {
  const unread = tdGetNumber(td, 'unread_message_count');
  return typeof unread === 'number' && Number.isSafeInteger(unread) && unread > 0 ? unread : 0;
}

export function createMessageThreadPageFromTd(td: TdObject): MessageThreadPage | undefined {
  if (td.getTopLevelStringStrict('@type') !== 'messageThreadInfo') {
    return undefined;
  }
  const page = new MessageThreadPage();
  const chatId = tdGetNumber(td, 'chat_id');
  page.chatId = typeof chatId === 'number' && Number.isSafeInteger(chatId) ? chatId : 0;
  page.threadId = tdGetInt64(td, 'message_thread_id');
  page.replyCount = parseReplyCount(tdGetObject(td, 'reply_info'));
  page.unreadCount = parseUnread(td);
  const messages = tdGetArray(td, 'messages');
  if (messages !== undefined) {
    for (const message of messages) {
      const messageId = tdGetInt64(message, 'id');
      if (isValidThreadMessageId(messageId)) {
        page.messageIds.push(messageId);
      }
      const comment = parseComment(message);
      if (comment !== undefined) {
        page.comments.push(comment);
      }
    }
  }
  return page;
}

// getMessageThreadHistory returns Messages with an explicit next offset in the thread.
export function createMessageThreadHistoryFromTd(td: TdObject): MessageThreadPage | undefined {
  if (td.getTopLevelStringStrict('@type') !== 'messages') {
    return undefined;
  }
  const page = new MessageThreadPage();
  const total = tdGetNumber(td, 'total_count');
  page.replyCount = typeof total === 'number' && Number.isSafeInteger(total) && total > 0 ? total : 0;
  const nextOffset = tdGetString(td, 'next_offset');
  page.nextFromMessageId = nextOffset !== undefined && isValidThreadMessageId(nextOffset) ? nextOffset : '0';
  const messages = tdGetArray(td, 'messages');
  if (messages !== undefined) {
    for (const message of messages) {
      const messageId = tdGetInt64(message, 'id');
      if (isValidThreadMessageId(messageId)) {
        page.messageIds.push(messageId);
      }
      const comment = parseComment(message);
      if (comment !== undefined) {
        page.comments.push(comment);
      }
    }
  }
  return page;
}

export class MessageThreadUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async loadThread(chatId: ChatId, messageId: string): Promise<MessageThreadPage> {
    this.validate(chatId, messageId);
    try {
      const command = createGetMessageThreadCommand(chatId, messageId);
      const response = await this.gateway.send(command) as TdObject;
      const page = createMessageThreadPageFromTd(response);
      if (page === undefined) {
        throw new AppError(AppErrorKind.UNKNOWN, 'Unsupported thread response', 'Unexpected @type', 0,
          false);
      }
      return page;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'getMessageThread failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to load the comments', err.message, 0, true);
    }
  }

  async loadHistory(chatId: ChatId, messageId: string, fromMessageId: string = '0',
    offset: number = 0, limit: number = 50): Promise<MessageThreadPage> {
    this.validate(chatId, messageId);
    if (fromMessageId !== '0' && !isValidThreadMessageId(fromMessageId)) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid fromMessageId', 'Input validation failed',
        400, false);
    }
    if (!Number.isSafeInteger(offset) || offset < 0 || offset > 100) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid offset', 'Input validation failed', 400,
        false);
    }
    if (!Number.isSafeInteger(limit) || limit <= 0 || limit > MESSAGE_THREAD_MAX_LIMIT) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid limit', 'Input validation failed', 400,
        false);
    }
    try {
      const command = createGetMessageThreadHistoryCommand(chatId, messageId, fromMessageId, offset,
        limit);
      const response = await this.gateway.send(command) as TdObject;
      const page = createMessageThreadHistoryFromTd(response);
      if (page === undefined) {
        throw new AppError(AppErrorKind.UNKNOWN, 'Unsupported thread history response',
          'Unexpected @type', 0, false);
      }
      page.chatId = chatId;
      page.threadId = messageId;
      return page;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'getMessageThreadHistory failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to load the comments', err.message, 0, true);
    }
  }

  private validate(chatId: ChatId, messageId: string): void {
    if (!Number.isSafeInteger(chatId) || chatId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400,
        false);
    }
    if (!isValidThreadMessageId(messageId)) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid messageId', 'Input validation failed', 400,
        false);
    }
  }
}

export function createMessageThreadUseCase(gateway: TdGatewayPort): MessageThreadUseCase {
  return new MessageThreadUseCase(gateway);
}
