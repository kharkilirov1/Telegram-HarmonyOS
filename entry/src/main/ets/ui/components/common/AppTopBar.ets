import { AppShellTokens } from '../../theme/AppShellTokens';
import { TgGlassPolicy } from '../../tg_ui/tokens/TgGlassPolicy';
import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

declare function px2vp(value: number): number;

@Component
export struct AppTopBar {
  @Prop title: string = '';
  @Prop showLeftAction: boolean = false;
  @Prop showRightAction: boolean = false;
  @Prop leftIcon: Resource = $r('app.media.ic_back');
  @Prop rightIcon: Resource = $r('app.media.ic_more');

  onLeftPress: () => void = (): void => {};
  onRightPress: () => void = (): void => {};
  @State private topInset: number = 0;
  @StorageLink(StorageKeys.GLASS_MODE) glassMode: string = TgGlassPolicy.MODE_AUTO;

  private useRealtimeBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  @Builder
  private buildGlassSpecular() {
    if (this.useRealtimeBlur()) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 110,
          colors: [
            [AppShellTokens.GLASS_SPECULAR_TOP, 0.0],
            [AppShellTokens.GLASS_SPECULAR_MID, 0.38],
            [AppShellTokens.GLASS_SPECULAR_BOTTOM, 1.0]
          ]
        })
        .hitTestBehavior(HitTestMode.Transparent)
    }
  }

  aboutToAppear(): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const windowStage = context.windowStage;
      if (windowStage) {
        const mainWindow = windowStage.getMainWindowSync();
        const avoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        this.topInset = px2vp(avoidArea.topRect.height);
      }
    } catch (_error) {
      this.topInset = 0;
    }
  }

  build() {
    Column() {
      Row()
        .width('100%')
        .height(this.topInset)

      Row() {
        Row() {
          if (this.showLeftAction) {
            Image(this.leftIcon)
              .width(AppShellTokens.TOP_BAR_ACTION_SIZE)
              .height(AppShellTokens.TOP_BAR_ACTION_SIZE)
              .fillColor(AppShellTokens.ACCENT)
              .onClick(() => {
                this.onLeftPress();
              })
          }
        }
        .width(AppShellTokens.TOP_BAR_ACTION_TOUCH)
        .height(AppShellTokens.TOP_BAR_ACTION_TOUCH)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        Text(this.title)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(AppShellTokens.TOP_BAR_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppShellTokens.TEXT_PRIMARY)

        Row() {
          if (this.showRightAction) {
            Image(this.rightIcon)
              .width(AppShellTokens.TOP_BAR_ACTION_SIZE)
              .height(AppShellTokens.TOP_BAR_ACTION_SIZE)
              .fillColor(AppShellTokens.ACCENT)
              .onClick(() => {
                this.onRightPress();
              })
          }
        }
        .width(AppShellTokens.TOP_BAR_ACTION_TOUCH)
        .height(AppShellTokens.TOP_BAR_ACTION_TOUCH)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
      .height(AppShellTokens.TOP_BAR_HEIGHT)
      .width('100%')
      .padding({ left: AppShellTokens.TOP_BAR_SIDE_PADDING, right: AppShellTokens.TOP_BAR_SIDE_PADDING })
    }
    .height(this.topInset + AppShellTokens.TOP_BAR_HEIGHT)
    .width('100%')
    .backgroundColor(this.useRealtimeBlur() ? AppShellTokens.TOP_BAR_GLASS_BG : AppShellTokens.TOP_BAR_GLASS_FALLBACK_BG)
    .backgroundBlurStyle(TgGlassPolicy.topBarBlurStyle())
    .overlay(this.buildGlassSpecular())
    .border({ width: { bottom: 1 }, color: AppShellTokens.SEPARATOR })
  }
}
