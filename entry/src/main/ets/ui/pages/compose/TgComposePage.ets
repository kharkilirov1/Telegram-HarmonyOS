import { common } from '@kit.AbilityKit';
import { fileUri } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState, UserStatusType } from '../../../core/model/AppState';
import { ChatDto } from '../../../core/model/dto/ChatDto';
import { UserDto } from '../../../core/model/dto/UserDto';
import { localized } from '../../../core/utils/AppResource';
import {
  CreatePrivateChatUseCase,
  createPrivateChatUseCase
} from '../../../domain/usecases/createPrivateChat';
import {
  ComposeRemoteUserSearchResult,
  SearchComposeUsersUseCase,
  searchComposeUsersUseCase
} from '../../../domain/usecases/searchComposeUsers';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { TgComposeActionRow } from '../../tg_ui/atoms/TgComposeActionRow';
import { TgContactRow } from '../../tg_ui/atoms/TgContactRow';
import { TgContactSectionHeader } from '../../tg_ui/atoms/TgContactSectionHeader';
import { TgForwardPickerNavigationBar } from '../../tg_ui/atoms/TgForwardPickerNavigationBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import {
  ComposeContactVO,
  ComposeSearchContactsVO,
  buildComposeContacts,
  filterComposeContacts,
  isCurrentComposeSearchRequest,
  mergeComposeSearchContacts
} from './ComposeContactModel';
import { ComposeCreationResult, ComposeCreationRouteParams } from './ComposeCreationRouteTypes';

const DOMAIN = 0x0044;
const TAG = 'TgComposePage';
const REMOTE_SEARCH_DELAY_MS = 200;
const STORE_REBUILD_DELAY_MS = 300;

export class ComposeResult {
  chatId: number = 0;
  chatTitle: string = '';
  failedMemberCount: number = 0;

  constructor(chatId: number, chatTitle: string, failedMemberCount: number = 0) {
    this.chatId = chatId;
    this.chatTitle = chatTitle;
    this.failedMemberCount = Math.max(0, Math.trunc(failedMemberCount));
  }
}

export class ComposeRouteParams {}

class ComposeContactSectionVO {
  title: string = '';
  contacts: ComposeContactVO[] = [];

  constructor(title: string, contacts: ComposeContactVO[]) {
    this.title = title;
    this.contacts = contacts;
  }
}

@ComponentV2
export struct TgComposePage {
  @Local pageStack: NavPathStack = new NavPathStack();
  @Local private searchQuery: string = '';
  @Local private contacts: ComposeContactVO[] = [];
  @Local private visibleContacts: ComposeContactVO[] = [];
  @Local private searchContactResults: ComposeContactVO[] = [];
  @Local private searchGlobalResults: ComposeContactVO[] = [];
  @Local private isRemoteSearching: boolean = false;
  @Local private isRemoteSearchSettled: boolean = false;
  @Local private contactSections: ComposeContactSectionVO[] = [];
  @Local private isOpeningContact: boolean = false;
  @Local private openingUserId: number = 0;
  @Local private isOpeningAction: boolean = false;
  @Local private errorText: string = '';

  private unsubscribe?: () => void;
  private rebuildScheduled: boolean = false;
  private rebuildTimerId: number = -1;
  private pageLifecycleToken: number = 0;
  private isClosing: boolean = false;
  private openPrivateChatUseCase?: CreatePrivateChatUseCase;
  private remoteUserSearchUseCase?: SearchComposeUsersUseCase;
  private pendingCreationResult?: ComposeCreationResult;
  private remoteSearchTimerId: number = -1;
  private remoteSearchGeneration: number = 0;
  private currentSelfUserId: number = 0;
  private remoteCloudContacts: UserDto[] = [];
  private remoteKnownUsers: UserDto[] = [];
  private remoteGlobalUsers: UserDto[] = [];

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
    this.remoteSearchGeneration += 1;
    this.clearRemoteSearchTimer();
    this.isClosing = false;
    this.isOpeningContact = false;
    this.openingUserId = 0;
    this.isOpeningAction = false;
    this.errorText = '';
    this.clearRemoteSearchResults();

    try {
      const runtime = getAppCoreRuntime();
      const store = runtime.getStore();
      this.openPrivateChatUseCase = createPrivateChatUseCase(getTdGatewayAdapter());
      this.remoteUserSearchUseCase = searchComposeUsersUseCase(getTdGatewayAdapter());
      this.rebuildContacts(store.getState());

      if (this.unsubscribe !== undefined) {
        this.unsubscribe();
        this.unsubscribe = undefined;
      }
      const lifecycleToken: number = this.pageLifecycleToken;
      let activeUnsubscribe: (() => void) | undefined = undefined;
      activeUnsubscribe = store.subscribe((newState: AppState, previousState: AppState) => {
        if (lifecycleToken !== this.pageLifecycleToken || this.unsubscribe !== activeUnsubscribe) {
          return;
        }
        if (newState.users !== previousState.users || newState.auth !== previousState.auth) {
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
                const currentState: AppState = getAppCoreRuntime().getStore().getState();
                this.rebuildContacts(currentState);
              } catch (error) {
                hilog.error(DOMAIN, TAG, 'Compose contacts rebuild failed: %{public}s', String(error));
              }
            }, STORE_REBUILD_DELAY_MS) as number;
            this.rebuildTimerId = scheduledTimerId;
          }
        }
      });
      this.unsubscribe = activeUnsubscribe;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Compose initialization failed: %{public}s', String(error));
      this.errorText = localized($r('app.string.action_failed').id, 'Action failed');
    }
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.clearRebuildTimer();
    this.remoteSearchGeneration += 1;
    this.clearRemoteSearchTimer();
    this.isRemoteSearching = false;
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
  }

  private resolveLocale(): string {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const configuredLocale: string = context.resourceManager.getConfigurationSync().locale;
      if (configuredLocale.length > 0) {
        return configuredLocale.replace('_', '-');
      }
    } catch (_error) {
      // Intl fallback below keeps Compose usable in previews/tests.
    }
    try {
      const locale: string = Intl.DateTimeFormat().resolvedOptions().locale;
      return locale.length > 0 ? locale : 'en';
    } catch (_error) {
      return 'en';
    }
  }

  private rebuildContacts(state: AppState): void {
    this.currentSelfUserId = state.auth.userId;
    this.contacts = buildComposeContacts(state, this.resolveLocale());
    this.rebuildVisibleContacts();
  }

  private rebuildVisibleContacts(): void {
    const visible: ComposeContactVO[] = filterComposeContacts(this.contacts, this.searchQuery);
    this.visibleContacts = visible;

    if (this.searchQuery.trim().length > 0) {
      const searchResults: ComposeSearchContactsVO = mergeComposeSearchContacts(
        visible,
        this.remoteCloudContacts,
        this.remoteKnownUsers,
        this.remoteGlobalUsers,
        this.currentSelfUserId
      );
      this.searchContactResults = searchResults.contacts;
      this.searchGlobalResults = searchResults.global;
    } else {
      this.searchContactResults = [];
      this.searchGlobalResults = [];
    }

    const sectionMap: Map<string, ComposeContactVO[]> = new Map<string, ComposeContactVO[]>();
    const sectionOrder: string[] = [];
    for (const contact of visible) {
      let sectionContacts: ComposeContactVO[] | undefined = sectionMap.get(contact.sectionTitle);
      if (sectionContacts === undefined) {
        sectionContacts = [];
        sectionMap.set(contact.sectionTitle, sectionContacts);
        sectionOrder.push(contact.sectionTitle);
      }
      sectionContacts.push(contact);
    }
    const sections: ComposeContactSectionVO[] = [];
    for (const title of sectionOrder) {
      sections.push(new ComposeContactSectionVO(title, sectionMap.get(title) ?? []));
    }
    this.contactSections = sections;
  }

  private clearRemoteSearchTimer(): void {
    if (this.remoteSearchTimerId !== -1) {
      clearTimeout(this.remoteSearchTimerId);
      this.remoteSearchTimerId = -1;
    }
  }

  private clearRemoteSearchResults(): void {
    this.remoteCloudContacts = [];
    this.remoteKnownUsers = [];
    this.remoteGlobalUsers = [];
    this.searchContactResults = [];
    this.searchGlobalResults = [];
    this.isRemoteSearching = false;
    this.isRemoteSearchSettled = false;
  }

  private isCurrentRemoteSearch(
    generation: number,
    lifecycleToken: number,
    query: string
  ): boolean {
    return isCurrentComposeSearchRequest(
      this.remoteSearchGeneration,
      generation,
      this.pageLifecycleToken,
      lifecycleToken,
      this.searchQuery,
      query,
      this.isClosing
    );
  }

  private scheduleRemoteSearch(query: string): void {
    const useCase: SearchComposeUsersUseCase | undefined = this.remoteUserSearchUseCase;
    if (useCase === undefined) {
      this.isRemoteSearchSettled = true;
      return;
    }

    this.isRemoteSearching = true;
    const generation: number = this.remoteSearchGeneration;
    const lifecycleToken: number = this.pageLifecycleToken;
    let scheduledTimerId: number = -1;
    scheduledTimerId = setTimeout(() => {
      if (this.remoteSearchTimerId !== scheduledTimerId ||
        !this.isCurrentRemoteSearch(generation, lifecycleToken, query)) {
        return;
      }
      this.remoteSearchTimerId = -1;
      this.executeRemoteSearch(query, generation, lifecycleToken, useCase);
    }, REMOTE_SEARCH_DELAY_MS) as number;
    this.remoteSearchTimerId = scheduledTimerId;
  }

  private executeRemoteSearch(
    query: string,
    generation: number,
    lifecycleToken: number,
    useCase: SearchComposeUsersUseCase
  ): void {
    useCase.execute(query)
      .then((result: ComposeRemoteUserSearchResult): void => {
        if (!this.isCurrentRemoteSearch(generation, lifecycleToken, query)) {
          return;
        }
        this.remoteCloudContacts = result.cloudContacts;
        this.remoteKnownUsers = result.knownUsers;
        this.remoteGlobalUsers = result.globalUsers;
        this.isRemoteSearching = false;
        this.isRemoteSearchSettled = true;
        this.rebuildVisibleContacts();
      })
      .catch((error: Error): void => {
        if (!this.isCurrentRemoteSearch(generation, lifecycleToken, query)) {
          return;
        }
        this.remoteCloudContacts = [];
        this.remoteKnownUsers = [];
        this.remoteGlobalUsers = [];
        this.isRemoteSearching = false;
        this.isRemoteSearchSettled = true;
        this.rebuildVisibleContacts();
        hilog.warn(DOMAIN, TAG, 'Compose remote search failed: %{public}s', error.message);
      });
  }

  private formatUserStatus(status: UserStatusType): string {
    switch (status) {
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

  private avatarUri(path: string): string {
    if (path.length === 0) {
      return '';
    }
    try {
      return fileUri.getUriFromPath(path);
    } catch (_error) {
      return '';
    }
  }

  private handleSearchChange(value: string): void {
    this.searchQuery = value;
    this.errorText = '';
    this.remoteSearchGeneration += 1;
    this.clearRemoteSearchTimer();
    this.clearRemoteSearchResults();
    this.rebuildVisibleContacts();

    const query: string = value.trim();
    if (query.length > 0) {
      this.scheduleRemoteSearch(query);
    }
  }

  private handleBackPress(): void {
    if (this.pendingCreationResult !== undefined) {
      this.handoffPendingCreation();
      return;
    }
    if (!this.canPop('cancel')) {
      return;
    }
    this.isClosing = true;
    try {
      this.pageStack.pop(new ComposeResult(0, ''));
    } catch (error) {
      this.isClosing = false;
      hilog.error(DOMAIN, TAG, 'Compose cancel pop failed: %{public}s', String(error));
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2400 });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Compose toast failed: %{public}s', String(error));
    }
  }

  private canPop(action: string): boolean {
    if (this.isClosing) {
      hilog.warn(DOMAIN, TAG, 'Ignoring duplicate Compose %{public}s pop', action);
      return false;
    }
    try {
      return this.pageStack.size() > 0;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Compose stack inspection failed: %{public}s', String(error));
      return false;
    }
  }

  private handleContactSelect(contact: ComposeContactVO): void {
    if (this.isOpeningContact || this.isOpeningAction) {
      hilog.info(DOMAIN, TAG, 'Ignoring duplicate Compose contact activation');
      return;
    }
    const useCase: CreatePrivateChatUseCase | undefined = this.openPrivateChatUseCase;
    if (useCase === undefined || this.isClosing) {
      return;
    }

    this.isOpeningContact = true;
    this.openingUserId = contact.userId;
    this.errorText = '';
    const lifecycleToken: number = this.pageLifecycleToken;
    useCase.execute(contact.userId, false)
      .then((chat: ChatDto): void => {
        if (lifecycleToken !== this.pageLifecycleToken || this.isClosing) {
          return;
        }
        if (!this.canPop('selection')) {
          this.isOpeningContact = false;
          this.openingUserId = 0;
          return;
        }
        try {
          this.isClosing = true;
          this.pageStack.pop(new ComposeResult(chat.id, contact.name));
        } catch (error) {
          this.isClosing = false;
          this.isOpeningContact = false;
          this.openingUserId = 0;
          this.errorText = localized($r('app.string.action_failed').id, 'Action failed');
          hilog.error(DOMAIN, TAG, 'Compose selection pop failed: %{public}s', String(error));
        }
      })
      .catch((error: Error): void => {
        if (lifecycleToken !== this.pageLifecycleToken || this.isClosing) {
          return;
        }
        this.isOpeningContact = false;
        this.openingUserId = 0;
        this.errorText = localized($r('app.string.action_failed').id, 'Action failed');
        hilog.error(DOMAIN, TAG, 'createPrivateChat failed for %{public}d: %{public}s',
          contact.userId, error.message);
      });
  }

  private openCreationRoute(routeName: string): void {
    if (this.pendingCreationResult !== undefined) {
      this.handoffPendingCreation();
      return;
    }
    if (this.isOpeningAction || this.isOpeningContact || this.isClosing) {
      return;
    }
    this.isOpeningAction = true;
    try {
      this.pageStack.pushPathByName(routeName, new ComposeCreationRouteParams(), (popInfo) => {
        this.isOpeningAction = false;
        const result = popInfo.result as ComposeCreationResult | undefined;
        if (!result || this.isClosing) {
          return;
        }
        if (result.contactImportedUnregistered) {
          this.showToast(localized(
            $r('app.string.contact_added_not_registered').id,
            'Contact added. This phone number is not registered on Telegram yet.'
          ));
          return;
        }
        if (result.chatId <= 0) {
          return;
        }
        this.pendingCreationResult = result;
        this.handoffPendingCreation();
      });
    } catch (error) {
      this.isOpeningAction = false;
      this.errorText = localized($r('app.string.action_failed').id, 'Action failed');
      hilog.error(DOMAIN, TAG, 'Failed to open Compose route %{public}s: %{public}s', routeName, String(error));
    }
  }

  private handoffPendingCreation(): void {
    const result: ComposeCreationResult | undefined = this.pendingCreationResult;
    if (result === undefined || !this.canPop('creation')) {
      return;
    }
    this.isClosing = true;
    try {
      this.pageStack.pop(new ComposeResult(result.chatId, result.chatTitle, result.failedMemberCount));
      this.pendingCreationResult = undefined;
    } catch (error) {
      this.isClosing = false;
      this.errorText = localized($r('app.string.action_failed').id, 'Action failed');
      hilog.error(DOMAIN, TAG, 'Compose creation handoff failed: %{public}s', String(error));
    }
  }

  @Builder
  private buildSearchRow() {
    Row() {
      Search({ value: this.searchQuery, placeholder: localized($r('app.string.search_placeholder').id, 'Search') })
        .width('100%')
        .height(TgUiTokens.FORWARD_PICKER_SEARCH_HEIGHT)
        .backgroundColor(TgUiTokens.SEARCH_BAR_BG)
        .borderRadius(TgUiTokens.FORWARD_PICKER_SEARCH_RADIUS)
        .placeholderColor(TgUiTokens.SEARCH_BAR_PLACEHOLDER_COLOR)
        .placeholderFont({ size: TgUiTokens.SEARCH_BAR_FONT_SIZE, weight: FontWeight.Regular })
        .textFont({ size: TgUiTokens.SEARCH_BAR_FONT_SIZE, weight: FontWeight.Regular })
        .fontColor(TgUiTokens.SEARCH_BAR_TEXT_COLOR)
        .searchIcon({
          size: TgUiTokens.SEARCH_BAR_ICON_SIZE,
          color: TgUiTokens.SEARCH_BAR_ICON_COLOR
        })
        .enterKeyType(EnterKeyType.Search)
        .onChange((value: string): void => this.handleSearchChange(value))
    }
    .width('100%')
    .height(TgUiTokens.FORWARD_PICKER_SEARCH_AREA_HEIGHT)
    .padding({
      left: TgUiTokens.FORWARD_PICKER_SEARCH_SIDE_INSET,
      right: TgUiTokens.FORWARD_PICKER_SEARCH_SIDE_INSET
    })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildContactRow(contact: ComposeContactVO, showSeparator: boolean, isGlobal: boolean = false) {
    TgContactRow({
      name: contact.name,
      initials: contact.initials,
      statusText: isGlobal && contact.username.length > 0
        ? '@' + contact.username
        : this.formatUserStatus(contact.status),
      avatarPath: this.avatarUri(contact.avatarPath),
      isOnline: contact.isOnline,
      showSeparator: showSeparator,
      rowHeight: TgUiTokens.COMPOSE_CONTACT_ROW_HEIGHT,
      contentGap: TgUiTokens.COMPOSE_CONTACT_ROW_GAP,
      statusFontSize: TgUiTokens.COMPOSE_CONTACT_STATUS_SIZE,
      separatorInset: TgUiTokens.COMPOSE_CONTACT_SEPARATOR_INSET,
      onPress: (): void => this.handleContactSelect(contact)
    })
    .opacity(this.isOpeningContact && this.openingUserId !== contact.userId ? 0.58 : 1)
  }

  @Builder
  private buildSectionHeader(title: string) {
    TgContactSectionHeader({
      title: title,
      sectionHeight: TgUiTokens.COMPOSE_CONTACT_SECTION_HEIGHT
    })
  }

  @Builder
  private buildContactsList() {
    List() {
      if (this.searchQuery.trim().length > 0) {
        if (this.searchContactResults.length > 0) {
          ListItemGroup({
            header: this.buildSectionHeader(
              localized($r('app.string.search_contacts_section').id, 'Contacts')
            )
          }) {
            ForEach(this.searchContactResults, (contact: ComposeContactVO, index?: number) => {
              ListItem() {
                this.buildContactRow(contact, (index ?? 0) < this.searchContactResults.length - 1)
              }
            }, (contact: ComposeContactVO): string => 'compose-search-contact-' + contact.userId.toString())
          }
        }
        if (this.searchGlobalResults.length > 0) {
          ListItemGroup({
            header: this.buildSectionHeader(
              localized($r('app.string.search_global_section').id, 'Global Search')
            )
          }) {
            ForEach(this.searchGlobalResults, (contact: ComposeContactVO, index?: number) => {
              ListItem() {
                this.buildContactRow(contact, (index ?? 0) < this.searchGlobalResults.length - 1, true)
              }
            }, (contact: ComposeContactVO): string => 'compose-search-global-' + contact.userId.toString())
          }
        }
      } else {
        ListItem() {
          TgComposeActionRow({
            title: localized($r('app.string.new_group').id, 'New Group'),
            icon: TgUiTokens.ICON_RES_GROUP,
            showSeparator: true,
            onPress: (): void => this.openCreationRoute('TgNewGroupMembersPage')
          })
        }
        ListItem() {
          TgComposeActionRow({
            title: localized($r('app.string.new_contact').id, 'New Contact'),
            icon: TgUiTokens.ICON_RES_CONTACT_ADD,
            showSeparator: true,
            onPress: (): void => this.openCreationRoute('TgNewContactPage')
          })
        }
        ListItem() {
          TgComposeActionRow({
            title: localized($r('app.string.new_channel').id, 'New Channel'),
            icon: TgUiTokens.ICON_RES_CHANNEL,
            showSeparator: false,
            onPress: (): void => this.openCreationRoute('TgNewChannelPage')
          })
        }

        ForEach(this.contactSections, (section: ComposeContactSectionVO) => {
          ListItemGroup({ header: this.buildSectionHeader(section.title) }) {
            ForEach(section.contacts, (contact: ComposeContactVO, index?: number) => {
              ListItem() {
                this.buildContactRow(contact, (index ?? 0) < section.contacts.length - 1)
              }
            }, (contact: ComposeContactVO): string => 'compose-contact-' + contact.userId.toString())
          }
        }, (section: ComposeContactSectionVO): string => 'compose-section-' + section.title)

        if (this.contactSections.length === 0) {
          ListItem() {
            Text(localized($r('app.string.no_contacts').id, 'No contacts'))
              .width('100%')
              .fontSize(TgUiTokens.CONTACT_ROW_STATUS_SIZE)
              .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
              .textAlign(TextAlign.Center)
              .padding({ top: TgUiTokens.SPACE_24, bottom: TgUiTokens.SPACE_24 })
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .cachedCount(12)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private buildEmptyState() {
    Column() {
      Text(this.searchQuery.trim().length > 0
        ? localized($r('app.string.search_no_results').id, 'No results')
        : localized($r('app.string.no_contacts').id, 'No contacts'))
        .fontSize(TgUiTokens.CONTACT_ROW_NAME_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .textAlign(TextAlign.Center)

      if (this.searchQuery.trim().length > 0) {
        Text('“' + this.searchQuery.trim() + '”')
          .fontSize(TgUiTokens.CHATLIST_STATUS_TEXT_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .textAlign(TextAlign.Center)
          .margin({ top: TgUiTokens.SPACE_4 })
      }

      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(TgUiTokens.CHATLIST_STATUS_TEXT_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .margin({ top: TgUiTokens.SPACE_8 })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
  }

  @Builder
  private buildBody() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.searchQuery.trim().length > 0) {
        if (this.searchContactResults.length > 0 || this.searchGlobalResults.length > 0) {
          this.buildContactsList()
        } else if (this.isRemoteSearchSettled) {
          this.buildEmptyState()
        }
      } else {
        // Creation actions remain reachable even when the account has no contacts.
        this.buildContactsList()
      }

      if (this.isOpeningContact || this.isOpeningAction) {
        LoadingProgress()
          .width(24)
          .height(24)
          .color(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  build() {
    NavDestination() {
      Column() {
        TgForwardPickerNavigationBar({
          title: localized($r('app.string.new_message').id, 'New Message'),
          backAccessibilityText: localized($r('app.string.accessibility_back').id, 'Back'),
          onBackPress: (): void => this.handleBackPress()
        })
        this.buildSearchRow()
        this.buildBody()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .hideTitleBar(true)
    .hideBackButton(true)
    .hideToolBar(true)
    .onReady((context: NavDestinationContext): void => {
      this.pageStack = context.pathStack;
    })
    .onBackPressed((): boolean => {
      this.handleBackPress();
      return true;
    })
  }
}

@Builder
export function TgComposePageBuilder() {
  TgComposePage()
}
