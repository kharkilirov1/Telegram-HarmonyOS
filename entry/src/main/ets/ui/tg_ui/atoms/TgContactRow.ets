import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgAvatar } from './TgAvatar';
import { TgIcon } from './TgIcon';

@ComponentV2
export struct TgContactRow {
  @Param name: string = '';
  @Param initials: string = '';
  @Param statusText: string = '';
  @Param avatarPath: string = '';
  @Param isOnline: boolean = false;
  @Param showSeparator: boolean = true;
  @Param avatarBgColor: ResourceColor = TgUiTokens.COLOR_AVATAR_PLACEHOLDER_BG;
  @Param rowHeight: number = TgUiTokens.CONTACT_ROW_HEIGHT;
  @Param contentGap: number = TgUiTokens.CONTACT_ROW_GAP;
  @Param statusFontSize: number = TgUiTokens.CONTACT_ROW_STATUS_SIZE;
  @Param separatorInset: number = TgUiTokens.CONTACT_ROW_SEPARATOR_INSET;
  @Param showSelection: boolean = false;
  @Param isSelected: boolean = false;

  @Event onPress: () => void = (): void => {};

  @Builder
  private buildSelectionIndicator() {
    Row() {
      if (this.isSelected) {
        TgIcon({
          src: TgUiTokens.ICON_RES_CHECK,
          iconSize: TgUiTokens.COMPOSE_SELECTION_INDICATOR_ICON_SIZE,
          tintColor: TgUiTokens.COLOR_UNREAD_TEXT
        })
      }
    }
    .width(TgUiTokens.COMPOSE_SELECTION_INDICATOR_SIZE)
    .height(TgUiTokens.COMPOSE_SELECTION_INDICATOR_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.isSelected ? TgUiTokens.COLOR_ICON_PRIMARY : Color.Transparent)
    .border({
      width: TgUiTokens.COMPOSE_SELECTION_INDICATOR_STROKE,
      color: this.isSelected ? TgUiTokens.COLOR_ICON_PRIMARY : TgUiTokens.COLOR_ICON_SECONDARY
    })
    .borderRadius(TgUiTokens.COMPOSE_SELECTION_INDICATOR_SIZE / 2)
    .margin({ left: TgUiTokens.SPACE_8 })
  }

  build() {
    Column() {
      Row() {
        TgAvatar({
          avatarSize: TgUiTokens.CONTACT_ROW_AVATAR_SIZE,
          initials: this.initials,
          useImage: this.avatarPath.length > 0,
          imageSrc: this.avatarPath,
          isOnline: this.isOnline,
          avatarBackgroundColor: this.avatarBgColor
        })

        Column() {
          Text(this.name)
            .fontSize(TgUiTokens.CONTACT_ROW_NAME_SIZE)
            .fontWeight(FontWeight.Regular)
            .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.statusText.length > 0) {
            Text(this.statusText)
              .fontSize(this.statusFontSize)
              .fontColor(this.isOnline ? TgUiTokens.COLOR_ONLINE_DOT : TgUiTokens.COLOR_TEXT_PREVIEW)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: TgUiTokens.SPACE_2 })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: this.contentGap })

        if (this.showSelection) {
          this.buildSelectionIndicator()
        }
      }
      .width('100%')
      .height(this.rowHeight)
      .padding({
        left: TgUiTokens.CONTACT_ROW_PADDING_H,
        right: TgUiTokens.CONTACT_ROW_INDEXER_END_PADDING
      })
      .alignItems(VerticalAlign.Center)

      if (this.showSeparator) {
        Row()
          .width('100%')
          .height(TgUiTokens.CONTACT_ROW_SEPARATOR_STROKE)
          .backgroundColor(TgUiTokens.COLOR_SEPARATOR)
          .margin({ left: this.separatorInset })
      }
    }
    .width('100%')
    .onClick(() => {
      this.onPress();
    })
  }
}
