import { TDLibClient } from '../services/TDLibClient';
import { NotificationCenter, EventId } from './NotificationCenter';
import { User } from '../models/User';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'ContactsController';
const DOMAIN = 0x0001;

export class ContactsController {
  private static instance: ContactsController | null = null;

  private usersById: Map<number, User> = new Map();
  private userFullInfoById: Map<number, Record<string, unknown>> = new Map();
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

  getUserFullInfo(userId: number): Record<string, unknown> | undefined {
    return this.userFullInfoById.get(userId);
  }

  getContacts(): User[] {
    return (this.contactIds
      .map((id: number) => this.usersById.get(id))
      .filter((u: User | undefined): boolean => u !== undefined) as User[])
      .sort((a: User, b: User) => {
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
        .send('getContacts') as Record<string, unknown>;
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
    const searchParams: Record<string, unknown> = {};
    searchParams['query'] = query;
    searchParams['limit'] = limit;
    const result = await TDLibClient.getInstance()
      .send('searchContacts', searchParams) as Record<string, unknown>;
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
    const contact: Record<string, unknown> = {};
    contact['@type'] = 'contact';
    contact['phone_number'] = phoneNumber;
    contact['first_name'] = firstName;
    contact['last_name'] = lastName;
    contact['user_id'] = userId;
    const addParams: Record<string, unknown> = {};
    addParams['contact'] = contact;
    await TDLibClient.getInstance().send('addContact', addParams);
  }

  async deleteContact(userId: number): Promise<void> {
    const removeIds: number[] = [userId];
    const removeParams: Record<string, unknown> = {};
    removeParams['user_ids'] = removeIds;
    await TDLibClient.getInstance().send('removeContacts', removeParams);

    const idx = this.contactIds.indexOf(userId);
    if (idx >= 0) {
      this.contactIds.splice(idx, 1);
      NotificationCenter.getInstance().post(EventId.CONTACTS_UPDATED);
    }
  }

  // --- Private ---

  private async loadUser(userId: number): Promise<User | undefined> {
    try {
      const userParams: Record<string, unknown> = {};
      userParams['user_id'] = userId;
      const result = await TDLibClient.getInstance()
        .send('getUser', userParams) as Record<string, unknown>;
      const user = this.parseUser(result);
      this.usersById.set(user.id, user);
      return user;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to load user %{public}d', userId);
      return undefined;
    }
  }

  private parseUser(raw: Record<string, unknown>): User {
    const status = raw['status'] as Record<string, unknown>;
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

    const profilePhoto = raw['profile_photo'] as Record<string, unknown>;
    let photoUrl: string | null = null;
    if (profilePhoto) {
      const small = profilePhoto['small'] as Record<string, unknown>;
      if (small) {
        const localPath = small['local'] as Record<string, unknown>;
        if (localPath && localPath['path']) {
          photoUrl = localPath['path'] as string;
        }
      }
    }

    return new User(
      (raw['id'] as number) || 0,
      (raw['first_name'] as string) || '',
      (raw['last_name'] as string) || '',
      (raw['username'] as string) || ((raw['usernames'] as Record<string, unknown>)?.['editable_username'] as string) || '',
      (raw['phone_number'] as string) || '',
      photoUrl,
      isOnline,
      lastSeenDate
    );
  }

  private subscribeToUpdates(): void {
    const client = TDLibClient.getInstance();

    client.on('updateUser', (update: Record<string, unknown>) => {
      const rawUser = update['user'] as Record<string, unknown>;
      if (!rawUser) return;

      const user = this.parseUser(rawUser);
      this.usersById.set(user.id, user);

      const userInfoArgs: Record<string, unknown> = {};
      userInfoArgs['userId'] = user.id;
      NotificationCenter.getInstance().post(
        EventId.USER_INFO_UPDATED,
        userInfoArgs
      );
    });

    client.on('updateUserStatus', (update: Record<string, unknown>) => {
      const userId = update['user_id'] as number;
      const status = update['status'] as Record<string, unknown>;
      const user = this.usersById.get(userId);

      if (user && status) {
        const statusType = (status['@type'] as string) || '';
        user.isOnline = statusType === 'userStatusOnline';
        if (statusType === 'userStatusOffline') {
          user.lastSeenDate = (status['was_online'] as number) || 0;
        }

        const statusArgs: Record<string, unknown> = {};
        statusArgs['userId'] = userId;
        NotificationCenter.getInstance().post(
          EventId.USER_STATUS_UPDATED,
          statusArgs
        );
      }
    });

    client.on('updateUserFullInfo', (update: Record<string, unknown>) => {
      const userId = (update['user_id'] as number) || 0;
      const fullInfo = update['user_full_info'] as Record<string, unknown>;
      if (userId === 0 || !fullInfo) return;

      this.userFullInfoById.set(userId, fullInfo);

      // Keep lightweight user cache warm for profile pages.
      if (!this.usersById.has(userId)) {
        void this.loadUser(userId);
      }

      const userInfoArgs: Record<string, unknown> = {};
      userInfoArgs['userId'] = userId;
      userInfoArgs['fullInfoUpdated'] = true;
      NotificationCenter.getInstance().post(
        EventId.USER_INFO_UPDATED,
        userInfoArgs
      );
    });
  }
}
