import { TDLibClient } from '../services/TDLibClient';
import { SecurityService } from '../services/SecurityService';
import { NotificationCenter, EventId } from './NotificationCenter';
import { TdObject, safeNumber, safeString, safeBool, asRecord } from '../models/TdTypes';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'AuthController';
const DOMAIN = 0x0001;

export class AuthController {
  private static instance: AuthController | null = null;
  private currentState: string = '';
  private connectionState: string = '';
  private passwordHint: string = '';
  private myUserId: number = 0;

  // Registration fields (new account flow)
  private registrationTermsOfService: string = '';
  private registrationRequired: boolean = false;

  // QR / other-device confirmation
  private otherDeviceLink: string = '';

  // Email auth fields
  private emailAddressPattern: string = '';
  private emailCodeLength: number = 0;

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

  getConnectionState(): string {
    return this.connectionState;
  }

  isConnected(): boolean {
    return this.connectionState === 'connectionStateReady';
  }

  getOtherDeviceLink(): string {
    return this.otherDeviceLink;
  }

  getRegistrationTermsOfService(): string {
    return this.registrationTermsOfService;
  }

  isRegistrationRequired(): boolean {
    return this.registrationRequired;
  }

  getEmailAddressPattern(): string {
    return this.emailAddressPattern;
  }

  async fetchMyUserId(): Promise<number> {
    if (this.myUserId > 0) return this.myUserId;
    try {
      const result = await TDLibClient.getInstance().send('getMe');
      this.myUserId = safeNumber(result['id']);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'Failed to fetch my user ID: %{public}s', String(e));
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

  /**
   * Submit registration info (first name, last name) for new accounts.
   * Called when TDLib is in authorizationStateWaitRegistration.
   */
  async submitRegistration(firstName: string, lastName: string): Promise<void> {
    const params: TdObject = {};
    params['first_name'] = firstName;
    params['last_name'] = lastName;
    await TDLibClient.getInstance().send('registerUser', params);
  }

  /**
   * Submit email address for email-based auth.
   * Called when TDLib is in authorizationStateWaitEmailAddress.
   */
  async submitEmailAddress(emailAddress: string): Promise<void> {
    const params: TdObject = {};
    params['email_address'] = emailAddress;
    await TDLibClient.getInstance().send('setAuthenticationEmailAddress', params);
  }

  /**
   * Submit email verification code.
   * Called when TDLib is in authorizationStateWaitEmailCode.
   */
  async submitEmailCode(code: string): Promise<void> {
    const emailAuth: TdObject = {};
    emailAuth['@type'] = 'emailAddressAuthenticationCode';
    emailAuth['code'] = code;
    const params: TdObject = {};
    params['code'] = emailAuth;
    await TDLibClient.getInstance().send('checkAuthenticationEmailCode', params);
  }

  async resendCode(): Promise<void> {
    await TDLibClient.getInstance().send('resendAuthenticationCode');
  }

  async logout(): Promise<void> {
    await TDLibClient.getInstance().send('logOut');
  }

  private resetAuthState(): void {
    this.passwordHint = '';
    this.registrationTermsOfService = '';
    this.registrationRequired = false;
    this.otherDeviceLink = '';
    this.emailAddressPattern = '';
    this.emailCodeLength = 0;
    this.myUserId = 0;
  }

  private subscribeToUpdates(): void {
    const client = TDLibClient.getInstance();

    client.on('updateAuthorizationState', (update: TdObject) => {
      const authState = asRecord(update['authorization_state']);
      const stateType = safeString(authState['@type']);

      hilog.info(DOMAIN, TAG, 'Auth state: %{public}s', stateType);
      this.currentState = stateType;

      // Handle states that need automatic responses
      if (stateType === 'authorizationStateWaitEncryptionKey') {
        const dbKey = SecurityService.getInstance().getDatabaseEncryptionKey();
        const params: TdObject = {};
        params['encryption_key'] = dbKey;
        client.send('checkDatabaseEncryptionKey', params);
        return;
      }

      // Extract password hint if waiting for password
      if (stateType === 'authorizationStateWaitPassword') {
        this.passwordHint = safeString(authState['password_hint']);
      }

      // New account registration — extract terms of service
      if (stateType === 'authorizationStateWaitRegistration') {
        this.registrationRequired = true;
        const tos = asRecord(authState['terms_of_service']);
        const tosText = asRecord(tos['text']);
        this.registrationTermsOfService = safeString(tosText['text']);
      }

      // QR code / other device login
      if (stateType === 'authorizationStateWaitOtherDeviceConfirmation') {
        this.otherDeviceLink = safeString(authState['link']);
      }

      // Email address required
      if (stateType === 'authorizationStateWaitEmailAddress') {
        this.emailAddressPattern = safeString(authState['email_address_pattern']);
      }

      // Email code required
      if (stateType === 'authorizationStateWaitEmailCode') {
        const codeInfo = asRecord(authState['code_info']);
        this.emailCodeLength = safeNumber(codeInfo['length']);
        this.emailAddressPattern = safeString(authState['email_address_pattern']);
      }

      // Fetch user ID once authorized
      if (stateType === 'authorizationStateReady') {
        this.fetchMyUserId();
      }

      // Clean up on logout/close
      if (stateType === 'authorizationStateLoggingOut' ||
          stateType === 'authorizationStateClosing') {
        hilog.info(DOMAIN, TAG, 'Auth closing/logging out');
      }

      if (stateType === 'authorizationStateClosed') {
        hilog.info(DOMAIN, TAG, 'Auth session closed, resetting state');
        this.resetAuthState();
      }

      const eventArgs: TdObject = {};
      eventArgs['state'] = stateType;
      NotificationCenter.getInstance().post(
        EventId.AUTH_STATE_CHANGED,
        eventArgs
      );
    });

    client.on('updateConnectionState', (update: TdObject) => {
      const state = asRecord(update['state']);
      if (!state) return;
      const stateType = safeString(state['@type']);
      hilog.info(DOMAIN, TAG, 'Connection state: %{public}s', stateType);
      this.connectionState = stateType;

      const connArgs: TdObject = {};
      connArgs['state'] = stateType;
      NotificationCenter.getInstance().post(
        EventId.CONNECTION_STATE_CHANGED,
        connArgs
      );
    });
  }
}
