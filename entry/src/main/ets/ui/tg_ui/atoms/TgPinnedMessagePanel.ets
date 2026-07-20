import { uiMaterial } from '@kit.ArkUI';
import { Available, deviceInfo } from '@kit.BasicServicesKit';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { TgIcon } from './TgIcon';

@ComponentV2
export struct TgPinnedMessagePanel {
  @Param title: string = 'Pinned Message';
  @Param preview: string = '';
  @Param index: number = 0;
  @Param totalCount: number = 1;
  @Param hasThumbnail: boolean = false;
  @Param thumbnailSrc: Resource | string = $r('app.media.app_icon_transparent');
  @Param showTrailingAction: boolean = true;
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;

  @Event onPress: () => void = (): void => {};
  @Event onClosePress: () => void = (): void => {};
  @Event onListPress: () => void = (): void => {};

  private useBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  private useNativeMaterial(): boolean {
    return deviceInfo.apiAvailable('26.0.0') && this.useBlur();
  }

  private capsuleBg(): ResourceColor {
    return this.useBlur() ? TgUiTokens.CHAT_TOP_BAR_CAPSULE_BG : TgUiTokens.CHAT_TOP_BAR_CAPSULE_FALLBACK_BG;
  }

  private capsuleBlurStyle(): BlurStyle {
    return this.useBlur() ? BlurStyle.COMPONENT_ULTRA_THIN : BlurStyle.NONE;
  }

  private safeTotalCount(): number {
    return Math.max(1, this.totalCount);
  }

  private safeIndex(): number {
    return Math.max(0, Math.min(this.index, this.safeTotalCount() - 1));
  }

  private activeStripeHeight(): number {
    return Math.max(
      TgUiTokens.PINNED_PANEL_STRIPE_MIN_SEGMENT,
      TgUiTokens.PINNED_PANEL_HEIGHT / this.safeTotalCount()
    );
  }

  private activeStripeOffset(): number {
    const available = TgUiTokens.PINNED_PANEL_HEIGHT - this.activeStripeHeight();
    if (this.safeTotalCount() === 1) {
      return 0;
    }
    return available * this.safeIndex() / (this.safeTotalCount() - 1);
  }

  @Builder
  private buildNavigationStripe() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row()
        .width(TgUiTokens.PINNED_PANEL_STRIPE_WIDTH)
        .height(TgUiTokens.PINNED_PANEL_HEIGHT)
        .backgroundColor(TgUiTokens.COLOR_SEPARATOR)
        .borderRadius(TgUiTokens.PINNED_PANEL_STRIPE_WIDTH / 2)

      Row()
        .width(TgUiTokens.PINNED_PANEL_STRIPE_WIDTH)
        .height(this.activeStripeHeight())
        .backgroundColor(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
        .borderRadius(TgUiTokens.PINNED_PANEL_STRIPE_WIDTH / 2)
        .position({ x: 0, y: this.activeStripeOffset() })
    }
    .width(TgUiTokens.PINNED_PANEL_STRIPE_WIDTH)
    .height(TgUiTokens.PINNED_PANEL_HEIGHT)
    .flexShrink(0)
  }

  @Builder
  private buildTextContent() {
    Row() {
      this.buildNavigationStripe()

      if (this.hasThumbnail) {
        Image(this.thumbnailSrc)
          .width(TgUiTokens.PINNED_PANEL_THUMB_SIZE)
          .height(TgUiTokens.PINNED_PANEL_THUMB_SIZE)
          .objectFit(ImageFit.Cover)
          .borderRadius(TgUiTokens.PINNED_PANEL_THUMB_RADIUS)
          .clip(true)
          .margin({ left: TgUiTokens.PINNED_PANEL_THUMB_GAP })
      }

      Column() {
        Text(this.title)
          .fontSize(TgUiTokens.PINNED_PANEL_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
          .lineHeight(TgUiTokens.PINNED_PANEL_TEXT_LINE_HEIGHT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.preview)
          .fontSize(TgUiTokens.PINNED_PANEL_PREVIEW_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .lineHeight(TgUiTokens.PINNED_PANEL_TEXT_LINE_HEIGHT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
      .margin({ left: TgUiTokens.PINNED_PANEL_STRIPE_GAP })
    }
    .layoutWeight(1)
    .height(TgUiTokens.PINNED_PANEL_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.onPress())
  }

  @Builder
  private buildTrailingAction() {
    Row() {
      if (this.safeTotalCount() > 1) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(TgUiTokens.PINNED_PANEL_ACTION_ICON_SIZE)
          .fontColor([TgUiTokens.COLOR_ICON_PRIMARY])
      } else {
        TgIcon({
          src: TgUiTokens.ICON_RES_CLOSE,
          iconSize: TgUiTokens.PINNED_PANEL_ACTION_ICON_SIZE,
          tintColor: TgUiTokens.COLOR_ICON_PRIMARY
        })
      }
    }
    .width(TgUiTokens.PINNED_PANEL_ACTION_SIZE)
    .height(TgUiTokens.PINNED_PANEL_HEIGHT)
    .flexShrink(0)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .responseRegion({
      x: (TgUiTokens.PINNED_PANEL_ACTION_SIZE - TgUiTokens.PINNED_PANEL_RESPONSE_SIZE) / 2,
      y: (TgUiTokens.PINNED_PANEL_HEIGHT - TgUiTokens.PINNED_PANEL_RESPONSE_SIZE) / 2,
      width: TgUiTokens.PINNED_PANEL_RESPONSE_SIZE,
      height: TgUiTokens.PINNED_PANEL_RESPONSE_SIZE
    })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.88 })
    .onClick(() => {
      if (this.safeTotalCount() > 1) {
        this.onListPress();
      } else {
        this.onClosePress();
      }
    })
  }

  @Builder
  private buildSurfaceContent() {
    Row() {
      this.buildTextContent()
      if (this.showTrailingAction) {
        this.buildTrailingAction()
      }
    }
    .width('100%')
    .height(TgUiTokens.PINNED_PANEL_HEIGHT)
    .padding({
      left: TgUiTokens.PINNED_PANEL_CONTENT_LEFT,
      right: TgUiTokens.PINNED_PANEL_CONTENT_RIGHT
    })
    .alignItems(VerticalAlign.Center)
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeSurface() {
    Row() {
      this.buildSurfaceContent()
    }
    .width('100%')
    .height(TgUiTokens.PINNED_PANEL_HEIGHT)
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true,
      interactive: false
    }))
    .borderRadius(TgUiTokens.PINNED_PANEL_RADIUS)
    .clip(true)
  }

  @Builder
  private buildFallbackSurface() {
    Row() {
      this.buildSurfaceContent()
    }
    .width('100%')
    .height(TgUiTokens.PINNED_PANEL_HEIGHT)
    .backgroundColor(this.capsuleBg())
    .backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
    .border({ width: TgUiTokens.PINNED_PANEL_BORDER_WIDTH, color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER })
    .borderRadius(TgUiTokens.PINNED_PANEL_RADIUS)
    .clip(true)
    .renderGroup(true)
  }

  @Builder
  private buildSurface() {
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

  build() {
    Row() {
      this.buildSurface()
    }
    .width('100%')
    .padding({
      left: TgUiTokens.PINNED_PANEL_SIDE_INSET,
      right: TgUiTokens.PINNED_PANEL_SIDE_INSET
    })
  }
}
