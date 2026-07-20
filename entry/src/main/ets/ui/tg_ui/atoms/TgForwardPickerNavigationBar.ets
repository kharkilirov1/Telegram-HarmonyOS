import { uiMaterial } from '@kit.ArkUI';
import { Available, deviceInfo } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { TgIcon } from './TgIcon';

declare function px2vp(value: number): number;

// Telegram iOS forwarding uses a modal PeerSelectionController with native
// navigation/search chrome above the regular ChatListNode. This atom owns only
// that navigation chrome; target data and selection remain page-owned.
@ComponentV2
export struct TgForwardPickerNavigationBar {
  @Param title: string = 'Forward';
  @Param topInset: number = -1;
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;
  @Param backAccessibilityText: string = 'Back';
  @Param trailingTitle: string = '';
  @Param trailingAccessibilityText: string = '';
  @Param trailingEnabled: boolean = true;

  @Local private measuredTopInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;

  @Event onBackPress: () => void = (): void => {};
  @Event onTrailingPress: () => void = (): void => {};

  aboutToAppear(): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const windowStage = context.windowStage;
      if (windowStage) {
        const mainWindow = windowStage.getMainWindowSync();
        const avoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        this.measuredTopInset = px2vp(avoidArea.topRect.height);
      }
    } catch (_error) {
      this.measuredTopInset = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
    }
  }

  private effectiveTopInset(): number {
    return this.topInset >= 0 ? this.topInset : this.measuredTopInset;
  }

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
    return (TgUiTokens.FORWARD_PICKER_NAV_CONTROL_SIZE - TgUiTokens.FORWARD_PICKER_NAV_RESPONSE_SIZE) / 2;
  }

  private hasTrailingAction(): boolean {
    return this.trailingTitle.trim().length > 0;
  }

  private titleMaxWidth(): number {
    return this.hasTrailingAction()
      ? TgUiTokens.FORWARD_PICKER_NAV_TITLE_WITH_ACTION_MAX_WIDTH
      : TgUiTokens.FORWARD_PICKER_NAV_TITLE_MAX_WIDTH;
  }

  @Builder
  private buildBackIcon() {
    TgIcon({
      src: TgUiTokens.ICON_RES_BACK,
      iconSize: TgUiTokens.FORWARD_PICKER_NAV_ICON_SIZE,
      tintColor: TgUiTokens.COLOR_ICON_PRIMARY
    })
  }

  @Builder
  private buildTitleContent() {
    Text(this.title)
      .fontSize(TgUiTokens.FORWARD_PICKER_NAV_TITLE_SIZE)
      .fontWeight(FontWeight.Medium)
      .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
      .maxLines(1)
      .textAlign(TextAlign.Center)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Builder
  private buildTrailingContent() {
    Text(this.trailingTitle)
      .fontSize(TgUiTokens.FORWARD_PICKER_NAV_ACTION_SIZE)
      .fontWeight(FontWeight.Medium)
      .fontColor(TgUiTokens.COLOR_ICON_PRIMARY)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeBackCapsule() {
    Row() {
      this.buildBackIcon()
    }
    .width(TgUiTokens.FORWARD_PICKER_NAV_CONTROL_SIZE)
    .height(TgUiTokens.FORWARD_PICKER_NAV_CONTROL_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      colorInvert: true,
      applyShadow: true,
      interactive: true
    }))
    .borderRadius(TgUiTokens.FORWARD_PICKER_NAV_CONTROL_RADIUS)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.88 })
    .responseRegion({
      x: this.responseRegionOffset(),
      y: this.responseRegionOffset(),
      width: TgUiTokens.FORWARD_PICKER_NAV_RESPONSE_SIZE,
      height: TgUiTokens.FORWARD_PICKER_NAV_RESPONSE_SIZE
    })
    .accessibilityText(this.backAccessibilityText)
    .onClick(() => this.onBackPress())
  }

  @Builder
  private buildFallbackBackCapsule() {
    Row() {
      this.buildBackIcon()
    }
    .width(TgUiTokens.FORWARD_PICKER_NAV_CONTROL_SIZE)
    .height(TgUiTokens.FORWARD_PICKER_NAV_CONTROL_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.capsuleBackground())
    .backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
    .border({ width: TgUiTokens.FORWARD_PICKER_NAV_BORDER_WIDTH, color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER })
    .borderRadius(TgUiTokens.FORWARD_PICKER_NAV_CONTROL_RADIUS)
    .clip(true)
    .renderGroup(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.88 })
    .responseRegion({
      x: this.responseRegionOffset(),
      y: this.responseRegionOffset(),
      width: TgUiTokens.FORWARD_PICKER_NAV_RESPONSE_SIZE,
      height: TgUiTokens.FORWARD_PICKER_NAV_RESPONSE_SIZE
    })
    .accessibilityText(this.backAccessibilityText)
    .onClick(() => this.onBackPress())
  }

  @Builder
  private buildBackCapsule() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.useNativeMaterial()) {
        this.buildNativeBackCapsule()
      } else {
        this.buildFallbackBackCapsule()
      }
    } else {
      this.buildFallbackBackCapsule()
    }
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeTrailingCapsule() {
    Row() {
      this.buildTrailingContent()
    }
    .width(LayoutPolicy.wrapContent)
    .height(TgUiTokens.FORWARD_PICKER_NAV_CONTROL_SIZE)
    .constraintSize({
      minWidth: TgUiTokens.FORWARD_PICKER_NAV_ACTION_MIN_WIDTH,
      maxWidth: TgUiTokens.FORWARD_PICKER_NAV_ACTION_MAX_WIDTH
    })
    .padding({
      left: TgUiTokens.FORWARD_PICKER_NAV_ACTION_PADDING_H,
      right: TgUiTokens.FORWARD_PICKER_NAV_ACTION_PADDING_H
    })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      colorInvert: true,
      applyShadow: true,
      interactive: true
    }))
    .borderRadius(TgUiTokens.FORWARD_PICKER_NAV_CONTROL_RADIUS)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
    .responseRegion({
      x: 0,
      y: this.responseRegionOffset(),
      width: '100%',
      height: TgUiTokens.FORWARD_PICKER_NAV_RESPONSE_SIZE
    })
    .opacity(this.trailingEnabled ? 1 : TgUiTokens.FORWARD_PICKER_NAV_ACTION_DISABLED_OPACITY)
    .enabled(this.trailingEnabled)
    .accessibilityText(this.trailingAccessibilityText.length > 0
      ? this.trailingAccessibilityText : this.trailingTitle)
    .onClick(() => {
      if (this.trailingEnabled) {
        this.onTrailingPress();
      }
    })
  }

  @Builder
  private buildFallbackTrailingCapsule() {
    Row() {
      this.buildTrailingContent()
    }
    .width(LayoutPolicy.wrapContent)
    .height(TgUiTokens.FORWARD_PICKER_NAV_CONTROL_SIZE)
    .constraintSize({
      minWidth: TgUiTokens.FORWARD_PICKER_NAV_ACTION_MIN_WIDTH,
      maxWidth: TgUiTokens.FORWARD_PICKER_NAV_ACTION_MAX_WIDTH
    })
    .padding({
      left: TgUiTokens.FORWARD_PICKER_NAV_ACTION_PADDING_H,
      right: TgUiTokens.FORWARD_PICKER_NAV_ACTION_PADDING_H
    })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.capsuleBackground())
    .backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
    .border({ width: TgUiTokens.FORWARD_PICKER_NAV_BORDER_WIDTH, color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER })
    .borderRadius(TgUiTokens.FORWARD_PICKER_NAV_CONTROL_RADIUS)
    .clip(true)
    .renderGroup(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
    .responseRegion({
      x: 0,
      y: this.responseRegionOffset(),
      width: '100%',
      height: TgUiTokens.FORWARD_PICKER_NAV_RESPONSE_SIZE
    })
    .opacity(this.trailingEnabled ? 1 : TgUiTokens.FORWARD_PICKER_NAV_ACTION_DISABLED_OPACITY)
    .enabled(this.trailingEnabled)
    .accessibilityText(this.trailingAccessibilityText.length > 0
      ? this.trailingAccessibilityText : this.trailingTitle)
    .onClick(() => {
      if (this.trailingEnabled) {
        this.onTrailingPress();
      }
    })
  }

  @Builder
  private buildTrailingCapsule() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.useNativeMaterial()) {
        this.buildNativeTrailingCapsule()
      } else {
        this.buildFallbackTrailingCapsule()
      }
    } else {
      this.buildFallbackTrailingCapsule()
    }
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeTitleCapsule() {
    Row() {
      this.buildTitleContent()
    }
    .width(LayoutPolicy.wrapContent)
    .height(TgUiTokens.FORWARD_PICKER_NAV_TITLE_HEIGHT)
    .constraintSize({
      minWidth: TgUiTokens.FORWARD_PICKER_NAV_TITLE_MIN_WIDTH,
      maxWidth: this.titleMaxWidth()
    })
    .padding({
      left: TgUiTokens.FORWARD_PICKER_NAV_TITLE_PADDING_H,
      right: TgUiTokens.FORWARD_PICKER_NAV_TITLE_PADDING_H
    })
    .justifyContent(FlexAlign.Center)
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true,
      interactive: false
    }))
    .borderRadius(TgUiTokens.FORWARD_PICKER_NAV_TITLE_RADIUS)
    .clip(true)
  }

  @Builder
  private buildFallbackTitleCapsule() {
    Row() {
      this.buildTitleContent()
    }
    .width(LayoutPolicy.wrapContent)
    .height(TgUiTokens.FORWARD_PICKER_NAV_TITLE_HEIGHT)
    .constraintSize({
      minWidth: TgUiTokens.FORWARD_PICKER_NAV_TITLE_MIN_WIDTH,
      maxWidth: this.titleMaxWidth()
    })
    .padding({
      left: TgUiTokens.FORWARD_PICKER_NAV_TITLE_PADDING_H,
      right: TgUiTokens.FORWARD_PICKER_NAV_TITLE_PADDING_H
    })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.capsuleBackground())
    .backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
    .border({ width: TgUiTokens.FORWARD_PICKER_NAV_BORDER_WIDTH, color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER })
    .borderRadius(TgUiTokens.FORWARD_PICKER_NAV_TITLE_RADIUS)
    .clip(true)
    .renderGroup(true)
  }

  @Builder
  private buildTitleCapsule() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.useNativeMaterial()) {
        this.buildNativeTitleCapsule()
      } else {
        this.buildFallbackTitleCapsule()
      }
    } else {
      this.buildFallbackTitleCapsule()
    }
  }

  build() {
    Column() {
      Row()
        .width('100%')
        .height(this.effectiveTopInset() + TgUiTokens.FORWARD_PICKER_NAV_TOP_GAP)

      Stack({ alignContent: Alignment.Center }) {
        this.buildTitleCapsule()

        Row() {
          this.buildBackCapsule()
          Blank()
          if (this.hasTrailingAction()) {
            this.buildTrailingCapsule()
          }
        }
        .width('100%')
        .height(TgUiTokens.FORWARD_PICKER_NAV_TITLE_HEIGHT)
        .padding({
          left: TgUiTokens.FORWARD_PICKER_NAV_SIDE_INSET,
          right: TgUiTokens.FORWARD_PICKER_NAV_SIDE_INSET
        })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height(TgUiTokens.FORWARD_PICKER_NAV_TITLE_HEIGHT)

      Row()
        .width('100%')
        .height(TgUiTokens.FORWARD_PICKER_NAV_BOTTOM_GAP)
    }
    .width('100%')
    .backgroundColor(Color.Transparent)
  }
}
