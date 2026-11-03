// TgBlockedUsersPage — Settings → Privacy → Blocked Users (H8).
// TDLib: getBlockedMessageSenders (td_api.tl:13188), setMessageSenderBlockList (td_api.tl:13175).
// The list payload carries identifiers only; names come from AppState users/chats.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { localized } from '../../../core/utils/AppResource';
import { AppState } from '../../../core/model/AppState';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { createLoadBlockedSendersUseCase, LoadBlockedSendersUseCase } from '../../../domain/usecases/loadBlockedSenders';
import { BlockedSenderDto } from '../../../core/model/dto/BlockedSenderDto';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { TgIcon } from '../../tg_ui/atoms/TgIcon';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';

const DOMAIN = 0x0035;
const TAG = 'TgBlockedUsersPage';

@Builder
export function TgBlockedUsersPageBuilder() {
  TgBlockedUsersPage();
}

@ComponentV2
export struct TgBlockedUsersPage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private senders: BlockedSenderDto[] = [];
  @Local private isLoading: boolean = true;
  @Local private loadFailed: boolean = false;
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private topBarInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
  @Local private unblockingKey: string = '';

  private loadBlockedUseCase?: LoadBlockedSendersUseCase;
  private pageLifecycleToken: number = 0;

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.topBarTotalHeight = computeTopBarHeight(context);
      this.topBarInset = this.topBarTotalHeight - TgUiTokens.TOP_BAR_HEIGHT;
    } catch (_error) {
      this.topBarTotalHeight = TgUiTokens.TOP_BAR_HEIGHT;
      this.topBarInset = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
    }
    try {
      this.loadBlockedUseCase = createLoadBlockedSendersUseCase(getTdGatewayAdapter());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Blocked users use case init failed: %{public}s', String(error));
      this.isLoading = false;
      this.loadFailed = true;
      return;
    }
    this.reloadSenders();
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.loadBlockedUseCase = undefined;
  }

  private reloadSenders(): void {
    const useCase = this.loadBlockedUseCase;
    if (useCase === undefined) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isLoading = true;
    this.loadFailed = false;
    useCase.fetchPage()
      .then((page) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.senders = page.senders;
        this.isLoading = false;
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        hilog.error(DOMAIN, TAG, 'Load blocked users failed: %{public}s', error.message);
        this.isLoading = false;
        this.loadFailed = true;
      });
  }

  private senderKey(sender: BlockedSenderDto): string {
    return sender.senderType + ':' + sender.senderId.toString();
  }

  private senderTitle(sender: BlockedSenderDto): string {
    let state: AppState | undefined = undefined;
    try {
      state = getAppCoreRuntime().getStore().getState();
    } catch (_error) {
      state = undefined;
    }
    if (sender.senderType === 'user') {
      const user = state === undefined ? undefined : state.users.users.get(sender.senderId);
      if (user !== undefined) {
        const full = `${user.firstName} ${user.lastName}`.trim();
        if (full.length > 0) {
          return full;
        }
        if (user.username.length > 0) {
          return '@' + user.username;
        }
      }
      return localized($r('app.string.blocked_user_fallback').id, 'User') + ' ' + sender.senderId.toString();
    }
    const chat = state === undefined ? undefined : state.chats.chats.get(sender.senderId);
    if (chat !== undefined && chat.title.length > 0) {
      return chat.title;
    }
    return localized($r('app.string.blocked_chat_fallback').id, 'Chat') + ' ' + sender.senderId.toString();
  }

  private confirmUnblock(sender: BlockedSenderDto): void {
    promptAction.showDialog({
      title: localized($r('app.string.blocked_unblock').id, 'Unblock'),
      message: this.senderTitle(sender),
      buttons: [
        { text: localized($r('app.string.cancel').id, 'Cancel'), color: TgUiTokens.COLOR_TEXT_PREVIEW },
        { text: localized($r('app.string.blocked_unblock').id, 'Unblock'),
          color: TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index !== 1) {
        return;
      }
      this.unblock(sender);
    }).catch((error: Error) => {
      hilog.warn(DOMAIN, TAG, 'Unblock dialog failed: %{public}s', error.message);
    });
  }

  private unblock(sender: BlockedSenderDto): void {
    const useCase = this.loadBlockedUseCase;
    if (useCase === undefined) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.unblockingKey = this.senderKey(sender);
    useCase.unblock(sender)
      .then(() => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.unblockingKey = '';
        this.reloadSenders();
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.unblockingKey = '';
        hilog.error(DOMAIN, TAG, 'Unblock failed: %{public}s', error.message);
      });
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        List() {
          if (this.isLoading) {
            ListItem() {
              Text(localized($r('app.string.blocked_loading').id, 'Loading…'))
                .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: TgUiTokens.SPACE_24 })
            }
          } else if (this.loadFailed) {
            ListItem() {
              Column() {
                Text(localized($r('app.string.blocked_load_failed').id, 'Could not load blocked users'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
                Text(localized($r('app.string.blocked_retry').id, 'Retry'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
                  .margin({ top: TgUiTokens.SPACE_8 })
                  .onClick(() => {
                    this.reloadSenders();
                  })
              }
              .width('100%')
              .padding({ top: TgUiTokens.SPACE_24 })
            }
          } else if (this.senders.length === 0) {
            ListItem() {
              Text(localized($r('app.string.blocked_empty').id, 'No blocked users'))
                .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: TgUiTokens.SPACE_24 })
            }
          } else {
            ForEach(this.senders, (sender: BlockedSenderDto) => {
              ListItem() {
                Row() {
                  TgIcon({
                    src: sender.senderType === 'user' ? TgUiTokens.ICON_RES_CONTACT : TgUiTokens.ICON_RES_GROUP,
                    iconSize: TgUiTokens.ICON_SIZE_MD,
                    tintColor: TgUiTokens.COLOR_TEXT_PREVIEW
                  })
                    .margin({ right: TgUiTokens.SPACE_12 })
                  Text(this.senderTitle(sender))
                    .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                    .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                  Text(localized($r('app.string.blocked_unblock').id, 'Unblock'))
                    .fontSize(TgUiTokens.FONT_META_SIZE)
                    .fontColor(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
                    .margin({ left: TgUiTokens.SPACE_8 })
                }
                .width('100%')
                .padding({
                  left: TgUiTokens.SPACE_16,
                  right: TgUiTokens.SPACE_16,
                  top: TgUiTokens.SPACE_12,
                  bottom: TgUiTokens.SPACE_12
                })
                .opacity(this.unblockingKey === this.senderKey(sender) ? 0.5 : 1)
              }
              .onClick(() => {
                this.confirmUnblock(sender);
              })
            }, (sender: BlockedSenderDto) => this.senderKey(sender))
          }
        }
        .width('100%')
        .height('100%')
        .contentStartOffset(this.topBarTotalHeight)
        .edgeEffect(EdgeEffect.Spring)
        .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)

        TgChatTopBar({
          topInset: this.topBarInset,
          title: localized($r('app.string.settings_blocked_users').id, 'Blocked Users'),
          subtitle: this.isLoading ? '' : `${this.senders.length}`,
          onBackPress: (): void => {
            this.pageStack.pop();
          }
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    }
    .hideTitleBar(true)
  }
}
