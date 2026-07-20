import { describe, expect, it } from '@ohos/hypium';
import { AppState, User, createInitialAppState } from '../../../main/ets/core/model/AppState';
import { UserDto } from '../../../main/ets/core/model/dto/UserDto';
import {
  buildComposeContacts,
  composeContactInitials,
  filterComposeContacts,
  isCurrentComposeSearchRequest,
  mergeComposeSearchContacts
} from '../../../main/ets/ui/pages/compose/ComposeContactModel';

function createUser(
  id: number,
  firstName: string,
  lastName: string,
  username: string,
  phoneNumber: string,
  isContact: boolean = true
): User {
  const user = new User();
  user.id = id;
  user.firstName = firstName;
  user.lastName = lastName;
  user.username = username;
  user.phoneNumber = phoneNumber;
  user.isContact = isContact;
  return user;
}

function createUserDto(id: number, name: string, username: string = ''): UserDto {
  const user = new UserDto();
  user.id = id;
  user.firstName = name;
  user.username = username;
  return user;
}

export default function composeContactModelTest() {
  describe('ComposeContactModel', () => {
    it('keeps only real contacts and excludes the current user', 0, () => {
      const state: AppState = createInitialAppState();
      state.auth.userId = 1;
      state.users.users.set(1, createUser(1, 'Self', '', 'self', '100'));
      state.users.users.set(2, createUser(2, 'Alice', 'Stone', 'alice', '200'));
      state.users.users.set(3, createUser(3, 'Group', '', 'not_contact', '300', false));
      state.users.users.set(4, createUser(4, '', '', '', ''));

      const contacts = buildComposeContacts(state, 'en');

      expect(contacts.length).assertEqual(1);
      expect(contacts[0].userId).assertEqual(2);
      expect(contacts[0].name).assertEqual('Alice Stone');
      expect(contacts[0].initials).assertEqual('AS');
    });

    it('searches by display name username and phone', 0, () => {
      const state: AppState = createInitialAppState();
      state.users.users.set(2, createUser(2, 'Alice', 'Stone', 'quiet_fox', '77001234567'));
      const contacts = buildComposeContacts(state, 'en');

      expect(filterComposeContacts(contacts, 'stone').length).assertEqual(1);
      expect(filterComposeContacts(contacts, '@quiet').length).assertEqual(1);
      expect(filterComposeContacts(contacts, '1234567').length).assertEqual(1);
      expect(filterComposeContacts(contacts, 'missing').length).assertEqual(0);
    });

    it('prefers Cyrillic sections for Russian locale', 0, () => {
      const state: AppState = createInitialAppState();
      state.users.users.set(2, createUser(2, 'Alice', '', 'alice', '200'));
      state.users.users.set(3, createUser(3, 'Яна', '', 'yana', '300'));

      const contacts = buildComposeContacts(state, 'ru-RU');

      expect(contacts[0].name).assertEqual('Яна');
      expect(contacts[0].sectionTitle).assertEqual('Я');
    });

    it('builds initials from alphabetic characters only', 0, () => {
      const user = createUser(2, '🍒 Alice', '🤖 Stone', 'alice', '200');
      expect(composeContactInitials(user)).assertEqual('AS');
    });

    it('merges local cloud known and global users with stable iOS precedence', 0, () => {
      const state: AppState = createInitialAppState();
      state.auth.userId = 1;
      state.users.users.set(2, createUser(2, 'Local', '', 'local', '200'));
      const local = buildComposeContacts(state, 'en');

      const cloud: UserDto[] = [createUserDto(2, 'Duplicate Local'), createUserDto(3, 'Cloud')];
      const known: UserDto[] = [createUserDto(3, 'Duplicate Cloud'), createUserDto(4, 'Known', 'known')];
      const global: UserDto[] = [
        createUserDto(4, 'Duplicate Known'),
        createUserDto(5, 'Global', 'global_user'),
        createUserDto(1, 'Self')
      ];

      const result = mergeComposeSearchContacts(local, cloud, known, global, 1);

      expect(result.contacts.length).assertEqual(2);
      expect(result.contacts[0].userId).assertEqual(2);
      expect(result.contacts[1].userId).assertEqual(3);
      expect(result.global.length).assertEqual(2);
      expect(result.global[0].userId).assertEqual(4);
      expect(result.global[1].userId).assertEqual(5);
      expect(result.global[1].username).assertEqual('global_user');
    });

    it('drops unusable explicit remote users instead of fabricating rows', 0, () => {
      const deleted = new UserDto();
      deleted.id = 8;
      const result = mergeComposeSearchContacts([], [deleted], [], [], 1);

      expect(result.contacts.length).assertEqual(0);
      expect(result.global.length).assertEqual(0);
    });

    it('rejects stale q1 results after q2 and after q1 is entered again', 0, () => {
      const q1Generation: number = 1;
      const q2Generation: number = 2;
      const newQ1Generation: number = 3;

      expect(isCurrentComposeSearchRequest(1, q1Generation, 7, 7, 'q1', 'q1', false)).assertTrue();
      expect(isCurrentComposeSearchRequest(q2Generation, q1Generation, 7, 7, 'q2', 'q1', false)).assertFalse();
      expect(isCurrentComposeSearchRequest(newQ1Generation, q1Generation, 7, 7, 'q1', 'q1', false)).assertFalse();
      expect(isCurrentComposeSearchRequest(newQ1Generation, newQ1Generation, 8, 7, 'q1', 'q1', false))
        .assertFalse();
      expect(isCurrentComposeSearchRequest(newQ1Generation, newQ1Generation, 8, 8, 'q1', 'q1', true))
        .assertFalse();
    });
  });
}
