// TgProfilePage — user/chat profile screen
// Opens from TgChatScreenPage via avatar/title tap
// V1 @Component — same as other shell pages

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
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

@Component
export struct TgProfilePage {
  pageStack: NavPathStack = new NavPathStack();

  @State private chatId: number = 0;
  @State private title: string = '';
  @State private subtitle: string = '';
  @State private avatarInitials: string = '';
  @State private avatarImageSrc: string = '';
  @State private avatarColor: Resource = TgUiTokens.AVATAR_COLOR_5;
  @State private isOnline: boolean = false;

  // Info fields
  @State private phoneNumber: string = '';
  @State private username: string = '';
  @State private bio: string = '';
  @State private chatType: string = 'private';
  @State private memberCount: number = 0;
  @State private description: string = '';
  @State private isMuted: boolean = false;
  @State private isVerified: boolean = false;
  @State private isPremium: boolean = false;

  @State private topInset: number = 0;
  private storeUnsubscribe: (() => void) | undefined = undefined;

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

    // Subscribe to store changes
    if (this.storeUnsubscribe) {
      this.storeUnsubscribe();
    }
    this.storeUnsubscribe = runtime.getStore().subscribe((newState: AppState) => {
      this.applyState(newState);
    });

    // Fetch full info from TDLib
    const chat = state.chats.chats.get(chatId);
    if (chat) {
      if (chat.type === 'private' && chat.peerUserId > 0) {
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

    if (chat.type === 'private' && chat.peerUserId > 0) {
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

  @Builder
  private buildInfoRow(icon: Resource, label: string, value: string) {
    Column() {
      Row() {
        Column() {
          Text(value)
            .fontSize(TgUiTokens.FONT_TITLE_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(label)
            .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({
        left: TgUiTokens.CHAT_ROW_SIDE_INSET,
        right: TgUiTokens.CHAT_ROW_SIDE_INSET,
        top: 12,
        bottom: 12
      })

      Divider()
        .strokeWidth(0.5)
        .color(TgUiTokens.COLOR_SEPARATOR)
        .margin({ left: TgUiTokens.CHAT_ROW_SIDE_INSET })
    }
  }

  build() {
    NavDestination() {
      Column() {
        // Scroll content
        Scroll() {
          Column() {
            // ── Header section ──
            Column({ space: 8 }) {
              // Large avatar
              TgAvatar({
                avatarSize: 100,
                initials: this.avatarInitials,
                useImage: this.avatarImageSrc.length > 0,
                imageSrc: this.avatarImageSrc,
                isOnline: this.isOnline,
                avatarBackgroundColor: this.avatarColor,
                textColor: TgUiTokens.COLOR_AVATAR_PLACEHOLDER_TEXT
              })

              // Name
              Text(this.title)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                .maxLines(2)
                .textAlign(TextAlign.Center)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              // Status / member count
              if (this.subtitle.length > 0) {
                Text(this.subtitle)
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(this.isOnline ? TgUiTokens.COLOR_ICON_PRIMARY : TgUiTokens.COLOR_TEXT_PREVIEW)
                  .textAlign(TextAlign.Center)
              }
            }
            .width('100%')
            .padding({ top: 24, bottom: 20 })
            .alignItems(HorizontalAlign.Center)

            // ── Info section ──
            Column() {
              // Phone number (private chats only)
              if (this.phoneNumber.length > 0) {
                this.buildInfoRow(TgUiTokens.ICON_RES_PHONE_CALL, 'phone', this.phoneNumber)
              }

              // Username
              if (this.username.length > 0) {
                this.buildInfoRow(TgUiTokens.ICON_RES_SETTINGS, 'username', '@' + this.username)
              }

              // Bio (private) or Description (group/channel)
              if (this.bio.length > 0) {
                this.buildInfoRow(TgUiTokens.ICON_RES_SETTINGS, 'bio', this.bio)
              }
              if (this.description.length > 0 && this.chatType !== 'private') {
                this.buildInfoRow(TgUiTokens.ICON_RES_SETTINGS, 'info', this.description)
              }
            }
            .width('100%')
            .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
            .borderRadius(12)
            .margin({ left: 16, right: 16 })
            .clip(true)

            // ── Notifications section ──
            Column() {
              Row() {
                Text('Notifications')
                  .fontSize(TgUiTokens.FONT_TITLE_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                  .layoutWeight(1)

                Toggle({ type: ToggleType.Switch, isOn: !this.isMuted })
                  .selectedColor(TgUiTokens.COLOR_ICON_PRIMARY)
              }
              .width('100%')
              .padding({
                left: TgUiTokens.CHAT_ROW_SIDE_INSET,
                right: TgUiTokens.CHAT_ROW_SIDE_INSET,
                top: 12,
                bottom: 12
              })
            }
            .width('100%')
            .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
            .borderRadius(12)
            .margin({ left: 16, right: 16, top: 16 })
            .clip(true)
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
