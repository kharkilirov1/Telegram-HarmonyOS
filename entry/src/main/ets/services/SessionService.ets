// SessionService — use-case layer for active session/device management
// Encapsulates all TDLib session operations so pages don't call TDLibClient directly
// Reference: Telegram iOS SessionsController, Android SessionsActivity

import { TDLibClient, TDLibError } from './TDLibClient';
import { handleTdlibError, AppError } from './AppError';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'SessionService';
const DOMAIN = 0x0001;

export interface SessionInfo {
  id: number;
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
    const sessions = result['sessions'] as Object[];
    if (!sessions) return [];

    return sessions.map((s): SessionInfo => {
      const session = s as Record<string, Object>;
      return {
        id: session['id'] as number,
        isCurrent: session['is_current'] as boolean,
        deviceModel: session['device_model'] as string,
        platform: session['platform'] as string,
        systemVersion: session['system_version'] as string,
        apiId: session['api_id'] as number,
        applicationName: session['application_name'] as string,
        applicationVersion: session['application_version'] as string,
        logInDate: session['log_in_date'] as number,
        lastActiveDate: session['last_active_date'] as number,
        ip: (session['ip_address'] as string) || (session['ip'] as string) || '',
        country: (session['country'] as string) || '',
        region: (session['region'] as string) || '',
      };
    });
  }

  /**
   * Terminate a specific session by ID.
   * Returns AppError on failure, null on success.
   */
  async terminateSession(sessionId: number): Promise<AppError | null> {
    try {
      const params: Record<string, Object> = {};
      params['session_id'] = sessionId;
      await this.tdlib.send('terminateSession', params);
      hilog.info(DOMAIN, TAG, 'Session %{public}d terminated', sessionId);
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

