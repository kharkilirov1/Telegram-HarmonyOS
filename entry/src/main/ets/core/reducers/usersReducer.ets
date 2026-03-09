// Users reducer - handles user events
// Pure function, no side effects
// Uses real data from DTOs instead of hardcoded values

import { AppState, User, ReducerAction } from '../model/AppState';
import { UserUpdatedEvent, UserStatusChangedEvent } from '../model/AppEvent';
import { cloneStateForUsers, cloneUser } from '../utils/stateClone';

// Events this reducer handles
function isUserEvent(type: string): boolean {
  return type === 'userUpdated' || type === 'userStatusChanged';
}

export function usersReducer(state: AppState, action: ReducerAction): AppState {
  if (!isUserEvent(action.type)) {
    return state;
  }

  const newState = cloneStateForUsers(state);

  switch (action.type) {
    case 'userUpdated': {
      const event = action as UserUpdatedEvent;
      
      // Check if userData is provided (full user update) or just updates (partial)
      if (event.userData && event.userData.id > 0) {
        // Full user update from userData
        const user = new User();
        user.id = event.userData.id;
        user.firstName = event.userData.firstName;
        user.lastName = event.userData.lastName;
        user.username = event.userData.username;
        user.phoneNumber = event.userData.phoneNumber;
        user.photoSmall = event.userData.photo?.small || '';
        user.photoBig = event.userData.photo?.big || '';
        user.photoSmallFileId = event.userData.photo?.smallFileId || 0;
        user.status = event.userData.status;
        user.isContact = event.userData.isContact;
        user.isVerified = event.userData.isVerified;
        user.isPremium = event.userData.isPremium;
        
        newState.users.users.set(event.userId, user);
      } else if (event.updates) {
        // Partial update
        const existingUser = newState.users.users.get(event.userId);
        if (!existingUser) break;
        
        const updatedUser = cloneUser(existingUser);
        
        if (event.updates.firstName !== undefined) { updatedUser.firstName = event.updates.firstName; }
        if (event.updates.lastName !== undefined) { updatedUser.lastName = event.updates.lastName; }
        if (event.updates.username !== undefined) { updatedUser.username = event.updates.username; }
        if (event.updates.phoneNumber !== undefined) { updatedUser.phoneNumber = event.updates.phoneNumber; }
        if (event.updates.photo !== undefined) {
          updatedUser.photoSmall = event.updates.photo.small;
          updatedUser.photoBig = event.updates.photo.big;
          updatedUser.photoSmallFileId = event.updates.photo.smallFileId || 0;
        }
        if (event.updates.status !== undefined) { 
          updatedUser.status = event.updates.status as 'online' | 'offline' | 'recently' | 'lastWeek' | 'lastMonth' | 'longTimeAgo'; 
        }
        if (event.updates.isContact !== undefined) { updatedUser.isContact = event.updates.isContact; }
        if (event.updates.isVerified !== undefined) { updatedUser.isVerified = event.updates.isVerified; }
        if (event.updates.isPremium !== undefined) { updatedUser.isPremium = event.updates.isPremium; }
        
        newState.users.users.set(event.userId, updatedUser);
      }
      break;
    }

    case 'userStatusChanged': {
      const event = action as UserStatusChangedEvent;
      const existingUser = newState.users.users.get(event.userId);
      if (!existingUser) break;
      
      const updatedUser = cloneUser(existingUser);
      updatedUser.status = event.status as 'online' | 'offline' | 'recently' | 'lastWeek' | 'lastMonth' | 'longTimeAgo';
      
      newState.users.users.set(event.userId, updatedUser);
      break;
    }
  }

  newState.version = state.version + 1;
  newState.lastEvent = action;

  return newState;
}
