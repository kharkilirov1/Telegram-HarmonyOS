// TgChatInviteLinksPage — admin screen listing, creating and revoking chat invite links (S12h).
// iOS counterpart: ChatInviteLinksController. Reached from the admin chat menu ("Manage" → Invite Links).

import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { ChatInviteLinkDto } from '../../../core/model/dto/ChatInviteLinkDto';
import {
  ChatInviteLinksUseCase,
  createChatInviteLinksUseCase
} from '../../../domain/usecases/chatInviteLinks';
import { ChatInviteLinksRouteParams } from './chatInviteLinksRoute';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';

const DOMAIN = 0x0043;
const TAG = 'TgChatInviteLinksPage';

@Builder
export function TgChatInviteLinksPageBuilder() {
  TgChatInviteLinksPage();
}

@ComponentV2
export struct TgChatInviteLinksPage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private chatId: number = 0;
  @Local private links: ChatInviteLinkDto[] = [];
  @Local private totalCount: number = 0;
  @Local private isLoading: boolean = true;
  @Local private isCreating: boolean = false;
  @Local private errorText: string = '';
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private topBarInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
  private useCase?: ChatInviteLinksUseCase;
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
      this.useCase = createChatInviteLinksUseCase(getTdGatewayAdapter());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Use case init failed: %{public}s', String(error));
      this.useCase = undefined;
    }
    const params = this.pageStack.getParamByName('TgChatInviteLinksPage') as Object[];
    if (params.length > 0) {
      const routeParams = params[0] as ChatInviteLinksRouteParams;
      this.chatId = routeParams.chatId;
    }
    this.reload();
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.useCase = undefined;
  }

  private reload(): void {
    const useCase = this.useCase;
    if (useCase === undefined || this.chatId <= 0) {
      this.isLoading = false;
      this.errorText = localized($r('app.string.invite_links_failed').id, 'Could not load invite links');
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isLoading = true;
    this.errorText = '';
    useCase.load(this.chatId)
      .then((page) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isLoading = false;
        this.links = page.links;
        this.totalCount = page.totalCount;
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isLoading = false;
        this.errorText = error.message.length > 0
          ? error.message : localized($r('app.string.invite_links_failed').id, 'Could not load invite links');
      });
  }

  private createLink(): void {
    const useCase = this.useCase;
    if (useCase === undefined || this.isCreating) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isCreating = true;
    this.errorText = '';
    useCase.create(this.chatId)
      .then(() => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isCreating = false;
        this.reload();
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isCreating = false;
        this.errorText = error.message.length > 0
          ? error.message : localized($r('app.string.invite_links_create_failed').id,
            'Could not create an invite link');
      });
  }

  private revokeLink(link: ChatInviteLinkDto): void {
    const useCase = this.useCase;
    if (useCase === undefined || link.isPrimary) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.errorText = '';
    useCase.revoke(this.chatId, link.inviteLink)
      .then(() => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.reload();
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.errorText = error.message.length > 0
          ? error.message : localized($r('app.string.invite_links_revoke_failed').id,
            'Could not revoke the invite link');
      });
  }

  private linkSubtitle(link: ChatInviteLinkDto): string {
    const parts: string[] = [];
    if (link.isPrimary) {
      parts.push(localized($r('app.string.invite_links_primary').id, 'Primary link'));
    }
    if (link.memberLimit > 0) {
      parts.push(link.memberCount.toString() + '/' + link.memberLimit.toString());
    } else {
      parts.push(link.memberCount.toString() + ' ' + localized($r('app.string.invite_links_joined').id,
        'joined'));
    }
    if (link.pendingJoinRequestCount > 0) {
      parts.push(link.pendingJoinRequestCount.toString() + ' ' +
        localized($r('app.string.invite_links_pending').id, 'pending'));
    }
    return parts.join(' · ');
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        List() {
          ListItem() {
            Row() {
              Text(localized($r('app.string.invite_links_create').id, 'Create Invite Link'))
                .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                .fontColor(TgUiTokens.CHAT_TOP_BAR_ACTION_FOREGROUND)
              Blank()
              if (this.isCreating) {
                LoadingProgress()
                  .width(20)
                  .height(20)
              }
            }
            .width('100%')
            .height(48)
            .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
            .onClick(() => {
              this.createLink();
            })
          }

          ForEach(this.links, (link: ChatInviteLinkDto) => {
            ListItem() {
              Column() {
                Text(link.inviteLink)
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                Text(this.linkSubtitle(link))
                  .fontSize(TgUiTokens.FONT_META_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_META)
                  .margin({ top: TgUiTokens.SPACE_4 })
                  .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_8,
                bottom: TgUiTokens.SPACE_8 })
              .onClick(() => {
                this.revokeLink(link);
              })
            }
          }, (link: ChatInviteLinkDto) => link.inviteLink + (link.isRevoked ? ':r' : ''))

          if (this.isLoading) {
            ListItem() {
              Text(localized($r('app.string.invite_links_loading').id, 'Loading invite links…'))
                .fontSize(TgUiTokens.FONT_META_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_META)
                .width('100%')
                .padding({ left: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_12 })
            }
          }
        }
        .width('100%')
        .height('100%')
        .contentStartOffset(this.topBarTotalHeight)
        .divider({ strokeWidth: 1, color: TgUiTokens.COLOR_SEPARATOR, startMargin: TgUiTokens.SPACE_16 })

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(TgUiTokens.FONT_META_SIZE)
            .fontColor(TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE)
            .width('100%')
            .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_12 })
            .position({ x: 0, y: this.topBarTotalHeight })
        }

        TgChatTopBar({
          topInset: this.topBarInset,
          title: localized($r('app.string.invite_links_title').id, 'Invite Links'),
          subtitle: this.totalCount > 0 ? this.totalCount.toString() : '',
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
