// LoginRouter — lifecycle auth truth with AppStorage-backed form metadata
//
// AppStoreBridge синхронизирует AppStore → AppStorage.
// V2: @Local поля + store.subscribe() → syncFromAppStorage() вместо @StorageLink.

import { PhoneInputPage } from './PhoneInputPage';
import { CodeInputPage } from './CodeInputPage';
import { PasswordInputPage } from './PasswordInputPage';
import { QrLoginPage } from './QrLoginPage';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { CodeType, LoginController } from '../../controllers/LoginController';
import { AppCoreRuntime, getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { hilog } from '@kit.PerformanceAnalysisKit';

// ─── Auth Context ───
export class AuthContext {
  phoneNumber: string = '';
  codeType: CodeType = 'sms';
  codeLength: number = 5;
  nextCodeType: CodeType | null = 'call';
  codeTimeout: number = 60;
  passwordHint: string = '';
  suggestReset: boolean = false;
  emailPattern: string = '';
}

@ComponentV2
export struct LoginRouter {
  @Param runtimeProvider: () => AppCoreRuntime = getAppCoreRuntime;
  @Event onAuthComplete: () => void = (): void => {};

  // ─── Local state (V2: @Local вместо @StorageLink) ───
  // Auth/error use the stable root store; other form metadata uses the UI bridge.
  @Local authStatus: string = 'notInitialized';
  @Local authPhone: string = '';
  @Local codeType: string = 'sms';
  @Local codeLength: number = 5;
  @Local codeTimeout: number = 60;
  @Local codeNextType: string = 'call';
  @Local passwordHint: string = '';
  @Local authError: string = '';
  @Local localError: Resource | undefined = undefined;
  @Local forceBackInFlight: boolean = false;
  @Local recoveryInFlight: boolean = false;

  private unsubscribe?: () => void;
  private pageLifecycleToken: number = 0;
  private forceBackRequestSerial: number = 0;
  private recoveryRequestSerial: number = 0;

  private isCurrentRouterContinuation(scheduledToken: number): boolean {
    return scheduledToken === this.pageLifecycleToken;
  }

  private isCurrentForceBackRequest(scheduledToken: number, scheduledSerial: number): boolean {
    return this.isCurrentRouterContinuation(scheduledToken) && scheduledSerial === this.forceBackRequestSerial;
  }

  // Request logout only. Neither ok nor failure proves that phone input is ready.
  // Runtime owns Closed recovery; only its real auth updates select the next step.
  private async forceBackToPhone(reason: string): Promise<void> {
    if (this.unsubscribe === undefined || this.forceBackInFlight || this.recoveryInFlight) {
      return;
    }
    const authStatus: string = this.runtimeProvider().getLifecycleStore().getState().auth.status;
    if (authStatus !== 'waitCode' && authStatus !== 'waitPassword' && authStatus !== 'waitQrCode' &&
        authStatus !== 'waitRegistration' && authStatus !== 'waitEmailAddress' && authStatus !== 'waitEmailCode') {
      return;
    }
    const requestToken: number = this.pageLifecycleToken;
    this.forceBackRequestSerial += 1;
    const requestSerial: number = this.forceBackRequestSerial;
    this.forceBackInFlight = true;
    this.localError = undefined;
    hilog.warn(0x0003, 'LoginRouter', 'forceBackToPhone: %{public}s — вызываем TDLib logOut', reason);
    try {
      await LoginController.getInstance().logout();
    } catch (error) {
      if (this.isCurrentForceBackRequest(requestToken, requestSerial)) {
        this.localError = $r('app.string.action_failed');
        hilog.warn(0x0003, 'LoginRouter', 'Logout failed; waiting for authoritative auth state');
      }
    } finally {
      if (this.isCurrentForceBackRequest(requestToken, requestSerial)) {
        this.forceBackInFlight = false;
      }
    }
  }

  private async retryRecovery(): Promise<void> {
    if (this.unsubscribe === undefined || this.recoveryInFlight || this.forceBackInFlight) {
      return;
    }
    const requestToken: number = this.pageLifecycleToken;
    this.recoveryRequestSerial += 1;
    const requestSerial: number = this.recoveryRequestSerial;
    this.recoveryInFlight = true;
    this.localError = undefined;
    try {
      const runtime = this.runtimeProvider();
      const auth = runtime.getLifecycleStore().getState().auth;
      if (auth.status === 'notInitialized' && auth.error.length > 0) {
        await runtime.retryInitialStartup();
      } else if (auth.status === 'closed') {
        await runtime.retryClientRecovery();
      }
    } catch (error) {
      if (this.isCurrentRouterContinuation(requestToken) && requestSerial === this.recoveryRequestSerial) {
        this.localError = $r('app.string.action_failed');
        hilog.warn(0x0003, 'LoginRouter', 'Client recovery failed');
      }
    } finally {
      if (this.isCurrentRouterContinuation(requestToken) && requestSerial === this.recoveryRequestSerial) {
        this.recoveryInFlight = false;
      }
    }
  }

  private hasRecoveryFailure(): boolean {
    return (this.authStatus === 'closed' || this.authStatus === 'notInitialized') &&
      (this.authError.length > 0 || this.localError !== undefined) && !this.recoveryInFlight;
  }

  private syncFromAppStorage(): void {
    const auth = this.runtimeProvider().getLifecycleStore().getState().auth;
    if (this.authStatus !== auth.status) {
      this.resetLocalActions();
    }
    this.authStatus = auth.status;
    // Error details stay out of Text/log output; the UI uses a localized generic message.
    this.authError = auth.error;
    this.authPhone = AppStorage.get<string>(StorageKeys.AUTH_PHONE) ?? '';
    this.codeType = AppStorage.get<string>(StorageKeys.CODE_TYPE) ?? 'sms';
    this.codeLength = AppStorage.get<number>(StorageKeys.CODE_LENGTH) ?? 5;
    this.codeTimeout = AppStorage.get<number>(StorageKeys.CODE_TIMEOUT) ?? 60;
    this.codeNextType = AppStorage.get<string>(StorageKeys.CODE_NEXT_TYPE) ?? 'call';
    this.passwordHint = AppStorage.get<string>(StorageKeys.PASSWORD_HINT) ?? '';
  }

  private resetLocalActions(): void {
    this.forceBackRequestSerial += 1;
    this.recoveryRequestSerial += 1;
    this.forceBackInFlight = false;
    this.recoveryInFlight = false;
    this.localError = undefined;
  }

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
    this.resetLocalActions();
    this.syncFromAppStorage();
    hilog.info(0x0003, 'LoginRouter', 'LoginRouter aboutToAppear, initial authStatus: %{public}s', this.authStatus);
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    try {
      const subscriptionToken: number = this.pageLifecycleToken;
      let activeUnsubscribe: (() => void) | undefined = undefined;
      activeUnsubscribe = this.runtimeProvider().getLifecycleStore().subscribe(() => {
        if (!this.isCurrentRouterContinuation(subscriptionToken) || this.unsubscribe !== activeUnsubscribe) {
          return;
        }
        this.syncFromAppStorage();
      });
      this.unsubscribe = activeUnsubscribe;
    } catch (e) {
      hilog.error(0x0003, 'LoginRouter', 'Failed to subscribe store: %{public}s', String(e));
    }
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.resetLocalActions();
    hilog.info(0x0003, 'LoginRouter', 'LoginRouter aboutToDisappear');
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
  }

  build() {
    Stack() {
      // Auth state/error come from the stable lifecycle store, not an account-scoped subscription.
      // authStatus обновляется через store subscription → syncFromAppStorage()

      if (this.hasRecoveryFailure()) {
        Column({ space: TgUiTokens.SPACE_16 }) {
          Text($r('app.string.action_failed'))
            .id('loginRecoveryError')
            .fontSize(TgUiTokens.LOGIN_ERROR_SIZE)
            .fontColor(TgUiTokens.LOGIN_ERROR_COLOR)
            .textAlign(TextAlign.Center)
          Button($r('app.string.retry'))
            .id('loginRecoveryRetry')
            .height(TgUiTokens.LOGIN_BUTTON_HEIGHT)
            .borderRadius(TgUiTokens.LOGIN_BUTTON_RADIUS)
            .fontSize(TgUiTokens.LOGIN_BUTTON_TEXT_SIZE)
            .fontColor(TgUiTokens.LOGIN_BUTTON_TEXT_COLOR)
            .backgroundColor(TgUiTokens.LOGIN_BUTTON_BG)
            .enabled(!this.recoveryInFlight)
            .onClick(() => { this.retryRecovery(); })
        }
        .width('100%')
        .height('100%')
        .padding(TgUiTokens.LOGIN_SIDE_INSET)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(TgUiTokens.LOGIN_BG)
      } else if (this.authStatus === 'notInitialized' ||
          this.authStatus === 'waitTdlibParameters' ||
          this.authStatus === 'loggingOut' ||
          this.authStatus === 'closing' ||
          this.authStatus === 'closed') {
        // TDLib not ready or going through logout/restart cycle.
        // Pending automatic/manual recovery remains a spinner until real auth state or error.
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(TgUiTokens.COLOR_ICON_PRIMARY)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(TgUiTokens.LOGIN_BG)

      } else if (this.authStatus === 'waitPhoneNumber') {
        PhoneInputPage({
          onPhoneSent: (): void => {
            // Переход произойдёт автоматически через AppStorage
          }
        })
          .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))

      } else if (this.authStatus === 'waitQrCode') {
        QrLoginPage({
          onBackToPhone: (): void => {
            this.forceBackToPhone('back_from_qr');
          }
        })
          .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))

      } else if (this.authStatus === 'waitCode') {
        CodeInputPage({
          phoneNumber: this.authPhone,
          codeType: this.codeType as CodeType,
          codeLength: this.codeLength,
          nextType: this.codeNextType.length > 0 ? this.codeNextType as CodeType : null,
          timeout: this.codeTimeout,
          onCodeAccepted: (): void => {
            // Переход произойдёт автоматически через AppStorage
          },
          onWrongNumber: (): void => {
            this.forceBackToPhone('wrong_number_pressed');
          }
        })
          .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))

      } else if (this.authStatus === 'waitPassword') {
        PasswordInputPage({
          hint: this.passwordHint,
          suggestReset: false,
          onPasswordAccepted: (): void => {
            // Переход произойдёт автоматически через AppStorage
          },
          onBackToPhone: (): void => {
            this.forceBackToPhone('back_to_phone_from_password');
          }
        })
          .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))

      } else if (this.authStatus === 'ready') {
        // Auth confirmed — spinner while main UI loads (Telegram iOS: OverlayStatusController)
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(TgUiTokens.COLOR_ICON_PRIMARY)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(TgUiTokens.LOGIN_BG)
        .onAppear(() => {
          this.onAuthComplete();
        })

      } else if (this.authStatus === 'waitRegistration' ||
                 this.authStatus === 'waitEmailAddress' ||
                 this.authStatus === 'waitEmailCode') {
        // Temporary fallback to keep auth flow navigable until dedicated pages are ported.
        Column({ space: TgUiTokens.SPACE_12 }) {
          LoadingProgress()
            .width(32)
            .height(32)
            .color(TgUiTokens.COLOR_ICON_PRIMARY)
          Text('Preparing login step...')
            .fontSize(TgUiTokens.LOGIN_SUBTITLE_SIZE)
            .fontColor(TgUiTokens.LOGIN_SUBTITLE_COLOR)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(TgUiTokens.LOGIN_BG)
        .onAppear(() => {
          this.forceBackToPhone(`unsupported_auth_state_${this.authStatus}`);
        })

      } else {
        // Safety net to avoid blank screens on unknown auth states.
        Column({ space: TgUiTokens.SPACE_12 }) {
          LoadingProgress()
            .width(32)
            .height(32)
            .color(TgUiTokens.COLOR_ICON_PRIMARY)
          Text('Loading...')
            .fontSize(TgUiTokens.LOGIN_SUBTITLE_SIZE)
            .fontColor(TgUiTokens.LOGIN_SUBTITLE_COLOR)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(TgUiTokens.LOGIN_BG)
      }

      // Keep the server-selected form mounted on logout failure; offer an explicit retry.
      if (this.localError !== undefined && this.authStatus !== 'closed' && this.authStatus !== 'notInitialized') {
        Column({ space: TgUiTokens.SPACE_12 }) {
          Text(this.localError)
            .fontSize(TgUiTokens.LOGIN_ERROR_SIZE)
            .fontColor(TgUiTokens.LOGIN_ERROR_COLOR)
            .textAlign(TextAlign.Center)
          Button($r('app.string.retry'))
            .height(TgUiTokens.LOGIN_BUTTON_HEIGHT)
            .borderRadius(TgUiTokens.LOGIN_BUTTON_RADIUS)
            .fontColor(TgUiTokens.LOGIN_BUTTON_TEXT_COLOR)
            .backgroundColor(TgUiTokens.LOGIN_BUTTON_BG)
            .enabled(!this.forceBackInFlight)
            .onClick(() => { this.forceBackToPhone('retry_logout'); })
        }
        .padding(TgUiTokens.LOGIN_SIDE_INSET)
        .backgroundColor(TgUiTokens.LOGIN_BG)
        .align(Alignment.Bottom)
      }
    }
    .width('100%')
    .height('100%')
  }
}

// ─── Re-export types for convenience ───
export type AuthStatus =
  | 'notInitialized'
  | 'waitPhoneNumber'
  | 'waitQrCode'
  | 'waitCode'
  | 'waitPassword'
  | 'waitRegistration'
  | 'waitEmailAddress'
  | 'waitEmailCode'
  | 'ready';
