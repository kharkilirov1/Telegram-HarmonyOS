// User DTO - domain data transfer object for users
// ArkTS compliant - uses TdObject wrapper class

import { UserId } from '../EntityId';
import { TdObject, tdGetString, tdGetNumber, tdGetBoolean, tdGetObject, tdHasKeys } from '../../utils/tdAccessors';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DTO_DOMAIN = 0x0003;
const DTO_TAG = 'UserDto';

// Type for user status
export type UserStatus = 'online' | 'offline' | 'recently' | 'lastWeek' | 'lastMonth' | 'longTimeAgo';

// Class for user photo
export class UserPhoto {
  small: string = '';
  big: string = '';
  smallFileId: number = 0;
  bigFileId: number = 0;
}

export class UserDto {
  id: UserId = 0;
  firstName: string = '';
  lastName: string = '';
  username: string = '';
  accentColorId: number = -1;
  phoneNumber: string = '';
  photo?: UserPhoto;
  isContact: boolean = false;
  isVerified: boolean = false;
  isScam: boolean = false;
  isFake: boolean = false;
  isPremium: boolean = false;
  isBot: boolean = false;
  status: UserStatus = 'offline';
}

// Parse TDLib user status @type string to our UserStatus
export function parseUserStatus(tdStatus: TdObject): UserStatus {
  const statusType = tdGetString(tdStatus, '@type');
  switch (statusType) {
    case 'userStatusOnline':
      return 'online';
    case 'userStatusOffline':
      return 'offline';
    case 'userStatusRecently':
      return 'recently';
    case 'userStatusLastWeek':
      return 'lastWeek';
    case 'userStatusLastMonth':
      return 'lastMonth';
    case 'userStatusEmpty':
    default:
      return 'longTimeAgo';
  }
}

// Extract user photo from TDLib profile_photo object
function extractUserPhoto(profilePhoto: TdObject): UserPhoto | undefined {
  if (!tdHasKeys(profilePhoto)) {
    return undefined;
  }
  const smallObj = tdGetObject(profilePhoto, 'small');
  const bigObj = tdGetObject(profilePhoto, 'big');
  const smallLocal = tdGetObject(smallObj, 'local');
  const bigLocal = tdGetObject(bigObj, 'local');

  const photo = new UserPhoto();
  photo.small = tdGetString(smallLocal, 'path');
  photo.big = tdGetString(bigLocal, 'path');
  // Use getTopLevelNumber to avoid nested remote.id (string) shadowing the numeric file id
  photo.smallFileId = smallObj.getTopLevelNumber('id');
  photo.bigFileId = bigObj.getTopLevelNumber('id');
  hilog.info(DTO_DOMAIN, DTO_TAG, 'extractUserPhoto smallFileId=%{public}d path=%{public}s',
    photo.smallFileId, photo.small.length > 0 ? photo.small : '(empty)');
  return photo;
}

function extractOptionalAccentColorId(tdObject: TdObject): number {
  const rawValue = tdObject.get('accent_color_id');
  if (typeof rawValue === 'number') {
    return rawValue;
  }
  if (typeof rawValue === 'string' && rawValue.length > 0) {
    const parsed = parseInt(rawValue, 10);
    return Number.isNaN(parsed) ? -1 : parsed;
  }
  return -1;
}

// Helper to create DTO from raw TDLib user object
export function createUserDtoFromTd(tdUser: TdObject): UserDto {
  const tdStatus = tdGetObject(tdUser, 'status');
  const status = parseUserStatus(tdStatus);

  const userDto = new UserDto();
  userDto.id = tdUser.getTopLevelNumber('id');
  userDto.firstName = tdGetString(tdUser, 'first_name');
  userDto.lastName = tdGetString(tdUser, 'last_name');
  userDto.accentColorId = extractOptionalAccentColorId(tdUser);
  userDto.phoneNumber = tdGetString(tdUser, 'phone_number');
  userDto.isContact = tdGetBoolean(tdUser, 'is_contact');
  userDto.isVerified = tdGetBoolean(tdUser, 'is_verified');
  userDto.isScam = tdGetBoolean(tdUser, 'is_scam');
  userDto.isFake = tdGetBoolean(tdUser, 'is_fake');
  userDto.isPremium = tdGetBoolean(tdUser, 'is_premium');
  userDto.isBot = tdGetString(tdGetObject(tdUser, 'type'), '@type') === 'userTypeBot';
  userDto.status = status;

  // Username: TDLib can have either 'username' or 'usernames.editable_username'
  const directUsername = tdGetString(tdUser, 'username');
  if (directUsername) {
    userDto.username = directUsername;
  } else {
    const usernames = tdGetObject(tdUser, 'usernames');
    if (tdHasKeys(usernames)) {
      userDto.username = tdGetString(usernames, 'editable_username');
    }
  }

  // Photo
  const profilePhoto = tdGetObject(tdUser, 'profile_photo');
  userDto.photo = extractUserPhoto(profilePhoto);

  return userDto;
}

// Helper for partial updates (userUpdated event)
export class UserUpdateDto {
  firstName?: string;
  lastName?: string;
  username?: string;
  accentColorId?: number;
  phoneNumber?: string;
  photo?: UserPhoto;
  status?: UserStatus;
  isContact?: boolean;
  isVerified?: boolean;
  isScam?: boolean;
  isFake?: boolean;
  isPremium?: boolean;
  isBot?: boolean;
}

export function applyUserUpdate(user: UserDto, update: UserUpdateDto): UserDto {
  const updatedUser = new UserDto();

  updatedUser.id = user.id;
  updatedUser.firstName = user.firstName;
  updatedUser.lastName = user.lastName;
  updatedUser.username = user.username;
  updatedUser.accentColorId = user.accentColorId;
  updatedUser.phoneNumber = user.phoneNumber;
  updatedUser.photo = user.photo;
  updatedUser.isContact = user.isContact;
  updatedUser.isVerified = user.isVerified;
  updatedUser.isScam = user.isScam;
  updatedUser.isFake = user.isFake;
  updatedUser.isPremium = user.isPremium;
  updatedUser.isBot = user.isBot;
  updatedUser.status = user.status;

  if (update.firstName !== undefined) { updatedUser.firstName = update.firstName; }
  if (update.lastName !== undefined) { updatedUser.lastName = update.lastName; }
  if (update.username !== undefined) { updatedUser.username = update.username; }
  if (update.accentColorId !== undefined) { updatedUser.accentColorId = update.accentColorId; }
  if (update.phoneNumber !== undefined) { updatedUser.phoneNumber = update.phoneNumber; }
  if (update.photo !== undefined) { updatedUser.photo = update.photo; }
  if (update.status !== undefined) { updatedUser.status = update.status; }
  if (update.isContact !== undefined) { updatedUser.isContact = update.isContact; }
  if (update.isVerified !== undefined) { updatedUser.isVerified = update.isVerified; }
  if (update.isScam !== undefined) { updatedUser.isScam = update.isScam; }
  if (update.isFake !== undefined) { updatedUser.isFake = update.isFake; }
  if (update.isPremium !== undefined) { updatedUser.isPremium = update.isPremium; }
  if (update.isBot !== undefined) { updatedUser.isBot = update.isBot; }

  return updatedUser;
}
