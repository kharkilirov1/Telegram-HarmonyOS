import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgAvatar {
  @Param avatarSize: number = TgUiTokens.AVATAR_SIZE_DEFAULT;
  @Param initials: string = 'TG';
  @Param useImage: boolean = false;
  @Param imageSrc: Resource | string = $r('app.media.app_icon_transparent');
  @Param isOnline: boolean = false;

  @Param avatarBackgroundColor: ResourceColor = TgUiTokens.COLOR_AVATAR_PLACEHOLDER_BG;
  @Param textColor: ResourceColor = TgUiTokens.COLOR_AVATAR_PLACEHOLDER_TEXT;
  @Param onlineDotColor: ResourceColor = TgUiTokens.COLOR_ONLINE_DOT;
  @Param onlineDotBorderColor: ResourceColor = TgUiTokens.COLOR_BG_PRIMARY;

  private normalizedInitials(): string {
    const trimmed = this.initials.trim();
    if (trimmed.length === 0) {
      return 'TG';
    }
    return trimmed.substring(0, 2).toUpperCase();
  }

  private initialsFontSize(): number {
    if (this.avatarSize <= TgUiTokens.AVATAR_SIZE_SM) {
      return TgUiTokens.FONT_AVATAR_INITIALS_SIZE_SM;
    }
    if (this.avatarSize <= TgUiTokens.AVATAR_SIZE_MD) {
      return TgUiTokens.FONT_AVATAR_INITIALS_SIZE_MD;
    }
    return TgUiTokens.FONT_AVATAR_INITIALS_SIZE_LG;
  }

  @Builder
  private buildAvatarContent() {
    if (this.useImage) {
      Image(this.imageSrc)
        .width(this.avatarSize)
        .height(this.avatarSize)
        .objectFit(ImageFit.Cover)
        .borderRadius(TgUiTokens.RADIUS_ROUND_MAX)
    } else {
      Row() {
        Text(this.normalizedInitials())
          .fontSize(this.initialsFontSize())
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
      }
      .width(this.avatarSize)
      .height(this.avatarSize)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.avatarBackgroundColor)
      .borderRadius(TgUiTokens.RADIUS_ROUND_MAX)
    }
  }

  @Builder
  private buildOnlineIndicator() {
    Row()
      .width(TgUiTokens.AVATAR_ONLINE_DOT_SIZE)
      .height(TgUiTokens.AVATAR_ONLINE_DOT_SIZE)
      .backgroundColor(this.onlineDotColor)
      .borderRadius(TgUiTokens.RADIUS_ROUND_MAX)
      .border({
        width: TgUiTokens.AVATAR_ONLINE_DOT_BORDER,
        color: this.onlineDotBorderColor
      })
      .translate({
        x: TgUiTokens.AVATAR_ONLINE_DOT_OFFSET_X,
        y: TgUiTokens.AVATAR_ONLINE_DOT_OFFSET_Y
      })
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      this.buildAvatarContent()

      if (this.isOnline) {
        this.buildOnlineIndicator()
      }
    }
    .width(this.avatarSize)
    .height(this.avatarSize)
  }
}
