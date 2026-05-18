import { TgSettingsRow, TgSettingsTrailing } from '../atoms/TgSettingsRow';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgSettingsRow' })
@ComponentV2
export struct TgSettingsRowDemo {
  @Local private notificationsEnabled: boolean = true;

  build() {
    Column() {
      TgSettingsRow({
        title: 'Notifications and Sounds',
        iconRes: TgUiTokens.ICON_RES_MIC,
        iconBgColor: TgUiTokens.SETTINGS_ICON_COLOR_RED,
        trailingType: TgSettingsTrailing.Arrow
      })

      TgSettingsRow({
        title: 'Language',
        iconRes: TgUiTokens.ICON_RES_SEARCH,
        iconBgColor: TgUiTokens.SETTINGS_ICON_COLOR_PURPLE,
        trailingType: TgSettingsTrailing.Text,
        trailingText: 'English'
      })

      TgSettingsRow({
        title: 'Enable Notifications',
        iconRes: TgUiTokens.ICON_RES_CHAT,
        iconBgColor: TgUiTokens.SETTINGS_ICON_COLOR_BLUE,
        trailingType: TgSettingsTrailing.Toggle,
        toggleValue: this.notificationsEnabled,
        onToggleChange: (value: boolean): void => {
          this.notificationsEnabled = value;
        }
      })

      TgSettingsRow({
        title: 'Version',
        iconRes: TgUiTokens.ICON_RES_DOCUMENT,
        iconBgColor: TgUiTokens.SETTINGS_ICON_COLOR_GREEN,
        trailingType: TgSettingsTrailing.None,
        showSeparator: false
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .padding({ top: TgUiTokens.SPACE_16 })
  }
}
