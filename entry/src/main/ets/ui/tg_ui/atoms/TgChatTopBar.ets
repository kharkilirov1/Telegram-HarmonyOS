import { uiMaterial } from '@kit.ArkUI';
import { Available, deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { chatTopBarContentTransition } from '../utils/TgChatTopBarMotionPolicy';
import { TgAvatar } from './TgAvatar';
import { TgIcon } from './TgIcon';

export const TG_CHAT_SEARCH_INPUT_ID: string = 'tg_chat_search_input';

export enum TgChatTopBarSubtitleMode {
  Secondary = 'secondary',
  Online = 'online',
  Activity = 'activity',
}

export enum TgChatTopBarTrailingAction {
  None = 'none',
  Search = 'search',
  Avatar = 'avatar',
}

@ComponentV2
export struct TgChatTopBar {
  @Param title: string = '';
  @Param subtitle: string = '';
  @Param subtitleMode: TgChatTopBarSubtitleMode = TgChatTopBarSubtitleMode.Secondary;
  @Param showSubtitleSpinner: boolean = false;
  @Param avatarInitials: string = '';
  @Param avatarColorIndex: number = 0;
  @Param avatarImageSrc: string = '';
  @Param isOnline: boolean = false;
  @Param trailingAction: TgChatTopBarTrailingAction = TgChatTopBarTrailingAction.Search;
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;
  @Param isSearchMode: boolean = false;
  @Param searchQuery: string = '';
  @Param searchPlaceholder: string = 'Search';
  @Param topInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;

  @Event onBackPress: () => void = (): void => {};
  @Event onTitlePress: () => void = (): void => {};
  @Event onAvatarPress: () => void = (): void => {};
  @Event onSearchPress: () => void = (): void => {};
  @Event onSearchQueryChange: (query: string) => void = (_query: string): void => {};
  @Event onSearchClose: () => void = (): void => {};

  private useBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  private useNativeMaterial(): boolean {
    return TgGlassPolicy.supportsNativeMaterial() && this.useBlur();
  }

  private capsuleBg(): ResourceColor {
    return this.useBlur() ? TgUiTokens.CHAT_TOP_BAR_SCROLL_CAPSULE_BG : TgUiTokens.CHAT_TOP_BAR_CAPSULE_FALLBACK_BG;
  }

  // Real within-app glass: backdropBlur samples the actual content behind the
  // capsule (timeline + fade band). backgroundBlurStyle collapses to an opaque
  // plate on emulator GPU paths, so fallback capsules blur the backdrop.
  private capsuleBackdropBlur(): number {
    return this.useBlur() ? TgUiTokens.GLASS_CAPSULE_BACKDROP_BLUR : 0;
  }

  private responseRegionOffset(): number {
    return (TgUiTokens.CHAT_TOP_BAR_CONTROL_SIZE - TgUiTokens.CHAT_TOP_BAR_RESPONSE_SIZE) / 2;
  }

  private avatarColor(): Resource {
    const palette: Resource[] = [
      TgUiTokens.AVATAR_COLOR_1, TgUiTokens.AVATAR_COLOR_2,
      TgUiTokens.AVATAR_COLOR_3, TgUiTokens.AVATAR_COLOR_4,
      TgUiTokens.AVATAR_COLOR_5, TgUiTokens.AVATAR_COLOR_6,
      TgUiTokens.AVATAR_COLOR_7, TgUiTokens.AVATAR_COLOR_8,
    ];
    return palette[Math.abs(this.avatarColorIndex) % palette.length];
  }

  private subtitleColor(): ResourceColor {
    switch (this.subtitleMode) {
      case TgChatTopBarSubtitleMode.Online:
      case TgChatTopBarSubtitleMode.Activity:
        return TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT;
      default:
        return TgUiTokens.COLOR_TEXT_PREVIEW;
    }
  }

  @Builder
  private buildBackIcon() {
    TgIcon({
      src: TgUiTokens.ICON_RES_BACK,
      iconSize: TgUiTokens.CHAT_TOP_BAR_ACTION_ICON_SIZE,
      tintColor: TgUiTokens.CHAT_TOP_BAR_ACTION_FOREGROUND
    })
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeBackCapsule() {
    Row() {
      this.buildBackIcon()
    }
    .width(TgUiTokens.CHAT_TOP_BAR_CONTROL_SIZE)
    .height(TgUiTokens.CHAT_TOP_BAR_CONTROL_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      colorInvert: true,
      applyShadow: true,
      interactive: true
    }))
    .borderRadius(TgUiTokens.CHAT_TOP_BAR_CONTROL_RADIUS)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.88 })
    .responseRegion({
      x: this.responseRegionOffset(),
      y: this.responseRegionOffset(),
      width: TgUiTokens.CHAT_TOP_BAR_RESPONSE_SIZE,
      height: TgUiTokens.CHAT_TOP_BAR_RESPONSE_SIZE
    })
    .onClick(() => this.onBackPress())
  }

  @Builder
  private buildFallbackBackCapsule() {
    Row() {
      this.buildBackIcon()
    }
    .width(TgUiTokens.CHAT_TOP_BAR_CONTROL_SIZE)
    .height(TgUiTokens.CHAT_TOP_BAR_CONTROL_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.capsuleBg())
    .backdropBlur(this.capsuleBackdropBlur())
    .border({ width: TgUiTokens.CHAT_TOP_BAR_BORDER_WIDTH, color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER })
    .borderRadius(TgUiTokens.CHAT_TOP_BAR_CONTROL_RADIUS)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.88 })
    .responseRegion({
      x: this.responseRegionOffset(),
      y: this.responseRegionOffset(),
      width: TgUiTokens.CHAT_TOP_BAR_RESPONSE_SIZE,
      height: TgUiTokens.CHAT_TOP_BAR_RESPONSE_SIZE
    })
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

  @Builder
  private buildTitleContent() {
    Column() {
      Text(this.title)
        .fontSize(TgUiTokens.CHAT_TOP_BAR_TITLE_SIZE)
        .fontWeight(TgUiTokens.CHAT_TOP_BAR_TITLE_WEIGHT)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .maxLines(1)
        .textAlign(TextAlign.Center)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.subtitle.length > 0) {
        Row({ space: TgUiTokens.CHAT_TOP_BAR_SPINNER_GAP }) {
          if (this.showSubtitleSpinner) {
            LoadingProgress()
              .width(TgUiTokens.CHAT_TOP_BAR_SPINNER_SIZE)
              .height(TgUiTokens.CHAT_TOP_BAR_SPINNER_SIZE)
              .color(this.subtitleColor())
          }
          Text(this.subtitle)
            .fontSize(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_SIZE)
            .fontColor(this.subtitleColor())
            .maxLines(1)
            .textAlign(TextAlign.Center)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .transition(chatTopBarContentTransition())
      }
    }
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeTitleCapsule() {
    Column() {
      this.buildTitleContent()
    }
    .width(LayoutPolicy.wrapContent)
    .height(TgUiTokens.CHAT_TOP_BAR_TITLE_HEIGHT)
    .constraintSize({ minWidth: TgUiTokens.CHAT_TOP_BAR_TITLE_MIN_WIDTH, maxWidth: '100%' })
    .padding({
      left: TgUiTokens.CHAT_TOP_BAR_TITLE_PADDING_H,
      right: TgUiTokens.CHAT_TOP_BAR_TITLE_PADDING_H
    })
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true,
      interactive: false
    }))
    .borderRadius(TgUiTokens.CHAT_TOP_BAR_TITLE_RADIUS)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
    .onClick(() => {
      hilog.info(0x0021, 'TgChatTopBar', 'title tapped');
      this.onTitlePress();
    })
  }

  @Builder
  private buildFallbackTitleCapsule() {
    Column() {
      this.buildTitleContent()
    }
    .width(LayoutPolicy.wrapContent)
    .height(TgUiTokens.CHAT_TOP_BAR_TITLE_HEIGHT)
    .constraintSize({ minWidth: TgUiTokens.CHAT_TOP_BAR_TITLE_MIN_WIDTH, maxWidth: '100%' })
    .padding({
      left: TgUiTokens.CHAT_TOP_BAR_TITLE_PADDING_H,
      right: TgUiTokens.CHAT_TOP_BAR_TITLE_PADDING_H
    })
    .backgroundColor(this.capsuleBg())
    .backdropBlur(this.capsuleBackdropBlur())
    .border({ width: TgUiTokens.CHAT_TOP_BAR_BORDER_WIDTH, color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER })
    .borderRadius(TgUiTokens.CHAT_TOP_BAR_TITLE_RADIUS)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
    .onClick(() => {
      hilog.info(0x0021, 'TgChatTopBar', 'title tapped');
      this.onTitlePress();
    })
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

  @Builder
  private buildSearchActionIcon() {
    TgIcon({
      src: TgUiTokens.ICON_RES_SEARCH,
      iconSize: TgUiTokens.CHAT_TOP_BAR_ACTION_ICON_SIZE,
      tintColor: TgUiTokens.CHAT_TOP_BAR_ACTION_FOREGROUND
    })
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeSearchActionCapsule() {
    Row() {
      this.buildSearchActionIcon()
    }
    .width(TgUiTokens.CHAT_TOP_BAR_CONTROL_SIZE)
    .height(TgUiTokens.CHAT_TOP_BAR_CONTROL_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      colorInvert: true,
      applyShadow: true,
      interactive: true
    }))
    .borderRadius(TgUiTokens.CHAT_TOP_BAR_CONTROL_RADIUS)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.88 })
    .responseRegion({
      x: this.responseRegionOffset(),
      y: this.responseRegionOffset(),
      width: TgUiTokens.CHAT_TOP_BAR_RESPONSE_SIZE,
      height: TgUiTokens.CHAT_TOP_BAR_RESPONSE_SIZE
    })
    .onClick(() => this.onSearchPress())
  }

  @Builder
  private buildFallbackSearchActionCapsule() {
    Row() {
      this.buildSearchActionIcon()
    }
    .width(TgUiTokens.CHAT_TOP_BAR_CONTROL_SIZE)
    .height(TgUiTokens.CHAT_TOP_BAR_CONTROL_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.capsuleBg())
    .backdropBlur(this.capsuleBackdropBlur())
    .border({ width: TgUiTokens.CHAT_TOP_BAR_BORDER_WIDTH, color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER })
    .borderRadius(TgUiTokens.CHAT_TOP_BAR_CONTROL_RADIUS)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.88 })
    .responseRegion({
      x: this.responseRegionOffset(),
      y: this.responseRegionOffset(),
      width: TgUiTokens.CHAT_TOP_BAR_RESPONSE_SIZE,
      height: TgUiTokens.CHAT_TOP_BAR_RESPONSE_SIZE
    })
    .onClick(() => this.onSearchPress())
  }

  @Builder
  private buildSearchActionCapsule() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.useNativeMaterial()) {
        this.buildNativeSearchActionCapsule()
      } else {
        this.buildFallbackSearchActionCapsule()
      }
    } else {
      this.buildFallbackSearchActionCapsule()
    }
  }

  @Builder
  private buildAvatarContent() {
    TgAvatar({
      avatarSize: TgUiTokens.CHAT_TOP_BAR_AVATAR_INNER,
      initials: this.avatarInitials,
      useImage: this.avatarImageSrc.length > 0,
      imageSrc: this.avatarImageSrc,
      isOnline: this.isOnline,
      avatarBackgroundColor: this.avatarColor()
    })
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeAvatarCapsule() {
    Row() {
      this.buildAvatarContent()
    }
    .width(TgUiTokens.CHAT_TOP_BAR_CONTROL_SIZE)
    .height(TgUiTokens.CHAT_TOP_BAR_CONTROL_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      colorInvert: true,
      applyShadow: true,
      interactive: true
    }))
    .borderRadius(TgUiTokens.CHAT_TOP_BAR_CONTROL_RADIUS)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.88 })
    .responseRegion({
      x: this.responseRegionOffset(),
      y: this.responseRegionOffset(),
      width: TgUiTokens.CHAT_TOP_BAR_RESPONSE_SIZE,
      height: TgUiTokens.CHAT_TOP_BAR_RESPONSE_SIZE
    })
    .onClick(() => {
      hilog.info(0x0021, 'TgChatTopBar', 'avatar tapped');
      this.onAvatarPress();
    })
  }

  @Builder
  private buildFallbackAvatarCapsule() {
    Row() {
      this.buildAvatarContent()
    }
    .width(TgUiTokens.CHAT_TOP_BAR_CONTROL_SIZE)
    .height(TgUiTokens.CHAT_TOP_BAR_CONTROL_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.capsuleBg())
    .backdropBlur(this.capsuleBackdropBlur())
    .border({ width: TgUiTokens.CHAT_TOP_BAR_BORDER_WIDTH, color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER })
    .borderRadius(TgUiTokens.CHAT_TOP_BAR_CONTROL_RADIUS)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.88 })
    .responseRegion({
      x: this.responseRegionOffset(),
      y: this.responseRegionOffset(),
      width: TgUiTokens.CHAT_TOP_BAR_RESPONSE_SIZE,
      height: TgUiTokens.CHAT_TOP_BAR_RESPONSE_SIZE
    })
    .onClick(() => {
      hilog.info(0x0021, 'TgChatTopBar', 'avatar tapped');
      this.onAvatarPress();
    })
  }

  @Builder
  private buildAvatarCapsule() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.useNativeMaterial()) {
        this.buildNativeAvatarCapsule()
      } else {
        this.buildFallbackAvatarCapsule()
      }
    } else {
      this.buildFallbackAvatarCapsule()
    }
  }

  @Builder
  private buildSearchFieldContent() {
    Row() {
      TgIcon({
        src: TgUiTokens.ICON_RES_SEARCH,
        iconSize: TgUiTokens.CHAT_TOP_BAR_ACTION_ICON_SIZE,
        tintColor: TgUiTokens.COLOR_TEXT_PREVIEW
      })
      TextInput({ text: this.searchQuery, placeholder: this.searchPlaceholder })
        .id(TG_CHAT_SEARCH_INPUT_ID)
        .layoutWeight(1)
        .height(TgUiTokens.CHAT_TOP_BAR_TITLE_HEIGHT)
        .fontSize(TgUiTokens.CHAT_TOP_BAR_TITLE_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .placeholderColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .backgroundColor(Color.Transparent)
        .padding({ left: TgUiTokens.CHAT_TOP_BAR_CAPSULE_GAP, right: TgUiTokens.CHAT_TOP_BAR_CAPSULE_GAP })
        .caretColor(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
        .defaultFocus(true)
        .onChange((value: string) => this.onSearchQueryChange(value))
      TgIcon({
        src: TgUiTokens.ICON_RES_CLOSE,
        iconSize: TgUiTokens.CHAT_TOP_BAR_ACTION_ICON_SIZE,
        tintColor: TgUiTokens.CHAT_TOP_BAR_ACTION_FOREGROUND
      })
        .onClick(() => this.onSearchClose())
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      left: TgUiTokens.CHAT_TOP_BAR_TITLE_PADDING_H,
      right: TgUiTokens.CHAT_TOP_BAR_TITLE_PADDING_H
    })
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeSearchCapsule() {
    Row() {
      this.buildSearchFieldContent()
    }
    .height(TgUiTokens.CHAT_TOP_BAR_TITLE_HEIGHT)
    .layoutWeight(1)
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true,
      interactive: false
    }))
    .borderRadius(TgUiTokens.CHAT_TOP_BAR_TITLE_RADIUS)
    .clip(true)
  }

  @Builder
  private buildFallbackSearchCapsule() {
    Row() {
      this.buildSearchFieldContent()
    }
    .height(TgUiTokens.CHAT_TOP_BAR_TITLE_HEIGHT)
    .layoutWeight(1)
    .backgroundColor(this.capsuleBg())
    .backdropBlur(this.capsuleBackdropBlur())
    .border({ width: TgUiTokens.CHAT_TOP_BAR_BORDER_WIDTH, color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER })
    .borderRadius(TgUiTokens.CHAT_TOP_BAR_TITLE_RADIUS)
    .clip(true)
  }

  @Builder
  private buildSearchCapsule() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.useNativeMaterial()) {
        this.buildNativeSearchCapsule()
      } else {
        this.buildFallbackSearchCapsule()
      }
    } else {
      this.buildFallbackSearchCapsule()
    }
  }

  // iOS-style progressive blur: content scrolling under the bar dissolves into
  // a fading blur+scrim band instead of stopping on a hard plate edge.
  // GradientDirection names the travel side (stop-0 opposite): Bottom +
  // ascending stops render STRONG at the very top edge, ZERO at the bottom.
  // Frost is tiered so content stays readable behind the title row (iOS
  // reference: heavy frost only over the status strip, medium across the bar).
  @Builder
  private buildFadeBackdrop() {
    Column() {
      Column()
        .width('100%')
        .height(this.topInset)
        .backdropBlur(this.useBlur() ? TgUiTokens.CHROME_FADE_BLUR_STRONG : 0)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            [TgUiTokens.CHROME_FADE_STRONG, 0],
            [TgUiTokens.CHROME_FADE_MID, 1]
          ]
        })

      Column()
        .width('100%')
        .height(TgUiTokens.CHAT_TOP_BAR_TITLE_HEIGHT + TgUiTokens.TOP_BAR_BOTTOM_PADDING)
        .backdropBlur(this.useBlur() ? TgUiTokens.CHROME_FADE_BLUR_MID : 0)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            [TgUiTokens.CHROME_FADE_MID, 0],
            [TgUiTokens.CHROME_FADE_WEAK, 1]
          ]
        })

      Column()
        .width('100%')
        .height(TgUiTokens.CHROME_FADE_ZONE_HEIGHT)
        .backdropBlur(this.useBlur() ? TgUiTokens.CHROME_FADE_BLUR_SOFT : 0)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            [TgUiTokens.CHROME_FADE_WEAK, 0],
            [TgUiTokens.CHROME_FADE_ZERO, 1]
          ]
        })
    }
    .width('100%')
    .hitTestBehavior(HitTestMode.None)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildFadeBackdrop()

      Column() {
        Row().width('100%').height(this.topInset)

        Row({ space: TgUiTokens.CHAT_TOP_BAR_CAPSULE_GAP }) {
          this.buildBackCapsule()

          if (this.isSearchMode) {
            Row() {
              this.buildSearchCapsule()
            }
            .layoutWeight(1)
            .height(TgUiTokens.CHAT_TOP_BAR_TITLE_HEIGHT)
            .transition(chatTopBarContentTransition())
          } else {
            Row() {
              this.buildTitleCapsule()
            }
            .layoutWeight(1)
            .height(TgUiTokens.CHAT_TOP_BAR_TITLE_HEIGHT)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .padding({
              left: TgUiTokens.CHAT_TOP_BAR_CAPSULE_GAP,
              right: TgUiTokens.CHAT_TOP_BAR_CAPSULE_GAP
            })
            .transition(chatTopBarContentTransition())

            if (this.trailingAction === TgChatTopBarTrailingAction.Avatar) {
              this.buildAvatarCapsule()
            } else if (this.trailingAction === TgChatTopBarTrailingAction.Search) {
              this.buildSearchActionCapsule()
            } else {
              Blank()
                .width(TgUiTokens.CHAT_TOP_BAR_CONTROL_SIZE)
                .height(TgUiTokens.CHAT_TOP_BAR_CONTROL_SIZE)
                .hitTestBehavior(HitTestMode.None)
            }
          }
        }
        .height(TgUiTokens.CHAT_TOP_BAR_TITLE_HEIGHT)
        .width('100%')
        .padding({ left: TgUiTokens.TOP_BAR_SIDE_PADDING, right: TgUiTokens.TOP_BAR_SIDE_PADDING })
        .alignItems(VerticalAlign.Center)
        .animation({ duration: TgUiTokens.CHAT_TOP_BAR_MOTION_MS, curve: Curve.Smooth })
      }
      .width('100%')
      .padding({ bottom: TgUiTokens.TOP_BAR_BOTTOM_PADDING })
    }
    .width('100%')
  }
}
