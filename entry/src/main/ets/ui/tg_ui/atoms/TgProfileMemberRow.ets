import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgAvatar } from './TgAvatar';

export type TgProfileMemberRoleKind = 'creator' | 'administrator' | 'member';

@ComponentV2
export struct TgProfileMemberRow {
  @Param title: string = '';
  @Param subtitle: string = '';
  @Param avatarInitials: string = '';
  @Param avatarImageSrc: string = '';
  @Param avatarColor: ResourceColor = TgUiTokens.COLOR_AVATAR_PLACEHOLDER_BG;
  @Param isOnline: boolean = false;
  @Param roleLabel: string = '';
  @Param roleKind: TgProfileMemberRoleKind = 'member';
  @Param showSeparator: boolean = true;
  @Param isEnabled: boolean = true;

  @Event onPress: () => void = (): void => {};

  private roleTextColor(): ResourceColor {
    if (this.roleKind === 'creator') {
      return TgUiTokens.PROFILE_MEMBER_OWNER_TEXT;
    }
    if (this.roleKind === 'administrator') {
      return TgUiTokens.PROFILE_MEMBER_ADMIN_TEXT;
    }
    return TgUiTokens.COLOR_TEXT_PREVIEW;
  }

  private roleBackgroundColor(): ResourceColor {
    if (this.roleKind === 'creator') {
      return TgUiTokens.PROFILE_MEMBER_OWNER_BG;
    }
    if (this.roleKind === 'administrator') {
      return TgUiTokens.PROFILE_MEMBER_ADMIN_BG;
    }
    return Color.Transparent;
  }

  build() {
    Column() {
      Row() {
        TgAvatar({
          avatarSize: TgUiTokens.PROFILE_MEMBER_AVATAR_SIZE,
          initials: this.avatarInitials,
          useImage: this.avatarImageSrc.length > 0,
          imageSrc: this.avatarImageSrc,
          isOnline: this.isOnline,
          avatarBackgroundColor: this.avatarColor,
          textColor: TgUiTokens.COLOR_AVATAR_PLACEHOLDER_TEXT,
          onlineDotBorderColor: TgUiTokens.COLOR_BG_PRIMARY
        })

        Column({ space: 1 }) {
          Text(this.title)
            .fontSize(TgUiTokens.PROFILE_MEMBER_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.subtitle)
            .fontSize(TgUiTokens.PROFILE_MEMBER_STATUS_SIZE)
            .fontColor(this.isOnline ? TgUiTokens.COLOR_ICON_PRIMARY : TgUiTokens.COLOR_TEXT_PREVIEW)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: TgUiTokens.PROFILE_MEMBER_CONTENT_GAP })

        if (this.roleLabel.length > 0) {
          Text(this.roleLabel)
            .fontSize(TgUiTokens.PROFILE_MEMBER_ROLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.roleTextColor())
            .maxLines(1)
            .padding({
              left: TgUiTokens.PROFILE_MEMBER_ROLE_HORIZONTAL_INSET,
              right: TgUiTokens.PROFILE_MEMBER_ROLE_HORIZONTAL_INSET,
              top: TgUiTokens.PROFILE_MEMBER_ROLE_VERTICAL_INSET,
              bottom: TgUiTokens.PROFILE_MEMBER_ROLE_VERTICAL_INSET
            })
            .backgroundColor(this.roleBackgroundColor())
            .borderRadius(TgUiTokens.PROFILE_MEMBER_ROLE_RADIUS)
            .margin({ left: 6 })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .padding({
        left: TgUiTokens.PROFILE_MEMBER_SIDE_INSET,
        right: TgUiTokens.PROFILE_MEMBER_SIDE_INSET
      })
      .alignItems(VerticalAlign.Center)

      if (this.showSeparator) {
        Divider()
          .strokeWidth(0.5)
          .color(TgUiTokens.COLOR_SEPARATOR)
          .margin({ left: TgUiTokens.PROFILE_MEMBER_SEPARATOR_INSET })
      }
    }
    .width('100%')
    .height(TgUiTokens.PROFILE_MEMBER_ROW_HEIGHT)
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .opacity(this.isEnabled ? 1 : 0.72)
    .onClick((): void => {
      if (this.isEnabled) {
        this.onPress();
      }
    })
  }
}
