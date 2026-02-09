// GroupService — use-case layer for supergroup/group TDLib operations
// Decouples UI pages from direct TDLibClient.send() calls
// Reference: Telegram iOS GroupInfoController, Android ChatEditActivity

import { TDLibClient } from './TDLibClient';
import { TdSupergroup, TdSupergroupFullInfo, TdSupergroupMembers } from '../models/TdTypes';

export class GroupService {
  private static instance: GroupService | null = null;

  private constructor() {}

  static getInstance(): GroupService {
    if (!GroupService.instance) {
      GroupService.instance = new GroupService();
    }
    return GroupService.instance;
  }

  async getSupergroup(supergroupId: number): Promise<TdSupergroup> {
    const params: Record<string, Object> = {};
    params['supergroup_id'] = supergroupId;
    const result = await TDLibClient.getInstance().send('getSupergroup', params);
    return result as TdSupergroup;
  }

  async getSupergroupFullInfo(supergroupId: number): Promise<TdSupergroupFullInfo> {
    const params: Record<string, Object> = {};
    params['supergroup_id'] = supergroupId;
    const result = await TDLibClient.getInstance().send('getSupergroupFullInfo', params);
    return result as TdSupergroupFullInfo;
  }

  async getSupergroupMembers(supergroupId: number, filterType: string = 'supergroupMembersFilterRecent',
    offset: number = 0, limit: number = 200): Promise<TdSupergroupMembers> {
    const filter: Record<string, Object> = {};
    filter['@type'] = filterType;
    const params: Record<string, Object> = {};
    params['supergroup_id'] = supergroupId;
    params['filter'] = filter;
    params['offset'] = offset;
    params['limit'] = limit;
    const result = await TDLibClient.getInstance().send('getSupergroupMembers', params);
    return result as TdSupergroupMembers;
  }

  async toggleSupergroupIsAllHistoryAvailable(supergroupId: number,
    isAllHistoryAvailable: boolean): Promise<void> {
    const params: Record<string, Object> = {};
    params['supergroup_id'] = supergroupId;
    params['is_all_history_available'] = isAllHistoryAvailable;
    await TDLibClient.getInstance().send('toggleSupergroupIsAllHistoryAvailable', params);
  }

  async getChat(chatId: number): Promise<Record<string, Object>> {
    const params: Record<string, Object> = {};
    params['chat_id'] = chatId;
    return TDLibClient.getInstance().send('getChat', params);
  }
}
