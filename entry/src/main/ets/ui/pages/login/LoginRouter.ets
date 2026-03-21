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
import { QrLoginPage } from './QrLoginPage';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { CodeType, LoginController } from '../../controllers/LoginController';
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

  // Сбрасывает auth state на сервере через TDLib logOut, затем возвращает на экран телефона.
  //
  // Аналог auth.cancelCode в Android (TLRPC.TL_auth_cancelCode).
  // Без этого вызова при повторном setAuthenticationPhoneNumber сервер либо
  // продолжает ждать код по старому номеру, либо отправляет код через другую сессию
  // (authenticationCodeTypeTelegramMessage) вместо SMS.
  //
  // После logOut TDLib сам присылает updateAuthorizationState: waitPhoneNumber →
  // AppStoreBridge обновляет AUTH_STATUS → @StorageLink обновляет роутер.
  // Fallback: если logOut не отвечает — принудительно обновляем AppStorage.
  private forceBackToPhone(reason: string): void {
    hilog.warn(0x0003, 'LoginRouter', 'forceBackToPhone: %{public}s — вызываем TDLib logOut', reason);

    LoginController.getInstance().logout()
      .then((): void => {
        hilog.info(0x0003, 'LoginRouter', 'logOut выполнен — TDLib обновит AUTH_STATUS на waitPhoneNumber');
        // TDLib сам эмитирует updateAuthorizationState: waitPhoneNumber.
        // AppStoreBridge подхватит и обновит AppStorage → роутер переключится сам.
      })
      .catch((error: Error): void => {
        // logout() внутри перехватывает ошибки и не бросает — этот catch страховочный.
        hilog.error(0x0003, 'LoginRouter', 'logout() unexpected throw: %{public}s', String(error));
        // Fallback: обновляем UI напрямую если TDLib не ответил
        AppStorage.set<string>(StorageKeys.AUTH_STATUS, 'waitPhoneNumber');
      });

    // Оптимистичный fallback через store — срабатывает если TDLib медленно обновляет состояние.
    // Если TDLib уже выставил waitPhoneNumber — повторная запись не имеет эффекта.
    try {
      getAppCoreRuntime().getStore().dispatch(createAuthStateChangedEvent('waitPhoneNumber'))
        .catch((error: Error) => {
          hilog.warn(0x0003, 'LoginRouter', 'Store dispatch waitPhoneNumber failed: %{public}s', String(error));
          AppStorage.set<string>(StorageKeys.AUTH_STATUS, 'waitPhoneNumber');
        });
    } catch (error) {
      hilog.error(0x0003, 'LoginRouter', 'Force back dispatch threw: %{public}s', String(error));
      AppStorage.set<string>(StorageKeys.AUTH_STATUS, 'waitPhoneNumber');
    }
  }

  aboutToAppear(): void {
    hilog.info(0x0003, 'LoginRouter', 'LoginRouter aboutToAppear, initial authStatus: %{public}s', this.authStatus);
  }

  aboutToDisappear(): void {
    hilog.info(0x0003, 'LoginRouter', 'LoginRouter aboutToDisappear');
  }

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
