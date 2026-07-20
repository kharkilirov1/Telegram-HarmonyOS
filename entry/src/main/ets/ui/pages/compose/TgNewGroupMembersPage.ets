import { common } from '@kit.AbilityKit';
import { fileUri } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState, UserStatusType } from '../../../core/model/AppState';
import { localized } from '../../../core/utils/AppResource';
import { MAX_BASIC_GROUP_MEMBER_COUNT } from '../../../domain/usecases/createBasicGroupChat';
import { TgContactRow } from '../../tg_ui/atoms/TgContactRow';
import { TgContactSectionHeader } from '../../tg_ui/atoms/TgContactSectionHeader';
import { TgForwardPickerNavigationBar } from '../../tg_ui/atoms/TgForwardPickerNavigationBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { ComposeContactVO, buildComposeContacts, filterComposeContacts } from './ComposeContactModel';
import { toggleComposeUserSelection } from './ComposeCreationModel';
import { ComposeCreationResult, NewGroupInfoRouteParams } from './ComposeCreationRouteTypes';

const DOMAIN = 0x0044;
const TAG = 'TgNewGroupMembersPage';

class GroupContactSectionVO {
  title: string = '';
  contacts: ComposeContactVO[] = [];

  constructor(title: string, contacts: ComposeContactVO[]) {
    this.title = title;
    this.contacts = contacts;
  }
}

@ComponentV2
export struct TgNewGroupMembersPage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private contacts: ComposeContactVO[] = [];
  @Local private visibleContacts: ComposeContactVO[] = [];
  @Local private sections: GroupContactSectionVO[] = [];
  @Local private selectedUserIds: number[] = [];
  @Local private searchQuery: string = '';
  @Local private isPushingInfo: boolean = false;
  @Local private errorText: string = '';

  private pendingCreationResult?: ComposeCreationResult;
  private isClosing: boolean = false;

  aboutToAppear(): void {
    this.isClosing = false;
    this.isPushingInfo = false;
    this.errorText = '';
    try {
      const state: AppState = getAppCoreRuntime().getStore().getState();
      this.contacts = buildComposeContacts(state, this.resolveLocale());
      this.rebuildVisibleContacts();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to build group contacts: %{public}s', String(error));
      this.contacts = [];
      this.visibleContacts = [];
      this.sections = [];
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
    }
    return 'en';
  }

  private rebuildVisibleContacts(): void {
    this.visibleContacts = filterComposeContacts(this.contacts, this.searchQuery);
    const sectionMap: Map<string, ComposeContactVO[]> = new Map<string, ComposeContactVO[]>();
    const sectionOrder: string[] = [];
    for (const contact of this.visibleContacts) {
      let sectionContacts: ComposeContactVO[] | undefined = sectionMap.get(contact.sectionTitle);
      if (sectionContacts === undefined) {
        sectionContacts = [];
        sectionMap.set(contact.sectionTitle, sectionContacts);
        sectionOrder.push(contact.sectionTitle);
      }
      sectionContacts.push(contact);
    }
    const nextSections: GroupContactSectionVO[] = [];
    for (const title of sectionOrder) {
      nextSections.push(new GroupContactSectionVO(title, sectionMap.get(title) ?? []));
    }
    this.sections = nextSections;
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

  private handleBackPress(): void {
    if (this.pendingCreationResult !== undefined) {
      this.handoffPendingCreation();
      return;
    }
    if (this.isClosing) {
      return;
    }
    this.isClosing = true;
    try {
      this.pageStack.pop(new ComposeCreationResult());
    } catch (error) {
      this.isClosing = false;
      hilog.error(DOMAIN, TAG, 'Group members cancel failed: %{public}s', String(error));
    }
  }

  private handoffPendingCreation(): void {
    const result: ComposeCreationResult | undefined = this.pendingCreationResult;
    if (result === undefined || this.isClosing) {
      return;
    }
    this.isClosing = true;
    try {
      this.pageStack.pop(result);
      this.pendingCreationResult = undefined;
    } catch (error) {
      this.isClosing = false;
      this.errorText = localized($r('app.string.action_failed').id, 'Action failed');
      hilog.error(DOMAIN, TAG, 'Group result handoff failed: %{public}s', String(error));
    }
  }

  private handleNextPress(): void {
    if (this.pendingCreationResult !== undefined) {
      this.handoffPendingCreation();
      return;
    }
    if (this.isPushingInfo || this.isClosing) {
      return;
    }
    this.isPushingInfo = true;
    try {
      this.pageStack.pushPathByName(
        'TgNewGroupInfoPage',
        new NewGroupInfoRouteParams(this.selectedUserIds),
        (popInfo) => {
          this.isPushingInfo = false;
          const result = popInfo.result as ComposeCreationResult | undefined;
          if (!result || result.chatId <= 0 || this.isClosing) {
            return;
          }
          this.pendingCreationResult = result;
          this.handoffPendingCreation();
        }
      );
    } catch (error) {
      this.isPushingInfo = false;
      hilog.error(DOMAIN, TAG, 'Failed to open group info: %{public}s', String(error));
    }
  }

  private toggleSelection(userId: number): void {
    if (this.isPushingInfo || this.isClosing) {
      return;
    }
    const isSelected: boolean = this.selectedUserIds.includes(userId);
    if (!isSelected && this.selectedUserIds.length >= MAX_BASIC_GROUP_MEMBER_COUNT) {
      this.errorText = localized(
        $r('app.string.group_member_limit_reached').id,
        'You can select up to %d members.'
      ).replace('%d', MAX_BASIC_GROUP_MEMBER_COUNT.toString());
      return;
    }
    this.selectedUserIds = toggleComposeUserSelection(this.selectedUserIds, userId);
    this.errorText = '';
  }

  private selectedCountText(): string {
    return localized($r('app.string.selected_count').id, '%d selected')
      .replace('%d', this.selectedUserIds.length.toString());
  }

  @Builder
  private buildSearch() {
    Column() {
      Search({ value: this.searchQuery, placeholder: localized($r('app.string.search_placeholder').id, 'Search') })
        .width('100%')
        .height(TgUiTokens.FORWARD_PICKER_SEARCH_HEIGHT)
        .backgroundColor(TgUiTokens.SEARCH_BAR_BG)
        .borderRadius(TgUiTokens.FORWARD_PICKER_SEARCH_RADIUS)
        .placeholderColor(TgUiTokens.SEARCH_BAR_PLACEHOLDER_COLOR)
        .placeholderFont({ size: TgUiTokens.SEARCH_BAR_FONT_SIZE, weight: FontWeight.Regular })
        .textFont({ size: TgUiTokens.SEARCH_BAR_FONT_SIZE, weight: FontWeight.Regular })
        .fontColor(TgUiTokens.SEARCH_BAR_TEXT_COLOR)
        .searchIcon({ size: TgUiTokens.SEARCH_BAR_ICON_SIZE, color: TgUiTokens.SEARCH_BAR_ICON_COLOR })
        .enterKeyType(EnterKeyType.Search)
        .onChange((value: string): void => {
          this.searchQuery = value;
          this.rebuildVisibleContacts();
        })
    }
    .width('100%')
    .height(TgUiTokens.FORWARD_PICKER_SEARCH_AREA_HEIGHT)
    .padding({
      left: TgUiTokens.FORWARD_PICKER_SEARCH_SIDE_INSET,
      right: TgUiTokens.FORWARD_PICKER_SEARCH_SIDE_INSET
    })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private buildContactRow(contact: ComposeContactVO, showSeparator: boolean) {
    TgContactRow({
      name: contact.name,
      initials: contact.initials,
      statusText: this.formatUserStatus(contact.status),
      avatarPath: this.avatarUri(contact.avatarPath),
      isOnline: contact.isOnline,
      showSeparator: showSeparator,
      rowHeight: TgUiTokens.COMPOSE_CONTACT_ROW_HEIGHT,
      contentGap: TgUiTokens.COMPOSE_CONTACT_ROW_GAP,
      statusFontSize: TgUiTokens.COMPOSE_CONTACT_STATUS_SIZE,
      separatorInset: TgUiTokens.COMPOSE_CONTACT_SEPARATOR_INSET,
      showSelection: true,
      isSelected: this.selectedUserIds.includes(contact.userId),
      onPress: (): void => this.toggleSelection(contact.userId)
    })
  }

  @Builder
  private buildSectionHeader(title: string) {
    TgContactSectionHeader({
      title: title,
      sectionHeight: TgUiTokens.COMPOSE_CONTACT_SECTION_HEIGHT
    })
  }

  @Builder
  private buildContactList() {
    List() {
      if (this.sections.length === 0) {
        ListItem() {
          Text(localized($r('app.string.no_contacts').id, 'No contacts'))
            .width('100%')
            .fontSize(TgUiTokens.CONTACT_ROW_STATUS_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            .textAlign(TextAlign.Center)
            .padding({ top: TgUiTokens.SPACE_24, bottom: TgUiTokens.SPACE_24 })
        }
      } else {
        ForEach(this.sections, (section: GroupContactSectionVO) => {
          ListItemGroup({ header: this.buildSectionHeader(section.title) }) {
            ForEach(section.contacts, (contact: ComposeContactVO, index?: number) => {
              ListItem() {
                this.buildContactRow(contact, (index ?? 0) < section.contacts.length - 1)
              }
            }, (contact: ComposeContactVO): string => 'new-group-contact-' + contact.userId.toString())
          }
        }, (section: GroupContactSectionVO): string => 'new-group-section-' + section.title)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .cachedCount(12)
    .edgeEffect(EdgeEffect.Spring)
  }

  build() {
    NavDestination() {
      Column() {
        TgForwardPickerNavigationBar({
          title: localized($r('app.string.new_group').id, 'New Group'),
          backAccessibilityText: localized($r('app.string.accessibility_back').id, 'Back'),
          trailingTitle: localized($r('app.string.next_button').id, 'Next'),
          trailingAccessibilityText: localized($r('app.string.next_button').id, 'Next'),
          trailingEnabled: !this.isPushingInfo && !this.isClosing,
          onBackPress: (): void => this.handleBackPress(),
          onTrailingPress: (): void => this.handleNextPress()
        })
        this.buildSearch()
        Text(this.errorText.length > 0 ? this.errorText : this.selectedCountText())
          .width('100%')
          .height(TgUiTokens.COMPOSE_CONTACT_SECTION_HEIGHT)
          .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
          .fontSize(TgUiTokens.COMPOSE_CONTACT_STATUS_SIZE)
          .fontColor(this.errorText.length > 0 ? TgUiTokens.COLOR_TEXT_ERROR : TgUiTokens.COLOR_TEXT_PREVIEW)
          .textAlign(TextAlign.Start)
        this.buildContactList()
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
export function TgNewGroupMembersPageBuilder() {
  TgNewGroupMembersPage()
}
