// LoginRouter — роутер авторизации с использованием AppStorage
//
// AppStoreBridge синхронизирует AppStore → AppStorage.
// V2: @Local поля + store.subscribe() → syncFromAppStorage() вместо @StorageLink.

import { PhoneInputPage } from './PhoneInputPage';
import { CodeInputPage } from './CodeInputPage';
import { PasswordInputPage } from './PasswordInputPage';
import { QrLoginPage } from './QrLoginPage';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { CodeType } from '../../controllers/LoginController';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { createAuthStateChangedEvent } from '../../../core/model/AppEvent';
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
  onAuthComplete: () => void = (): void => {};

  // ─── Local state (V2: @Local вместо @StorageLink) ───
  // Синхронизируется с AppStorage через store subscription в aboutToAppear
  @Local authStatus: string = 'notInitialized';
  @Local authPhone: string = '';
  @Local codeType: string = 'sms';
  @Local codeLength: number = 5;
  @Local codeTimeout: number = 60;
  @Local codeNextType: string = 'call';
  @Local passwordHint: string = '';

  private unsubscribe?: () => void;
  // Отслеживание предыдущего статуса для определения направления перехода
  private prevStatus: string = 'notInitialized';

  private forceBackToPhone(reason: string): void {
    hilog.warn(0x0003, 'LoginRouter', 'Force back to waitPhoneNumber, reason: %{public}s', reason);
    try {
      getAppCoreRuntime().getStore().dispatch(createAuthStateChangedEvent('waitPhoneNumber'))
        .catch((error: Error) => {
          hilog.error(0x0003, 'LoginRouter', 'Store dispatch waitPhoneNumber failed: %{public}s', String(error));
          AppStorage.set<string>(StorageKeys.AUTH_STATUS, 'waitPhoneNumber');
        });
    } catch (error) {
      hilog.error(0x0003, 'LoginRouter', 'Force back dispatch threw: %{public}s', String(error));
      AppStorage.set<string>(StorageKeys.AUTH_STATUS, 'waitPhoneNumber');
    }
  }

  private syncFromAppStorage(): void {
    this.authStatus = AppStorage.get<string>(StorageKeys.AUTH_STATUS) ?? 'notInitialized';
    this.authPhone = AppStorage.get<string>(StorageKeys.AUTH_PHONE) ?? '';
    this.codeType = AppStorage.get<string>(StorageKeys.CODE_TYPE) ?? 'sms';
    this.codeLength = AppStorage.get<number>(StorageKeys.CODE_LENGTH) ?? 5;
    this.codeTimeout = AppStorage.get<number>(StorageKeys.CODE_TIMEOUT) ?? 60;
    this.codeNextType = AppStorage.get<string>(StorageKeys.CODE_NEXT_TYPE) ?? 'call';
    this.passwordHint = AppStorage.get<string>(StorageKeys.PASSWORD_HINT) ?? '';
  }

  aboutToAppear(): void {
    this.syncFromAppStorage();
    hilog.info(0x0003, 'LoginRouter', 'LoginRouter aboutToAppear, initial authStatus: %{public}s', this.authStatus);
    try {
      this.unsubscribe = getAppCoreRuntime().getStore().subscribe(() => {
        this.syncFromAppStorage();
      });
    } catch (e) {
      hilog.error(0x0003, 'LoginRouter', 'Failed to subscribe store: %{public}s', String(e));
    }
  }

  aboutToDisappear(): void {
    hilog.info(0x0003, 'LoginRouter', 'LoginRouter aboutToDisappear');
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
  }

  build() {
    Stack() {
      // Реактивное переключение по статусу из AppStorage
      // authStatus обновляется через store subscription → syncFromAppStorage()

      if (this.authStatus === 'notInitialized' || this.authStatus === 'waitTdlibParameters') {
        // TDLib ещё не инициализирован — блокируем UI до готовности
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
