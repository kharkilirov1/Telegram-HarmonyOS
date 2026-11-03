// Session grouping — iOS separates Web Sessions (browser logins) from Active Sessions (apps).
// TDLib sessionType* (td_api.tl:8224-8272): browsers are Brave/Chrome/Edge/Firefox/Opera/Safari/Vivaldi.

import { SessionInfoDto } from '../../core/model/dto/SessionDto';

export const WEB_SESSION_TYPES: string[] = [
  'sessionTypeBrave',
  'sessionTypeChrome',
  'sessionTypeEdge',
  'sessionTypeFirefox',
  'sessionTypeOpera',
  'sessionTypeSafari',
  'sessionTypeVivaldi'
];

export function isWebSession(sessionType: string): boolean {
  return WEB_SESSION_TYPES.indexOf(sessionType) >= 0;
}

export class SessionSections {
  active: SessionInfoDto[] = [];
  web: SessionInfoDto[] = [];
}

// Stable split: within a section TDLib order is preserved (current session stays first if TDLib
// listed it first). Unknown session types count as app sessions, never as web.
export function splitSessionsByKind(sessions: SessionInfoDto[]): SessionSections {
  const sections = new SessionSections();
  for (const session of sessions) {
    if (isWebSession(session.sessionType)) {
      sections.web.push(session);
    } else {
      sections.active.push(session);
    }
  }
  return sections;
}

// "Terminate all other sessions" is only offered when removing something is possible.
export function canTerminateOthers(sessions: SessionInfoDto[]): boolean {
  let others = 0;
  for (const session of sessions) {
    if (!session.isCurrent) {
      others += 1;
    }
  }
  return others > 0;
}
