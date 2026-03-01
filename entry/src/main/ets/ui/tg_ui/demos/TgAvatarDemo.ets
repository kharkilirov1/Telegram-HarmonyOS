import { TgAvatar } from '../atoms/TgAvatar';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgAvatarDemo {
  build() {
    Column() {
      Text('TgAvatar Demo')
        .fontSize(TgUiTokens.FONT_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .width('100%')
        .padding({
          left: TgUiTokens.SPACE_16,
          right: TgUiTokens.SPACE_16,
          top: TgUiTokens.SPACE_16,
          bottom: TgUiTokens.SPACE_8
        })

      Row() {
        Text('01 Placeholder / default offline')
          .layoutWeight(1)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
        TgAvatar({
          avatarSize: TgUiTokens.AVATAR_SIZE_DEFAULT,
          initials: 'MK',
          isOnline: false
        })
      }
      .width('100%')
      .padding({
        left: TgUiTokens.SPACE_16,
        right: TgUiTokens.SPACE_16,
        top: TgUiTokens.SPACE_8,
        bottom: TgUiTokens.SPACE_8
      })
      .alignItems(VerticalAlign.Center)

      Row() {
        Text('02 Placeholder / default online')
          .layoutWeight(1)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
        TgAvatar({
          avatarSize: TgUiTokens.AVATAR_SIZE_DEFAULT,
          initials: 'MK',
          isOnline: true
        })
      }
      .width('100%')
      .padding({
        left: TgUiTokens.SPACE_16,
        right: TgUiTokens.SPACE_16,
        top: TgUiTokens.SPACE_8,
        bottom: TgUiTokens.SPACE_8
      })
      .alignItems(VerticalAlign.Center)

      Row() {
        Text('03 Placeholder / medium online')
          .layoutWeight(1)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
        TgAvatar({
          avatarSize: TgUiTokens.AVATAR_SIZE_MD,
          initials: 'QA',
          isOnline: true
        })
      }
      .width('100%')
      .padding({
        left: TgUiTokens.SPACE_16,
        right: TgUiTokens.SPACE_16,
        top: TgUiTokens.SPACE_8,
        bottom: TgUiTokens.SPACE_8
      })
      .alignItems(VerticalAlign.Center)

      Row() {
        Text('04 Placeholder / small offline')
          .layoutWeight(1)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
        TgAvatar({
          avatarSize: TgUiTokens.AVATAR_SIZE_SM,
          initials: 'AL',
          isOnline: false
        })
      }
      .width('100%')
      .padding({
        left: TgUiTokens.SPACE_16,
        right: TgUiTokens.SPACE_16,
        top: TgUiTokens.SPACE_8,
        bottom: TgUiTokens.SPACE_8
      })
      .alignItems(VerticalAlign.Center)

      Row() {
        Text('05 Long initials normalization')
          .layoutWeight(1)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
        TgAvatar({
          avatarSize: TgUiTokens.AVATAR_SIZE_DEFAULT,
          initials: 'Alexander',
          isOnline: false
        })
      }
      .width('100%')
      .padding({
        left: TgUiTokens.SPACE_16,
        right: TgUiTokens.SPACE_16,
        top: TgUiTokens.SPACE_8,
        bottom: TgUiTokens.SPACE_8
      })
      .alignItems(VerticalAlign.Center)

      Row() {
        Text('06 Initials centering matrix')
          .layoutWeight(1)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
        Row({ space: TgUiTokens.SPACE_4 }) {
          TgAvatar({
            avatarSize: TgUiTokens.AVATAR_SIZE_SM,
            initials: 'A'
          })
          TgAvatar({
            avatarSize: TgUiTokens.AVATAR_SIZE_SM,
            initials: 'MW'
          })
          TgAvatar({
            avatarSize: TgUiTokens.AVATAR_SIZE_SM,
            initials: 'Ж'
          })
          TgAvatar({
            avatarSize: TgUiTokens.AVATAR_SIZE_SM,
            initials: 'И'
          })
          TgAvatar({
            avatarSize: TgUiTokens.AVATAR_SIZE_SM,
            initials: '12'
          })
        }
      }
      .width('100%')
      .padding({
        left: TgUiTokens.SPACE_16,
        right: TgUiTokens.SPACE_16,
        top: TgUiTokens.SPACE_8,
        bottom: TgUiTokens.SPACE_8
      })
      .alignItems(VerticalAlign.Center)

      Row() {
        Text('07 Image / offline')
          .layoutWeight(1)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
        TgAvatar({
          avatarSize: TgUiTokens.AVATAR_SIZE_DEFAULT,
          useImage: true,
          imageSrc: $r('app.media.app_icon'),
          isOnline: false
        })
      }
      .width('100%')
      .padding({
        left: TgUiTokens.SPACE_16,
        right: TgUiTokens.SPACE_16,
        top: TgUiTokens.SPACE_8,
        bottom: TgUiTokens.SPACE_8
      })
      .alignItems(VerticalAlign.Center)

      Row() {
        Text('08 Image / online')
          .layoutWeight(1)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
        TgAvatar({
          avatarSize: TgUiTokens.AVATAR_SIZE_DEFAULT,
          useImage: true,
          imageSrc: $r('app.media.app_icon'),
          isOnline: true
        })
      }
      .width('100%')
      .padding({
        left: TgUiTokens.SPACE_16,
        right: TgUiTokens.SPACE_16,
        top: TgUiTokens.SPACE_8,
        bottom: TgUiTokens.SPACE_8
      })
      .alignItems(VerticalAlign.Center)

      Row() {
        Text('09 Custom colors')
          .layoutWeight(1)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
        TgAvatar({
          avatarSize: TgUiTokens.AVATAR_SIZE_MD,
          initials: 'TG',
          avatarBackgroundColor: TgUiTokens.COLOR_ICON_PRIMARY,
          textColor: TgUiTokens.COLOR_UNREAD_TEXT,
          isOnline: true
        })
      }
      .width('100%')
      .padding({
        left: TgUiTokens.SPACE_16,
        right: TgUiTokens.SPACE_16,
        top: TgUiTokens.SPACE_8,
        bottom: TgUiTokens.SPACE_8
      })
      .alignItems(VerticalAlign.Center)

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}
