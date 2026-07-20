import { AppState, User, UserStatusType } from '../../../core/model/AppState';
import { UserDto } from '../../../core/model/dto/UserDto';

export class ComposeContactVO {
  userId: number = 0;
  name: string = '';
  username: string = '';
  phoneNumber: string = '';
  initials: string = '';
  status: UserStatusType = 'offline';
  avatarPath: string = '';
  isOnline: boolean = false;
  sectionTitle: string = '#';
  sortKey: string = '';
  searchKey: string = '';
}

export class ComposeSearchContactsVO {
  contacts: ComposeContactVO[] = [];
  global: ComposeContactVO[] = [];
}

export function firstComposeAlphabeticLetter(value: string): string {
  const upper: string = value.toUpperCase();
  for (let index: number = 0; index < upper.length; index += 1) {
    const character: string = upper.charAt(index);
    if ((character >= 'A' && character <= 'Z') ||
      (character >= 'А' && character <= 'Я') || character === 'Ё') {
      return character;
    }
  }
  return '';
}

function isCyrillicComposeLetter(value: string): boolean {
  return (value >= 'А' && value <= 'Я') || value === 'Ё';
}

export function isDeletedComposeContact(user: User): boolean {
  return (user.firstName + user.lastName).trim().length === 0 &&
    user.username.length === 0 && user.phoneNumber.length === 0;
}

export function composeContactDisplayName(user: User): string {
  const fullName: string = (user.firstName + ' ' + user.lastName).trim();
  if (fullName.length > 0) {
    return fullName;
  }
  if (user.username.length > 0) {
    return '@' + user.username;
  }
  return '+' + user.phoneNumber;
}

export function composeContactInitials(user: User): string {
  const first: string = firstComposeAlphabeticLetter(user.firstName);
  const last: string = firstComposeAlphabeticLetter(user.lastName);
  if (first.length > 0 && last.length > 0) {
    return first + last;
  }
  if (first.length > 0) {
    return first;
  }
  const usernameInitial: string = firstComposeAlphabeticLetter(user.username);
  if (usernameInitial.length > 0) {
    return usernameInitial;
  }
  return '?';
}

function composeContactSortRank(contact: ComposeContactVO, preferCyrillic: boolean): number {
  const first: string = firstComposeAlphabeticLetter(contact.name);
  if (first.length === 0) {
    return 2;
  }
  return isCyrillicComposeLetter(first) === preferCyrillic ? 0 : 1;
}

export function buildComposeContacts(state: AppState, locale: string = 'en'): ComposeContactVO[] {
  const contacts: ComposeContactVO[] = [];
  for (const user of state.users.users.values()) {
    if (!user.isContact || user.id === state.auth.userId || isDeletedComposeContact(user)) {
      continue;
    }

    const contact = new ComposeContactVO();
    contact.userId = user.id;
    contact.name = composeContactDisplayName(user);
    contact.username = user.username;
    contact.phoneNumber = user.phoneNumber;
    contact.initials = composeContactInitials(user);
    contact.status = user.status;
    contact.avatarPath = user.photoSmall;
    contact.isOnline = user.status === 'online';
    const firstLetter: string = firstComposeAlphabeticLetter(contact.name);
    contact.sectionTitle = firstLetter.length > 0 ? firstLetter : '#';
    contact.sortKey = firstLetter.toLowerCase() + ' ' + contact.name.toLowerCase();
    contact.searchKey = contact.name.toLowerCase() + ' ' +
      user.username.toLowerCase() + ' @' + user.username.toLowerCase() + ' ' +
      user.phoneNumber.toLowerCase() + ' +' + user.phoneNumber.toLowerCase();
    contacts.push(contact);
  }

  const preferCyrillic: boolean = locale.toLowerCase().startsWith('ru');
  contacts.sort((a: ComposeContactVO, b: ComposeContactVO): number => {
    const aRank: number = composeContactSortRank(a, preferCyrillic);
    const bRank: number = composeContactSortRank(b, preferCyrillic);
    if (aRank !== bRank) {
      return aRank - bRank;
    }
    try {
      return a.sortKey.localeCompare(b.sortKey, locale);
    } catch (_error) {
      return a.sortKey.localeCompare(b.sortKey);
    }
  });
  return contacts;
}

export function filterComposeContacts(contacts: ComposeContactVO[], query: string): ComposeContactVO[] {
  const normalizedQuery: string = query.trim().toLowerCase();
  if (normalizedQuery.length === 0) {
    return contacts;
  }
  return contacts.filter((contact: ComposeContactVO): boolean => contact.searchKey.includes(normalizedQuery));
}

function composeRemoteContactDisplayName(user: UserDto): string {
  const fullName: string = (user.firstName + ' ' + user.lastName).trim();
  if (fullName.length > 0) {
    return fullName;
  }
  if (user.username.length > 0) {
    return '@' + user.username;
  }
  return '+' + user.phoneNumber;
}

function composeRemoteContactInitials(user: UserDto): string {
  const first: string = firstComposeAlphabeticLetter(user.firstName);
  const last: string = firstComposeAlphabeticLetter(user.lastName);
  if (first.length > 0 && last.length > 0) {
    return first + last;
  }
  if (first.length > 0) {
    return first;
  }
  const usernameInitial: string = firstComposeAlphabeticLetter(user.username);
  return usernameInitial.length > 0 ? usernameInitial : '?';
}

export function composeContactFromUserDto(user: UserDto): ComposeContactVO | undefined {
  if (user.id <= 0 || ((user.firstName + user.lastName).trim().length === 0 &&
    user.username.length === 0 && user.phoneNumber.length === 0)) {
    return undefined;
  }

  const contact = new ComposeContactVO();
  contact.userId = user.id;
  contact.name = composeRemoteContactDisplayName(user);
  contact.username = user.username;
  contact.phoneNumber = user.phoneNumber;
  contact.initials = composeRemoteContactInitials(user);
  contact.status = user.status;
  contact.avatarPath = user.photo?.small ?? '';
  contact.isOnline = user.status === 'online';
  const firstLetter: string = firstComposeAlphabeticLetter(contact.name);
  contact.sectionTitle = firstLetter.length > 0 ? firstLetter : '#';
  contact.sortKey = firstLetter.toLowerCase() + ' ' + contact.name.toLowerCase();
  contact.searchKey = contact.name.toLowerCase() + ' ' +
    user.username.toLowerCase() + ' @' + user.username.toLowerCase() + ' ' +
    user.phoneNumber.toLowerCase() + ' +' + user.phoneNumber.toLowerCase();
  return contact;
}

function appendUniqueComposeUsers(
  target: ComposeContactVO[],
  users: UserDto[],
  seen: Set<number>,
  selfUserId: number
): void {
  for (const user of users) {
    if (user.id === selfUserId || seen.has(user.id)) {
      continue;
    }
    const contact: ComposeContactVO | undefined = composeContactFromUserDto(user);
    if (contact === undefined) {
      continue;
    }
    seen.add(contact.userId);
    target.push(contact);
  }
}

/**
 * Preserves Telegram iOS search precedence:
 * immediate local contacts -> TDLib cloud contacts -> known private chats -> global public users.
 */
export function mergeComposeSearchContacts(
  localContacts: ComposeContactVO[],
  cloudContacts: UserDto[],
  knownUsers: UserDto[],
  globalUsers: UserDto[],
  selfUserId: number
): ComposeSearchContactsVO {
  const result = new ComposeSearchContactsVO();
  const seen: Set<number> = new Set<number>();
  if (selfUserId > 0) {
    seen.add(selfUserId);
  }

  for (const contact of localContacts) {
    if (contact.userId <= 0 || seen.has(contact.userId)) {
      continue;
    }
    seen.add(contact.userId);
    result.contacts.push(contact);
  }
  appendUniqueComposeUsers(result.contacts, cloudContacts, seen, selfUserId);
  appendUniqueComposeUsers(result.global, knownUsers, seen, selfUserId);
  appendUniqueComposeUsers(result.global, globalUsers, seen, selfUserId);
  return result;
}

export function isCurrentComposeSearchRequest(
  currentGeneration: number,
  expectedGeneration: number,
  currentLifecycleToken: number,
  expectedLifecycleToken: number,
  currentQuery: string,
  expectedQuery: string,
  isClosing: boolean
): boolean {
  return currentGeneration === expectedGeneration &&
    currentLifecycleToken === expectedLifecycleToken &&
    currentQuery.trim() === expectedQuery &&
    !isClosing;
}
