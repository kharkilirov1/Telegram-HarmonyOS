import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { TgIcon } from './TgIcon';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

declare function px2vp(value: number): number;

@ComponentV2
export struct TgTopBar {
  @Param title: string = '';
  @Param showBackAction: boolean = false;
  @Param showRightAction: boolean = false;
  @Param rightIcon: Resource = TgUiTokens.ICON_RES_MORE;
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;

  @Event onBackPress: () => void = (): void => {};
  @Event onRightPress: () => void = (): void => {};

  @Local topInset: number = 0;

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
            [TgUiTokens.GLASS_SPECULAR_TOP, 0.0],
            [TgUiTokens.GLASS_SPECULAR_MID, 0.38],
            [TgUiTokens.GLASS_SPECULAR_BOTTOM, 1.0]
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

  @Builder
  private buildBackSlot() {
    Row() {
      if (this.showBackAction) {
        TgIcon({
          src: TgUiTokens.ICON_RES_BACK,
          iconSize: TgUiTokens.TOP_BAR_ACTION_ICON_SIZE,
          tintColor: TgUiTokens.COLOR_ICON_PRIMARY
        })
      }
    }
    .width(TgUiTokens.TOP_BAR_ACTION_TOUCH)
    .height(TgUiTokens.TOP_BAR_ACTION_TOUCH)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (this.showBackAction) {
        this.onBackPress();
      }
    })
  }

  @Builder
  private buildRightSlot() {
    Row() {
      if (this.showRightAction) {
        TgIcon({
          src: this.rightIcon,
          iconSize: TgUiTokens.TOP_BAR_ACTION_ICON_SIZE,
          tintColor: TgUiTokens.COLOR_ICON_PRIMARY
        })
      }
    }
    .width(TgUiTokens.TOP_BAR_ACTION_TOUCH)
    .height(TgUiTokens.TOP_BAR_ACTION_TOUCH)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (this.showRightAction) {
        this.onRightPress();
      }
    })
  }

  build() {
    Column() {
      Row()
        .width('100%')
        .height(this.topInset)

      Row() {
        this.buildBackSlot()

        Text(this.title)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(TgUiTokens.TOP_BAR_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        this.buildRightSlot()
      }
      .height(TgUiTokens.TOP_BAR_HEIGHT)
      .width('100%')
      .padding({
        left: TgUiTokens.TOP_BAR_SIDE_PADDING,
        right: TgUiTokens.TOP_BAR_SIDE_PADDING
      })
    }
    .height(this.topInset + TgUiTokens.TOP_BAR_HEIGHT)
    .width('100%')
    .backgroundColor(this.useRealtimeBlur() ? TgUiTokens.TOP_BAR_GLASS_BG : TgUiTokens.TOP_BAR_GLASS_FALLBACK_BG)
    .backgroundBlurStyle(TgGlassPolicy.topBarBlurStyle())
    .overlay(this.buildGlassSpecular())
    .border({
      width: { bottom: TgUiTokens.TOP_BAR_SEPARATOR_STROKE },
      color: TgUiTokens.TOP_BAR_SEPARATOR
    })
  }
}
