// SettingsPage — Settings tab (Phase E-5)
// Stack overlay: scroll content under translucent TgTopBar
// iOS insetGrouped style with inline tokenized section containers + TgSettingsRow

import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState, User } from '../../../core/model/AppState';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgTopBar } from '../../tg_ui/atoms/TgTopBar';
import { TgAvatar } from '../../tg_ui/atoms/TgAvatar';
import { TgSettingsRow, TgSettingsTrailing } from '../../tg_ui/atoms/TgSettingsRow';
import { fileUri } from '@kit.CoreFileKit';
import { localized } from '../../../core/utils/AppResource';
import { computeTopBarHeight, computeTabBottomInset, getMainWindow, removeWindowSizeListener } from '../../utils/SafeAreaUtils';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0x0032;
const TAG = 'SettingsPage';

@ComponentV2
export struct SettingsPage {
  @Local private userName: string = '';
  @Local private userPhone: string = '';
  @Local private userInitials: string = 'ME';
  @Local private userPhoto: string = '';
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private contentBottomInset: number = TgUiTokens.TAB_BAR_CONTENT_SAFE_BOTTOM;

  private unsubscribe?: () => void;
  private mainWindow?: window.Window;

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'SettingsPage aboutToAppear');
    this.computeSafeInsets();
    this.bindWindowSizeListener();

    try {
      const runtime = getAppCoreRuntime();
      const store = runtime.getStore();
      this.loadCurrentUser(store.getState());

      this.unsubscribe = store.subscribe((_newState: AppState, _prevState: AppState) => {
        try {
          const currentState = getAppCoreRuntime().getStore().getState();
          this.loadCurrentUser(currentState);
        } catch (e) {
          hilog.error(DOMAIN, TAG, 'Load user failed: %{public}s', String(e));
        }
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Init failed: %{public}s', String(e));
    }
  }

  aboutToDisappear(): void {
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    removeWindowSizeListener(this.mainWindow);
    this.mainWindow = undefined;
  }

  private bindWindowSizeListener(): void {
    try {
      removeWindowSizeListener(this.mainWindow);
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.mainWindow = getMainWindow(context);
      if (this.mainWindow !== undefined) {
        this.mainWindow.on('windowSizeChange', (_size: window.Size) => {
          this.computeSafeInsets();
        });
      }
    } catch (_error) {
      this.mainWindow = undefined;
    }
  }

  private computeSafeInsets(): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.topBarTotalHeight = computeTopBarHeight(context);
      this.contentBottomInset = computeTabBottomInset(context);
    } catch (_error) {
      this.topBarTotalHeight = TgUiTokens.TOP_BAR_HEIGHT;
      this.contentBottomInset = TgUiTokens.TAB_BAR_CONTENT_SAFE_BOTTOM;
    }
  }

  private loadCurrentUser(state: AppState): void {
    const userId = state.auth.userId;
    if (userId <= 0) {
      return;
    }
    const user: User | undefined = state.users.users.get(userId);
    if (!user) {
      return;
    }
    const full = (user.firstName + ' ' + user.lastName).trim();
    this.userName = full.length > 0
      ? full
      : (user.username.length > 0 ? '@' + user.username : localized($r('app.string.profile_title').id, 'User'));
    this.userPhone = user.phoneNumber.length > 0 ? '+' + user.phoneNumber : '';
    this.userPhoto = user.photoSmall.length > 0 ? fileUri.getUriFromPath(user.photoSmall) : '';

    const first = user.firstName.length > 0 ? user.firstName.charAt(0) : '';
    const last = user.lastName.length > 0 ? user.lastName.charAt(0) : '';
    this.userInitials = first.length > 0 ? (first + last).toUpperCase() : 'ME';
  }

  @Builder
  private buildProfileHeader() {
    Row() {
      TgAvatar({
        avatarSize: 60,
        initials: this.userInitials,
        useImage: this.userPhoto.length > 0,
        imageSrc: this.userPhoto
      })

      Column() {
        Text(this.userName)
          .fontSize(TgUiTokens.SETTINGS_PROFILE_NAME_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.userPhone.length > 0) {
          Text(this.userPhone)
            .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            .margin({ top: TgUiTokens.SPACE_2 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: TgUiTokens.SPACE_16 })
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SETTINGS_SECTION_SIDE_INSET,
      right: TgUiTokens.SETTINGS_SECTION_SIDE_INSET,
      top: TgUiTokens.SPACE_16,
      bottom: TgUiTokens.SPACE_16
    })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll() {
        Column() {
          // Top padding for the top bar
          Row().width('100%').height(this.topBarTotalHeight)

          this.buildProfileHeader()

          // ── Account section ──
          Column() {
            TgSettingsRow({
              title: localized($r('app.string.saved_messages').id, 'Saved Messages'),
              iconRes: TgUiTokens.ICON_RES_CHAT,
              iconBgColor: TgUiTokens.SETTINGS_ICON_COLOR_BLUE,
              trailingType: TgSettingsTrailing.Arrow,
              showSeparator: true
            })
            TgSettingsRow({
              title: localized($r('app.string.settings_recent_calls').id, 'Recent Calls'),
              iconRes: TgUiTokens.ICON_RES_PHONE_CALL,
              iconBgColor: TgUiTokens.SETTINGS_ICON_COLOR_GREEN,
              trailingType: TgSettingsTrailing.Arrow,
              showSeparator: false
            })
          }
          .width('100%')
          .backgroundColor(TgUiTokens.SETTINGS_SECTION_BG)
          .borderRadius(TgUiTokens.SETTINGS_SECTION_RADIUS)
          .clip(true)
          .margin({
            left: TgUiTokens.SETTINGS_SECTION_SIDE_INSET,
            right: TgUiTokens.SETTINGS_SECTION_SIDE_INSET,
            top: TgUiTokens.SETTINGS_SECTION_TOP_GAP
          })

          // ── Settings section ──
          Column() {
            TgSettingsRow({
              title: localized($r('app.string.settings_notifications_sounds').id, 'Notifications and Sounds'),
              iconRes: TgUiTokens.ICON_RES_MIC,
              iconBgColor: TgUiTokens.SETTINGS_ICON_COLOR_RED,
              trailingType: TgSettingsTrailing.Arrow,
              showSeparator: true
            })
            TgSettingsRow({
              title: localized($r('app.string.settings_privacy_security').id, 'Privacy and Security'),
              iconRes: TgUiTokens.ICON_RES_SETTINGS,
              iconBgColor: TgUiTokens.SETTINGS_ICON_COLOR_BLUE,
              trailingType: TgSettingsTrailing.Arrow,
              showSeparator: true
            })
            TgSettingsRow({
              title: localized($r('app.string.settings_data_storage').id, 'Data and Storage'),
              iconRes: TgUiTokens.ICON_RES_DOCUMENT,
              iconBgColor: TgUiTokens.SETTINGS_ICON_COLOR_GREEN,
              trailingType: TgSettingsTrailing.Arrow,
              showSeparator: true
            })
            TgSettingsRow({
              title: localized($r('app.string.settings_appearance').id, 'Appearance'),
              iconRes: TgUiTokens.ICON_RES_EMOJI,
              iconBgColor: TgUiTokens.SETTINGS_ICON_COLOR_BLUE,
              trailingType: TgSettingsTrailing.Arrow,
              showSeparator: true
            })
            TgSettingsRow({
              title: localized($r('app.string.settings_language').id, 'Language'),
              iconRes: TgUiTokens.ICON_RES_SEARCH,
              iconBgColor: TgUiTokens.SETTINGS_ICON_COLOR_PURPLE,
              trailingType: TgSettingsTrailing.Text,
              trailingText: 'English',
              showSeparator: false
            })
          }
          .width('100%')
          .backgroundColor(TgUiTokens.SETTINGS_SECTION_BG)
          .borderRadius(TgUiTokens.SETTINGS_SECTION_RADIUS)
          .clip(true)
          .margin({
            left: TgUiTokens.SETTINGS_SECTION_SIDE_INSET,
            right: TgUiTokens.SETTINGS_SECTION_SIDE_INSET,
            top: TgUiTokens.SETTINGS_SECTION_TOP_GAP
          })

          // ── Help section ──
          Column() {
            TgSettingsRow({
              title: localized($r('app.string.settings_ask_question').id, 'Ask a Question'),
              iconRes: TgUiTokens.ICON_RES_CHAT,
              iconBgColor: TgUiTokens.SETTINGS_ICON_COLOR_ORANGE,
              trailingType: TgSettingsTrailing.Arrow,
              showSeparator: true
            })
            TgSettingsRow({
              title: localized($r('app.string.settings_telegram_faq').id, 'Telegram FAQ'),
              iconRes: TgUiTokens.ICON_RES_DOCUMENT,
              iconBgColor: TgUiTokens.SETTINGS_ICON_COLOR_BLUE,
              trailingType: TgSettingsTrailing.Arrow,
              showSeparator: false
            })
          }
          .width('100%')
          .backgroundColor(TgUiTokens.SETTINGS_SECTION_BG)
          .borderRadius(TgUiTokens.SETTINGS_SECTION_RADIUS)
          .clip(true)
          .margin({
            left: TgUiTokens.SETTINGS_SECTION_SIDE_INSET,
            right: TgUiTokens.SETTINGS_SECTION_SIDE_INSET,
            top: TgUiTokens.SETTINGS_SECTION_TOP_GAP
          })

          // Bottom safe padding
          Row().width('100%').height(this.contentBottomInset)
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)

      TgTopBar({ title: localized($r('app.string.settings').id, 'Settings') })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
