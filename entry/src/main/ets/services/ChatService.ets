// ChatService — use-case layer for chat-level TDLib operations
// Decouples UI pages from direct TDLibClient.send() calls
// Reference: Telegram iOS ChatController, Android ChatActivity

import { TDLibClient } from './TDLibClient';
import {
  TdChats,
  TdChatInviteLink,
  TdChatInviteLinks,
  TdSecretChat,
  TdChatsNearby,
  TdAutoDownloadSettingsPresets,
  TdPassportAuthorizationForm,
  TdMessages,
  TdMessage,
  safeNumber
} from '../models/TdTypes';
import { Message } from '../models/Message';
import { parseMessage } from '../controllers/TdMessageParser';

export class ChatService {
  private static instance: ChatService | null = null;

  private constructor() {}

  static getInstance(): ChatService {
    if (!ChatService.instance) {
      ChatService.instance = new ChatService();
    }
    return ChatService.instance;
  }

  // --- Chat creation ---

  async createPrivateChat(userId: number): Promise<number> {
    const params: Record<string, Object> = {};
    params['user_id'] = userId;
    params['force'] = false;
    const result = await TDLibClient.getInstance().send('createPrivateChat', params);
    return (result['id'] as number) || 0;
  }

  async createNewBasicGroupChat(userIds: number[], title: string): Promise<number> {
    const params: Record<string, Object> = {};
    params['user_ids'] = userIds;
    params['title'] = title;
    const result = await TDLibClient.getInstance().send('createNewBasicGroupChat', params);
    return (result['id'] as number) || 0;
  }

  async createNewSupergroupChat(title: string, isChannel: boolean, description: string): Promise<number> {
    const params: Record<string, Object> = {};
    params['title'] = title;
    params['is_channel'] = isChannel;
    params['description'] = description;
    const result = await TDLibClient.getInstance().send('createNewSupergroupChat', params);
    return (result['id'] as number) || 0;
  }

  async createNewSecretChat(userId: number): Promise<Record<string, Object>> {
    const params: Record<string, Object> = {};
    params['user_id'] = userId;
    return TDLibClient.getInstance().send('createNewSecretChat', params);
  }

  // --- Chat list operations ---

  async addChatToList(chatId: number, listType: string): Promise<void> {
    const chatList: Record<string, Object> = {};
    chatList['@type'] = listType;
    const params: Record<string, Object> = {};
    params['chat_id'] = chatId;
    params['chat_list'] = chatList;
    await TDLibClient.getInstance().send('addChatToList', params);
  }

  async getChat(chatId: number): Promise<Record<string, Object>> {
    const params: Record<string, Object> = {};
    params['chat_id'] = chatId;
    return TDLibClient.getInstance().send('getChat', params);
  }

  async getSupergroupIdByChat(chatId: number): Promise<number> {
    const result = await this.getChat(chatId);
    const type = result['type'] as Record<string, Object> | undefined;
    if (!type) return 0;
    return safeNumber(type['supergroup_id']);
  }

  async setSupergroupUsername(supergroupId: number, username: string): Promise<void> {
    const params: Record<string, Object> = {};
    params['supergroup_id'] = supergroupId;
    params['username'] = username;
    await TDLibClient.getInstance().send('setSupergroupUsername', params);
  }

  async addChatMembers(chatId: number, userIds: number[]): Promise<Record<string, Object>> {
    const params: Record<string, Object> = {};
    params['chat_id'] = chatId;
    params['user_ids'] = userIds;
    return TDLibClient.getInstance().send('addChatMembers', params);
  }

  // --- Search ---

  async searchChats(query: string, limit: number = 20): Promise<TdChats> {
    const params: Record<string, Object> = {};
    params['query'] = query;
    params['limit'] = limit;
    const result = await TDLibClient.getInstance().send('searchChats', params);
    return result as TdChats;
  }

  async searchChatsNearby(latitude: number, longitude: number): Promise<TdChatsNearby> {
    const location: Record<string, Object> = {};
    location['@type'] = 'location';
    location['latitude'] = latitude;
    location['longitude'] = longitude;
    const params: Record<string, Object> = {};
    params['location'] = location;
    const result = await TDLibClient.getInstance().send('searchChatsNearby', params);
    return result as TdChatsNearby;
  }

  async searchChatMessages(chatId: number, query: string, fromMessageId: number = 0,
    limit: number = 50, filterType: string = ''): Promise<Message[]> {
    const searchParams: Record<string, Object> = {};
    searchParams['chat_id'] = chatId;
    searchParams['query'] = query;
    searchParams['from_message_id'] = fromMessageId;
    searchParams['offset'] = 0;
    searchParams['limit'] = limit;
    searchParams['message_thread_id'] = 0;

    if (filterType.length > 0) {
      const filterParam: Record<string, Object> = {};
      filterParam['@type'] = filterType;
      searchParams['filter'] = filterParam;
    }

    const result: TdMessages = await TDLibClient.getInstance()
      .send('searchChatMessages', searchParams) as TdMessages;
    const rawMessages: TdMessage[] | undefined = result.messages;
    if (!rawMessages) return [];
    return rawMessages.map((raw: TdMessage): Message => parseMessage(raw));
  }

  async searchGlobalMessages(query: string, limit: number = 50): Promise<Record<string, Object>> {
    const chatListMain: Record<string, Object> = {};
    chatListMain['@type'] = 'chatListMain';
    const params: Record<string, Object> = {};
    params['chat_list'] = chatListMain;
    params['query'] = query;
    params['offset'] = '';
    params['offset_chat_id'] = 0;
    params['offset_message_id'] = 0;
    params['limit'] = limit;
    return TDLibClient.getInstance().send('searchMessages', params);
  }

  async getChatMessageByDate(chatId: number, date: number): Promise<Record<string, Object>> {
    const params: Record<string, Object> = {};
    params['chat_id'] = chatId;
    params['date'] = date;
    return TDLibClient.getInstance().send('getChatMessageByDate', params);
  }

  async searchChatMembers(chatId: number, query: string, limit: number = 20): Promise<Record<string, Object>> {
    const params: Record<string, Object> = {};
    params['chat_id'] = chatId;
    params['query'] = query;
    params['limit'] = limit;
    return TDLibClient.getInstance().send('searchChatMembers', params);
  }

  // --- Invite links ---

  async getChatInviteLinks(chatId: number, creatorUserId: number, isRevoked: boolean = false,
    limit: number = 50): Promise<TdChatInviteLinks> {
    const params: Record<string, Object> = {};
    params['chat_id'] = chatId;
    params['creator_user_id'] = creatorUserId;
    params['is_revoked'] = isRevoked;
    params['offset_date'] = 0;
    params['offset_invite_link'] = '';
    params['limit'] = limit;
    const result = await TDLibClient.getInstance().send('getChatInviteLinks', params);
    return result as TdChatInviteLinks;
  }

  async createChatInviteLink(chatId: number, name: string = '',
    expireDate: number = 0, memberLimit: number = 0): Promise<TdChatInviteLink> {
    const params: Record<string, Object> = {};
    params['chat_id'] = chatId;
    if (name.length > 0) params['name'] = name;
    if (expireDate > 0) params['expiration_date'] = expireDate;
    if (memberLimit > 0) params['member_limit'] = memberLimit;
    const result = await TDLibClient.getInstance().send('createChatInviteLink', params);
    return result as TdChatInviteLink;
  }

  async revokeChatInviteLink(chatId: number, inviteLink: string): Promise<void> {
    const params: Record<string, Object> = {};
    params['chat_id'] = chatId;
    params['invite_link'] = inviteLink;
    await TDLibClient.getInstance().send('revokeChatInviteLink', params);
  }

  // --- Secret chat ---

  async getSecretChat(secretChatId: number): Promise<TdSecretChat> {
    const params: Record<string, Object> = {};
    params['secret_chat_id'] = secretChatId;
    const result = await TDLibClient.getInstance().send('getSecretChat', params);
    return result as TdSecretChat;
  }

  async setChatMessageAutoDeleteTime(chatId: number, autoDeleteTime: number): Promise<void> {
    const params: Record<string, Object> = {};
    params['chat_id'] = chatId;
    params['message_auto_delete_time'] = autoDeleteTime;
    await TDLibClient.getInstance().send('setChatMessageAutoDeleteTime', params);
  }

  // --- Forward ---

  async forwardMessages(chatId: number, fromChatId: number, messageIds: number[]): Promise<void> {
    const params: Record<string, Object> = {};
    params['chat_id'] = chatId;
    params['from_chat_id'] = fromChatId;
    params['message_ids'] = messageIds;
    await TDLibClient.getInstance().send('forwardMessages', params);
  }

  // --- Chat permissions ---

  async setChatPermissions(chatId: number, permissions: Record<string, Object>): Promise<void> {
    const params: Record<string, Object> = {};
    params['chat_id'] = chatId;
    params['permissions'] = permissions;
    await TDLibClient.getInstance().send('setChatPermissions', params);
  }

  // --- Data/storage settings ---

  async getAutoDownloadSettingsPresets(): Promise<TdAutoDownloadSettingsPresets> {
    const result = await TDLibClient.getInstance().send('getAutoDownloadSettingsPresets');
    return result as TdAutoDownloadSettingsPresets;
  }

  async setAutoDownloadSettings(settings: Record<string, Object>, networkType: string): Promise<void> {
    const type: Record<string, Object> = {};
    type['@type'] = networkType;
    const params: Record<string, Object> = {};
    params['settings'] = settings;
    params['type'] = type;
    await TDLibClient.getInstance().send('setAutoDownloadSettings', params);
  }

  // --- Passport ---

  async getPassportAuthorizationForm(botUserId: number, scope: string,
    publicKey: string): Promise<TdPassportAuthorizationForm> {
    const params: Record<string, Object> = {};
    params['bot_user_id'] = botUserId;
    params['scope'] = scope;
    params['public_key'] = publicKey;
    const result = await TDLibClient.getInstance().send('getPassportAuthorizationForm', params);
    return result as TdPassportAuthorizationForm;
  }

  // --- Mute / unmute ---

  async muteChat(chatId: number, muteForSeconds: number): Promise<void> {
    await TDLibClient.getInstance().setChatNotificationSettings(chatId, muteForSeconds);
  }

  async unmuteChat(chatId: number): Promise<void> {
    await TDLibClient.getInstance().setChatNotificationSettings(chatId, 0);
  }

  // --- Pin / unpin ---

  async pinChat(chatId: number): Promise<void> {
    await TDLibClient.getInstance().toggleChatIsPinned(chatId, true);
  }

  async unpinChat(chatId: number): Promise<void> {
    await TDLibClient.getInstance().toggleChatIsPinned(chatId, false);
  }

  // --- Delete chat history ---

  async deleteChatHistory(chatId: number): Promise<void> {
    await TDLibClient.getInstance().deleteChat(chatId);
  }

  // --- Mark as read ---

  async markChatAsRead(chatId: number): Promise<void> {
    await TDLibClient.getInstance().openChat(chatId);
  }

  async setChatMarkedAsUnread(chatId: number, isMarkedAsUnread: boolean): Promise<void> {
    await TDLibClient.getInstance().toggleChatIsMarkedAsUnread(chatId, isMarkedAsUnread);
  }

  // --- Auth recovery (used by PasswordPage) ---

  async requestAuthPasswordRecovery(): Promise<Record<string, Object>> {
    return TDLibClient.getInstance().send('requestAuthenticationPasswordRecovery');
  }

  async recoverAuthPassword(recoveryCode: string): Promise<void> {
    const params: Record<string, Object> = {};
    params['recovery_code'] = recoveryCode;
    await TDLibClient.getInstance().send('recoverAuthenticationPassword', params);
  }
}

