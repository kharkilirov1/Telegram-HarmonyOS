// QrLoginPage — экран QR-кода для авторизации
// TDLib: requestQrCodeAuthentication → waitOtherDeviceConfirmation → link (tg://login?token=...)
// Пользователь сканирует QR с залогиненного устройства

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { MonkeyAnimation } from '../../components/login/MonkeyAnimation';
import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { LoginController, SendCodeFailure } from '../../controllers/LoginController';
import { LengthMetrics } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0042;
const TAG = 'QrLoginPage';

@ComponentV2
export struct QrLoginPage {
  @Event onBackToPhone: () => void = (): void => {};

  @Local qrCodeLink: string = '';
  @Local private errorMessage: string = '';
  @Local private isRequesting: boolean = false;

  private unsubscribe?: () => void;
  private pageLifecycleToken: number = 0;

  private isCurrentQrContinuation(scheduledToken: number): boolean {
    return scheduledToken === this.pageLifecycleToken;
  }

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
    this.qrCodeLink = AppStorage.get<string>(StorageKeys.QR_CODE_LINK) ?? '';
    hilog.info(DOMAIN, TAG, 'QrLoginPage appeared, qrCodeLink length: %{public}d', this.qrCodeLink.length);
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    try {
      const subscriptionToken: number = this.pageLifecycleToken;
      let activeUnsubscribe: (() => void) | undefined = undefined;
      activeUnsubscribe = getAppCoreRuntime().getStore().subscribe(() => {
        if (!this.isCurrentQrContinuation(subscriptionToken) || this.unsubscribe !== activeUnsubscribe) {
          return;
        }
        this.qrCodeLink = AppStorage.get<string>(StorageKeys.QR_CODE_LINK) ?? '';
      });
      this.unsubscribe = activeUnsubscribe;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to subscribe store: %{public}s', String(e));
    }
    // Если link ещё пуст — запрашиваем QR (может прийти из LoginRouter уже с link)
    if (this.qrCodeLink.length === 0 && !this.isRequesting) {
      this.requestQr();
    }
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.isRequesting = false;
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
  }

  build() {
    Column() {
      // Scrollable content
      Scroll() {
        Column({ space: 0 }) {
          // Monkey animation
          MonkeyAnimation({ screen: 'phone' })
            .margin({ top: TgUiTokens.LOGIN_SPACING_MONKEY_TOP })

          // Title
          Text('Log in by QR Code')
            .fontSize(TgUiTokens.LOGIN_TITLE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(TgUiTokens.LOGIN_TITLE_COLOR)
            .textAlign(TextAlign.Center)
            .margin({ top: TgUiTokens.LOGIN_SPACING_TITLE_TOP })

          // Subtitle — instructions
          Text('Open Telegram on your phone\nGo to Settings > Devices > Link Desktop Device\nScan this QR code')
            .fontSize(TgUiTokens.LOGIN_SUBTITLE_SIZE)
            .fontColor(TgUiTokens.LOGIN_SUBTITLE_COLOR)
            .textAlign(TextAlign.Center)
            .lineHeight(22)
            .margin({ top: 8 })
            .padding({
              start: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET),
              end: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET)
            })

          // QR Code
          if (this.qrCodeLink.length > 0) {
            Column() {
              QRCode(this.qrCodeLink)
                .width(220)
                .height(220)
                .color(Color.Black)
                .backgroundColor(Color.White)
            }
            .width(240)
            .height(240)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .backgroundColor(Color.White)
            .borderRadius(16)
            .margin({ top: 24 })
          } else {
            // Loading state
            Column() {
              LoadingProgress()
                .width(40)
                .height(40)
                .color(TgUiTokens.COLOR_ICON_PRIMARY)
            }
            .width(240)
            .height(240)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .margin({ top: 24 })
          }

          // Error message
          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .fontSize(TgUiTokens.LOGIN_ERROR_SIZE)
              .fontColor(TgUiTokens.LOGIN_ERROR_COLOR)
              .textAlign(TextAlign.Center)
              .margin({ top: TgUiTokens.LOGIN_SPACING_ERROR_TOP })
              .padding({
                start: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET),
                end: LengthMetrics.vp(TgUiTokens.LOGIN_SIDE_INSET)
              })
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: TgUiTokens.LOGIN_MAX_WIDTH })
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)

      // Back to phone button
      Column() {
        Text('Log in by phone number')
          .fontSize(TgUiTokens.LOGIN_SUBTITLE_SIZE)
          .fontColor(TgUiTokens.LOGIN_LINK_COLOR)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.onBackToPhone();
          })
      }
      .width('100%')
      .padding({
        bottom: TgUiTokens.LOGIN_SIDE_INSET + 16
      })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.LOGIN_BG)
  }

  private async requestQr(): Promise<void> {
    const requestToken: number = this.pageLifecycleToken;
    this.isRequesting = true;
    this.errorMessage = '';

    const controller = LoginController.getInstance();
    const result = await controller.requestQrLogin();

    if (!this.isCurrentQrContinuation(requestToken)) {
      return;
    }
    this.isRequesting = false;

    if (!result.success) {
      const failure = result as SendCodeFailure;
      this.errorMessage = failure.error.message;
      hilog.error(DOMAIN, TAG, 'requestQrLogin failed: %{public}s', failure.error.message);
    }
  }
}
