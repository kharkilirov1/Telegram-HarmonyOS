// Compose-only peer search adapted from Telegram iOS ContactsSearchContainerNode.
// Local UI contacts are immediate; this use case supplies TDLib cloud/known/global users.

import {
  createGetChatCommand,
  createGetUserCommand,
  createSearchChatsOnServerCommand,
  createSearchContactsCommand,
  createSearchPublicChatsCommand
} from '../../core/model/AppCommand';
import { ChatType, createChatDtoFromTd } from '../../core/model/dto/ChatDto';
import { UserDto, createUserDtoFromTd } from '../../core/model/dto/UserDto';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DEFAULT_COMPOSE_SEARCH_LIMIT = 20;
const MAX_COMPOSE_SEARCH_LIMIT = 50;

export class ComposeRemoteUserSearchResult {
  cloudContacts: UserDto[] = [];
  knownUsers: UserDto[] = [];
  globalUsers: UserDto[] = [];
}

function uniquePositiveIds(ids: number[]): number[] {
  const result: number[] = [];
  const seen: Set<number> = new Set<number>();
  for (const rawId of ids) {
    const id: number = Math.trunc(rawId);
    if (id <= 0 || seen.has(id)) {
      continue;
    }
    seen.add(id);
    result.push(id);
  }
  return result;
}

export function parseComposeUserIdsResponse(response: TdObject): number[] | undefined {
  if (response.getType() !== 'users') {
    return undefined;
  }
  return uniquePositiveIds(response.getNumberArray('user_ids'));
}

export function parseComposeChatIdsResponse(response: TdObject): number[] | undefined {
  if (response.getType() !== 'chats') {
    return undefined;
  }
  return uniquePositiveIds(response.getNumberArray('chat_ids'));
}

function isUsableComposeUser(user: UserDto): boolean {
  return user.id > 0 && ((user.firstName + user.lastName).trim().length > 0 ||
    user.username.length > 0 || user.phoneNumber.length > 0);
}

function appendUniqueUsers(target: UserDto[], candidates: UserDto[], seen: Set<number>): void {
  for (const user of candidates) {
    if (!isUsableComposeUser(user) || seen.has(user.id)) {
      continue;
    }
    seen.add(user.id);
    target.push(user);
  }
}

export class SearchComposeUsersUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async execute(
    rawQuery: string,
    limit: number = DEFAULT_COMPOSE_SEARCH_LIMIT
  ): Promise<ComposeRemoteUserSearchResult> {
    const query: string = rawQuery.trim();
    if (query.length === 0) {
      return new ComposeRemoteUserSearchResult();
    }
    const safeLimit: number = Math.max(1, Math.min(MAX_COMPOSE_SEARCH_LIMIT, Math.trunc(limit)));

    // TDLib has no single contacts.search equivalent that returns myResults/results.
    // Run the three closest typed sources together, then preserve iOS precedence.
    const sources: UserDto[][] = await Promise.all([
      this.searchCloudContacts(query, safeLimit),
      this.searchKnownPrivateChats(query, safeLimit),
      this.searchGlobalPrivateChats(query, safeLimit)
    ]);

    const result = new ComposeRemoteUserSearchResult();
    const seen: Set<number> = new Set<number>();
    appendUniqueUsers(result.cloudContacts, sources[0], seen);
    appendUniqueUsers(result.knownUsers, sources[1], seen);
    appendUniqueUsers(result.globalUsers, sources[2], seen);
    return result;
  }

  private async searchCloudContacts(query: string, limit: number): Promise<UserDto[]> {
    try {
      const response = await this.gateway.send(createSearchContactsCommand(query, limit));
      if (!(response instanceof TdObject)) {
        return [];
      }
      const userIds: number[] | undefined = parseComposeUserIdsResponse(response);
      // Cap primitive IDs before the per-user TDLib hydration path.
      const limitedUserIds: number[] = userIds === undefined ? [] : userIds.slice(0, limit);
      return await this.hydrateUsers(limitedUserIds);
    } catch (_error) {
      // Telegram iOS treats an individual search-source failure as an empty source.
      return [];
    }
  }

  private async searchKnownPrivateChats(query: string, limit: number): Promise<UserDto[]> {
    try {
      const response = await this.gateway.send(createSearchChatsOnServerCommand(query, limit));
      if (!(response instanceof TdObject)) {
        return [];
      }
      const chatIds: number[] | undefined = parseComposeChatIdsResponse(response);
      // Keep the sequential getChat -> getUser path bounded by the source limit.
      const limitedChatIds: number[] = chatIds === undefined ? [] : chatIds.slice(0, limit);
      return await this.hydratePrivateChatUsers(limitedChatIds);
    } catch (_error) {
      return [];
    }
  }

  private async searchGlobalPrivateChats(query: string, limit: number): Promise<UserDto[]> {
    try {
      const response = await this.gateway.send(createSearchPublicChatsCommand(query));
      if (!(response instanceof TdObject)) {
        return [];
      }
      const chatIds: number[] | undefined = parseComposeChatIdsResponse(response);
      // searchPublicChats has no limit argument, so enforce the same budget locally.
      const limitedChatIds: number[] = chatIds === undefined ? [] : chatIds.slice(0, limit);
      return await this.hydratePrivateChatUsers(limitedChatIds);
    } catch (_error) {
      return [];
    }
  }

  private async hydrateUsers(userIds: number[]): Promise<UserDto[]> {
    const users: UserDto[] = [];
    for (const userId of uniquePositiveIds(userIds)) {
      const user: UserDto | undefined = await this.hydrateUser(userId);
      if (user !== undefined) {
        users.push(user);
      }
    }
    return users;
  }

  private async hydratePrivateChatUsers(chatIds: number[]): Promise<UserDto[]> {
    const users: UserDto[] = [];
    const seenUsers: Set<number> = new Set<number>();
    for (const chatId of uniquePositiveIds(chatIds)) {
      try {
        const response = await this.gateway.send(createGetChatCommand(chatId));
        if (!(response instanceof TdObject) || response.getType() !== 'chat') {
          continue;
        }
        const chat = createChatDtoFromTd(response);
        if (chat.id !== chatId || chat.type !== ChatType.PRIVATE || chat.peerUserId <= 0 ||
          seenUsers.has(chat.peerUserId)) {
          continue;
        }
        const user: UserDto | undefined = await this.hydrateUser(chat.peerUserId);
        if (user === undefined) {
          continue;
        }
        seenUsers.add(user.id);
        users.push(user);
      } catch (_error) {
        // One stale/deleted chat must not discard the rest of the search page.
      }
    }
    return users;
  }

  private async hydrateUser(userId: number): Promise<UserDto | undefined> {
    try {
      const response = await this.gateway.send(createGetUserCommand(userId));
      if (!(response instanceof TdObject) || response.getType() !== 'user') {
        return undefined;
      }
      const userType: string = response.getObject('type').getType();
      if (userType === 'userTypeDeleted' || userType === 'userTypeUnknown') {
        return undefined;
      }
      const user = createUserDtoFromTd(response);
      return user.id === userId && isUsableComposeUser(user) ? user : undefined;
    } catch (_error) {
      return undefined;
    }
  }
}

export function searchComposeUsersUseCase(gateway: TdGatewayPort): SearchComposeUsersUseCase {
  return new SearchComposeUsersUseCase(gateway);
}
