import { TgSettingsSection } from '../atoms/TgSettingsSection';
import { TgSettingsRow, TgSettingsTrailing } from '../atoms/TgSettingsRow';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgSettingsSectionDemo {
  @Local private autoDownload: boolean = true;

  build() {
    Scroll() {
      Column() {
        TgSettingsSection({
          header: 'Account',
          footer: 'Primary profile actions and shortcuts.'
        }) {
          TgSettingsRow({
            title: 'Saved Messages',
            iconRes: TgUiTokens.ICON_RES_CHAT,
            iconBgColor: TgUiTokens.SETTINGS_ICON_COLOR_BLUE,
            trailingType: TgSettingsTrailing.Arrow
          })
          TgSettingsRow({
            title: 'Recent Calls',
            iconRes: TgUiTokens.ICON_RES_PHONE_CALL,
            iconBgColor: TgUiTokens.SETTINGS_ICON_COLOR_GREEN,
            trailingType: TgSettingsTrailing.Arrow,
            showSeparator: false
          })
        }

        TgSettingsSection({
          header: 'Data and Storage',
          footer: 'Control network, media, and local storage behavior.'
        }) {
          TgSettingsRow({
            title: 'Auto-Download Media',
            iconRes: TgUiTokens.ICON_RES_DOCUMENT,
            iconBgColor: TgUiTokens.SETTINGS_ICON_COLOR_GREEN,
            trailingType: TgSettingsTrailing.Toggle,
            toggleValue: this.autoDownload,
            onToggleChange: (value: boolean): void => {
              this.autoDownload = value;
            }
          })
          TgSettingsRow({
            title: 'Language',
            iconRes: TgUiTokens.ICON_RES_SEARCH,
            iconBgColor: TgUiTokens.SETTINGS_ICON_COLOR_PURPLE,
            trailingType: TgSettingsTrailing.Text,
            trailingText: 'English',
            showSeparator: false
          })
        }
      }
      .width('100%')
      .padding({ bottom: TgUiTokens.SPACE_16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
  }
}
