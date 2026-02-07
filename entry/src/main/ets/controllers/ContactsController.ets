import { TDLibClient } from '../services/TDLibClient';
import { NotificationCenter, EventId } from './NotificationCenter';
import { User } from '../models/User';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'ContactsController';
const DOMAIN = 0x0001;

export class ContactsController {
  private static instance: ContactsController | null = null;

  private usersById: Map<number, User> = new Map();
  private contactIds: number[] = [];
  private contactsLoaded: boolean = false;

  private constructor() {
    this.subscribeToUpdates();
  }

  static getInstance(): ContactsController {
    if (!ContactsController.instance) {
      ContactsController.instance = new ContactsController();
    }
    return ContactsController.instance;
  }

  // --- Public read API ---

  getUser(userId: number): User | undefined {
    return this.usersById.get(userId);
  }

  getContacts(): User[] {
    return this.contactIds
      .map(id => this.usersById.get(id))
      .filter((u): u is User => u !== undefined)
      .sort((a, b) => {
        const nameA = `${a.firstName} ${a.lastName}`.toLowerCase();
        const nameB = `${b.firstName} ${b.lastName}`.toLowerCase();
        return nameA.localeCompare(nameB);
      });
  }

  isContactsLoaded(): boolean {
    return this.contactsLoaded;
  }

  // --- Public action API ---

  async loadContacts(): Promise<void> {
    if (this.contactsLoaded) return;

    try {
      const result = await TDLibClient.getInstance()
        .send('getContacts') as Record<string, object>;
      const userIds = result['user_ids'] as number[];

      if (userIds) {
        this.contactIds = userIds;

        // Load each user's info
        for (const userId of userIds) {
          if (!this.usersById.has(userId)) {
            await this.loadUser(userId);
          }
        }

        this.contactsLoaded = true;
        NotificationCenter.getInstance().post(EventId.CONTACTS_UPDATED);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to load contacts');
    }
  }

  async searchContacts(query: string, limit: number = 50): Promise<User[]> {
    const result = await TDLibClient.getInstance()
      .send('searchContacts', { query: query, limit: limit }) as Record<string, object>;
    const userIds = result['user_ids'] as number[];
    const users: User[] = [];

    if (userIds) {
      for (const userId of userIds) {
        let user = this.usersById.get(userId);
        if (!user) {
          user = await this.loadUser(userId);
        }
        if (user) {
          users.push(user);
        }
      }
    }

    return users;
  }

  async addContact(userId: number, firstName: string, lastName: string,
    phoneNumber: string): Promise<void> {
    await TDLibClient.getInstance().send('addContact', {
      contact: {
        '@type': 'contact',
        phone_number: phoneNumber,
        first_name: firstName,
        last_name: lastName,
        user_id: userId
      }
    });
  }

  async deleteContact(userId: number): Promise<void> {
    await TDLibClient.getInstance().send('removeContacts', {
      user_ids: [userId]
    });

    const idx = this.contactIds.indexOf(userId);
    if (idx >= 0) {
      this.contactIds.splice(idx, 1);
      NotificationCenter.getInstance().post(EventId.CONTACTS_UPDATED);
    }
  }

  // --- Private ---

  private async loadUser(userId: number): Promise<User | undefined> {
    try {
      const result = await TDLibClient.getInstance()
        .send('getUser', { user_id: userId }) as Record<string, object>;
      const user = this.parseUser(result);
      this.usersById.set(user.id, user);
      return user;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to load user %{public}d', userId);
      return undefined;
    }
  }

  private parseUser(raw: Record<string, object>): User {
    const status = raw['status'] as Record<string, object>;
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

    const profilePhoto = raw['profile_photo'] as Record<string, object>;
    let photoUrl: string | null = null;
    if (profilePhoto) {
      const small = profilePhoto['small'] as Record<string, object>;
      if (small) {
        const localPath = small['local'] as Record<string, string>;
        if (localPath && localPath['path']) {
          photoUrl = localPath['path'];
        }
      }
    }

    return new User(
      (raw['id'] as number) || 0,
      (raw['first_name'] as string) || '',
      (raw['last_name'] as string) || '',
      (raw['username'] as string) || (raw['usernames'] as Record<string, string>)?.['editable_username'] || '',
      (raw['phone_number'] as string) || '',
      photoUrl,
      isOnline,
      lastSeenDate
    );
  }

  private subscribeToUpdates(): void {
    const client = TDLibClient.getInstance();

    client.on('updateUser', (update: object) => {
      const data = update as Record<string, object>;
      const rawUser = data['user'] as Record<string, object>;
      if (!rawUser) return;

      const user = this.parseUser(rawUser);
      this.usersById.set(user.id, user);

      NotificationCenter.getInstance().post(
        EventId.USER_INFO_UPDATED,
        { userId: user.id } as Record<string, Object>
      );
    });

    client.on('updateUserStatus', (update: object) => {
      const data = update as Record<string, object>;
      const userId = data['user_id'] as number;
      const status = data['status'] as Record<string, object>;
      const user = this.usersById.get(userId);

      if (user && status) {
        const statusType = (status['@type'] as string) || '';
        user.isOnline = statusType === 'userStatusOnline';
        if (statusType === 'userStatusOffline') {
          user.lastSeenDate = (status['was_online'] as number) || 0;
        }

        NotificationCenter.getInstance().post(
          EventId.USER_STATUS_UPDATED,
          { userId: userId } as Record<string, Object>
        );
      }
    });
  }
}
