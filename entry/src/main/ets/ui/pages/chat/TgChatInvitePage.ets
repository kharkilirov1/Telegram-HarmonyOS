// TgChatInvitePage — preview and join a chat by invite link (S14c).
// iOS counterpart: ChatInviteLinkPreviewScreen. The link arrives from App Linking (t.me/+... or
// t.me/joinchat/...) and the page checks it immediately; Join pops the joined chat to MainTabsPage.

import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { ChatDto } from '../../../core/model/dto/ChatDto';
import { ChatInviteLinkInfoDto } from '../../../core/model/dto/ChatInviteLinkInfoDto';
import {
  createChatInviteLinkUseCase,
  ChatInviteLinkUseCase,
  isChatInviteLink
} from '../../../domain/usecases/chatInviteLink';
import { ChatInviteJoinResult, ChatInviteRouteParams } from './chatInviteRoute';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';

const DOMAIN = 0x0041;
const TAG = 'TgChatInvitePage';

@Builder
export function TgChatInvitePageBuilder() {
  TgChatInvitePage();
}

@ComponentV2
export struct TgChatInvitePage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private inviteLink: string = '';
  @Local private info: ChatInviteLinkInfoDto | undefined = undefined;
  @Local private isChecking: boolean = true;
  @Local private isJoining: boolean = false;
  @Local private errorText: string = '';
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private topBarInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
  private useCase?: ChatInviteLinkUseCase;
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
      this.useCase = createChatInviteLinkUseCase(getTdGatewayAdapter());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Use case init failed: %{public}s', String(error));
      this.useCase = undefined;
    }
    const params = this.pageStack.getParamByName('TgChatInvitePage') as Object[];
    if (params.length > 0) {
      const routeParams = params[0] as ChatInviteRouteParams;
      this.inviteLink = routeParams.inviteLink;
    }
    this.checkLink();
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.useCase = undefined;
  }

  private checkLink(): void {
    const useCase = this.useCase;
    if (useCase === undefined) {
      this.isChecking = false;
      this.errorText = localized($r('app.string.chat_invite_failed').id, 'Could not open the invite link');
      return;
    }
    if (!isChatInviteLink(this.inviteLink)) {
      this.isChecking = false;
      this.errorText = localized($r('app.string.chat_invite_invalid').id, 'This invite link is not valid');
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isChecking = true;
    this.errorText = '';
    useCase.check(this.inviteLink)
      .then((info: ChatInviteLinkInfoDto) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isChecking = false;
        this.info = info;
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isChecking = false;
        this.errorText = error.message.length > 0
          ? error.message : localized($r('app.string.chat_invite_failed').id,
            'Could not open the invite link');
      });
  }

  private join(): void {
    const useCase = this.useCase;
    if (useCase === undefined || this.isJoining || this.info === undefined) {
      return;
    }
    if (this.info.chatId > 0) {
      // Already a member: nothing to join, hand the known chat back.
      this.pageStack.pop(new ChatInviteJoinResult(this.knownChat()), true);
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isJoining = true;
    this.errorText = '';
    useCase.join(this.inviteLink)
      .then((chat: ChatDto) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isJoining = false;
        this.pageStack.pop(new ChatInviteJoinResult(chat), true);
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isJoining = false;
        this.errorText = error.message.length > 0
          ? error.message : localized($r('app.string.chat_invite_join_failed').id, 'Could not join the chat');
      });
  }

  // The preview carries enough fields to open an already-joined chat without another TDLib call.
  private knownChat(): ChatDto {
    const info = this.info as ChatInviteLinkInfoDto;
    const chat = new ChatDto();
    chat.id = info.chatId;
    chat.title = info.title;
    return chat;
  }

  private memberCountText(): string {
    if (this.info === undefined || this.info.memberCount <= 0) {
      return '';
    }
    return this.info.memberCount.toString() + ' ' +
      localized($r('app.string.chat_invite_members').id, 'members');
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        Scroll() {
          Column() {
            if (this.isChecking) {
              Text(localized($r('app.string.chat_invite_checking').id, 'Checking the invite link…'))
                .fontSize(TgUiTokens.FONT_META_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_META)
                .width('100%')
                .padding({ left: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_16 })
            }

            if (this.info !== undefined) {
              Column() {
                Text(this.info.title)
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                if (this.memberCountText().length > 0) {
                  Text(this.memberCountText())
                    .fontSize(TgUiTokens.FONT_META_SIZE)
                    .fontColor(TgUiTokens.COLOR_TEXT_META)
                    .margin({ top: TgUiTokens.SPACE_4 })
                }
                if (this.info.description.length > 0) {
                  Text(this.info.description)
                    .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                    .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
                    .margin({ top: TgUiTokens.SPACE_8 })
                    .maxLines(4)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                if (this.info.createsJoinRequest) {
                  Text(localized($r('app.string.chat_invite_request_hint').id,
                    'An admin must approve your join request.'))
                    .fontSize(TgUiTokens.FONT_META_SIZE)
                    .fontColor(TgUiTokens.COLOR_TEXT_META)
                    .margin({ top: TgUiTokens.SPACE_8 })
                }
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_16 })

              Row() {
                Button(this.info.chatId > 0
                  ? localized($r('app.string.chat_invite_open').id, 'Open Chat')
                  : localized($r('app.string.chat_invite_join').id, 'Join'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .height(40)
                  .enabled(!this.isJoining)
                  .onClick(() => {
                    this.join();
                  })
              }
              .width('100%')
              .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_12 })
            }

            if (this.errorText.length > 0) {
              Text(this.errorText)
                .fontSize(TgUiTokens.FONT_META_SIZE)
                .fontColor(TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE)
                .width('100%')
                .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_12 })
            }
          }
          .width('100%')
          .padding({ bottom: TgUiTokens.SPACE_24 })
        }
        .width('100%')
        .height('100%')
        .contentStartOffset(this.topBarTotalHeight)
        .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)

        TgChatTopBar({
          topInset: this.topBarInset,
          title: localized($r('app.string.chat_invite_title').id, 'Invite Link'),
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
