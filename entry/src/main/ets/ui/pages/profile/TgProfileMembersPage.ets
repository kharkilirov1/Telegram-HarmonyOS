// TgProfileMembersPage — live Peer Info members/administrators list.
// Native/HDS chrome stays in TgChatTopBar; Telegram identity rows are custom.

import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { fileUri } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { ChatMembersFilterKind } from '../../../core/model/AppCommand';
import { AppState, Chat, User } from '../../../core/model/AppState';
import { localized } from '../../../core/utils/AppResource';
import {
  ChatMemberDescriptor,
  ChatMembersUseCase,
  createChatMembersUseCase
} from '../../../domain/usecases/chatMembers';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import {
  TgChatTopBar,
  TgChatTopBarSubtitleMode,
  TgChatTopBarTrailingAction
} from '../../tg_ui/atoms/TgChatTopBar';
import { TgProfileMemberRoleKind, TgProfileMemberRow } from '../../tg_ui/atoms/TgProfileMemberRow';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgProfileMemberRowVO, TgProfileMembersDataSource } from './TgProfileMembersDataSource';

const DOMAIN = 0x0035;
const TAG = 'TgProfileMembers';
const PAGE_SIZE = 100;
const SEARCH_DEBOUNCE_MS = 240;

declare function px2vp(value: number): number;

export class ProfileMembersRouteParams {
  chatId: number = 0;
  supergroupId: number = 0;
  filterKind: ChatMembersFilterKind = 'all';
  expectedCount: number = 0;

  constructor(
    chatId: number,
    supergroupId: number = 0,
    filterKind: ChatMembersFilterKind = 'all',
    expectedCount: number = 0
  ) {
    this.chatId = chatId;
    this.supergroupId = supergroupId;
    this.filterKind = filterKind;
    this.expectedCount = expectedCount;
  }
}

class DirectUserProfileRouteParams {
  chatId: number = 0;
  userId: number = 0;

  constructor(userId: number) {
    this.userId = userId;
  }
}

function firstAlphabeticLetter(value: string): string {
  const upper: string = value.toUpperCase();
  for (let index: number = 0; index < upper.length; index++) {
    const character: string = upper.charAt(index);
    if ((character >= 'A' && character <= 'Z') ||
      (character >= 'А' && character <= 'Я') || character === 'Ё') {
      return character;
    }
  }
  return '';
}

function initialsForUser(user: User): string {
  const first = firstAlphabeticLetter(user.firstName);
  const last = firstAlphabeticLetter(user.lastName);
  if (first.length > 0 && last.length > 0) {
    return first + last;
  }
  if (first.length > 0) {
    return first;
  }
  if (user.username.length > 0) {
    return user.username.charAt(0).toUpperCase();
  }
  return '?';
}

function initialsForTitle(title: string): string {
  const first = firstAlphabeticLetter(title);
  return first.length > 0 ? first : '?';
}

function userDisplayName(user: User): string {
  const fullName = (user.firstName + ' ' + user.lastName).trim();
  if (fullName.length > 0) {
    return fullName;
  }
  if (user.username.length > 0) {
    return '@' + user.username;
  }
  return localized($r('app.string.deleted_account').id, 'Deleted Account');
}

function userStatusText(user: User): string {
  if (user.isBot) {
    return localized($r('app.string.member_role_bot').id, 'bot');
  }
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

function toFileUri(path: string): string {
  if (path.length === 0) {
    return '';
  }
  try {
    return fileUri.getUriFromPath(path);
  } catch (_error) {
    return '';
  }
}

@ComponentV2
export struct TgProfileMembersPage {
  @Local pageStack: NavPathStack = new NavPathStack();
  @Local private chatId: number = 0;
  @Local private supergroupId: number = 0;
  @Local private filterKind: ChatMembersFilterKind = 'all';
  @Local private topInset: number = 0;
  @Local private totalCount: number = 0;
  @Local private rowCount: number = 0;
  @Local private isLoading: boolean = true;
  @Local private isLoadingMore: boolean = false;
  @Local private canLoadMore: boolean = false;
  @Local private errorText: string = '';
  @Local private isSearchMode: boolean = false;
  @Local private searchQuery: string = '';

  private useCase?: ChatMembersUseCase;
  private descriptors: ChatMemberDescriptor[] = [];
  private dataSource: TgProfileMembersDataSource = new TgProfileMembersDataSource();
  private storeUnsubscribe?: () => void;
  private searchTimer: number = -1;
  private requestGeneration: number = 0;
  private isClosing: boolean = false;

  aboutToAppear(): void {
    this.isClosing = false;
    this.useCase = createChatMembersUseCase(getTdGatewayAdapter());
    const store = getAppCoreRuntime().getStore();
    this.storeUnsubscribe = store.subscribe((state: AppState): void => {
      if (this.descriptors.length > 0) {
        this.rebuildRows(state);
      }
    });
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const mainWindow = context.windowStage?.getMainWindowSync();
      if (mainWindow !== undefined) {
        const avoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        this.topInset = px2vp(avoidArea.topRect.height);
      }
    } catch (_error) {
      this.topInset = 0;
    }
  }

  aboutToDisappear(): void {
    this.requestGeneration++;
    this.cancelSearchTimer();
    if (this.storeUnsubscribe !== undefined) {
      this.storeUnsubscribe();
      this.storeUnsubscribe = undefined;
    }
    this.isClosing = false;
  }

  private cancelSearchTimer(): void {
    if (this.searchTimer >= 0) {
      clearTimeout(this.searchTimer);
      this.searchTimer = -1;
    }
  }

  private pageTitle(): string {
    if (this.filterKind === 'administrators') {
      return localized($r('app.string.administrators_label').id, 'Administrators');
    }
    return localized($r('app.string.members_label').id, 'Members');
  }

  private pageSubtitle(): string {
    const count = this.totalCount > 0 ? this.totalCount : this.rowCount;
    if (count <= 0) {
      return '';
    }
    return localized($r('app.string.members_count').id, '%d members').replace('%d', count.toString());
  }

  private roleLabel(descriptor: ChatMemberDescriptor): string {
    if (descriptor.customTitle.length > 0) {
      return descriptor.customTitle;
    }
    if (descriptor.role === 'creator') {
      return localized($r('app.string.owner_role').id, 'Owner');
    }
    if (descriptor.role === 'administrator') {
      return localized($r('app.string.admin_label').id, 'admin');
    }
    return '';
  }

  private avatarColorIndex(id: number): number {
    return Math.abs(id) % 8;
  }

  private avatarColor(index: number): ResourceColor {
    const palette: Resource[] = [
      TgUiTokens.AVATAR_COLOR_1, TgUiTokens.AVATAR_COLOR_2,
      TgUiTokens.AVATAR_COLOR_3, TgUiTokens.AVATAR_COLOR_4,
      TgUiTokens.AVATAR_COLOR_5, TgUiTokens.AVATAR_COLOR_6,
      TgUiTokens.AVATAR_COLOR_7, TgUiTokens.AVATAR_COLOR_8
    ];
    return palette[Math.abs(index) % palette.length];
  }

  private buildUserRow(descriptor: ChatMemberDescriptor, user: User | undefined): TgProfileMemberRowVO {
    const row = new TgProfileMemberRowVO();
    row.stableId = descriptor.stableKey();
    row.userId = descriptor.senderUserId;
    row.role = descriptor.role;
    row.roleLabel = this.roleLabel(descriptor);
    row.isEnabled = descriptor.senderUserId !== 0;
    if (user !== undefined) {
      row.title = userDisplayName(user);
      row.subtitle = userStatusText(user);
      row.avatarInitials = initialsForUser(user);
      row.avatarImageSrc = toFileUri(user.photoSmall);
      row.avatarColorIndex = this.avatarColorIndex(user.accentColorId >= 0 ? user.accentColorId : user.id);
      row.isOnline = user.status === 'online';
    } else {
      row.title = localized($r('app.string.deleted_account').id, 'Deleted Account');
      row.subtitle = localized($r('app.string.offline').id, 'offline');
      row.avatarInitials = '?';
      row.avatarColorIndex = this.avatarColorIndex(descriptor.senderUserId);
    }
    return row;
  }

  private buildSenderChatRow(descriptor: ChatMemberDescriptor, chat: Chat | undefined): TgProfileMemberRowVO {
    const row = new TgProfileMemberRowVO();
    row.stableId = descriptor.stableKey();
    row.senderChatId = descriptor.senderChatId;
    row.role = descriptor.role;
    row.roleLabel = this.roleLabel(descriptor);
    row.isEnabled = false;
    row.title = chat !== undefined && chat.title.length > 0 ? chat.title : this.pageTitle();
    row.subtitle = descriptor.isAnonymous ? localized($r('app.string.admin_label').id, 'admin') : '';
    row.avatarInitials = initialsForTitle(row.title);
    row.avatarImageSrc = chat !== undefined ? toFileUri(chat.photoSmall) : '';
    row.avatarColorIndex = this.avatarColorIndex(descriptor.senderChatId);
    return row;
  }

  private rebuildRows(state: AppState): void {
    const rows: TgProfileMemberRowVO[] = [];
    for (let i = 0; i < this.descriptors.length; i++) {
      const descriptor = this.descriptors[i];
      if (descriptor.senderUserId !== 0) {
        rows.push(this.buildUserRow(descriptor, state.users.users.get(descriptor.senderUserId)));
      } else {
        rows.push(this.buildSenderChatRow(descriptor, state.chats.chats.get(descriptor.senderChatId)));
      }
    }
    this.dataSource.replace(rows);
    this.rowCount = rows.length;
  }

  private mergeDescriptors(next: ChatMemberDescriptor[], reset: boolean): void {
    if (reset) {
      this.descriptors = next.slice();
      return;
    }
    const seen = new Set<string>();
    for (let i = 0; i < this.descriptors.length; i++) {
      seen.add(this.descriptors[i].stableKey());
    }
    const merged = this.descriptors.slice();
    for (let i = 0; i < next.length; i++) {
      const key = next[i].stableKey();
      if (!seen.has(key)) {
        seen.add(key);
        merged.push(next[i]);
      }
    }
    this.descriptors = merged;
  }

  private async loadMembers(reset: boolean): Promise<void> {
    if (this.useCase === undefined || this.chatId === 0 || (!reset && (!this.canLoadMore || this.isLoadingMore))) {
      return;
    }
    const generation = ++this.requestGeneration;
    const query = this.searchQuery.trim();
    const offset = reset ? 0 : this.descriptors.length;
    if (reset) {
      this.isLoading = true;
      this.errorText = '';
      this.canLoadMore = false;
    } else {
      this.isLoadingMore = true;
    }
    try {
      const result = await this.useCase.execute(
        this.chatId,
        this.supergroupId,
        this.filterKind,
        query,
        offset,
        PAGE_SIZE
      );
      if (generation !== this.requestGeneration) {
        return;
      }
      this.mergeDescriptors(result.members, reset);
      this.totalCount = result.totalCount;
      this.canLoadMore = result.canLoadMore;
      this.rebuildRows(getAppCoreRuntime().getStore().getState());
      hilog.info(DOMAIN, TAG, 'Loaded %{public}d/%{public}d members query=%{public}s',
        this.rowCount, this.totalCount, query.length > 0 ? 'yes' : 'no');
    } catch (error) {
      if (generation !== this.requestGeneration) {
        return;
      }
      this.errorText = localized($r('app.string.members_unavailable').id, 'Members are unavailable');
      if (reset) {
        this.descriptors = [];
        this.dataSource.replace([]);
        this.rowCount = 0;
      }
      hilog.warn(DOMAIN, TAG, 'Member load failed: %{public}s', String(error));
    } finally {
      if (generation === this.requestGeneration) {
        this.isLoading = false;
        this.isLoadingMore = false;
      }
    }
  }

  private scheduleSearch(query: string): void {
    this.searchQuery = query;
    this.cancelSearchTimer();
    this.searchTimer = setTimeout((): void => {
      this.searchTimer = -1;
      this.loadMembers(true);
    }, SEARCH_DEBOUNCE_MS);
  }

  private closeSearch(): void {
    this.cancelSearchTimer();
    this.isSearchMode = false;
    if (this.searchQuery.length > 0) {
      this.searchQuery = '';
      this.loadMembers(true);
    }
  }

  private openUserProfile(userId: number): void {
    if (userId === 0) {
      return;
    }
    try {
      this.pageStack.pushPathByName('TgProfilePage', new DirectUserProfileRouteParams(userId));
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to open member profile: %{public}s', String(error));
    }
  }

  private handleBackPress(): void {
    if (this.isClosing) {
      return;
    }
    try {
      this.isClosing = true;
      this.pageStack.pop();
    } catch (error) {
      this.isClosing = false;
      hilog.error(DOMAIN, TAG, 'Failed to pop members page: %{public}s', String(error));
    }
  }

  private roleKind(row: TgProfileMemberRowVO): TgProfileMemberRoleKind {
    if (row.role === 'creator') {
      return 'creator';
    }
    if (row.role === 'administrator') {
      return 'administrator';
    }
    return 'member';
  }

  @Builder
  private buildMemberList() {
    List() {
      LazyForEach(this.dataSource, (row: TgProfileMemberRowVO, index: number) => {
        ListItem() {
          TgProfileMemberRow({
            title: row.title,
            subtitle: row.subtitle,
            avatarInitials: row.avatarInitials,
            avatarImageSrc: row.avatarImageSrc,
            avatarColor: this.avatarColor(row.avatarColorIndex),
            isOnline: row.isOnline,
            roleLabel: row.roleLabel,
            roleKind: this.roleKind(row),
            showSeparator: index < this.rowCount - 1,
            isEnabled: row.isEnabled,
            onPress: (): void => {
              this.openUserProfile(row.userId);
            }
          })
        }
        .reuseId('tg_profile_member_row')
      }, (row: TgProfileMemberRowVO): string => row.stableId)

      if (this.isLoadingMore) {
        ListItem() {
          Row() {
            LoadingProgress()
              .width(24)
              .height(24)
          }
          .width('100%')
          .height(48)
          .justifyContent(FlexAlign.Center)
        }
      }
    }
    .width('100%')
    .layoutWeight(1)
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Off)
    .onScrollIndex((_first: number, last: number): void => {
      if (last >= this.rowCount - 8) {
        this.loadMembers(false);
      }
    })
  }

  @Builder
  private buildStateMessage(text: string, showRetry: boolean) {
    Column({ space: 12 }) {
      Text(text)
        .fontSize(15)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .textAlign(TextAlign.Center)
      if (showRetry) {
        Text(localized($r('app.string.retry').id, 'Retry'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_ICON_PRIMARY)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .onClick((): void => {
            this.loadMembers(true);
          })
      }
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 32, right: 32 })
  }

  build() {
    NavDestination() {
      Column() {
        TgChatTopBar({
          title: this.pageTitle(),
          subtitle: this.pageSubtitle(),
          subtitleMode: TgChatTopBarSubtitleMode.Secondary,
          trailingAction: TgChatTopBarTrailingAction.Search,
          topInset: this.topInset,
          isSearchMode: this.isSearchMode,
          searchQuery: this.searchQuery,
          searchPlaceholder: localized($r('app.string.search_members').id, 'Search Members'),
          onBackPress: (): void => {
            this.handleBackPress();
          },
          onSearchPress: (): void => {
            this.isSearchMode = true;
          },
          onSearchQueryChange: (query: string): void => {
            this.scheduleSearch(query);
          },
          onSearchClose: (): void => {
            this.closeSearch();
          }
        })

        if (this.isLoading && this.rowCount === 0) {
          Column() {
            LoadingProgress()
              .width(32)
              .height(32)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.errorText.length > 0 && this.rowCount === 0) {
          this.buildStateMessage(this.errorText, true)
        } else if (this.rowCount === 0) {
          this.buildStateMessage(localized($r('app.string.search_no_results').id, 'No results found'), false)
        } else {
          this.buildMemberList()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext): void => {
      this.pageStack = context.pathStack;
      const params = context.pathInfo.param as ProfileMembersRouteParams;
      if (params !== undefined && params.chatId !== 0) {
        this.chatId = params.chatId;
        this.supergroupId = params.supergroupId;
        this.filterKind = params.filterKind;
        this.totalCount = params.expectedCount;
        this.loadMembers(true);
      }
    })
    .onBackPressed((): boolean => {
      this.handleBackPress();
      return true;
    })
  }
}

@Builder
export function TgProfileMembersPageBuilder() {
  TgProfileMembersPage()
}
