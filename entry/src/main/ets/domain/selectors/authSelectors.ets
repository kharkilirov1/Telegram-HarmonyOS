// Auth selectors - pure functions for selecting auth/connection data from state
// Used by UI components to get derived data

import { AppState } from '../../core/model/AppState';

// Auth state selectors
export const selectAuthState = (state: AppState) => state.auth;

export const selectAuthStatus = (state: AppState) => state.auth.status;

export const selectAuthUserId = (state: AppState) => state.auth.userId;

export const selectAuthPhoneNumber = (state: AppState) => state.auth.phoneNumber;

export const selectAuthError = (state: AppState) => state.auth.error;

// Connection state selectors
export const selectConnectionState = (state: AppState) => state.connection;

export const selectConnectionStatus = (state: AppState) => state.connection.status;

export const selectIsConnected = (state: AppState) => state.connection.status === 'ready';

export const selectIsConnecting = (state: AppState) => 
  state.connection.status === 'connecting' || state.connection.status === 'updating';

// Combined selectors
export const selectIsAuthenticated = (state: AppState) => 
  state.auth.status === 'ready';

export const selectIsWaitingForAuth = (state: AppState) => 
  state.auth.status === 'waitPhoneNumber' || 
  state.auth.status === 'waitCode' || 
  state.auth.status === 'waitPassword';

export const selectCanSendMessages = (state: AppState) => 
  selectIsAuthenticated(state) && selectIsConnected(state);

export const selectAuthScreenNeeded = (state: AppState): boolean => {
  const status = state.auth.status;
  return status === 'waitPhoneNumber' ||
         status === 'waitCode' ||
         status === 'waitPassword' ||
         status === 'notInitialized';
};

// DTO for auth display info
export class AuthDisplayInfo {
  status: string = 'notInitialized';
  userId: number = 0;
  phoneNumber: string = '';
  isConnected: boolean = false;
  connectionStatus: string = 'connecting';
  lastUpdated: number = 0;
  error: string = '';
}

// Selector for UI display
export const selectAuthDisplayInfo = (state: AppState): AuthDisplayInfo => {
  const auth = state.auth;
  const connection = state.connection;

  const result = new AuthDisplayInfo();
  result.status = auth.status;
  result.userId = auth.userId;
  result.phoneNumber = auth.phoneNumber;
  result.isConnected = connection.status === 'ready';
  result.connectionStatus = connection.status;
  result.lastUpdated = connection.lastUpdated;
  result.error = auth.error;
  return result;
};

// Memoized selector for auth display info (non-generic for ArkTS)
export function createMemoizedAuthDisplaySelector(): (state: AppState) => AuthDisplayInfo {
  let lastState: AppState | null = null;
  let lastResult: AuthDisplayInfo | null = null;

  return (state: AppState): AuthDisplayInfo => {
    if (lastState === state && lastResult !== null) {
      return lastResult;
    }

    lastState = state;
    lastResult = selectAuthDisplayInfo(state);
    return lastResult;
  };
}