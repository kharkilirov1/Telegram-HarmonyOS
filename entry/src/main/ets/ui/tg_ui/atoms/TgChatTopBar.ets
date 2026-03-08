import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { TgIcon } from './TgIcon';
import { TgAvatar } from './TgAvatar';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

declare function px2vp(value: number): number;

@ComponentV2
export struct TgChatTopBar {
  // Data
  @Param title: string = '';
  @Param subtitle: string = '';
  @Param avatarInitials: string = '';
  @Param avatarColorIndex: number = 0;
  @Param avatarImageSrc: string = '';
  @Param isOnline: boolean = false;
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;

  // Events
  @Event onBackPress: () => void = (): void => {};
  @Event onTitlePress: () => void = (): void => {};
  @Event onAvatarPress: () => void = (): void => {};

  // Internal
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
    return TgGlassPolicy.topBarBlurStyle();
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

  @Builder
  private buildGlassSpecular() {
    if (this.useBlur()) {
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
    .backgroundBlurStyle(this.capsuleBlurStyle())
    .borderRadius(TgUiTokens.CHAT_TOP_BAR_CAPSULE_RADIUS)
    .border({ width: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER_WIDTH, color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER })
    .overlay(this.buildGlassSpecular())
    .clip(true)
    .onClick(() => {
      this.onBackPress();
    })
  }

  @Builder
  private buildTitleCapsule() {
    Column() {
      Text(this.title)
        .fontSize(TgUiTokens.TOP_BAR_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.subtitle.length > 0) {
        Text(this.subtitle)
          .fontSize(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_SIZE)
          .fontColor(this.isOnline ? TgUiTokens.COLOR_ICON_PRIMARY : TgUiTokens.COLOR_TEXT_PREVIEW)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .height(TgUiTokens.CHAT_TOP_BAR_CAPSULE_SIZE)
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: TgUiTokens.CHAT_TOP_BAR_TITLE_PADDING_H, right: TgUiTokens.CHAT_TOP_BAR_TITLE_PADDING_H })
    .backgroundColor(this.capsuleBg())
    .backgroundBlurStyle(this.capsuleBlurStyle())
    .borderRadius(TgUiTokens.CHAT_TOP_BAR_CAPSULE_RADIUS)
    .border({ width: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER_WIDTH, color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER })
    .overlay(this.buildGlassSpecular())
    .clip(true)
    .onClick(() => {
      this.onTitlePress();
    })
  }

  @Builder
  private buildAvatarCapsule() {
    Row() {
      TgAvatar({
        avatarSize: TgUiTokens.CHAT_TOP_BAR_AVATAR_INNER,
        initials: this.avatarInitials,
        useImage: this.avatarImageSrc.length > 0,
        imageSrc: this.avatarImageSrc,
        isOnline: false,
        avatarBackgroundColor: this.avatarColor()
      })
    }
    .width(TgUiTokens.CHAT_TOP_BAR_CAPSULE_SIZE)
    .height(TgUiTokens.CHAT_TOP_BAR_CAPSULE_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.capsuleBg())
    .backgroundBlurStyle(this.capsuleBlurStyle())
    .borderRadius(TgUiTokens.CHAT_TOP_BAR_CAPSULE_RADIUS)
    .border({ width: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER_WIDTH, color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER })
    .overlay(this.buildGlassSpecular())
    .clip(true)
    .onClick(() => {
      this.onAvatarPress();
    })
  }

  build() {
    Column() {
      // Status bar spacer
      Row()
        .width('100%')
        .height(this.topInset)

      // Content row: [back] [title] [avatar]
      Row({ space: TgUiTokens.CHAT_TOP_BAR_CAPSULE_GAP }) {
        this.buildBackCapsule()
        this.buildTitleCapsule()
        this.buildAvatarCapsule()
      }
      .height(TgUiTokens.CHAT_TOP_BAR_CAPSULE_SIZE)
      .width('100%')
      .padding({ left: TgUiTokens.SPACE_12, right: TgUiTokens.SPACE_12 })
    }
    .width('100%')
    .backgroundColor(Color.Transparent)
  }
}
