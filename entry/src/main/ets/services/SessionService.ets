// SessionService — use-case layer for active session/device management
// Encapsulates all TDLib session operations so pages don't call TDLibClient directly
// Reference: Telegram iOS SessionsController, Android SessionsActivity

import { TDLibClient, TDLibError } from './TDLibClient';
import { handleTdlibError, AppError } from './AppError';
import { TdObject, TdSessions, TdSession, safeNumber, safeString, safeBool, safeInt64, asRecord, asArray } from '../models/TdTypes';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'SessionService';
const DOMAIN = 0x0001;

export interface SessionInfo {
  id: string; // TDLib int64 — stored as string to prevent precision loss
  isCurrent: boolean;
  deviceModel: string;
  platform: string;
  systemVersion: string;
  apiId: number;
  applicationName: string;
  applicationVersion: string;
  logInDate: number;
  lastActiveDate: number;
  ip: string;
  country: string;
  region: string;
}

export class SessionService {
  private static instance: SessionService | null = null;
  private tdlib: TDLibClient = TDLibClient.getInstance();

  private constructor() {}

  static getInstance(): SessionService {
    if (!SessionService.instance) {
      SessionService.instance = new SessionService();
    }
    return SessionService.instance;
  }

  /**
   * Fetch all active sessions/devices from TDLib.
   */
  async getActiveSessions(): Promise<SessionInfo[]> {
    const result = await this.tdlib.send('getActiveSessions');
    const sessions = asArray(result['sessions']);
    if (!sessions) return [];

    return sessions.map((session: TdObject): SessionInfo => {
      return {
        id: safeInt64(session['id']),
        isCurrent: safeBool(session['is_current']),
        deviceModel: safeString(session['device_model']),
        platform: safeString(session['platform']),
        systemVersion: safeString(session['system_version']),
        apiId: safeNumber(session['api_id']),
        applicationName: safeString(session['application_name']),
        applicationVersion: safeString(session['application_version']),
        logInDate: safeNumber(session['log_in_date']),
        lastActiveDate: safeNumber(session['last_active_date']),
        ip: safeString(session['ip_address']) || safeString(session['ip']),
        country: safeString(session['country']),
        region: safeString(session['region']),
      };
    });
  }

  /**
   * Terminate a specific session by ID.
   * Returns AppError on failure, null on success.
   */
  async terminateSession(sessionId: string): Promise<AppError | null> {
    try {
      const params: TdObject = {};
      params['session_id'] = sessionId;
      await this.tdlib.send('terminateSession', params);
      hilog.info(DOMAIN, TAG, 'Session %{public}s terminated', sessionId);
      return null;
    } catch (e) {
      if (e instanceof TDLibError) {
        return handleTdlibError(e.code, e.tdMessage);
      }
      hilog.error(DOMAIN, TAG, 'terminateSession failed: %{public}s', String(e));
      return null;
    }
  }

  /**
   * Terminate all sessions except the current one.
   * Returns AppError on failure, null on success.
   */
  async terminateAllOtherSessions(): Promise<AppError | null> {
    try {
      await this.tdlib.send('terminateAllOtherSessions');
      hilog.info(DOMAIN, TAG, 'All other sessions terminated');
      return null;
    } catch (e) {
      if (e instanceof TDLibError) {
        return handleTdlibError(e.code, e.tdMessage);
      }
      hilog.error(DOMAIN, TAG, 'terminateAllOtherSessions failed: %{public}s', String(e));
      return null;
    }
  }
}
