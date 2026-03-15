// Auth reducer - handles authentication and connection events
// Pure function, no side effects
// Uses selective state cloning for performance

import { AppState, ReducerAction } from '../model/AppState';
import { AuthStateChangedEvent, MyUserResolvedEvent, ConnectionStateChangedEvent } from '../model/AppEvent';
import { cloneStateForAuth } from '../utils/stateClone';

// Events this reducer handles
function isAuthEvent(type: string): boolean {
  return type === 'authStateChanged' || type === 'myUserResolved' ||
    type === 'connectionStateChanged';
}

export function authReducer(state: AppState, action: ReducerAction): AppState {
  if (!isAuthEvent(action.type)) {
    return state;
  }

  const newState = cloneStateForAuth(state);

  switch (action.type) {
    case 'authStateChanged': {
      const authEvent = action as AuthStateChangedEvent;
      newState.auth.status = authEvent.state;

      if (authEvent.state === 'waitPhoneNumber') {
        newState.auth.phoneNumber = '';
        newState.auth.codeType = 'sms';
        newState.auth.codeLength = 5;
        newState.auth.codeTimeout = 60;
        newState.auth.nextCodeType = 'call';
        newState.auth.passwordHint = '';
      }

      // userId приходит только из myUserResolved (через getMe).
      // authStateChanged НЕ содержит userId — не перезаписываем существующий.
      if (authEvent.userId && authEvent.userId > 0) {
        newState.auth.userId = authEvent.userId;
      }
      if (authEvent.phoneNumber.length > 0) {
        newState.auth.phoneNumber = authEvent.phoneNumber;
      }
      if (authEvent.codeType.length > 0) {
        newState.auth.codeType = authEvent.codeType;
      }
      if (authEvent.codeLength > 0) {
        newState.auth.codeLength = authEvent.codeLength;
      }
      if (authEvent.codeTimeout >= 0) {
        newState.auth.codeTimeout = authEvent.codeTimeout;
      }
      if (authEvent.state === 'waitCode' || authEvent.nextCodeType.length > 0) {
        newState.auth.nextCodeType = authEvent.nextCodeType;
      }
      if (authEvent.state !== 'waitPassword') {
        newState.auth.passwordHint = '';
      } else {
        newState.auth.passwordHint = authEvent.passwordHint;
      }

      // QR code link (waitQrCode state)
      if (authEvent.state === 'waitQrCode' && authEvent.qrCodeLink.length > 0) {
        newState.auth.qrCodeLink = authEvent.qrCodeLink;
      } else if (authEvent.state !== 'waitQrCode') {
        newState.auth.qrCodeLink = '';
      }
      break;
    }

    case 'myUserResolved': {
      const resolvedEvent = action as MyUserResolvedEvent;
      if (resolvedEvent.userId > 0) {
        newState.auth.userId = resolvedEvent.userId;
      }
      break;
    }

    case 'connectionStateChanged': {
      const connectionEvent = action as ConnectionStateChangedEvent;
      newState.connection.status = connectionEvent.state;
      newState.connection.lastUpdated = Date.now();
      break;
    }
  }

  newState.version = state.version + 1;
  newState.lastEvent = action;

  return newState;
}
