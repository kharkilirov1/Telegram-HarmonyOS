import { uiMaterial } from '@kit.ArkUI';
import { Available, deviceInfo } from '@kit.BasicServicesKit';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { TgIcon } from './TgIcon';

// Telegram iOS PeerInfo keeps left/right navigation controls in independent
// glass containers. This atom ports that boundary without owning profile data.
@ComponentV2
export struct TgProfileNavigationBar {
  @Param topInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
  @Param showSearch: boolean = true;
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;
  @Param backAccessibilityText: string = 'Back';
  @Param searchAccessibilityText: string = 'Search in chat';

  @Event onBackPress: () => void = (): void => {};
  @Event onSearchPress: () => void = (): void => {};

  private useBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  private useNativeMaterial(): boolean {
    return deviceInfo.apiAvailable('26.0.0') && this.useBlur();
  }

  private capsuleBackground(): ResourceColor {
    return this.useBlur() ? TgUiTokens.CHAT_TOP_BAR_CAPSULE_BG : TgUiTokens.CHAT_TOP_BAR_CAPSULE_FALLBACK_BG;
  }

  private capsuleBlurStyle(): BlurStyle {
    return this.useBlur() ? BlurStyle.COMPONENT_ULTRA_THIN : BlurStyle.NONE;
  }

  private responseRegionOffset(): number {
    return (TgUiTokens.PROFILE_NAV_CONTROL_SIZE - TgUiTokens.PROFILE_NAV_RESPONSE_SIZE) / 2;
  }

  private actionAccessibilityText(isSearch: boolean): string {
    return isSearch ? this.searchAccessibilityText : this.backAccessibilityText;
  }

  private handleAction(isSearch: boolean): void {
    if (isSearch) {
      this.onSearchPress();
    } else {
      this.onBackPress();
    }
  }

  @Builder
  private buildActionIcon(isSearch: boolean) {
    TgIcon({
      src: isSearch ? TgUiTokens.ICON_RES_SEARCH : TgUiTokens.ICON_RES_BACK,
      iconSize: TgUiTokens.PROFILE_NAV_ICON_SIZE,
      tintColor: TgUiTokens.COMPOSER_ACTION_ACTIVE
    })
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeAction(isSearch: boolean) {
    Row() {
      this.buildActionIcon(isSearch)
    }
    .width(TgUiTokens.PROFILE_NAV_CONTROL_SIZE)
    .height(TgUiTokens.PROFILE_NAV_CONTROL_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      colorInvert: true,
      applyShadow: true,
      interactive: true
    }))
    .borderRadius(TgUiTokens.PROFILE_NAV_CONTROL_RADIUS)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.88 })
    .responseRegion({
      x: this.responseRegionOffset(),
      y: this.responseRegionOffset(),
      width: TgUiTokens.PROFILE_NAV_RESPONSE_SIZE,
      height: TgUiTokens.PROFILE_NAV_RESPONSE_SIZE
    })
    .accessibilityText(this.actionAccessibilityText(isSearch))
    .onClick(() => this.handleAction(isSearch))
  }

  @Builder
  private buildFallbackAction(isSearch: boolean) {
    Row() {
      this.buildActionIcon(isSearch)
    }
    .width(TgUiTokens.PROFILE_NAV_CONTROL_SIZE)
    .height(TgUiTokens.PROFILE_NAV_CONTROL_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.capsuleBackground())
    .backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
    .border({ width: TgUiTokens.PROFILE_NAV_BORDER_WIDTH, color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER })
    .borderRadius(TgUiTokens.PROFILE_NAV_CONTROL_RADIUS)
    .clip(true)
    .renderGroup(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.88 })
    .responseRegion({
      x: this.responseRegionOffset(),
      y: this.responseRegionOffset(),
      width: TgUiTokens.PROFILE_NAV_RESPONSE_SIZE,
      height: TgUiTokens.PROFILE_NAV_RESPONSE_SIZE
    })
    .accessibilityText(this.actionAccessibilityText(isSearch))
    .onClick(() => this.handleAction(isSearch))
  }

  @Builder
  private buildAction(isSearch: boolean) {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.useNativeMaterial()) {
        this.buildNativeAction(isSearch)
      } else {
        this.buildFallbackAction(isSearch)
      }
    } else {
      this.buildFallbackAction(isSearch)
    }
  }

  build() {
    Column() {
      Row()
        .width('100%')
        .height(this.topInset + TgUiTokens.PROFILE_NAV_TOP_GAP)

      Row() {
        this.buildAction(false)
        Blank()
        if (this.showSearch) {
          this.buildAction(true)
        }
      }
      .width('100%')
      .height(TgUiTokens.PROFILE_NAV_CONTROL_SIZE)
      .padding({
        left: TgUiTokens.PROFILE_NAV_SIDE_INSET,
        right: TgUiTokens.PROFILE_NAV_SIDE_INSET
      })

      Row()
        .width('100%')
        .height(TgUiTokens.PROFILE_NAV_BOTTOM_GAP)
    }
    .width('100%')
  }
}
