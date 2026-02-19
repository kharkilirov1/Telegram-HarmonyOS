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
      newState.auth.userId = authEvent.userId || 0;
      break;
    }

    case 'myUserResolved': {
      const resolvedEvent = action as MyUserResolvedEvent;
      newState.auth.userId = resolvedEvent.userId;
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
