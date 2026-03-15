// AuthNormalizer — handles auth + connection TDLib updates
// Extracted from EventNormalizer to prevent god-file growth

import {
  AnyAppEvent,
  AuthState,
  ConnectionState,
  createAuthStateChangedEvent,
  ConnectionStateChangedEvent
} from '../../model/AppEvent';
import { TdObject } from '../../../models/TdTypes';
import { tdGetNumber, tdGetObject, tdGetString } from '../../utils/tdAccessors';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0003;
const TAG = 'AuthNormalizer';

function mapAuthenticationCodeType(typeObj: TdObject): string {
  if (!typeObj || !typeObj.hasType()) {
    return '';
  }

  const type = tdGetString(typeObj, '@type');
  switch (type) {
    case 'authenticationCodeTypeTelegramMessage':
      return 'otherSession';
    case 'authenticationCodeTypeSms':
      return 'sms';
    case 'authenticationCodeTypeCall':
    case 'authenticationCodeTypeFlashCall':
      return 'call';
    case 'authenticationCodeTypeMissedCall':
      return 'missedCall';
    case 'authenticationCodeTypeFragment':
      return 'fragment';
    case 'authenticationCodeTypeEmailAddress':
      return 'email';
    case 'authenticationCodeTypeEmailAddressReset':
      return 'emailSetupRequired';
    case 'authenticationCodeTypeWord':
    case 'authenticationCodeTypeSmsWord':
      return 'word';
    case 'authenticationCodeTypePhrase':
    case 'authenticationCodeTypeSmsPhrase':
      return 'phrase';
    default:
      return '';
  }
}

function normalizeAuthState(events: AnyAppEvent[], update: TdObject): void {
  const authState = tdGetObject(update, 'authorization_state');
  if (!authState || !authState.hasType()) {
    hilog.warn(DOMAIN, TAG, 'updateAuthorizationState without valid authorization_state object');
    return;
  }
  const stateType = tdGetString(authState, '@type');

  let appAuthState: AuthState = 'waitPhoneNumber';
  let isKnown = true;

  switch (stateType) {
    case 'authorizationStateWaitTdlibParameters':
      appAuthState = 'waitTdlibParameters';
      break;
    case 'authorizationStateWaitPhoneNumber':
      appAuthState = 'waitPhoneNumber';
      break;
    case 'authorizationStateWaitCode':
      appAuthState = 'waitCode';
      break;
    case 'authorizationStateWaitPassword':
      appAuthState = 'waitPassword';
      break;
    case 'authorizationStateWaitRegistration':
      appAuthState = 'waitRegistration';
      break;
    case 'authorizationStateWaitOtherDeviceConfirmation':
      appAuthState = 'waitQrCode';
      break;
    case 'authorizationStateReady':
      appAuthState = 'ready';
      break;
    case 'authorizationStateLoggingOut':
      appAuthState = 'loggingOut';
      break;
    case 'authorizationStateClosing':
      appAuthState = 'closing';
      break;
    case 'authorizationStateClosed':
      appAuthState = 'closed';
      break;
    default:
      isKnown = false;
  }

  if (isKnown) {
    // Note: authorizationStateReady does NOT contain user_id.
    // UserId must be obtained separately via getMe() after auth is ready.
    const event = createAuthStateChangedEvent(appAuthState);

    if (stateType === 'authorizationStateWaitCode') {
      const codeInfo = tdGetObject(authState, 'code_info');
      const codeTypeObj = tdGetObject(codeInfo, 'type');
      const nextTypeObj = tdGetObject(codeInfo, 'next_type');

      const codeType = mapAuthenticationCodeType(codeTypeObj);
      if (codeType.length > 0) {
        event.codeType = codeType;
      }

      const codeLength = tdGetNumber(codeTypeObj, 'length');
      if (codeLength > 0) {
        event.codeLength = codeLength;
      }

      const timeout = tdGetNumber(codeInfo, 'timeout');
      if (timeout >= 0) {
        event.codeTimeout = timeout;
      }

      event.nextCodeType = mapAuthenticationCodeType(nextTypeObj);

      const phoneNumber = tdGetString(authState, 'phone_number');
      if (phoneNumber.length > 0) {
        event.phoneNumber = phoneNumber;
      } else {
        const phonePattern = tdGetString(codeInfo, 'phone_number_pattern');
        if (phonePattern.length > 0) {
          event.phoneNumber = phonePattern;
        }
      }

      hilog.info(
        DOMAIN,
        TAG,
        'waitCode: type=%{public}s len=%{public}d timeout=%{public}d next=%{public}s',
        event.codeType.length > 0 ? event.codeType : 'unknown',
        event.codeLength > 0 ? event.codeLength : 0,
        event.codeTimeout >= 0 ? event.codeTimeout : 0,
        event.nextCodeType.length > 0 ? event.nextCodeType : 'none'
      );
    }

    if (stateType === 'authorizationStateWaitOtherDeviceConfirmation') {
      const link = tdGetString(authState, 'link');
      event.qrCodeLink = link;
      hilog.info(DOMAIN, TAG, 'waitQrCode: link length=%{public}d', link.length);
    }

    if (stateType === 'authorizationStateWaitPassword') {
      event.passwordHint = tdGetString(authState, 'password_hint');
    }

    events.push(event);
  }
}

function normalizeConnectionState(events: AnyAppEvent[], update: TdObject): void {
  const state = tdGetObject(update, 'state');
  const stateType = tdGetString(state, '@type');

  let appConnectionState: ConnectionState = 'connecting';
  let isKnown = true;

  switch (stateType) {
    case 'connectionStateUpdating':
      appConnectionState = 'updating';
      break;
    case 'connectionStateReady':
      appConnectionState = 'ready';
      break;
    case 'connectionStateConnecting':
      appConnectionState = 'connecting';
      break;
    case 'connectionStateConnectingToProxy':
      appConnectionState = 'connecting';
      break;
    case 'connectionStateWaitingForNetwork':
      appConnectionState = 'waitingForNetwork';
      break;
    default:
      isKnown = false;
  }

  if (isKnown) {
    const event = new ConnectionStateChangedEvent();
    event.state = appConnectionState;
    event.timestamp = Date.now();
    events.push(event);
  }
}

export function registerAuthHandlers(
  handlers: Map<string, (events: AnyAppEvent[], update: TdObject) => void>
): void {
  handlers.set('updateAuthorizationState', normalizeAuthState);
  handlers.set('updateConnectionState', normalizeConnectionState);
}
