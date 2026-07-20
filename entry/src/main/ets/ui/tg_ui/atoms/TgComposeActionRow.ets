import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgIcon } from './TgIcon';

// Telegram iOS ContactListActionItem counterpart for Compose actions.
// Routing and TDLib behavior stay page-owned; this atom owns row geometry only.
@ComponentV2
export struct TgComposeActionRow {
  @Param title: string = '';
  @Param icon: Resource = TgUiTokens.ICON_RES_CONTACT_ADD;
  @Param showSeparator: boolean = true;

  @Event onPress: () => void = (): void => {};

  build() {
    Column() {
      Row() {
        Row() {
          TgIcon({
            src: this.icon,
            iconSize: TgUiTokens.COMPOSE_ACTION_ICON_SIZE,
            tintColor: TgUiTokens.COLOR_ICON_PRIMARY
          })
        }
        .width(TgUiTokens.COMPOSE_ACTION_ICON_LANE_WIDTH)
        .height(TgUiTokens.COMPOSE_ACTION_ROW_HEIGHT)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        Text(this.title)
          .layoutWeight(1)
          .fontSize(TgUiTokens.COMPOSE_ACTION_TITLE_SIZE)
          .fontWeight(FontWeight.Regular)
          .fontColor(TgUiTokens.COLOR_ICON_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(TgUiTokens.COMPOSE_ACTION_ROW_HEIGHT)
      .padding({ right: TgUiTokens.SPACE_16 })
      .alignItems(VerticalAlign.Center)

      if (this.showSeparator) {
        Row()
          .width('100%')
          .height(TgUiTokens.CONTACT_ROW_SEPARATOR_STROKE)
          .backgroundColor(TgUiTokens.COLOR_SEPARATOR)
          .margin({ left: TgUiTokens.COMPOSE_ACTION_SEPARATOR_INSET })
      }
    }
    .width('100%')
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.99 })
    .accessibilityText(this.title)
    .onClick((): void => this.onPress())
  }
}
