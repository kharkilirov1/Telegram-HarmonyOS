// Active sessions (devices) — TDLib getActiveSessions / terminateSession.
// Contract: td_api.tl:8294 session, :13755 getActiveSessions = Sessions, :13758 terminateSession.
//
// The page owns the list; this use case only requests and validates. A terminated session disappears
// on the next refresh (TDLib sends no per-session update for it).

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdObject } from '../../models/TdTypes';
import { createGetActiveSessionsCommand, createTerminateAllOtherSessionsCommand, createTerminateSessionCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { SessionInfoDto, createSessionInfoListFromTd } from '../../core/model/dto/SessionDto';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0034;
const TAG = 'LoadSessions';

export class LoadSessionsUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async fetchSessions(): Promise<SessionInfoDto[]> {
    try {
      const response = await this.gateway.send(createGetActiveSessionsCommand()) as TdObject;
      return createSessionInfoListFromTd(response);
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'getActiveSessions failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to load sessions', err.message, 0, true);
    }
  }

  // iOS "Terminate all other sessions": one TDLib call, the current session is kept.
  async terminateAllOthers(): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, 'Terminating all other sessions');
      await this.gateway.send(createTerminateAllOtherSessionsCommand());
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'terminateAllOtherSessions failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to terminate other sessions', err.message, 0, true);
    }
  }

  async terminate(sessionId: string): Promise<void> {
    if (typeof sessionId !== 'string' || !/^[1-9][0-9]*$/.test(sessionId)) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid sessionId', 'Input validation failed', 400, false);
    }
    try {
      hilog.info(DOMAIN, TAG, 'Terminating session %{public}s', sessionId);
      await this.gateway.send(createTerminateSessionCommand(sessionId));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'terminateSession failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to terminate session', err.message, 0, true);
    }
  }
}

export function createLoadSessionsUseCase(gateway: TdGatewayPort): LoadSessionsUseCase {
  return new LoadSessionsUseCase(gateway);
}
