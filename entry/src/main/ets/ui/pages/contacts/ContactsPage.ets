// ContactsPage — Contacts tab (Phase E-5)
// Stack overlay: list scrolls under translucent TgTopBar
// Data: users from AppStore filtered by isContact

import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState, User } from '../../../core/model/AppState';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgContactRow } from '../../tg_ui/atoms/TgContactRow';
import { TgContactSectionHeader } from '../../tg_ui/atoms/TgContactSectionHeader';
import { localized } from '../../../core/utils/AppResource';
import { fileUri } from '@kit.CoreFileKit';
import { computeTopBarHeight, computeTabBottomInset, getMainWindow, removeWindowSizeListener } from '../../utils/SafeAreaUtils';
import { ROOT_TAB_BAR_FALLBACK_CONTENT_INSET } from '../../utils/RootTabBarGeometry';
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

class ContactSectionVO {
  title: string = '';
  contacts: ContactVO[] = [];

  constructor(title: string, contacts: ContactVO[]) {
    this.title = title;
    this.contacts = contacts;
  }
}

function firstAlphabeticLetter(value: string): string {
  const upper: string = value.toUpperCase();
  for (let index: number = 0; index < upper.length; index += 1) {
    const character: string = upper.charAt(index);
    if ((character >= 'A' && character <= 'Z') ||
      (character >= 'А' && character <= 'Я') || character === 'Ё') {
      return character;
    }
  }
  return '';
}

function isCyrillicLetter(value: string): boolean {
  return (value >= 'А' && value <= 'Я') || value === 'Ё';
}

@ComponentV2
export struct ContactsPage {
  @Local private contacts: ContactVO[] = [];
  @Local private visibleContacts: ContactVO[] = [];
  @Local private sections: ContactSectionVO[] = [];
  @Local private alphabet: string[] = [];
  @Local private searchText: string = '';
  @Local private selectedSectionIndex: number = 0;
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private listBottomInset: number = ROOT_TAB_BAR_FALLBACK_CONTENT_INSET;

  @Event onContactPress: (userId: number, name: string) => void = (_userId: number, _name: string): void => {};

  private unsubscribe?: () => void;
  private rebuildScheduled: boolean = false;
  private rebuildTimerId: number = -1;
  private pageLifecycleToken: number = 0;
  private pendingSectionIndex: number = -1;
  private mainWindow?: window.Window;
  private listScroller: Scroller = new Scroller();

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
    this.pendingSectionIndex = -1;
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
      this.listBottomInset = ROOT_TAB_BAR_FALLBACK_CONTENT_INSET;
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
    const first: string = firstAlphabeticLetter(user.firstName);
    const last: string = firstAlphabeticLetter(user.lastName);
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

  private sectionTitleForName(name: string): string {
    const first: string = firstAlphabeticLetter(name);
    return first.length > 0 ? first : '#';
  }

  private rebuildVisibleContacts(): void {
    const query: string = this.searchText.trim().toLowerCase();
    const visible: ContactVO[] = [];
    for (const contact of this.contacts) {
      if (query.length === 0 || contact.sortKey.includes(query)) {
        visible.push(contact);
      }
    }
    this.visibleContacts = visible;

    const sectionMap: Map<string, ContactVO[]> = new Map<string, ContactVO[]>();
    const sectionOrder: string[] = [];
    for (const contact of visible) {
      const sectionTitle: string = this.sectionTitleForName(contact.name);
      let sectionContacts: ContactVO[] | undefined = sectionMap.get(sectionTitle);
      if (sectionContacts === undefined) {
        sectionContacts = [];
        sectionMap.set(sectionTitle, sectionContacts);
        sectionOrder.push(sectionTitle);
      }
      sectionContacts.push(contact);
    }

    const grouped: ContactSectionVO[] = [];
    for (const title of sectionOrder) {
      grouped.push(new ContactSectionVO(title, sectionMap.get(title) ?? []));
    }
    this.sections = grouped;
    this.alphabet = sectionOrder;
    if (this.selectedSectionIndex >= grouped.length) {
      this.selectedSectionIndex = Math.max(0, grouped.length - 1);
    }
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
      const firstLetter: string = firstAlphabeticLetter(vo.name).toLowerCase();
      vo.sortKey = firstLetter + ' ' + vo.name.toLowerCase();
      result.push(vo);
    }
    let locale: string = 'en';
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const configuredLocale: string = context.resourceManager.getConfigurationSync().locale;
      if (configuredLocale.length > 0) {
        locale = configuredLocale.replace('_', '-');
      }
    } catch (_error) {
      try {
        const resolvedLocale: string = Intl.DateTimeFormat().resolvedOptions().locale;
        if (resolvedLocale.length > 0) {
          locale = resolvedLocale;
        }
      } catch (_fallbackError) {
        locale = 'en';
      }
    }
    const preferCyrillic: boolean = locale.toLowerCase().startsWith('ru');
    result.sort((a: ContactVO, b: ContactVO): number => {
      const aLetter: string = firstAlphabeticLetter(a.name);
      const bLetter: string = firstAlphabeticLetter(b.name);
      const aRank: number = aLetter.length === 0 ? 2
        : isCyrillicLetter(aLetter) === preferCyrillic ? 0 : 1;
      const bRank: number = bLetter.length === 0 ? 2
        : isCyrillicLetter(bLetter) === preferCyrillic ? 0 : 1;
      if (aRank !== bRank) {
        return aRank - bRank;
      }
      try {
        return a.sortKey.localeCompare(b.sortKey, locale);
      } catch (_error) {
        return a.sortKey.localeCompare(b.sortKey);
      }
    });
    this.contacts = result;
    this.rebuildVisibleContacts();
  }

  @Builder
  private buildSectionHeader(title: string) {
    TgContactSectionHeader({ title: title })
  }

  @Builder
  private buildContactRow(contact: ContactVO, showSeparator: boolean) {
    TgContactRow({
      name: contact.name,
      initials: contact.initials,
      statusText: contact.statusText,
      avatarPath: contact.avatarPath,
      isOnline: contact.isOnline,
      showSeparator: showSeparator,
      onPress: (): void => {
        this.onContactPress(contact.userId, contact.name);
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Stack({ alignContent: Alignment.End }) {
        List({ scroller: this.listScroller }) {
          ListItem() {
            Search({ value: this.searchText, placeholder: $r('app.string.search_placeholder') })
              .height(TgUiTokens.CONTACT_SEARCH_HEIGHT)
              .backgroundColor(TgUiTokens.SEARCH_BAR_BG)
              .margin({
                left: TgUiTokens.CONTACT_SEARCH_SIDE_INSET,
                right: TgUiTokens.CONTACT_SEARCH_SIDE_INSET,
                top: TgUiTokens.CONTACT_SEARCH_VERTICAL_INSET,
                bottom: TgUiTokens.CONTACT_SEARCH_VERTICAL_INSET
              })
              .onChange((value: string) => {
                this.pendingSectionIndex = -1;
                this.searchText = value;
                this.selectedSectionIndex = 0;
                this.rebuildVisibleContacts();
              })
          }

          if (this.visibleContacts.length === 0) {
            ListItem() {
              Column() {
                Text(this.searchText.trim().length > 0
                  ? localized($r('app.string.search_no_results').id, 'No results')
                  : localized($r('app.string.no_contacts').id, 'No contacts yet'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
              }
              .width('100%')
              .height(TgUiTokens.CONTACT_EMPTY_STATE_HEIGHT)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            }
          } else if (this.searchText.trim().length > 0) {
            ForEach(this.visibleContacts, (contact: ContactVO, index: number) => {
              ListItem() {
                this.buildContactRow(contact, index < this.visibleContacts.length - 1)
              }
            }, (contact: ContactVO) => contact.userId.toString())
          } else {
            ForEach(this.sections, (section: ContactSectionVO) => {
              ListItemGroup({ header: this.buildSectionHeader(section.title) }) {
                ForEach(section.contacts, (contact: ContactVO, index: number) => {
                  ListItem() {
                    this.buildContactRow(contact, index < section.contacts.length - 1)
                  }
                }, (contact: ContactVO) => contact.userId.toString())
              }
            }, (section: ContactSectionVO) => section.title)
          }
        }
        .width('100%')
        .height('100%')
        .edgeEffect(EdgeEffect.Spring)
        .sticky(StickyStyle.Header)
        .contentEndOffset(this.listBottomInset)
        .onScrollIndex((firstIndex: number, _lastIndex: number, _centerIndex: number) => {
          if (this.pendingSectionIndex < 0 &&
            this.searchText.trim().length === 0 && this.sections.length > 0) {
            this.selectedSectionIndex = Math.max(0, Math.min(this.sections.length - 1, firstIndex - 1));
          }
        })
        .onScrollStop(() => {
          if (this.pendingSectionIndex >= 0) {
            this.selectedSectionIndex = this.pendingSectionIndex;
            this.pendingSectionIndex = -1;
          }
        })

        if (this.searchText.trim().length === 0 && this.alphabet.length > 1) {
          AlphabetIndexer({ arrayValue: this.alphabet, selected: this.selectedSectionIndex })
            .selected(this.selectedSectionIndex)
            .font({ size: TgUiTokens.CONTACT_INDEXER_FONT_SIZE })
            .selectedFont({ size: TgUiTokens.CONTACT_INDEXER_FONT_SIZE, weight: FontWeight.Bold })
            .color(TgUiTokens.COLOR_ICON_PRIMARY)
            .selectedColor(TgUiTokens.COLOR_TEXT_TITLE)
            .selectedBackgroundColor(Color.Transparent)
            .usingPopup(true)
            .popupFont({ size: TgUiTokens.CONTACT_INDEXER_POPUP_FONT_SIZE, weight: FontWeight.Bold })
            .popupBackground(TgUiTokens.COLOR_OVERLAY_DIM)
            .alignStyle(IndexerAlign.Right)
            .itemSize(TgUiTokens.CONTACT_INDEXER_ITEM_SIZE)
            .autoCollapse(true)
            .margin({ right: TgUiTokens.CONTACT_INDEXER_MARGIN_RIGHT })
            .onSelect((index: number) => {
              this.pendingSectionIndex = index;
              this.selectedSectionIndex = index;
              this.listScroller.scrollToIndex(index + 1, true, ScrollAlign.START);
            })
        }
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.topBarTotalHeight })

    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
