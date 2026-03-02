// ContactsPage — Contacts tab (Phase E-5)
// Stack overlay: list scrolls under translucent TgTopBar
// Data: users from AppStore filtered by isContact

import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState, User } from '../../../core/model/AppState';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgTopBar } from '../../tg_ui/atoms/TgTopBar';
import { TgContactRow } from '../../tg_ui/atoms/TgContactRow';
import { localized } from '../../../core/utils/AppResource';
import { computeTopBarHeight, computeTabBottomInset, getMainWindow, removeWindowSizeListener } from '../../utils/SafeAreaUtils';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0x0030;
const TAG = 'ContactsPage';

class ContactVO {
  userId: number = 0;
  name: string = '';
  initials: string = '';
  statusText: string = '';
  avatarPath: string = '';
  isOnline: boolean = false;
  sortKey: string = '';
}

@Component
export struct ContactsPage {
  @State private contacts: ContactVO[] = [];
  @State private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @State private listBottomInset: number = TgUiTokens.TAB_BAR_CONTENT_SAFE_BOTTOM;

  private unsubscribe?: () => void;
  private rebuildScheduled: boolean = false;
  private mainWindow?: window.Window;

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'ContactsPage aboutToAppear');
    this.computeSafeInsets();
    this.bindWindowSizeListener();

    try {
      const runtime = getAppCoreRuntime();
      const store = runtime.getStore();
      this.rebuildContacts(store.getState());

      this.unsubscribe = store.subscribe((_newState: AppState, _prevState: AppState) => {
        if (!this.rebuildScheduled) {
          this.rebuildScheduled = true;
          setTimeout(() => {
            this.rebuildScheduled = false;
            try {
              const currentState = getAppCoreRuntime().getStore().getState();
              this.rebuildContacts(currentState);
            } catch (e) {
              hilog.error(DOMAIN, TAG, 'Rebuild failed: %{public}s', String(e));
            }
          }, 0);
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
      this.listBottomInset = computeTabBottomInset(context);
    } catch (_error) {
      this.topBarTotalHeight = TgUiTokens.TOP_BAR_HEIGHT;
      this.listBottomInset = TgUiTokens.TAB_BAR_CONTENT_SAFE_BOTTOM;
    }
  }

  private formatUserStatus(user: User): string {
    switch (user.status) {
      case 'online':
        return localized($r('app.string.online').id, 'online');
      case 'recently':
        return localized($r('app.string.last_seen_recently').id, 'last seen recently');
      case 'lastWeek':
        return localized($r('app.string.last_seen_within_week').id, 'last seen within a week');
      case 'lastMonth':
        return localized($r('app.string.last_seen_within_month').id, 'last seen within a month');
      case 'longTimeAgo':
        return localized($r('app.string.last_seen_long_ago').id, 'last seen a long time ago');
      default:
        return localized($r('app.string.offline').id, 'offline');
    }
  }

  private userInitials(user: User): string {
    const first = user.firstName.length > 0 ? user.firstName.charAt(0) : '';
    const last = user.lastName.length > 0 ? user.lastName.charAt(0) : '';
    if (first.length > 0 && last.length > 0) {
      return (first + last).toUpperCase();
    }
    if (first.length > 0) {
      return first.toUpperCase();
    }
    if (user.username.length > 0) {
      return user.username.charAt(0).toUpperCase();
    }
    return '?';
  }

  private userDisplayName(user: User): string {
    const full = (user.firstName + ' ' + user.lastName).trim();
    if (full.length > 0) {
      return full;
    }
    if (user.username.length > 0) {
      return '@' + user.username;
    }
    return 'Unknown';
  }

  private rebuildContacts(state: AppState): void {
    const result: ContactVO[] = [];
    for (const user of state.users.users.values()) {
      if (!user.isContact) {
        continue;
      }
      if (user.id === state.auth.userId) {
        continue;
      }
      const vo = new ContactVO();
      vo.userId = user.id;
      vo.name = this.userDisplayName(user);
      vo.initials = this.userInitials(user);
      vo.statusText = this.formatUserStatus(user);
      vo.avatarPath = user.photoSmall;
      vo.isOnline = user.status === 'online';
      vo.sortKey = vo.name.toLowerCase();
      result.push(vo);
    }
    result.sort((a: ContactVO, b: ContactVO): number => {
      if (a.sortKey < b.sortKey) {
        return -1;
      }
      if (a.sortKey > b.sortKey) {
        return 1;
      }
      return 0;
    });
    this.contacts = result;
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.contacts.length > 0) {
        List() {
          ForEach(this.contacts, (contact: ContactVO, index: number) => {
            ListItem() {
              TgContactRow({
                name: contact.name,
                statusText: contact.statusText,
                initials: contact.initials,
                avatarPath: contact.avatarPath,
                isOnline: contact.isOnline,
                showSeparator: index < this.contacts.length - 1
              })
            }
          }, (contact: ContactVO) => contact.userId.toString())
        }
        .width('100%')
        .height('100%')
        .edgeEffect(EdgeEffect.Spring)
        .contentStartOffset(this.topBarTotalHeight)
        .contentEndOffset(this.listBottomInset)
      } else {
        Column() {
          Text(localized($r('app.string.no_contacts').id, 'No contacts yet'))
            .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }

      TgTopBar({ title: localized($r('app.string.contacts_title').id, 'Contacts') })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
