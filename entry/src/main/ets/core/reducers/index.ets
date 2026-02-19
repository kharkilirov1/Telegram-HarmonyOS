// Combined reducer - routes events to the correct reducer
// Each event is processed by exactly ONE reducer (no wasted clones)

import { AppState, ReducerAction } from '../model/AppState';
import { authReducer } from './authReducer';
import { dialogsReducer } from './dialogsReducer';
import { messagesReducer } from './messagesReducer';
import { usersReducer } from './usersReducer';

export type AppReducerFn = (state: AppState, action: ReducerAction) => AppState;

// Main application reducer — routes each event to the appropriate sub-reducer.
// Each sub-reducer returns state unchanged (no clone) for events it doesn't handle,
// so only ONE full clone happens per event regardless of how many reducers exist.
export function appReducer(state: AppState, action: ReducerAction): AppState {
  // Auth & connection
  if (action.type === 'authStateChanged' || action.type === 'myUserResolved' ||
    action.type === 'connectionStateChanged') {
    return authReducer(state, action);
  }

  // Dialogs / chats
  if (action.type === 'newChat' || action.type === 'chatUpdated' ||
    action.type === 'chatReadInbox' || action.type === 'chatReadOutbox') {
    return dialogsReducer(state, action);
  }

  // Messages
  if (action.type === 'newMessage' || action.type === 'messageUpdated' ||
    action.type === 'messageContentUpdated' || action.type === 'messageSendSucceeded' ||
    action.type === 'messageSendFailed' || action.type === 'messagesDeleted') {
    return messagesReducer(state, action);
  }

  // Users
  if (action.type === 'userUpdated' || action.type === 'userStatusChanged') {
    return usersReducer(state, action);
  }

  // Unknown event type — no state change
  return state;
}

export type AppReducer = AppReducerFn;

export default appReducer;
