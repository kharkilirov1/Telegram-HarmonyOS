import { TDLibClient } from '../services/TDLibClient';
import { NotificationCenter, EventId } from './NotificationCenter';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'AuthController';
const DOMAIN = 0x0001;

export class AuthController {
  private static instance: AuthController | null = null;
  private currentState: string = '';
  private passwordHint: string = '';

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

    client.on('updateAuthorizationState', (update: object) => {
      const data = update as Record<string, object>;
      const authState = data['authorization_state'] as Record<string, object>;
      const stateType = (authState?.['@type'] as string) || '';

      hilog.info(DOMAIN, TAG, 'Auth state: %{public}s', stateType);
      this.currentState = stateType;

      // Handle states that need automatic responses
      if (stateType === 'authorizationStateWaitEncryptionKey') {
        client.send('checkDatabaseEncryptionKey', { encryption_key: '' });
        return;
      }

      // Extract password hint if waiting for password
      if (stateType === 'authorizationStateWaitPassword') {
        this.passwordHint = (authState['password_hint'] as string) || '';
      }

      NotificationCenter.getInstance().post(
        EventId.AUTH_STATE_CHANGED,
        { state: stateType } as Record<string, Object>
      );
    });
  }
}
