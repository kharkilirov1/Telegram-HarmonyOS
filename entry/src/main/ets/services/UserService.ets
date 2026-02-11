// UserService — use-case layer for user/profile TDLib operations
// Decouples UI pages from direct TDLibClient.send() calls
// Reference: Telegram iOS UserInfoController, Android ProfileActivity

import { TDLibClient, TDLibError } from './TDLibClient';
import { handleTdlibError } from './AppError';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdUser, TdUserFullInfo } from '../models/TdTypes';

const TAG = 'UserService';
const DOMAIN = 0x0001;

export class UserService {
  private static instance: UserService | null = null;

  private constructor() {}

  static getInstance(): UserService {
    if (!UserService.instance) {
      UserService.instance = new UserService();
    }
    return UserService.instance;
  }

  async getMe(): Promise<TdUser> {
    const result = await TDLibClient.getInstance().send('getMe');
    return result as TdUser;
  }

  async getUser(userId: number): Promise<TdUser> {
    const params: Record<string, unknown> = {};
    params['user_id'] = userId;
    const result = await TDLibClient.getInstance().send('getUser', params);
    return result as TdUser;
  }

  async getUserFullInfo(userId: number): Promise<TdUserFullInfo> {
    const params: Record<string, unknown> = {};
    params['user_id'] = userId;
    const result = await TDLibClient.getInstance().send('getUserFullInfo', params);
    return result as TdUserFullInfo;
  }

  async setName(firstName: string, lastName: string): Promise<void> {
    const params: Record<string, unknown> = {};
    params['first_name'] = firstName;
    params['last_name'] = lastName;
    await TDLibClient.getInstance().send('setName', params);
  }

  async setBio(bio: string): Promise<void> {
    const params: Record<string, unknown> = {};
    params['bio'] = bio;
    await TDLibClient.getInstance().send('setBio', params);
  }

  async setUsername(username: string): Promise<void> {
    const params: Record<string, unknown> = {};
    params['username'] = username;
    await TDLibClient.getInstance().send('setUsername', params);
  }

  async isPremium(): Promise<boolean> {
    try {
      const me = await this.getMe();
      return me.is_premium || false;
    } catch (e) {
      if (e instanceof TDLibError) {
        handleTdlibError(e.code, e.tdMessage);
      }
      hilog.warn(DOMAIN, TAG, 'Failed to check premium status');
      return false;
    }
  }
}
