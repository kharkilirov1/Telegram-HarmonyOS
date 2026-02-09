import { describe, it, expect } from '@ohos/hypium';
import { User } from '../../../main/ets/models/User';

/**
 * Unit tests for ContactsController — contact management and User parsing.
 * Tests parseUser logic, contact list sorting, and User model.
 */

// Standalone copy of parseUser — the private method on ContactsController
function parseUser(raw: Record<string, Object>): User {
  const status = raw['status'] as Record<string, Object>;
  let isOnline = false;
  let lastSeenDate = 0;

  if (status) {
    const statusType = (status['@type'] as string) || '';
    if (statusType === 'userStatusOnline') {
      isOnline = true;
    } else if (statusType === 'userStatusOffline') {
      lastSeenDate = (status['was_online'] as number) || 0;
    }
  }

  const profilePhoto = raw['profile_photo'] as Record<string, Object>;
  let photoUrl: string | null = null;
  if (profilePhoto) {
    const small = profilePhoto['small'] as Record<string, Object>;
    if (small) {
      const localPath = small['local'] as Record<string, Object>;
      if (localPath && localPath['path']) {
        photoUrl = localPath['path'] as string;
      }
    }
  }

  return new User(
    (raw['id'] as number) || 0,
    (raw['first_name'] as string) || '',
    (raw['last_name'] as string) || '',
    (raw['username'] as string) ||
      ((raw['usernames'] as Record<string, Object>)?.['editable_username'] as string) || '',
    (raw['phone_number'] as string) || '',
    photoUrl,
    isOnline,
    lastSeenDate
  );
}

// Standalone copy of getContacts sort logic
function sortContacts(users: User[]): User[] {
  return users.sort((a: User, b: User) => {
    const nameA = `${a.firstName} ${a.lastName}`.toLowerCase();
    const nameB = `${b.firstName} ${b.lastName}`.toLowerCase();
    return nameA.localeCompare(nameB);
  });
}

export default function contactsControllerTest() {
  describe('ContactsController', () => {

    // -----------------------------------------------------------------------
    // parseUser
    // -----------------------------------------------------------------------
    describe('parseUser', () => {

      it('should parse basic user fields', 0, () => {
        const raw: Record<string, Object> = {};
        raw['id'] = 12345;
        raw['first_name'] = 'Alice';
        raw['last_name'] = 'Smith';
        raw['username'] = 'alice_s';
        raw['phone_number'] = '+1234567890';

        const user = parseUser(raw);
        expect(user.id).assertEqual(12345);
        expect(user.firstName).assertEqual('Alice');
        expect(user.lastName).assertEqual('Smith');
        expect(user.username).assertEqual('alice_s');
        expect(user.phoneNumber).assertEqual('+1234567890');
      });

      it('should detect online status', 0, () => {
        const status: Record<string, Object> = {};
        status['@type'] = 'userStatusOnline';
        const raw: Record<string, Object> = {};
        raw['id'] = 1;
        raw['status'] = status;

        const user = parseUser(raw);
        expect(user.isOnline).assertTrue();
        expect(user.lastSeenDate).assertEqual(0);
      });

      it('should detect offline status with was_online', 0, () => {
        const status: Record<string, Object> = {};
        status['@type'] = 'userStatusOffline';
        status['was_online'] = 1700000000;
        const raw: Record<string, Object> = {};
        raw['id'] = 2;
        raw['status'] = status;

        const user = parseUser(raw);
        expect(user.isOnline).assertFalse();
        expect(user.lastSeenDate).assertEqual(1700000000);
      });

      it('should handle missing status', 0, () => {
        const raw: Record<string, Object> = {};
        raw['id'] = 3;

        const user = parseUser(raw);
        expect(user.isOnline).assertFalse();
        expect(user.lastSeenDate).assertEqual(0);
      });

      it('should extract profile photo path', 0, () => {
        const localPath: Record<string, Object> = {};
        localPath['path'] = '/data/photos/avatar.jpg';
        const small: Record<string, Object> = {};
        small['local'] = localPath;
        const profilePhoto: Record<string, Object> = {};
        profilePhoto['small'] = small;
        const raw: Record<string, Object> = {};
        raw['id'] = 4;
        raw['profile_photo'] = profilePhoto;

        const user = parseUser(raw);
        expect(user.photoUrl).assertEqual('/data/photos/avatar.jpg');
      });

      it('should return null photo when no profile_photo', 0, () => {
        const raw: Record<string, Object> = {};
        raw['id'] = 5;

        const user = parseUser(raw);
        expect(user.photoUrl === null).assertTrue();
      });

      it('should use editable_username from usernames object', 0, () => {
        const usernames: Record<string, Object> = {};
        usernames['editable_username'] = 'bob_username';
        const raw: Record<string, Object> = {};
        raw['id'] = 6;
        raw['usernames'] = usernames;

        const user = parseUser(raw);
        expect(user.username).assertEqual('bob_username');
      });

      it('should default fields when data is missing', 0, () => {
        const raw: Record<string, Object> = {};

        const user = parseUser(raw);
        expect(user.id).assertEqual(0);
        expect(user.firstName).assertEqual('');
        expect(user.lastName).assertEqual('');
        expect(user.phoneNumber).assertEqual('');
      });
    });

    // -----------------------------------------------------------------------
    // Contact sorting
    // -----------------------------------------------------------------------
    describe('sortContacts', () => {

      it('should sort contacts alphabetically by full name', 0, () => {
        const users: User[] = [
          new User(1, 'Charlie', 'Brown'),
          new User(2, 'Alice', 'Wonderland'),
          new User(3, 'Bob', 'Builder'),
        ];

        const sorted = sortContacts(users);
        expect(sorted[0].firstName).assertEqual('Alice');
        expect(sorted[1].firstName).assertEqual('Bob');
        expect(sorted[2].firstName).assertEqual('Charlie');
      });

      it('should handle case-insensitive sorting', 0, () => {
        const users: User[] = [
          new User(1, 'bob', ''),
          new User(2, 'Alice', ''),
        ];

        const sorted = sortContacts(users);
        expect(sorted[0].firstName).assertEqual('Alice');
        expect(sorted[1].firstName).assertEqual('bob');
      });

      it('should handle empty array', 0, () => {
        const users: User[] = [];
        const sorted = sortContacts(users);
        expect(sorted.length).assertEqual(0);
      });

      it('should handle single contact', 0, () => {
        const users: User[] = [new User(1, 'Solo', 'Person')];
        const sorted = sortContacts(users);
        expect(sorted.length).assertEqual(1);
        expect(sorted[0].id).assertEqual(1);
      });
    });

    // -----------------------------------------------------------------------
    // User model
    // -----------------------------------------------------------------------
    describe('User model', () => {

      it('should construct with default values', 0, () => {
        const user = new User();
        expect(user.id).assertEqual(0);
        expect(user.firstName).assertEqual('');
        expect(user.lastName).assertEqual('');
        expect(user.isOnline).assertFalse();
      });

      it('should construct with all parameters', 0, () => {
        const user = new User(42, 'John', 'Doe', 'johnd', '+555', '/photo.jpg', true, 12345);
        expect(user.id).assertEqual(42);
        expect(user.firstName).assertEqual('John');
        expect(user.lastName).assertEqual('Doe');
        expect(user.username).assertEqual('johnd');
        expect(user.phoneNumber).assertEqual('+555');
        expect(user.photoUrl).assertEqual('/photo.jpg');
        expect(user.isOnline).assertTrue();
        expect(user.lastSeenDate).assertEqual(12345);
      });
    });
  });
}
