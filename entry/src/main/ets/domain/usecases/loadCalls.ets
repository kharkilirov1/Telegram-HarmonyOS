// LoadCalls use case - real recent calls data path for CallsPage.
// Grounding:
// - TDLib official docs: searchCallMessages(from_message_id, limit, only_missed)
// - Android ref: CallLogActivity loads phone calls via TL_messages_search + inputMessagesFilterPhoneCalls

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStore } from '../../core/store/AppStore';
import { AppState, Chat } from '../../core/model/AppState';
import { ChatId, MessageId, UserId } from '../../core/model/EntityId';
import {
  createSearchCallMessagesCommand,
  createGetChatCommand,
  createGetUserCommand
} from '../../core/model/AppCommand';
import { getEventNormalizer } from '../../core/events/EventNormalizer';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { TdObject } from '../../models/TdTypes';
import {
  tdGetArray,
  tdGetBoolean,
  tdGetInt64,
  tdGetNumber,
  tdGetObject,
  tdGetString,
  tdHasKeys
} from '../../core/utils/tdAccessors';

const TAG = 'LoadCalls';
const DOMAIN = 0x000F;

export type CallHistoryDirection = 'incoming' | 'outgoing' | 'missed';
export type CallHistoryContentType = 'messageCall' | 'messageGroupCall';

export class LoadCallsParams {
  fromMessageId: MessageId = '0';
  limit: number = 50;
  onlyMissed: boolean = false;
}

export class CallHistoryRecord {
  messageId: MessageId = '0';
  chatId: ChatId = 0;
  peerUserId: UserId = 0;
  senderUserId: UserId = 0;
  fallbackTitle: string = '';
  fallbackAvatarPath: string = '';
  timestamp: number = 0;
  direction: CallHistoryDirection = 'outgoing';
  isVideo: boolean = false;
  discardReasonType: string = '';
  contentType: CallHistoryContentType = 'messageCall';
}

export class LoadCallsResult {
  records: CallHistoryRecord[] = [];
  nextFromMessageId: MessageId = '0';
  hasMore: boolean = false;
}

export class LoadCallsUseCase {
  private store: AppStore;
  private gateway: TdGatewayPort;
  private inFlightUserIds: Set<number> = new Set<number>();
  private inFlightChatIds: Set<number> = new Set<number>();

  constructor(store: AppStore, gateway: TdGatewayPort) {
    this.store = store;
    this.gateway = gateway;
  }

  async execute(params: LoadCallsParams): Promise<LoadCallsResult> {
    const result = new LoadCallsResult();
    const response = await this.gateway.send(
      createSearchCallMessagesCommand(params.fromMessageId, params.limit, params.onlyMissed)
    );
    const tdResponse = response as TdObject;
    if (!(tdResponse instanceof TdObject)) {
      hilog.warn(DOMAIN, TAG, 'searchCallMessages returned non-object response');
      return result;
    }

    const messages = tdGetArray(tdResponse, 'messages');
    await this.hydrateChatsIfMissing(this.collectMissingChatIds(messages));

    const records = this.parseMessages(messages, this.store.getState());
    await this.hydrateUsersIfMissing(this.collectMissingPeerUsers(records));

    result.records = records;
    result.nextFromMessageId = tdGetInt64(tdResponse, 'next_from_message_id');
    result.hasMore = result.nextFromMessageId !== '0';

    hilog.info(DOMAIN, TAG,
      'Loaded %{public}d call records, nextFromMessageId=%{public}s, hasMore=%{public}s',
      result.records.length,
      result.nextFromMessageId,
      result.hasMore ? 'true' : 'false');

    return result;
  }

  private collectMissingChatIds(messages: TdObject[]): number[] {
    const state = this.store.getState();
    const missing: number[] = [];
    const seen: Set<number> = new Set<number>();
    for (const message of messages) {
      const chatId = tdGetNumber(message, 'chat_id');
      if (chatId <= 0 || seen.has(chatId) || state.chats.chats.has(chatId)) {
        continue;
      }
      seen.add(chatId);
      missing.push(chatId);
    }
    return missing;
  }

  private collectMissingPeerUsers(records: CallHistoryRecord[]): number[] {
    const state = this.store.getState();
    const missing: number[] = [];
    const seen: Set<number> = new Set<number>();
    for (const record of records) {
      const userId = record.peerUserId;
      if (userId <= 0 || seen.has(userId) || state.auth.userId === userId || state.users.users.has(userId)) {
        continue;
      }
      seen.add(userId);
      missing.push(userId);
    }
    return missing;
  }

  private async hydrateChatsIfMissing(chatIds: number[]): Promise<void> {
    for (const chatId of chatIds) {
      if (chatId <= 0 || this.store.getState().chats.chats.has(chatId) || this.inFlightChatIds.has(chatId)) {
        continue;
      }
      this.inFlightChatIds.add(chatId);
      try {
        const response = await this.gateway.send(createGetChatCommand(chatId));
        const normalized = response as TdObject;
        if (!(normalized instanceof TdObject)) {
          continue;
        }
        const events = getEventNormalizer().normalize(normalized);
        if (events.length > 0) {
          await this.store.dispatchBatch(events);
        }
      } catch (error) {
        hilog.info(DOMAIN, TAG, 'Unable to hydrate chat %{public}d for calls: %{public}s', chatId, String(error));
      } finally {
        this.inFlightChatIds.delete(chatId);
      }
    }
  }

  private async hydrateUsersIfMissing(userIds: number[]): Promise<void> {
    for (const userId of userIds) {
      if (userId <= 0 || this.store.getState().users.users.has(userId) || this.inFlightUserIds.has(userId)) {
        continue;
      }
      this.inFlightUserIds.add(userId);
      try {
        const response = await this.gateway.send(createGetUserCommand(userId));
        const normalized = response as TdObject;
        if (!(normalized instanceof TdObject)) {
          continue;
        }
        const events = getEventNormalizer().normalize(normalized);
        if (events.length > 0) {
          await this.store.dispatchBatch(events);
        }
      } catch (error) {
        hilog.info(DOMAIN, TAG, 'Unable to hydrate user %{public}d for calls: %{public}s', userId, String(error));
      } finally {
        this.inFlightUserIds.delete(userId);
      }
    }
  }

  private parseMessages(messages: TdObject[], state: AppState): CallHistoryRecord[] {
    const records: CallHistoryRecord[] = [];
    for (const message of messages) {
      const record = this.buildRecord(message, state);
      if (record !== undefined) {
        records.push(record);
      }
    }
    return records;
  }

  private buildRecord(message: TdObject, state: AppState): CallHistoryRecord | undefined {
    const content = tdGetObject(message, 'content');
    if (!tdHasKeys(content)) {
      return undefined;
    }

    const contentType = tdGetString(content, '@type');
    if (contentType !== 'messageCall' && contentType !== 'messageGroupCall') {
      return undefined;
    }

    const chatId = tdGetNumber(message, 'chat_id');
    const chat = state.chats.chats.get(chatId);
    const sender = tdGetObject(message, 'sender_id');
    const senderType = tdGetString(sender, '@type');
    const senderUserId = senderType === 'messageSenderUser' ? tdGetNumber(sender, 'user_id') : 0;
    const otherParticipantUserIds = this.extractOtherParticipantUserIds(content);
    const isOutgoing = tdGetBoolean(message, 'is_outgoing');

    let peerUserId = 0;
    if (chat && chat.peerUserId > 0) {
      peerUserId = chat.peerUserId;
    }
    if (peerUserId === 0 && senderUserId > 0 && senderUserId !== state.auth.userId) {
      peerUserId = senderUserId;
    }
    if (peerUserId === 0) {
      for (const participantUserId of otherParticipantUserIds) {
        if (participantUserId > 0 && participantUserId !== state.auth.userId) {
          peerUserId = participantUserId;
          break;
        }
      }
    }

    let direction: CallHistoryDirection = isOutgoing ? 'outgoing' : 'incoming';
    let discardReasonType = '';
    const isVideo = tdGetBoolean(content, 'is_video');

    if (contentType === 'messageCall') {
      discardReasonType = tdGetString(tdGetObject(content, 'discard_reason'), '@type');
      if (!isOutgoing &&
        (discardReasonType === 'callDiscardReasonMissed' || discardReasonType === 'callDiscardReasonDeclined')) {
        direction = 'missed';
      }
    } else {
      const wasMissed = tdGetBoolean(content, 'was_missed');
      if (!isOutgoing && wasMissed) {
        direction = 'missed';
      }
    }

    const record = new CallHistoryRecord();
    record.messageId = tdGetInt64(message, 'id');
    record.chatId = chatId;
    record.peerUserId = peerUserId;
    record.senderUserId = senderUserId;
    record.timestamp = tdGetNumber(message, 'date');
    record.direction = direction;
    record.isVideo = isVideo;
    record.discardReasonType = discardReasonType;
    record.contentType = contentType === 'messageGroupCall' ? 'messageGroupCall' : 'messageCall';

    this.applyFallbacks(record, chat, state);
    return record;
  }

  private extractOtherParticipantUserIds(content: TdObject): number[] {
    const result: number[] = [];
    const otherParticipantIds = tdGetArray(content, 'other_participant_ids');
    for (const participant of otherParticipantIds) {
      const participantType = tdGetString(participant, '@type');
      if (participantType !== 'messageSenderUser') {
        continue;
      }
      const userId = tdGetNumber(participant, 'user_id');
      if (userId > 0) {
        result.push(userId);
      }
    }
    return result;
  }

  private applyFallbacks(record: CallHistoryRecord, chat: Chat | undefined, state: AppState): void {
    if (record.peerUserId > 0) {
      const peerUser = state.users.users.get(record.peerUserId);
      if (peerUser) {
        const fullName = (peerUser.firstName + ' ' + peerUser.lastName).trim();
        record.fallbackTitle = fullName.length > 0 ? fullName :
          (peerUser.username.length > 0 ? '@' + peerUser.username : chat?.title || '');
        record.fallbackAvatarPath = peerUser.photoSmall;
        return;
      }
    }

    if (chat) {
      record.fallbackTitle = chat.title;
      record.fallbackAvatarPath = chat.photoSmall;
      return;
    }

    record.fallbackTitle = '';
    record.fallbackAvatarPath = '';
  }
}

export function createLoadCallsUseCase(store: AppStore, gateway: TdGatewayPort): LoadCallsUseCase {
  return new LoadCallsUseCase(store, gateway);
}
