// TgProfilePage — user/chat profile screen
// Opens from TgChatScreenPage via avatar/title tap
// V2 @ComponentV2 — migrated from V1
// Reference: iOS Telegram PeerInfoScreen

import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState, User, Chat } from '../../../core/model/AppState';
import { loadUserFullInfo, loadSupergroupFullInfo } from '../../../domain/usecases/loadProfileInfo';
import { TgAvatar } from '../../tg_ui/atoms/TgAvatar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
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

  constructor(chatId: number) {
    this.chatId = chatId;
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
  if (!title) return '?';
  const trimmed = title.trim();
  if (trimmed.length === 0) return '?';
  const spaceIdx = trimmed.indexOf(' ');
  if (spaceIdx > 0 && spaceIdx < trimmed.length - 1) {
    return (trimmed.charAt(0) + trimmed.charAt(spaceIdx + 1)).toUpperCase();
  }
  return trimmed.charAt(0).toUpperCase();
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
    case 'online': return 'online';
    case 'recently': return 'last seen recently';
    case 'lastWeek': return 'last seen within a week';
    case 'lastMonth': return 'last seen within a month';
    case 'longTimeAgo': return 'last seen a long time ago';
    default: return 'offline';
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

  private isGroupOrChannel(): boolean {
    return this.chatType === 'supergroup' || this.chatType === 'channel' || this.chatType === 'group';
  }

  aboutToAppear(): void {
    try {
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
    if (chatId <= 0) return;
    this.chatId = chatId;

    const runtime = getAppCoreRuntime();
    const state = runtime.getStore().getState();
    this.applyState(state);

    if (this.storeUnsubscribe) {
      this.storeUnsubscribe();
    }
    this.storeUnsubscribe = runtime.getStore().subscribe((newState: AppState) => {
      this.applyState(newState);
    });

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

  private applyState(state: AppState): void {
    const chat = state.chats.chats.get(this.chatId);
    if (!chat) return;

    this.chatType = chat.type;
    this.isMuted = chat.muteForSeconds > 0;
    this.memberCount = chat.memberCount;
    this.description = chat.description;
    this.inviteLink = chat.inviteLink;
    this.administratorCount = chat.administratorCount;

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
    if (this.storeUnsubscribe) {
      this.storeUnsubscribe();
      this.storeUnsubscribe = undefined;
    }
  }

  private handleBackPress(): void {
    const navStack: NavPathStack | undefined = this.pageStack;
    if (navStack !== undefined) {
      navStack.pop();
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
        this.buildDisclosureRow('Members', formatMemberCount(this.memberCount),
          this.administratorCount > 0)
      }
      if (this.administratorCount > 0) {
        this.buildDisclosureRow('Administrators', this.administratorCount.toString(), false)
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
        this.buildDisclosureRow('Media', '', true)
        this.buildDisclosureRow('Files', '', true)
        this.buildDisclosureRow('Links', '', true)
        this.buildDisclosureRow('Voice', '', false)
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

            // Notifications
            this.buildNotificationsSection()

            // Members (groups/channels only)
            if (this.isGroupOrChannel() && (this.memberCount > 0 || this.administratorCount > 0)) {
              this.buildMembersSection()
            }

            // Shared Media (all chat types)
            this.buildSharedMediaSection()

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
    .title(this.title)
    .onReady((context: NavDestinationContext) => {
      hilog.info(DOMAIN, TAG, 'onReady');
      const params = context.pathInfo.param as ProfileRouteParams;
      if (params && params.chatId > 0) {
        this.loadProfile(params.chatId);
      }
      this.pageStack = context.pathStack;
    })
    .onBackPressed((): boolean => {
      this.handleBackPress();
      return true;
    })
  }
}
