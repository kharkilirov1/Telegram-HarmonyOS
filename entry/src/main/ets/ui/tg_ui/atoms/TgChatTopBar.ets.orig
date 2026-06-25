// TgChatTopBar — iOS-style capsule chat navigation bar
// Layout: [← Back ○]  [Title capsule (content-width)]  [Avatar ○]
// Title capsule stays centered between side controls.

import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgIcon } from './TgIcon';
import { TgAvatar } from './TgAvatar';
import { TgTopChromeBackground } from './TgTopChromeBackground';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

declare function px2vp(value: number): number;

export enum TgChatTopBarSubtitleMode {
  Secondary = 'secondary',
  Online = 'online',
  Activity = 'activity',
}

@ComponentV2
export struct TgChatTopBar {
  @Param title: string = '';
  @Param subtitle: string = '';
  @Param subtitleMode: TgChatTopBarSubtitleMode = TgChatTopBarSubtitleMode.Secondary;
  @Param avatarInitials: string = '';
  @Param avatarColorIndex: number = 0;
  @Param avatarImageSrc: string = '';
  @Param isOnline: boolean = false;
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;
  @Param isSearchMode: boolean = false;
  @Param searchQuery: string = '';

  @Event onBackPress: () => void = (): void => {};
  @Event onTitlePress: () => void = (): void => {};
  @Event onAvatarPress: () => void = (): void => {};
  @Event onSearchPress: () => void = (): void => {};
  @Event onSearchQueryChange: (query: string) => void = (_query: string): void => {};
  @Event onSearchClose: () => void = (): void => {};

  @Local topInset: number = 0;

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

  private useBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  private capsuleBg(): ResourceColor {
    return this.useBlur() ? TgUiTokens.CHAT_TOP_BAR_CAPSULE_BG : TgUiTokens.CHAT_TOP_BAR_CAPSULE_FALLBACK_BG;
  }

  private capsuleBlurStyle(): BlurStyle {
    return this.useBlur() ? BlurStyle.COMPONENT_ULTRA_THIN : BlurStyle.NONE;
  }

  private avatarColor(): Resource {
    const palette: Resource[] = [
      TgUiTokens.AVATAR_COLOR_1, TgUiTokens.AVATAR_COLOR_2,
      TgUiTokens.AVATAR_COLOR_3, TgUiTokens.AVATAR_COLOR_4,
      TgUiTokens.AVATAR_COLOR_5, TgUiTokens.AVATAR_COLOR_6,
      TgUiTokens.AVATAR_COLOR_7, TgUiTokens.AVATAR_COLOR_8,
    ];
    const idx = Math.abs(this.avatarColorIndex) % palette.length;
    return palette[idx];
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
  private buildBackCapsule() {
    Row() {
      TgIcon({
        src: TgUiTokens.ICON_RES_BACK,
        iconSize: TgUiTokens.TOP_BAR_ACTION_ICON_SIZE,
        tintColor: TgUiTokens.COLOR_ICON_PRIMARY
      })
    }
    .width(TgUiTokens.CHAT_TOP_BAR_CAPSULE_SIZE)
    .height(TgUiTokens.CHAT_TOP_BAR_CAPSULE_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.capsuleBg())
    .backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
    .borderRadius(TgUiTokens.CHAT_TOP_BAR_CAPSULE_RADIUS)
    .border({ width: TgUiTokens.CHAT_TOP_BAR_BORDER_WIDTH, color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER })
    .clip(true)
    .renderGroup(true)
    .onClick(() => {
      this.onBackPress();
    })
  }

  @Builder
  private buildTitleCapsule() {
    // Title capsule hugs content width — Column drives the width, Stack wraps it
    Column() {
      Text(this.title)
        .fontSize(TgUiTokens.CHAT_TOP_BAR_TITLE_SIZE)
        .fontWeight(TgUiTokens.CHAT_TOP_BAR_TITLE_WEIGHT)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .maxLines(1)
        .textAlign(TextAlign.Center)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.subtitle.length > 0) {
        Text(this.subtitle)
          .fontSize(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_SIZE)
          .fontColor(this.subtitleColor())
          .maxLines(1)
          .textAlign(TextAlign.Center)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .height(TgUiTokens.CHAT_TOP_BAR_CAPSULE_SIZE)
    .constraintSize({ minWidth: TgUiTokens.CHAT_TOP_BAR_TITLE_MIN_WIDTH })
    .padding({
      left: TgUiTokens.CHAT_TOP_BAR_TITLE_PADDING_H,
      right: TgUiTokens.CHAT_TOP_BAR_TITLE_PADDING_H
    })
    .backgroundColor(this.capsuleBg())
    .backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
    .borderRadius(TgUiTokens.CHAT_TOP_BAR_CAPSULE_RADIUS)
    .border({ width: TgUiTokens.CHAT_TOP_BAR_BORDER_WIDTH, color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER })
    .clip(true)
    .renderGroup(true)
    .onClick(() => {
      this.onTitlePress();
    })
  }

  @Builder
  private buildSearchCapsule() {
    // iOS ref: inline search field replaces title capsule, same glass capsule shape
    Row() {
      TextInput({ text: this.searchQuery, placeholder: 'Search' })
        .layoutWeight(1)
        .height(TgUiTokens.CHAT_TOP_BAR_CAPSULE_SIZE - 8)
        .fontSize(TgUiTokens.CHAT_TOP_BAR_TITLE_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .placeholderColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .backgroundColor(Color.Transparent)
        .padding({ left: 4, right: 4 })
        .caretColor(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
        .defaultFocus(true)
        .onChange((value: string) => {
          this.onSearchQueryChange(value);
        })

      TgIcon({
        src: $r('app.media.ic_close'),
        iconSize: 18,
        tintColor: TgUiTokens.COLOR_ICON_PRIMARY
      })
        .onClick(() => {
          this.onSearchClose();
        })
        .margin({ right: 4 })
    }
    .height(TgUiTokens.CHAT_TOP_BAR_CAPSULE_SIZE)
    .layoutWeight(1)
    .padding({
      left: TgUiTokens.CHAT_TOP_BAR_TITLE_PADDING_H,
      right: 8
    })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.capsuleBg())
    .backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
    .borderRadius(TgUiTokens.CHAT_TOP_BAR_CAPSULE_RADIUS)
    .border({ width: TgUiTokens.CHAT_TOP_BAR_BORDER_WIDTH, color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER })
    .clip(true)
    .renderGroup(true)
  }

  @Builder
  private buildAvatarCapsule() {
    Row() {
      TgAvatar({
        avatarSize: TgUiTokens.CHAT_TOP_BAR_AVATAR_INNER,
        initials: this.avatarInitials,
        useImage: this.avatarImageSrc.length > 0,
        imageSrc: this.avatarImageSrc,
        isOnline: this.isOnline,
        avatarBackgroundColor: this.avatarColor()
      })
    }
    .width(TgUiTokens.CHAT_TOP_BAR_CAPSULE_SIZE)
    .height(TgUiTokens.CHAT_TOP_BAR_CAPSULE_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.capsuleBg())
    .backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
    .borderRadius(TgUiTokens.CHAT_TOP_BAR_CAPSULE_RADIUS)
    .border({ width: TgUiTokens.CHAT_TOP_BAR_BORDER_WIDTH, color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER })
    .clip(true)
    .renderGroup(true)
    .onClick(() => {
      this.onAvatarPress();
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      TgTopChromeBackground({
        topInset: this.topInset,
        contentHeight: TgUiTokens.CHAT_TOP_BAR_CAPSULE_SIZE + TgUiTokens.TOP_BAR_BOTTOM_PADDING,
        glassMode: this.glassMode,
        showBottomSeparator: false,
        showTopEdgeEmphasis: this.useBlur()
      })

      Column() {
        Row()
          .width('100%')
          .height(this.topInset)

        Row() {
          this.buildBackCapsule()

          if (this.isSearchMode) {
            // Search mode: search field replaces title + avatar (iOS pattern)
            this.buildSearchCapsule()
          } else {
            Row() {
              this.buildTitleCapsule()
            }
            .layoutWeight(1)
            .height(TgUiTokens.CHAT_TOP_BAR_CAPSULE_SIZE)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .padding({
              left: TgUiTokens.CHAT_TOP_BAR_CAPSULE_GAP,
              right: TgUiTokens.CHAT_TOP_BAR_CAPSULE_GAP
            })

            this.buildAvatarCapsule()
          }
        }
        .height(TgUiTokens.CHAT_TOP_BAR_CAPSULE_SIZE)
        .width('100%')
        .padding({ left: TgUiTokens.TOP_BAR_SIDE_PADDING, right: TgUiTokens.TOP_BAR_SIDE_PADDING })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ bottom: TgUiTokens.TOP_BAR_BOTTOM_PADDING })
      .backgroundColor(Color.Transparent)
    }
    .width('100%')
  }
}
