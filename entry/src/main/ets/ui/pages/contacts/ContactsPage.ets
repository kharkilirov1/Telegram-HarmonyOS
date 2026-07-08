// ContactsPage — Contacts tab (Phase E-5)
// Stack overlay: list scrolls under translucent TgTopBar
// Data: users from AppStore filtered by isContact

import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState, User } from '../../../core/model/AppState';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgAvatar } from '../../tg_ui/atoms/TgAvatar';
import { localized } from '../../../core/utils/AppResource';
import { fileUri } from '@kit.CoreFileKit';
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

@ComponentV2
export struct ContactsPage {
  @Local private contacts: ContactVO[] = [];
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private listBottomInset: number = TgUiTokens.TAB_BAR_CONTENT_SAFE_BOTTOM;

  private unsubscribe?: () => void;
  private rebuildScheduled: boolean = false;
  private rebuildTimerId: number = -1;
  private pageLifecycleToken: number = 0;
  private mainWindow?: window.Window;

  private clearRebuildTimer(): void {
    if (this.rebuildTimerId !== -1) {
      clearTimeout(this.rebuildTimerId);
      this.rebuildTimerId = -1;
    }
    this.rebuildScheduled = false;
  }

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
    this.clearRebuildTimer();
    hilog.info(DOMAIN, TAG, 'ContactsPage aboutToAppear');
    this.computeSafeInsets();
    this.bindWindowSizeListener();

    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }

    try {
      const runtime = getAppCoreRuntime();
      const store = runtime.getStore();
      this.rebuildContacts(store.getState());

      const subscriptionToken: number = this.pageLifecycleToken;
      let activeUnsubscribe: (() => void) | undefined = undefined;
      activeUnsubscribe = store.subscribe((_newState: AppState, _prevState: AppState) => {
        if (subscriptionToken !== this.pageLifecycleToken || this.unsubscribe !== activeUnsubscribe) {
          return;
        }
        if (!this.rebuildScheduled) {
          this.rebuildScheduled = true;
          const scheduledToken: number = this.pageLifecycleToken;
          let scheduledTimerId: number = -1;
          scheduledTimerId = setTimeout(() => {
            if (scheduledToken !== this.pageLifecycleToken ||
              this.rebuildTimerId !== scheduledTimerId ||
              this.unsubscribe !== activeUnsubscribe) {
              return;
            }
            this.rebuildTimerId = -1;
            this.rebuildScheduled = false;
            try {
              const currentState = getAppCoreRuntime().getStore().getState();
              this.rebuildContacts(currentState);
            } catch (e) {
              hilog.error(DOMAIN, TAG, 'Rebuild failed: %{public}s', String(e));
            }
          }, 300) as number;
          this.rebuildTimerId = scheduledTimerId;
        }
      });
      this.unsubscribe = activeUnsubscribe;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Init failed: %{public}s', String(e));
    }
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.clearRebuildTimer();
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
        const lifecycleToken: number = this.pageLifecycleToken;
        const boundWindow: window.Window = this.mainWindow;
        this.mainWindow.on('windowSizeChange', (_size: window.Size) => {
          if (lifecycleToken !== this.pageLifecycleToken || this.mainWindow !== boundWindow) {
            return;
          }
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
    if (user.phoneNumber.length > 0) {
      return '+' + user.phoneNumber;
    }
    return localized($r('app.string.deleted_account').id, 'Deleted Account');
  }

  // No name, no username, no phone — a deleted account; Telegram hides these
  private isDeletedAccount(user: User): boolean {
    return (user.firstName + user.lastName).trim().length === 0 &&
      user.username.length === 0 &&
      user.phoneNumber.length === 0;
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
      if (this.isDeletedAccount(user)) {
        continue;
      }
      const vo = new ContactVO();
      vo.userId = user.id;
      vo.name = this.userDisplayName(user);
      vo.initials = this.userInitials(user);
      vo.statusText = this.formatUserStatus(user);
      vo.avatarPath = user.photoSmall.length > 0 ? fileUri.getUriFromPath(user.photoSmall) : '';
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
              Column() {
                Row() {
                  TgAvatar({
                    avatarSize: TgUiTokens.CONTACT_ROW_AVATAR_SIZE,
                    initials: contact.initials,
                    useImage: contact.avatarPath.length > 0,
                    imageSrc: contact.avatarPath,
                    isOnline: contact.isOnline,
                    avatarBackgroundColor: TgUiTokens.COLOR_AVATAR_PLACEHOLDER_BG
                  })

                  Column() {
                    Text(contact.name)
                      .fontSize(TgUiTokens.CONTACT_ROW_NAME_SIZE)
                      .fontWeight(FontWeight.Regular)
                      .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    if (contact.statusText.length > 0) {
                      Text(contact.statusText)
                        .fontSize(TgUiTokens.CONTACT_ROW_STATUS_SIZE)
                        .fontColor(contact.isOnline ? TgUiTokens.COLOR_ONLINE_DOT : TgUiTokens.COLOR_TEXT_PREVIEW)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .margin({ top: TgUiTokens.SPACE_2 })
                    }
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  .margin({ left: TgUiTokens.CONTACT_ROW_GAP })
                }
                .width('100%')
                .height(TgUiTokens.CONTACT_ROW_HEIGHT)
                .padding({
                  left: TgUiTokens.CONTACT_ROW_PADDING_H,
                  right: TgUiTokens.CONTACT_ROW_PADDING_H
                })
                .alignItems(VerticalAlign.Center)

                if (index < this.contacts.length - 1) {
                  Row()
                    .width('100%')
                    .height(TgUiTokens.CONTACT_ROW_SEPARATOR_STROKE)
                    .backgroundColor(TgUiTokens.COLOR_SEPARATOR)
                    .margin({ left: TgUiTokens.CONTACT_ROW_SEPARATOR_INSET })
                }
              }
              .width('100%')
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

    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
