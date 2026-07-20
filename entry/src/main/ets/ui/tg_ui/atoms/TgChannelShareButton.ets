import { uiMaterial } from '@kit.ArkUI';
import { Available, deviceInfo } from '@kit.BasicServicesKit';
import { localized } from '../../../core/utils/AppResource';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgIcon } from './TgIcon';

@ComponentV2
export struct TgChannelShareButton {
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;
  @Param accessibilityLabel: string = localized($r('app.string.action_forward').id, 'Forward');
  @Event onPress: () => void = (): void => {};

  private useBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  private useNativeMaterial(): boolean {
    return deviceInfo.apiAvailable('26.0.0') && this.useBlur();
  }

  private responseOffset(): number {
    return (TgUiTokens.CHANNEL_SHARE_BUTTON_SIZE - TgUiTokens.CHANNEL_SHARE_BUTTON_RESPONSE_SIZE) / 2;
  }

  @Builder
  private buildIcon() {
    TgIcon({
      src: TgUiTokens.ICON_RES_FORWARD,
      iconSize: TgUiTokens.CHANNEL_SHARE_BUTTON_ICON_SIZE,
      tintColor: TgUiTokens.COLOR_ICON_PRIMARY
    })
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeSurface() {
    Row() {
      this.buildIcon()
    }
    .width(TgUiTokens.CHANNEL_SHARE_BUTTON_SIZE)
    .height(TgUiTokens.CHANNEL_SHARE_BUTTON_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      applyShadow: true,
      interactive: true
    }))
    .borderRadius(TgUiTokens.CHANNEL_SHARE_BUTTON_SIZE / 2)
    .clip(true)
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private buildFallbackSurface() {
    Row() {
      this.buildIcon()
    }
    .width(TgUiTokens.CHANNEL_SHARE_BUTTON_SIZE)
    .height(TgUiTokens.CHANNEL_SHARE_BUTTON_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(TgUiTokens.CHANNEL_SHARE_BUTTON_BG)
    .backgroundBlurStyle(
      this.useBlur() ? BlurStyle.COMPONENT_ULTRA_THIN : BlurStyle.NONE,
      TgGlassPolicy.glassOptions()
    )
    .border({
      width: TgUiTokens.CHANNEL_SHARE_BUTTON_BORDER_WIDTH,
      color: TgUiTokens.CHANNEL_SHARE_BUTTON_BORDER
    })
    .borderRadius(TgUiTokens.CHANNEL_SHARE_BUTTON_SIZE / 2)
    .clip(true)
    .renderGroup(true)
    .hitTestBehavior(HitTestMode.None)
  }

  build() {
    Row() {
      if (deviceInfo.apiAvailable('26.0.0')) {
        if (this.useNativeMaterial()) {
          this.buildNativeSurface()
        } else {
          this.buildFallbackSurface()
        }
      } else {
        this.buildFallbackSurface()
      }
    }
    .width(TgUiTokens.CHANNEL_SHARE_BUTTON_SIZE)
    .height(TgUiTokens.CHANNEL_SHARE_BUTTON_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .responseRegion({
      x: this.responseOffset(),
      y: this.responseOffset(),
      width: TgUiTokens.CHANNEL_SHARE_BUTTON_RESPONSE_SIZE,
      height: TgUiTokens.CHANNEL_SHARE_BUTTON_RESPONSE_SIZE
    })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.86 })
    .accessibilityText(this.accessibilityLabel)
    .onClick(() => {
      this.onPress();
    })
  }
}
