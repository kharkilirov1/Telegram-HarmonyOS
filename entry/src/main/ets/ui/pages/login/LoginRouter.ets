// LoginRouter — роутер авторизации с использованием AppStorage
//
// Huawei рекомендует использовать @StorageLink для синхронизации UI с глобальным состоянием.
// Мост AppStoreBridge синхронизирует AppStore → AppStorage,
// а UI читает через @StorageLink декоратор.
//
// Это заменяет ручную подписку на AppStore.subscribe() в aboutToAppear().

import { PhoneInputPage } from './PhoneInputPage';
import { CodeInputPage } from './CodeInputPage';
import { PasswordInputPage } from './PasswordInputPage';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { CodeType } from '../../controllers/LoginController';

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

@Component
export struct LoginRouter {
  onAuthComplete: () => void = (): void => {};

  // ─── AppStorage Bindings (Huawei recommended) ───
  // @StorageLink создаёт двустороннюю связь с AppStorage
  // Когда AppStoreBridge обновляет AppStorage, UI автоматически перерисовывается
  @StorageLink(StorageKeys.AUTH_STATUS) authStatus: string = 'notInitialized';
  @StorageLink(StorageKeys.AUTH_PHONE) authPhone: string = '';
  @StorageLink(StorageKeys.CODE_TYPE) codeType: string = 'sms';
  @StorageLink(StorageKeys.CODE_LENGTH) codeLength: number = 5;
  @StorageLink(StorageKeys.CODE_TIMEOUT) codeTimeout: number = 60;
  @StorageLink(StorageKeys.CODE_NEXT_TYPE) codeNextType: string = 'call';
  @StorageLink(StorageKeys.PASSWORD_HINT) passwordHint: string = '';

  // Local context (не из AppStorage)
  @State private context: AuthContext = new AuthContext();

  // Отслеживание предыдущего статуса для определения направления перехода
  private prevStatus: string = 'notInitialized';

  build() {
    Stack() {
      // Реактивное переключение по статусу из AppStorage
      // @StorageLink автоматически обновляет authStatus при изменении в AppStorage

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
            // Возврат к вводу номера
            // В идеале это должно идти через TDLib команду
            // Но для UX можно сбросить локально
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
            // Возврат к вводу номера
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
      }

      // TODO: waitRegistration → SignUpPage
      // TODO: waitEmailAddress → EmailSetupPage
    }
    .width('100%')
    .height('100%')
  }
}

// ─── Re-export types for convenience ───
export type AuthStatus =
  | 'notInitialized'
  | 'waitPhoneNumber'
  | 'waitCode'
  | 'waitPassword'
  | 'waitRegistration'
  | 'waitEmailAddress'
  | 'waitEmailCode'
  | 'ready';
