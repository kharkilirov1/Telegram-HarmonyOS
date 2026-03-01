// TgSettingsRow — Settings row with colored icon + title + trailing (Phase E-3).
// Trailing types: arrow (chevron), text value, toggle switch, or none.

import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgIcon } from './TgIcon';

export enum TgSettingsTrailing {
  None = 0,
  Arrow = 1,
  Text = 2,
  Toggle = 3
}

@ComponentV2
export struct TgSettingsRow {
  @Param title: string = '';
  @Param iconRes: Resource = TgUiTokens.ICON_RES_SETTINGS;
  @Param iconBgColor: ResourceColor = $r('app.color.settings_icon_blue');
  @Param trailingType: TgSettingsTrailing = TgSettingsTrailing.Arrow;
  @Param trailingText: string = '';
  @Param toggleValue: boolean = false;
  @Param showSeparator: boolean = true;

  @Event onToggleChange: (value: boolean) => void = (_: boolean) => {};
  @Event onRowClick: () => void = () => {};

  @Builder
  private buildIconBox() {
    Row() {
      TgIcon({
        src: this.iconRes,
        iconSize: TgUiTokens.SETTINGS_ROW_ICON_SIZE,
        tintColor: Color.White
      })
    }
    .width(TgUiTokens.SETTINGS_ROW_ICON_BOX_SIZE)
    .height(TgUiTokens.SETTINGS_ROW_ICON_BOX_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.iconBgColor)
    .borderRadius(TgUiTokens.SETTINGS_ROW_ICON_RADIUS)
  }

  @Builder
  private buildTrailing() {
    if (this.trailingType === TgSettingsTrailing.Arrow) {
      Row() {
        TgIcon({
          src: TgUiTokens.ICON_RES_ARROW_RIGHT,
          iconSize: TgUiTokens.SETTINGS_ROW_ARROW_SIZE,
          tintColor: TgUiTokens.SETTINGS_ROW_ARROW_COLOR
        })
      }
    } else if (this.trailingType === TgSettingsTrailing.Text) {
      Row() {
        Text(this.trailingText)
          .fontSize(TgUiTokens.SETTINGS_ROW_TRAILING_SIZE)
          .fontColor(TgUiTokens.SETTINGS_ROW_TRAILING_COLOR)
          .maxLines(1)

        TgIcon({
          src: TgUiTokens.ICON_RES_ARROW_RIGHT,
          iconSize: TgUiTokens.SETTINGS_ROW_ARROW_SIZE,
          tintColor: TgUiTokens.SETTINGS_ROW_ARROW_COLOR
        })
          .margin({ left: TgUiTokens.SPACE_4 })
      }
      .alignItems(VerticalAlign.Center)
    } else if (this.trailingType === TgSettingsTrailing.Toggle) {
      Toggle({ type: ToggleType.Switch, isOn: this.toggleValue })
        .onChange((isOn: boolean) => {
          this.onToggleChange(isOn);
        })
    }
  }

  build() {
    Column() {
      Row() {
        this.buildIconBox()

        Text(this.title)
          .fontSize(TgUiTokens.SETTINGS_ROW_TITLE_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: TgUiTokens.SETTINGS_ROW_GAP })

        this.buildTrailing()
      }
      .width('100%')
      .height(TgUiTokens.SETTINGS_ROW_HEIGHT)
      .padding({
        left: TgUiTokens.SETTINGS_ROW_PADDING_H,
        right: TgUiTokens.SETTINGS_ROW_PADDING_H
      })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.onRowClick();
      })

      if (this.showSeparator) {
        Row()
          .width('100%')
          .height(TgUiTokens.SETTINGS_ROW_SEPARATOR_STROKE)
          .backgroundColor(TgUiTokens.COLOR_SEPARATOR)
          .margin({ left: TgUiTokens.SETTINGS_ROW_SEPARATOR_INSET })
      }
    }
    .width('100%')
  }
}
