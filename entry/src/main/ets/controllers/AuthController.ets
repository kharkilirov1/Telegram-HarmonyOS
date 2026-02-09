import { TDLibClient } from '../services/TDLibClient';
import { SecurityService } from '../services/SecurityService';
import { NotificationCenter, EventId } from './NotificationCenter';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'AuthController';
const DOMAIN = 0x0001;

export class AuthController {
  private static instance: AuthController | null = null;
  private currentState: string = '';
  private passwordHint: string = '';
  private myUserId: number = 0;

  private constructor() {
    this.subscribeToUpdates();
  }

  static getInstance(): AuthController {
    if (!AuthController.instance) {
      AuthController.instance = new AuthController();
    }
    return AuthController.instance;
  }

  getCurrentState(): string {
    return this.currentState;
  }

  getPasswordHint(): string {
    return this.passwordHint;
  }

  isAuthorized(): boolean {
    return this.currentState === 'authorizationStateReady';
  }

  getMyUserId(): number {
    return this.myUserId;
  }

  async fetchMyUserId(): Promise<number> {
    if (this.myUserId > 0) return this.myUserId;
    try {
      const result = await TDLibClient.getInstance().send('getMe') as Record<string, Object>;
      this.myUserId = (result['id'] as number) || 0;
    } catch (_e) {
      hilog.warn(DOMAIN, TAG, 'Failed to fetch my user ID');
    }
    return this.myUserId;
  }

  async submitPhoneNumber(phoneNumber: string): Promise<void> {
    await TDLibClient.getInstance().setPhoneNumber(phoneNumber);
  }

  async submitCode(code: string): Promise<void> {
    await TDLibClient.getInstance().checkAuthCode(code);
  }

  async submitPassword(password: string): Promise<void> {
    await TDLibClient.getInstance().checkAuthPassword(password);
  }

  async logout(): Promise<void> {
    await TDLibClient.getInstance().send('logOut');
  }

  private subscribeToUpdates(): void {
    const client = TDLibClient.getInstance();

    client.on('updateAuthorizationState', (update: Record<string, Object>) => {
      const authState = update['authorization_state'] as Record<string, Object>;
      const stateType = (authState['@type'] as string) || '';

      hilog.info(DOMAIN, TAG, 'Auth state: %{public}s', stateType);
      this.currentState = stateType;

      // Handle states that need automatic responses
      if (stateType === 'authorizationStateWaitEncryptionKey') {
        const dbKey = SecurityService.getInstance().getDatabaseEncryptionKey();
        const params: Record<string, Object> = {};
        params['encryption_key'] = dbKey;
        client.send('checkDatabaseEncryptionKey', params);
        return;
      }

      // Extract password hint if waiting for password
      if (stateType === 'authorizationStateWaitPassword') {
        this.passwordHint = (authState['password_hint'] as string) || '';
      }

      // Fetch user ID once authorized
      if (stateType === 'authorizationStateReady') {
        this.fetchMyUserId();
      }

      const eventArgs: Record<string, Object> = {};
      eventArgs['state'] = stateType;
      NotificationCenter.getInstance().post(
        EventId.AUTH_STATE_CHANGED,
        eventArgs
      );
    });
  }
}
