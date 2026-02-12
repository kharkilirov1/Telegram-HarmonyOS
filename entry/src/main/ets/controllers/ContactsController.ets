import { TDLibClient } from '../services/TDLibClient';
import { NotificationCenter, EventId } from './NotificationCenter';
import { FileController } from './FileController';
import { User } from '../models/User';
import { TdObject, TdUserFullInfo, safeNumber, safeString, safeBool, asRecord, safeNumberArray } from '../models/TdTypes';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'ContactsController';
const DOMAIN = 0x0001;

export class ContactsController {
  private static instance: ContactsController | null = null;

  private usersById: Map<number, User> = new Map();
  private userFullInfoById: Map<number, TdObject> = new Map();
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

  getUserFullInfo(userId: number): TdObject | undefined {
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
        .send('getContacts');
      const userIds = safeNumberArray(result['user_ids']);

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
    const searchParams: TdObject = {};
    searchParams['query'] = query;
    searchParams['limit'] = limit;
    const result = await TDLibClient.getInstance()
      .send('searchContacts', searchParams);
    const userIds = safeNumberArray(result['user_ids']);
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
    const contact: TdObject = {};
    contact['@type'] = 'contact';
    contact['phone_number'] = phoneNumber;
    contact['first_name'] = firstName;
    contact['last_name'] = lastName;
    contact['user_id'] = userId;
    const addParams: TdObject = {};
    addParams['contact'] = contact;
    await TDLibClient.getInstance().send('addContact', addParams);
  }

  async deleteContact(userId: number): Promise<void> {
    const removeIds: number[] = [userId];
    const removeParams: TdObject = {};
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
      const userParams: TdObject = {};
      userParams['user_id'] = userId;
      const result = await TDLibClient.getInstance()
        .send('getUser', userParams);
      const user = this.parseUser(result);
      this.usersById.set(user.id, user);
      return user;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to load user %{public}d', userId);
      return undefined;
    }
  }

  private parseUser(raw: TdObject): User {
    let isOnline = false;
    let lastSeenDate = 0;

    const statusObj = raw['status'];
    if (statusObj) {
      const status = asRecord(statusObj);
      const statusType = safeString(status['@type']);
      if (statusType === 'userStatusOnline') {
        isOnline = true;
      } else if (statusType === 'userStatusOffline') {
        lastSeenDate = safeNumber(status['was_online']);
      }
    }

    const profilePhotoObj = raw['profile_photo'];
    let photoUrl: string | null = null;
    let photoFileId = 0;
    if (profilePhotoObj) {
      const profilePhoto = asRecord(profilePhotoObj);
      const smallObj = profilePhoto['small'];
      if (smallObj) {
        const small = asRecord(smallObj);
        photoFileId = safeNumber(small['id']);
        const localObj = small['local'];
        if (localObj) {
          const localFile = asRecord(localObj);
          if (safeBool(localFile['is_downloading_completed'])) {
            const pathVal = safeString(localFile['path']);
            if (pathVal) {
              photoUrl = pathVal;
            }
          }
        }
      }
    }

    const username = safeString(raw['username']) || safeString(asRecord(raw['usernames'])['editable_username']);
    const userId = safeNumber(raw['id']);

    const user = new User(
      userId,
      safeString(raw['first_name']),
      safeString(raw['last_name']),
      username,
      safeString(raw['phone_number']),
      photoUrl,
      photoFileId,
      isOnline,
      lastSeenDate
    );

    // Trigger download if photo not yet downloaded
    if (photoFileId > 0 && !photoUrl) {
      FileController.getInstance().requestFile(photoFileId, 5, (path: string) => {
        if (path.length > 0) {
          user.photoUrl = path;
          const eventArgs: Record<string, Object> = {};
          eventArgs['userId'] = userId;
          NotificationCenter.getInstance().post(EventId.USER_INFO_UPDATED, eventArgs);
        }
      });
    }

    return user;
  }

  private subscribeToUpdates(): void {
    const client = TDLibClient.getInstance();

    client.on('updateUser', (update: Record<string, Object>) => {
      const rawUser = update['user'] as Record<string, Object>;
      if (!rawUser) return;

      const user = this.parseUser(rawUser);
      this.usersById.set(user.id, user);

      const userInfoArgs: Record<string, Object> = {};
      userInfoArgs['userId'] = user.id;
      NotificationCenter.getInstance().post(
        EventId.USER_INFO_UPDATED,
        userInfoArgs
      );
    });

    client.on('updateUserStatus', (update: Record<string, Object>) => {
      const userId = update['user_id'] as number;
      const status = update['status'] as Record<string, Object>;
      const user = this.usersById.get(userId);

      if (user && status) {
        const statusType = (status['@type'] as string) || '';
        user.isOnline = statusType === 'userStatusOnline';
        if (statusType === 'userStatusOffline') {
          user.lastSeenDate = (status['was_online'] as number) || 0;
        }

        const statusArgs: Record<string, Object> = {};
        statusArgs['userId'] = userId;
        NotificationCenter.getInstance().post(
          EventId.USER_STATUS_UPDATED,
          statusArgs
        );
      }
    });

    client.on('updateUserFullInfo', (update: Record<string, Object>) => {
      const userId = (update['user_id'] as number) || 0;
      const fullInfo = update['user_full_info'] as Record<string, Object>;
      if (userId === 0 || !fullInfo) return;

      this.userFullInfoById.set(userId, fullInfo);

      // Keep lightweight user cache warm for profile pages.
      if (!this.usersById.has(userId)) {
        void this.loadUser(userId);
      }

      const userInfoArgs: Record<string, Object> = {};
      userInfoArgs['userId'] = userId;
      userInfoArgs['fullInfoUpdated'] = true;
      NotificationCenter.getInstance().post(
        EventId.USER_INFO_UPDATED,
        userInfoArgs
      );
    });
  }
}
