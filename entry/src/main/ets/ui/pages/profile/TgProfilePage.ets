// TgProfilePage — user/chat profile screen
// Opens from TgChatScreenPage via avatar/title tap
// V2 @ComponentV2 — migrated from V1
// Reference: iOS Telegram PeerInfoScreen

import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState, User, Chat } from '../../../core/model/AppState';
import { loadUserFullInfo, loadSupergroupFullInfo } from '../../../domain/usecases/loadProfileInfo';
import { TgAvatar } from '../../tg_ui/atoms/TgAvatar';
import { TgProfileNavigationBar } from '../../tg_ui/atoms/TgProfileNavigationBar';
import { SharedMediaRouteParams } from './TgSharedMediaPage';
import { ProfileMembersRouteParams } from './TgProfileMembersPage';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { PendingChatSearchSignal } from '../chat/PendingChatSearchSignal';
import { localized } from '../../../core/utils/AppResource';
import { fileUri } from '@kit.CoreFileKit';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0031;
const TAG = 'TgProfilePage';

declare function px2vp(value: number): number;

// Route params passed from chat screen
export class ProfileRouteParams {
  chatId: number = 0;
  userId: number = 0;

  constructor(chatId: number, userId: number = 0) {
    this.chatId = chatId;
    this.userId = userId;
  }
}

const AVATAR_COLORS: Resource[] = [
  TgUiTokens.AVATAR_COLOR_1, TgUiTokens.AVATAR_COLOR_2,
  TgUiTokens.AVATAR_COLOR_3, TgUiTokens.AVATAR_COLOR_4,
  TgUiTokens.AVATAR_COLOR_5, TgUiTokens.AVATAR_COLOR_6,
  TgUiTokens.AVATAR_COLOR_7, TgUiTokens.AVATAR_COLOR_8,
];

function getAvatarColor(id: number): Resource {
  return AVATAR_COLORS[Math.abs(id) % AVATAR_COLORS.length];
}

function getInitials(title: string): string {
  const words = title.trim().split(' ');
  let result = '';
  for (let wordIndex = 0; wordIndex < words.length && result.length < 2; wordIndex++) {
    const upper = words[wordIndex].toUpperCase();
    for (let index = 0; index < upper.length; index++) {
      const character = upper.charAt(index);
      if ((character >= 'A' && character <= 'Z') ||
        (character >= 'А' && character <= 'Я') || character === 'Ё') {
        result += character;
        break;
      }
    }
  }
  return result.length > 0 ? result : '?';
}

function toFileUri(path: string): string {
  if (path.length === 0) return '';
  try {
    return fileUri.getUriFromPath(path);
  } catch (_e) {
    return '';
  }
}

function formatPhone(phone: string): string {
  if (phone.length === 0) return '';
  if (phone.startsWith('+')) return phone;
  return '+' + phone;
}

function statusText(user: User): string {
  switch (user.status) {
    case 'online': return localized($r('app.string.online').id, 'online');
    case 'recently': return localized($r('app.string.last_seen_recently').id, 'last seen recently');
    case 'lastWeek': return localized($r('app.string.last_seen_within_week').id, 'last seen within a week');
    case 'lastMonth': return localized($r('app.string.last_seen_within_month').id, 'last seen within a month');
    case 'longTimeAgo': return localized($r('app.string.last_seen_long_ago').id, 'last seen a long time ago');
    default: return localized($r('app.string.offline').id, 'offline');
  }
}

function memberCountText(count: number, chatType: string): string {
  if (count <= 0) return '';
  if (chatType === 'channel') {
    return count.toString() + ' subscribers';
  }
  return count.toString() + ' members';
}

function formatMemberCount(count: number): string {
  if (count >= 1000000) {
    return (count / 1000000).toFixed(1) + 'M';
  }
  if (count >= 1000) {
    return (count / 1000).toFixed(1) + 'K';
  }
  return count.toString();
}

@ComponentV2
export struct TgProfilePage {
  @Local pageStack: NavPathStack = new NavPathStack();

  @Local private chatId: number = 0;
  @Local private profileUserId: number = 0;
  @Local private supergroupId: number = 0;
  @Local private title: string = '';
  @Local private subtitle: string = '';
  @Local private avatarInitials: string = '';
  @Local private avatarImageSrc: string = '';
  @Local private avatarColor: Resource = TgUiTokens.AVATAR_COLOR_5;
  @Local private isOnline: boolean = false;

  // Info fields
  @Local private phoneNumber: string = '';
  @Local private username: string = '';
  @Local private bio: string = '';
  @Local private chatType: string = 'private';
  @Local private memberCount: number = 0;
  @Local private administratorCount: number = 0;
  @Local private description: string = '';
  @Local private inviteLink: string = '';
  @Local private isMuted: boolean = false;
  @Local private isVerified: boolean = false;
  @Local private isPremium: boolean = false;

  @Local private topInset: number = 0;
  private storeUnsubscribe: (() => void) | undefined = undefined;
  private pageLifecycleToken: number = 0;
  private isClosing: boolean = false;

  private isGroupOrChannel(): boolean {
    return this.chatType === 'supergroup' || this.chatType === 'channel' || this.chatType === 'group';
  }

  aboutToAppear(): void {
    try {
      this.isClosing = false;
      this.pageLifecycleToken++;
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const windowStage = context.windowStage;
      if (windowStage) {
        const mainWindow = windowStage.getMainWindowSync();
        const avoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        this.topInset = px2vp(avoidArea.topRect.height);
      }
    } catch (_e) {
      this.topInset = 0;
    }
  }

  private loadProfile(chatId: number): void {
    if (chatId === 0) return; // groups/channels have negative ids
    this.chatId = chatId;
    this.profileUserId = 0;

    const runtime = getAppCoreRuntime();
    const state = runtime.getStore().getState();
    this.applyState(state);

    if (this.storeUnsubscribe !== undefined) {
      this.storeUnsubscribe();
      this.storeUnsubscribe = undefined;
    }
    const lifecycleToken: number = this.pageLifecycleToken;
    const profileChatId: number = chatId;
    let activeUnsubscribe: (() => void) | undefined = undefined;
    activeUnsubscribe = runtime.getStore().subscribe((newState: AppState) => {
      if (lifecycleToken !== this.pageLifecycleToken ||
        this.chatId !== profileChatId ||
        this.storeUnsubscribe !== activeUnsubscribe) {
        return;
      }
      this.applyState(newState);
    });
    this.storeUnsubscribe = activeUnsubscribe;

    // Fetch full info from TDLib
    const chat = state.chats.chats.get(chatId);
    if (chat) {
      if ((chat.type === 'private' || chat.type === 'secret') && chat.peerUserId > 0) {
        loadUserFullInfo(chat.peerUserId);
      } else if ((chat.type === 'supergroup' || chat.type === 'channel') && chat.supergroupId > 0) {
        loadSupergroupFullInfo(chatId, chat.supergroupId);
      }
    }
  }

  private loadUserProfile(userId: number): void {
    if (userId <= 0) return;
    this.chatId = 0;
    this.profileUserId = userId;
    this.chatType = 'private';

    const runtime = getAppCoreRuntime();
    this.applyState(runtime.getStore().getState());
    if (this.storeUnsubscribe !== undefined) {
      this.storeUnsubscribe();
      this.storeUnsubscribe = undefined;
    }
    const lifecycleToken = this.pageLifecycleToken;
    const targetUserId = userId;
    let activeUnsubscribe: (() => void) | undefined = undefined;
    activeUnsubscribe = runtime.getStore().subscribe((state: AppState): void => {
      if (lifecycleToken !== this.pageLifecycleToken ||
        this.profileUserId !== targetUserId ||
        this.storeUnsubscribe !== activeUnsubscribe) {
        return;
      }
      this.applyState(state);
    });
    this.storeUnsubscribe = activeUnsubscribe;
    loadUserFullInfo(userId);
  }

  private applyState(state: AppState): void {
    if (this.chatId === 0 && this.profileUserId > 0) {
      const directUser = state.users.users.get(this.profileUserId);
      if (directUser === undefined) return;
      const directName = (directUser.firstName + ' ' + directUser.lastName).trim();
      this.title = directName.length > 0 ? directName :
        (directUser.username.length > 0 ? '@' + directUser.username :
          localized($r('app.string.deleted_account').id, 'Deleted Account'));
      this.subtitle = statusText(directUser);
      this.isOnline = directUser.status === 'online';
      this.phoneNumber = formatPhone(directUser.phoneNumber);
      this.username = directUser.username;
      this.bio = directUser.bio;
      this.isVerified = directUser.isVerified;
      this.isPremium = directUser.isPremium;
      this.avatarImageSrc = toFileUri(directUser.photoSmall);
      this.avatarInitials = getInitials(this.title);
      this.avatarColor = getAvatarColor(directUser.accentColorId >= 0 ? directUser.accentColorId : directUser.id);
      this.memberCount = 0;
      this.administratorCount = 0;
      this.supergroupId = 0;
      this.description = '';
      this.inviteLink = '';
      this.isMuted = false;
      return;
    }
    const chat = state.chats.chats.get(this.chatId);
    if (!chat) return;

    this.chatType = chat.type;
    this.isMuted = chat.muteForSeconds > 0;
    this.memberCount = chat.memberCount;
    this.description = chat.description;
    this.inviteLink = chat.inviteLink;
    this.administratorCount = chat.administratorCount;
    this.supergroupId = chat.supergroupId;

    if ((chat.type === 'private' || chat.type === 'secret') && chat.peerUserId > 0) {
      const user = state.users.users.get(chat.peerUserId);
      if (user) {
        const fullName = (user.firstName + ' ' + user.lastName).trim();
        this.title = fullName.length > 0 ? fullName : (user.username.length > 0 ? '@' + user.username : 'Unknown');
        this.subtitle = statusText(user);
        this.isOnline = user.status === 'online';
        this.phoneNumber = formatPhone(user.phoneNumber);
        this.username = user.username;
        this.bio = user.bio;
        this.isVerified = user.isVerified;
        this.isPremium = user.isPremium;

        const photoPath = user.photoSmall.length > 0 ? toFileUri(user.photoSmall) :
          (chat.photoSmall.length > 0 ? toFileUri(chat.photoSmall) : '');
        this.avatarImageSrc = photoPath;
        this.avatarInitials = getInitials(this.title);
        this.avatarColor = getAvatarColor(chat.id);
      }
    } else {
      // Group / supergroup / channel
      this.title = chat.title.length > 0 ? chat.title : 'Unknown';
      this.subtitle = memberCountText(chat.memberCount, chat.type);
      this.isOnline = false;
      this.avatarImageSrc = chat.photoSmall.length > 0 ? toFileUri(chat.photoSmall) : '';
      this.avatarInitials = getInitials(this.title);
      this.avatarColor = getAvatarColor(chat.id);
      this.phoneNumber = '';
      this.username = '';
      this.bio = '';
    }
  }

  aboutToDisappear(): void {
    this.isClosing = false;
    this.pageLifecycleToken++;
    if (this.storeUnsubscribe) {
      this.storeUnsubscribe();
      this.storeUnsubscribe = undefined;
    }
  }

  private openSharedMedia(): void {
    this.openSharedMediaFiltered('PhotoAndVideo');
  }

  private openSharedMediaFiltered(filterType: string): void {
    if (this.chatId === 0) return;
    try {
      this.pageStack.pushPathByName('TgSharedMediaPage', new SharedMediaRouteParams(this.chatId, filterType));
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to push shared media: %{public}s', String(error));
    }
  }

  private openMembers(filterKind: 'all' | 'administrators'): void {
    if (this.chatId === 0) return;
    const expectedCount = filterKind === 'administrators' ? this.administratorCount : this.memberCount;
    try {
      this.pageStack.pushPathByName('TgProfileMembersPage', new ProfileMembersRouteParams(
        this.chatId,
        this.supergroupId,
        filterKind,
        expectedCount
      ));
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to push profile members: %{public}s', String(error));
    }
  }

  private handleBackPress(): void {
    if (this.isClosing) {
      hilog.warn(DOMAIN, TAG, 'Ignoring duplicate profile back pop while closing');
      return;
    }
    const navStack: NavPathStack | undefined = this.pageStack;
    if (navStack !== undefined) {
      try {
        if (navStack.size() <= 0) {
          hilog.error(DOMAIN, TAG, 'Cannot pop profile page: pageStack is empty');
          return;
        }
        this.isClosing = true;
        navStack.pop();
      } catch (error) {
        this.isClosing = false;
        hilog.error(DOMAIN, TAG, 'Failed to pop profile page: %{public}s', String(error));
      }
    }
  }

  private openChatSearch(): void {
    if (this.chatId === 0) {
      return;
    }
    PendingChatSearchSignal.set(this.chatId);
    try {
      this.pageStack.popToName('TgChatScreenPage');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to return to chat search: %{public}s', String(error));
    }
  }

  // ─── Builders ───

  @Builder
  private buildInfoRowAccent(label: string, value: string, showSeparator: boolean = true) {
    Column() {
      Row() {
        Column() {
          Text(value)
            .fontSize(17)
            .fontColor(TgUiTokens.COLOR_ICON_PRIMARY)
            .maxLines(5)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .copyOption(CopyOptions.LocalDevice)

          Text(label)
            .fontSize(14)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 11, bottom: 11 })

      if (showSeparator) {
        Divider()
          .strokeWidth(0.5)
          .color(TgUiTokens.COLOR_SEPARATOR)
          .margin({ left: 16 })
      }
    }
  }

  @Builder
  private buildInfoRow(label: string, value: string, showSeparator: boolean = true) {
    Column() {
      Row() {
        Column() {
          Text(value)
            .fontSize(17)
            .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
            .maxLines(5)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .copyOption(CopyOptions.LocalDevice)

          Text(label)
            .fontSize(14)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 11, bottom: 11 })

      if (showSeparator) {
        Divider()
          .strokeWidth(0.5)
          .color(TgUiTokens.COLOR_SEPARATOR)
          .margin({ left: 16 })
      }
    }
  }

  @Builder
  private buildDisclosureRow(label: string, value: string, showSeparator: boolean = true) {
    Column() {
      Row() {
        Text(label)
          .fontSize(TgUiTokens.FONT_TITLE_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .layoutWeight(1)

        if (value.length > 0) {
          Text(value)
            .fontSize(TgUiTokens.FONT_TITLE_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            .margin({ right: 4 })
        }

        Image(TgUiTokens.ICON_RES_ARROW_RIGHT)
          .width(16)
          .height(16)
          .fillColor(TgUiTokens.COLOR_ICON_SECONDARY)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .alignItems(VerticalAlign.Center)

      if (showSeparator) {
        Divider()
          .strokeWidth(0.5)
          .color(TgUiTokens.COLOR_SEPARATOR)
          .margin({ left: 16 })
      }
    }
  }

  @Builder
  private buildSwitchRow(label: string, isOn: boolean, showSeparator: boolean = false) {
    Column() {
      Row() {
        Text(label)
          .fontSize(TgUiTokens.FONT_TITLE_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: isOn })
          .selectedColor(TgUiTokens.COLOR_ICON_PRIMARY)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .alignItems(VerticalAlign.Center)

      if (showSeparator) {
        Divider()
          .strokeWidth(0.5)
          .color(TgUiTokens.COLOR_SEPARATOR)
          .margin({ left: 16 })
      }
    }
  }

  @Builder
  private buildSectionHeader(title: string) {
    Text(title.toUpperCase())
      .fontSize(13)
      .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })
  }

  // ─── Section: Header ───
  @Builder
  private buildHeader() {
    Column({ space: 8 }) {
      TgAvatar({
        avatarSize: 100,
        initials: this.avatarInitials,
        useImage: this.avatarImageSrc.length > 0,
        imageSrc: this.avatarImageSrc,
        isOnline: this.isOnline,
        avatarBackgroundColor: this.avatarColor,
        textColor: TgUiTokens.COLOR_AVATAR_PLACEHOLDER_TEXT
      })

      Text(this.title)
        .fontSize(28)
        .fontWeight(FontWeight.Medium)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .maxLines(2)
        .textAlign(TextAlign.Center)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.subtitle.length > 0) {
        Text(this.subtitle)
          .fontSize(17)
          .fontColor(this.isOnline ? TgUiTokens.COLOR_ONLINE_DOT : TgUiTokens.COLOR_TEXT_PREVIEW)
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .padding({ top: 24, bottom: 20 })
    .alignItems(HorizontalAlign.Center)
  }

  // ─── Section: User Info ───
  @Builder
  private buildUserInfoSection() {
    Column() {
      if (this.phoneNumber.length > 0) {
        this.buildInfoRowAccent('phone', this.phoneNumber, this.username.length > 0 || this.bio.length > 0)
      }
      if (this.username.length > 0) {
        this.buildInfoRow('username', '@' + this.username, this.bio.length > 0)
      }
      if (this.bio.length > 0) {
        this.buildInfoRow('bio', this.bio, false)
      }
    }
    .width('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .borderRadius(12)
    .margin({ left: 16, right: 16 })
    .clip(true)
  }

  // ─── Section: Group/Channel Info ───
  @Builder
  private buildGroupInfoSection() {
    Column() {
      // Description
      if (this.description.length > 0) {
        this.buildInfoRow('info', this.description, this.inviteLink.length > 0)
      }
      // Invite link
      if (this.inviteLink.length > 0) {
        this.buildInfoRow('link', this.inviteLink, false)
      }
    }
    .width('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .borderRadius(12)
    .margin({ left: 16, right: 16 })
    .clip(true)
  }

  // ─── Section: Notifications ───
  @Builder
  private buildNotificationsSection() {
    Column() {
      this.buildSwitchRow('Notifications', !this.isMuted)
    }
    .width('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .borderRadius(12)
    .margin({ left: 16, right: 16, top: 16 })
    .clip(true)
  }

  // ─── Section: Members (groups/channels) ───
  @Builder
  private buildMembersSection() {
    Column() {
      if (this.memberCount > 0) {
        Column() {
          this.buildDisclosureRow(localized($r('app.string.members_label').id, 'Members'),
            formatMemberCount(this.memberCount), this.administratorCount > 0)
        }
        .onClick((): void => {
          this.openMembers('all');
        })
      }
      if (this.administratorCount > 0) {
        Column() {
          this.buildDisclosureRow(localized($r('app.string.administrators_label').id, 'Administrators'),
            this.administratorCount.toString(), false)
        }
        .onClick((): void => {
          this.openMembers('administrators');
        })
      }
    }
    .width('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .borderRadius(12)
    .margin({ left: 16, right: 16, top: 16 })
    .clip(true)
  }

  // ─── Section: Shared Media ───
  @Builder
  private buildSharedMediaSection() {
    Column() {
      this.buildSectionHeader('Shared Media')

      Column() {
        Column() {
          this.buildDisclosureRow('Media', '', true)
        }
        .onClick(() => {
          this.openSharedMedia();
        })
        Column() {
          this.buildDisclosureRow('Files', '', true)
        }
        .onClick(() => {
          this.openSharedMediaFiltered('Document');
        })
        Column() {
          this.buildDisclosureRow('Links', '', true)
        }
        .onClick(() => {
          this.openSharedMediaFiltered('Url');
        })
        Column() {
          this.buildDisclosureRow('Voice', '', false)
        }
        .onClick(() => {
          this.openSharedMediaFiltered('VoiceNote');
        })
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
      .borderRadius(12)
      .margin({ left: 16, right: 16 })
      .clip(true)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 16 })
  }

  // ─── Main Build ───
  build() {
    NavDestination() {
      Column() {
        // PeerInfo uses independent left/right glass navigation containers;
        // the system title bar remains hidden because it overlaps the status bar.
        TgProfileNavigationBar({
          topInset: this.topInset,
          showSearch: this.chatId !== 0,
          backAccessibilityText: localized($r('app.string.accessibility_back').id, 'Back'),
          searchAccessibilityText: localized($r('app.string.search_in_chat').id, 'Search in chat'),
          onBackPress: (): void => {
            this.handleBackPress();
          },
          onSearchPress: (): void => {
            this.openChatSearch();
          }
        })

        Scroll() {
          Column() {
            // Header (avatar + name + status)
            this.buildHeader()

            // Info section
            if (this.isGroupOrChannel()) {
              // Group/Channel: description + link
              if (this.description.length > 0 || this.inviteLink.length > 0) {
                this.buildGroupInfoSection()
              }
            } else {
              // User: phone + username + bio
              if (this.phoneNumber.length > 0 || this.username.length > 0 || this.bio.length > 0) {
                this.buildUserInfoSection()
              }
            }

            // Direct member profiles have no chat-owned settings yet.
            if (this.chatId !== 0) {
              this.buildNotificationsSection()
            }

            // Members (groups/channels only)
            if (this.isGroupOrChannel() && (this.memberCount > 0 || this.administratorCount > 0)) {
              this.buildMembersSection()
            }

            if (this.chatId !== 0) {
              this.buildSharedMediaSection()
            }

            // Bottom spacer
            Column().height(40)
          }
          .width('100%')
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      hilog.info(DOMAIN, TAG, 'onReady');
      const params = context.pathInfo.param as ProfileRouteParams;
      if (params && params.chatId !== 0) {
        this.loadProfile(params.chatId);
      } else if (params && params.userId > 0) {
        this.loadUserProfile(params.userId);
      }
      this.pageStack = context.pathStack;
    })
    .onBackPressed((): boolean => {
      this.handleBackPress();
      return true;
    })
  }
}

// System route table builder — referenced by route_map.json
@Builder
export function TgProfilePageBuilder() {
  TgProfilePage()
}
