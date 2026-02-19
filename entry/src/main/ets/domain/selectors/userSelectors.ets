// User selectors - pure functions for selecting user data from state
// Used by UI components to get derived user data

import { AppState } from '../../core/model/AppState';
import { UserId } from '../../core/model/EntityId';
import { User } from '../../core/model/AppState';

// Basic selectors
export const selectUsersState = (state: AppState) => state.users;

export const selectUsersMap = (state: AppState) => state.users.users;

// User by ID
export const selectUserById = (userId: UserId) => (state: AppState): User | undefined => {
  return state.users.users.get(userId);
};

// Multiple users by IDs
export const selectUsersByIds = (userIds: UserId[]) => (state: AppState): User[] => {
  const result: User[] = [];
  
  for (const userId of userIds) {
    const user = state.users.users.get(userId);
    if (user) {
      result.push(user);
    }
  }
  
  return result;
};

// Current user (authenticated user)
export const selectCurrentUser = (state: AppState): User | undefined => {
  const userId = state.auth.userId;
  if (!userId) {
    return undefined;
  }
  return selectUserById(userId)(state);
};

// User display name
export const selectUserDisplayName = (userId: UserId) => (state: AppState): string => {
  const user = selectUserById(userId)(state);
  if (!user) {
    return 'Unknown';
  }
  
  if (user.firstName && user.lastName) {
    return `${user.firstName} ${user.lastName}`;
  }
  
  return user.firstName || user.username || 'Unknown';
};

// User initials (for avatars)
export const selectUserInitials = (userId: UserId) => (state: AppState): string => {
  const user = selectUserById(userId)(state);
  if (!user) {
    return '?';
  }
  
  const first = user.firstName?.charAt(0) || '';
  const last = user.lastName?.charAt(0) || '';
  
  if (first && last) {
    return `${first}${last}`.toUpperCase();
  } else if (first) {
    return first.toUpperCase();
  } else if (user.username) {
    return user.username.charAt(0).toUpperCase();
  }
  
  return '?';
};

// User status display
export const selectUserStatus = (userId: UserId) => (state: AppState): string => {
  const user = selectUserById(userId)(state);
  if (!user) {
    return 'offline';
  }
  
  // TODO: Add status field to User type
  return 'online'; // Placeholder
};

// Search users
export const selectUsersBySearchQuery = (query: string) => (state: AppState): User[] => {
  const normalizedQuery = query.toLowerCase().trim();
  if (!normalizedQuery) {
    return [];
  }
  
  const result: User[] = [];
  
  for (const user of state.users.users.values()) {
    const firstName = user.firstName?.toLowerCase() || '';
    const lastName = user.lastName?.toLowerCase() || '';
    const username = user.username?.toLowerCase() || '';
    const phoneNumber = user.phoneNumber?.toLowerCase() || '';
    
    if (firstName.includes(normalizedQuery) ||
        lastName.includes(normalizedQuery) ||
        username.includes(normalizedQuery) ||
        phoneNumber.includes(normalizedQuery)) {
      result.push(user);
    }
  }
  
  return result;
};

// Contacts (all users for now - TODO: add isContact field to User)
export const selectContacts = (state: AppState): User[] => {
  const result: User[] = [];

  for (const user of state.users.users.values()) {
    // TODO: Add isContact field to User type
    result.push(user);
  }

  return result;
};

// Online users
export const selectOnlineUsers = (state: AppState): User[] => {
  const result: User[] = [];
  
  for (const user of state.users.users.values()) {
    // TODO: Check status field
    // if (user.status === 'online') {
    //   result.push(user);
    // }
  }
  
  return result;
};

// DTO for user UI
export class UserForUI {
  id: UserId = 0;
  firstName: string = '';
  lastName: string = '';
  username: string = '';
  phoneNumber: string = '';
  photo: string = '';
  displayName: string = '';
  initials: string = '';
  status: string = '';
  hasPhoto: boolean = false;
  isCurrentUser: boolean = false;
}

// Combined selectors for UI
export const selectUserForUI = (userId: UserId) => (state: AppState): UserForUI | null => {
  const user = selectUserById(userId)(state);
  if (!user) {
    return null;
  }

  const result = new UserForUI();
  result.id = user.id;
  result.firstName = user.firstName;
  result.lastName = user.lastName;
  result.username = user.username;
  result.phoneNumber = user.phoneNumber;
  result.photo = user.photo;
  result.displayName = selectUserDisplayName(userId)(state);
  result.initials = selectUserInitials(userId)(state);
  result.status = selectUserStatus(userId)(state);
  result.hasPhoto = user.photo.length > 0;
  result.isCurrentUser = state.auth.userId === userId;
  return result;
};

// Selector for user list UI
export const selectUserListForUI = (userIds: UserId[]) => (state: AppState): UserForUI[] => {
  const result: UserForUI[] = [];

  for (const userId of userIds) {
    const userForUI = selectUserForUI(userId)(state);
    if (userForUI !== null) {
      result.push(userForUI);
    }
  }

  return result;
};

// Memoized selector for user (non-generic for ArkTS)
export function createMemoizedUserSelector(userId: UserId): (state: AppState) => UserForUI | null {
  let lastState: AppState | null = null;
  let lastResult: UserForUI | null = null;

  return (state: AppState): UserForUI | null => {
    if (lastState === state) {
      return lastResult;
    }

    lastState = state;
    lastResult = selectUserForUI(userId)(state);
    return lastResult;
  };
}