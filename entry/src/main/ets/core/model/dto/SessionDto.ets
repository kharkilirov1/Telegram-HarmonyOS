// Session (device) DTO — one entry of getActiveSessions (td_api.tl:8294, getActiveSessions:13755).
//
// session.id is int64 and therefore a decimal string; everything else is a plain field. last_active
// is a client-side derived label (TDLib only sends a unix date), formatted by the page.

import { TdObject as TdObjectType } from '../../../models/TdTypes';

export class SessionInfoDto {
  id: string = '0';
  isCurrent: boolean = false;
  isPasswordPending: boolean = false;
  isUnconfirmed: boolean = false;
  canAcceptSecretChats: boolean = false;
  canAcceptCalls: boolean = false;
  // TDLib sessionType*: tells browser sessions (Chrome, Safari...) from app sessions.
  sessionType: string = '';
  applicationName: string = '';
  applicationVersion: string = '';
  isOfficialApplication: boolean = false;
  deviceModel: string = '';
  platform: string = '';
  systemVersion: string = '';
  ipAddress: string = '';
  country: string = '';
  lastActiveDate: number = 0;
}

export function createSessionInfoFromTd(td: TdObjectType): SessionInfoDto | undefined {
  if (td.getTopLevelStringStrict('@type') !== 'session') {
    return undefined;
  }
  const dto = new SessionInfoDto();
  const rawId = td.getTopLevelInt64StringStrict('id');
  if (typeof rawId !== 'string' || rawId.length === 0) {
    return undefined;
  }
  dto.id = rawId;
  dto.isCurrent = td.getTopLevelBooleanStrict('is_current') === true;
  dto.isPasswordPending = td.getTopLevelBooleanStrict('is_password_pending') === true;
  dto.isUnconfirmed = td.getTopLevelBooleanStrict('is_unconfirmed') === true;
  dto.canAcceptSecretChats = td.getTopLevelBooleanStrict('can_accept_secret_chats') === true;
  dto.canAcceptCalls = td.getTopLevelBooleanStrict('can_accept_calls') === true;
  const type = td.getTopLevelObjectStrict('type');
  dto.sessionType = type === undefined ? '' : (type.getTopLevelStringStrict('@type') ?? '');
  dto.applicationName = td.getTopLevelStringStrict('application_name') ?? '';
  dto.applicationVersion = td.getTopLevelStringStrict('application_version') ?? '';
  dto.isOfficialApplication = td.getTopLevelBooleanStrict('is_official_application') === true;
  dto.deviceModel = td.getTopLevelStringStrict('device_model') ?? '';
  dto.platform = td.getTopLevelStringStrict('platform') ?? '';
  dto.systemVersion = td.getTopLevelStringStrict('system_version') ?? '';
  dto.ipAddress = td.getTopLevelStringStrict('ip_address') ?? '';
  dto.country = td.getTopLevelStringStrict('country') ?? '';
  const rawDate = td.getTopLevelNumberStrict('last_active_date');
  dto.lastActiveDate = typeof rawDate === 'number' && Number.isFinite(rawDate) && rawDate > 0 ? rawDate : 0;
  return dto;
}

export function createSessionInfoListFromTd(td: TdObjectType): SessionInfoDto[] {
  const sessions: SessionInfoDto[] = [];
  if (td.getTopLevelStringStrict('@type') !== 'sessions') {
    return sessions;
  }
  // Raw slices, not parsed children: session.id is int64 and must keep its exact digits.
  const rawSessions = td.getTopLevelRawObjectArrayStrict('sessions');
  if (rawSessions === undefined) {
    return sessions;
  }
  for (const rawText of rawSessions) {
    const session = createSessionInfoFromTd(TdObjectType.fromJSON(rawText));
    if (session !== undefined) {
      sessions.push(session);
    }
  }
  return sessions;
}
