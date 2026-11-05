// TgMessageThreadPage — comments of a channel post (D11). iOS counterpart: ChatControllerOpenMessageReplies.
// The page loads the thread counters, pages the replies by TDLib cursor and renders one row per comment.

import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import {
  MessageThreadComment,
  MessageThreadPage,
  MessageThreadUseCase,
  createMessageThreadUseCase
} from '../../../domain/usecases/messageThread';
import { selectUserDisplayName } from '../../../domain/selectors/userSelectors';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { MessageThreadRouteParams } from './messageThreadRoute';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';
import { SendMessageUseCase, createSendMessageUseCase } from '../../../domain/usecases/sendMessage';

const DOMAIN = 0x004C;
const TAG = 'TgMessageThreadPage';
const THREAD_PAGE_SIZE = 50;

@Builder
export function TgMessageThreadPageBuilder() {
  TgMessageThreadPage();
}

@ComponentV2
export struct TgMessageThreadPage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private chatId: number = 0;
  @Local private messageId: string = '0';
  @Local private title: string = '';
  @Local private replyCount: number = 0;
  @Local private unreadCount: number = 0;
  @Local private comments: MessageThreadComment[] = [];
  @Local private nextCursor: string = '0';
  @Local private isLoading: boolean = true;
  @Local private isLoadingMore: boolean = false;
  @Local private errorText: string = '';
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private topBarInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
  @Local private commentDraft: string = '';
  @Local private sendingComment: boolean = false;
  private useCase?: MessageThreadUseCase;
  private sendUseCase?: SendMessageUseCase;
  private threadChatId: number = 0;
  private threadId: string = '0';
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
      this.useCase = createMessageThreadUseCase(getTdGatewayAdapter());
      this.sendUseCase = createSendMessageUseCase(getTdGatewayAdapter());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Use case init failed: %{public}s', String(error));
      this.useCase = undefined;
    }
    const params = this.pageStack.getParamByName('TgMessageThreadPage') as Object[];
    if (params.length > 0) {
      const routeParams = params[0] as MessageThreadRouteParams;
      this.chatId = routeParams.chatId;
      this.messageId = routeParams.messageId;
      this.title = routeParams.title;
      this.replyCount = routeParams.replyCount;
    }
    this.loadThread();
  }

  private loadThread(): void {
    const useCase = this.useCase;
    if (useCase === undefined) {
      this.isLoading = false;
      this.errorText = localized($r('app.string.comments_load_failed').id, 'Could not load comments');
      return;
    }
    const lifecycleToken = this.pageLifecycleToken;
    this.isLoading = true;
    this.errorText = '';
    useCase.loadThread(this.chatId, this.messageId)
      .then((page: MessageThreadPage) => {
        if (lifecycleToken !== this.pageLifecycleToken) {
          return;
        }
        this.replyCount = page.replyCount > 0 ? page.replyCount : this.replyCount;
        this.threadChatId = page.chatId;
        this.threadId = page.threadId;
        this.unreadCount = page.unreadCount;
        this.comments = page.comments;
        this.nextCursor = page.nextFromMessageId;
        this.isLoading = false;
      })
      .catch((error: Error) => {
        if (lifecycleToken !== this.pageLifecycleToken) {
          return;
        }
        this.isLoading = false;
        this.errorText = localized($r('app.string.comments_load_failed').id, 'Could not load comments');
        hilog.warn(DOMAIN, TAG, 'Thread load failed: %{public}s', error.message);
      });
  }

  private loadMore(): void {
    const useCase = this.useCase;
    if (useCase === undefined || this.isLoadingMore || this.nextCursor === '0') {
      return;
    }
    const lifecycleToken = this.pageLifecycleToken;
    this.isLoadingMore = true;
    useCase.loadHistory(this.chatId, this.messageId, this.nextCursor, 0, THREAD_PAGE_SIZE)
      .then((page: MessageThreadPage) => {
        if (lifecycleToken !== this.pageLifecycleToken) {
          return;
        }
        this.comments = this.comments.concat(page.comments);
        this.nextCursor = page.nextFromMessageId;
        this.isLoadingMore = false;
      })
      .catch((error: Error) => {
        if (lifecycleToken !== this.pageLifecycleToken) {
          return;
        }
        this.isLoadingMore = false;
        hilog.warn(DOMAIN, TAG, 'Thread page failed: %{public}s', error.message);
      });
  }

  private commentAuthor(comment: MessageThreadComment): string {
    if (comment.senderUserId <= 0) {
      return '';
    }
    try {
      return selectUserDisplayName(comment.senderUserId)(getAppCoreRuntime().getStore().getState());
    } catch (_error) {
      return '';
    }
  }

  private commentTime(comment: MessageThreadComment): string {
    if (comment.date <= 0) {
      return '';
    }
    const date = new Date(comment.date * 1000);
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    return `${hours}:${minutes}`;
  }

  private sendComment(): void {
    const sendUseCase = this.sendUseCase;
    const text = this.commentDraft.trim();
    if (sendUseCase === undefined || text.length === 0 || this.sendingComment ||
      this.threadChatId === 0 || this.threadId === '0') {
      return;
    }
    const lifecycleToken = this.pageLifecycleToken;
    this.sendingComment = true;
    sendUseCase.execute({
      chatId: this.threadChatId,
      text: text,
      replyToMessageId: '0',
      customEmojiEntities: [],
      topicThreadId: this.threadId,
        scheduledDateSeconds: 0
    }).then(() => {
      if (lifecycleToken !== this.pageLifecycleToken) {
        return;
      }
      this.sendingComment = false;
      this.commentDraft = '';
      this.loadThread();
    }).catch((error: Error) => {
      if (lifecycleToken !== this.pageLifecycleToken) {
        return;
      }
      this.sendingComment = false;
      hilog.warn(DOMAIN, TAG, 'Sending a comment failed: %{public}s', error.message);
    });
  }

  @Builder
  private buildComposer() {
    Row() {
      TextInput({ text: this.commentDraft, placeholder: localized($r('app.string.comments_placeholder').id, 'Comment') })
        .fontSize(TgUiTokens.CHAT_ROW_PREVIEW_FONT_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
        .borderRadius(TgUiTokens.RADIUS_12)
        .padding({ left: TgUiTokens.SPACE_12, right: TgUiTokens.SPACE_12 })
        .height(TgUiTokens.COMPOSER_MIN_CAPSULE_HEIGHT)
        .layoutWeight(1)
        .enabled(!this.sendingComment)
        .onChange((value: string) => {
          this.commentDraft = value;
        })
      Text(localized($r('app.string.comments_send').id, 'Send'))
        .fontSize(TgUiTokens.CHAT_ROW_TITLE_FONT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.commentDraft.trim().length > 0 && !this.sendingComment
          ? TgUiTokens.LINK_PREVIEW_ACCENT_INCOMING
          : TgUiTokens.COLOR_TEXT_META)
        .margin({ left: TgUiTokens.SPACE_12 })
        .onClick(() => {
          this.sendComment();
        })
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_16,
      right: TgUiTokens.SPACE_16,
      top: TgUiTokens.SPACE_8,
      bottom: TgUiTokens.SPACE_8
    })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildCommentRow(comment: MessageThreadComment) {
    Row() {
      Column() {
        Row() {
          Text(this.commentAuthor(comment))
            .fontSize(TgUiTokens.CHAT_ROW_TITLE_FONT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(this.commentTime(comment))
            .fontSize(TgUiTokens.CHAT_ROW_SCAM_FONT_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            .margin({ left: TgUiTokens.SPACE_8 })
        }
        .width('100%')
        if (comment.text.length > 0) {
          Text(comment.text)
            .fontSize(TgUiTokens.CHAT_ROW_PREVIEW_FONT_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
            .maxLines(8)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: TgUiTokens.SPACE_4 })
            .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_16,
      right: TgUiTokens.SPACE_16,
      top: TgUiTokens.SPACE_8,
      bottom: TgUiTokens.SPACE_8
    })
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private buildHeader() {
    TgChatTopBar({
      title: this.title.length > 0
        ? this.title
        : localized($r('app.string.comments_title').id, 'Comments'),
      subtitle: this.isLoading
        ? ''
        : localized($r('app.string.comments_count').id, 'comments') + ': ' + this.replyCount.toString(),
      topInset: this.topBarInset,
      onBackPress: (): void => {
        this.pageStack.pop();
      }
    })
  }

  @Builder
  private buildEmpty() {
    Column() {
      Text(localized($r('app.string.comments_empty').id, 'No comments yet'))
        .fontSize(TgUiTokens.CHAT_ROW_PREVIEW_FONT_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    NavDestination() {
      Column() {
        this.buildHeader()
        Stack({ alignContent: Alignment.Top }) {
          if (this.errorText.length > 0) {
            Column() {
              Text(this.errorText)
                .fontSize(TgUiTokens.CHAT_ROW_PREVIEW_FONT_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
                .textAlign(TextAlign.Center)
              Text(localized($r('app.string.retry').id, 'Retry'))
                .fontSize(TgUiTokens.CHAT_ROW_TITLE_FONT_SIZE)
                .fontColor(TgUiTokens.LINK_PREVIEW_ACCENT_INCOMING)
                .margin({ top: TgUiTokens.SPACE_12 })
                .onClick(() => {
                  this.loadThread();
                })
            }
            .width('100%')
            .padding({ top: TgUiTokens.SPACE_24 })
            .justifyContent(FlexAlign.Center)
          } else if (this.isLoading) {
            LoadingProgress()
              .width(TgUiTokens.SPACE_24)
              .height(TgUiTokens.SPACE_24)
              .margin({ top: TgUiTokens.SPACE_24 })
          } else if (this.comments.length === 0) {
            this.buildEmpty()
          } else {
            List({ space: 0 }) {
              ForEach(this.comments, (comment: MessageThreadComment) => {
                ListItem() {
                  this.buildCommentRow(comment)
                }
              }, (comment: MessageThreadComment) => comment.messageId)
              if (this.nextCursor !== '0') {
                ListItem() {
                  Row() {
                    LoadingProgress()
                      .width(TgUiTokens.SPACE_24)
                      .height(TgUiTokens.SPACE_24)
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Center)
                  .padding({ top: TgUiTokens.SPACE_8, bottom: TgUiTokens.SPACE_8 })
                }
              }
            }
            .width('100%')
            .layoutWeight(1)
            .onReachEnd(() => {
              this.loadMore();
            })
          }
        }
        .width('100%')
        .layoutWeight(1)
        this.buildComposer()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pageStack = context.pathStack;
    })
  }
}
