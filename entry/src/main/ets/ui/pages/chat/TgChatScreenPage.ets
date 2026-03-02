// TgChatScreenPage — chat message timeline
// Phase D-3: Stack overlay — message list scrolls under translucent top bar for blur

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState } from '../../../core/model/AppState';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgDateSeparator, TgUnreadMarker } from '../../tg_ui/atoms/TgDateSeparator';
import { TgMessageRouter } from '../../tg_ui/molecules/TgMessageRouter';
import { TgMessageMeta } from '../../tg_ui/atoms/TgMessageMeta';
import { TgReplySnippet } from '../../tg_ui/atoms/TgReplySnippet';
import { TgComposerInput } from '../../tg_ui/atoms/TgComposerInput';
import { TgTopBar } from '../../tg_ui/atoms/TgTopBar';
import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { ChatTimelineEntryVO, buildChatTimeline } from './ChatTimelineVO';
import { SendMessageParams, createSendMessageUseCase, SendMessageUseCase } from '../../../domain/usecases/sendMessage';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { localized } from '../../../core/utils/AppResource';
import { computeTopBarHeight, computeChatBottomInset, getMainWindow, removeWindowSizeListener } from '../../utils/SafeAreaUtils';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';

declare function px2vp(value: number): number;

@Component
export struct TgChatScreenPage {
  navStack?: NavPathStack;

  @StorageLink(StorageKeys.ACTIVE_CHAT_ID) activeChatId: number = 0;
  @StorageLink(StorageKeys.ACTIVE_CHAT_TITLE) activeChatTitle: string = '';

  @State private title: string = 'Chat';
  @State private timelineContainerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @State private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @State private bottomOverlayInset: number = TgUiTokens.SPACE_8;

  private dataSource: ChatTimelineDataSource = new ChatTimelineDataSource();
  private unsubscribe?: () => void;
  private rebuildScheduled: boolean = false;
  private mainWindow?: window.Window;
  private sendUseCase?: SendMessageUseCase;
  private isSending: boolean = false;

  aboutToAppear(): void {
    try {
      AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, true);
      this.computeSafeInsets();

      const runtime = getAppCoreRuntime();
      const store = runtime.getStore();
      this.sendUseCase = createSendMessageUseCase(getTdGatewayAdapter());
      this.rebuildTimeline(store.getState());

      this.unsubscribe = store.subscribe((_newState: AppState, _prevState: AppState) => {
        if (!this.rebuildScheduled) {
          this.rebuildScheduled = true;
          setTimeout(() => {
            this.rebuildScheduled = false;
            try {
              const currentState = getAppCoreRuntime().getStore().getState();
              this.rebuildTimeline(currentState);
            } catch (e) {
              hilog.error(DOMAIN, TAG, 'Timeline rebuild failed: %{public}s', String(e));
            }
          }, 0);
        }
      });

      this.bindWindowSizeListener();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'aboutToAppear failed: %{public}s', String(e));
    }
  }

  aboutToDisappear(): void {
    AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    removeWindowSizeListener(this.mainWindow);
    this.mainWindow = undefined;
  }

  private computeSafeInsets(): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.topBarTotalHeight = computeTopBarHeight(context);
      this.bottomOverlayInset = computeChatBottomInset(context);
    } catch (_error) {
      this.topBarTotalHeight = TgUiTokens.TOP_BAR_HEIGHT;
      this.bottomOverlayInset = TgUiTokens.SPACE_8;
    }
  }

  private bindWindowSizeListener(): void {
    try {
      removeWindowSizeListener(this.mainWindow);
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.mainWindow = getMainWindow(context);
      if (this.mainWindow !== undefined) {
        this.updateTimelineContainerWidth(this.mainWindow.getWindowProperties().windowRect.width);
        this.mainWindow.on('windowSizeChange', (size: window.Size) => {
          this.updateTimelineContainerWidth(size.width);
          this.computeSafeInsets();
        });
      }
    } catch (_error) {
      this.timelineContainerWidth = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
    }
  }

  private updateTimelineContainerWidth(windowWidthPx: number): void {
    const widthVp: number = px2vp(windowWidthPx);
    const horizontalInsets: number = TgUiTokens.SPACE_12 * 2;
    const computed: number = Math.floor(widthVp - horizontalInsets);
    this.timelineContainerWidth = Math.max(1, computed);
  }

  private rebuildTimeline(state: AppState): void {
    if (this.activeChatId === 0) {
      this.dataSource.applyDiff([]);
      this.title = this.activeChatTitle.length > 0
        ? this.activeChatTitle
        : localized($r('app.string.chats_title').id, 'Chat');
      return;
    }

    const result = buildChatTimeline(this.activeChatId, state);
    this.title = result.chatTitle.length > 0 ? result.chatTitle : this.activeChatTitle;
    this.dataSource.applyDiff(result.entries);
  }

  private handleSendMessage(text: string): void {
    if (this.isSending || this.activeChatId === 0 || !this.sendUseCase) {
      return;
    }
    this.isSending = true;
    const params = new SendMessageParams();
    params.chatId = this.activeChatId;
    params.text = text;
    this.sendUseCase.execute(params)
      .catch((err: Error) => {
        hilog.error(DOMAIN, TAG, 'Send failed: %{public}s', err.message);
      })
      .finally(() => {
        this.isSending = false;
      });
  }

  private handleBackPress(): void {
    AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    if (this.navStack !== undefined) {
      this.navStack.pop();
    }
  }

  private entryReuseId(entry: ChatTimelineEntryVO): string {
    if (entry.kind === 'date') {
      return 'chat_date_separator';
    }
    if (entry.kind === 'unread') {
      return 'chat_unread_marker';
    }
    const contentKey = entry.message.contentType;
    const outKey = entry.message.isOutgoing ? 'out' : 'in';
    const replyKey = entry.message.showReplySnippet ? 'r1' : 'r0';
    const statusKey = entry.message.sendStatus.toString();
    return `chat_msg_${contentKey}_${outKey}_${replyKey}_${statusKey}`;
  }

  @Builder
  private buildMessageItem(entry: ChatTimelineEntryVO) {
    Column({ space: TgUiTokens.SPACE_4 }) {
      if (entry.message.showReplySnippet) {
        Row() {
          TgReplySnippet({
            author: entry.message.replyAuthor,
            preview: entry.message.replyPreview,
            isOutgoing: entry.message.replyIsOutgoing,
            isQuote: entry.message.replyIsQuote,
            containerWidth: this.timelineContainerWidth
          })
        }
        .width('100%')
        .justifyContent(entry.message.isOutgoing ? FlexAlign.End : FlexAlign.Start)
      }

      TgMessageRouter({
        contentType: entry.message.contentType,
        isOutgoing: entry.message.isOutgoing,
        containerWidth: this.timelineContainerWidth,
        text: entry.message.text,
        isEmojiOnly: entry.message.isEmojiOnly,
        forceBreakAll: entry.message.forceBreakAll,
        caption: entry.message.caption,
        photoPath: entry.message.photoPath,
        photoWidth: entry.message.photoWidth,
        photoHeight: entry.message.photoHeight,
        videoThumbPath: entry.message.videoThumbPath,
        videoPath: entry.message.videoPath,
        videoDuration: entry.message.videoDuration,
        videoWidth: entry.message.videoWidth,
        videoHeight: entry.message.videoHeight,
        fileName: entry.message.fileName,
        fileSize: entry.message.fileSize,
        mimeType: entry.message.mimeType,
        voiceDuration: entry.message.voiceDuration,
        voiceWaveform: entry.message.voiceWaveform,
        isVoiceListened: entry.message.isVoiceListened,
        stickerPath: entry.message.stickerPath,
        stickerWidth: entry.message.stickerWidth,
        stickerHeight: entry.message.stickerHeight,
        isAnimatedSticker: entry.message.isAnimatedSticker,
        isVideoSticker: entry.message.isVideoSticker
      })

      Row() {
        TgMessageMeta({
          timeText: entry.message.timeText,
          sendStatus: entry.message.sendStatus,
          isOutgoing: entry.message.isOutgoing
        })
      }
      .width('100%')
      .justifyContent(entry.message.isOutgoing ? FlexAlign.End : FlexAlign.Start)
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_12,
      right: TgUiTokens.SPACE_12,
      top: TgUiTokens.SPACE_4,
      bottom: TgUiTokens.SPACE_4
    })
  }

  @Builder
  private buildTimelineEntry(entry: ChatTimelineEntryVO) {
    if (entry.kind === 'date') {
      TgDateSeparator({
        text: entry.dateText,
        containerWidth: this.timelineContainerWidth
      })
        .padding({ top: TgUiTokens.SPACE_8, bottom: TgUiTokens.SPACE_4 })
    } else if (entry.kind === 'unread') {
      TgUnreadMarker({
        text: entry.unreadText,
        containerWidth: this.timelineContainerWidth
      })
        .padding({ top: TgUiTokens.SPACE_6, bottom: TgUiTokens.SPACE_6 })
    } else {
      this.buildMessageItem(entry)
    }
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        // ── Content layer (scrolls under top bar) ──
        Column() {
          if (this.activeChatId > 0) {
            if (this.dataSource.totalCount() > 0) {
              List() {
                LazyForEach(this.dataSource, (entry: ChatTimelineEntryVO) => {
                  ListItem() {
                    Row() {
                      this.buildTimelineEntry(entry)
                    }
                    .width('100%')
                    .reuseId(this.entryReuseId(entry))
                  }
                }, (entry: ChatTimelineEntryVO) => entry.key)
              }
              .cachedCount(30) // Увеличиваем кэш для лучшей производительности
              .listDirection(Axis.Vertical)
              .layoutWeight(1)
              .edgeEffect(EdgeEffect.Spring)
              .contentStartOffset(this.topBarTotalHeight)
              .onScrollIndex((start: number, end: number) => {
                // Оптимизация: логируем скролл для отладки производительности
                if (end - start > 50) {
                  hilog.info(DOMAIN, TAG, 'Large scroll range: %{public}d-%{public}d', start, end);
                }
              })
            } else {
              Column({ space: TgUiTokens.SPACE_8 }) {
                Text(localized($r('app.string.no_messages').id, 'No messages yet'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
              }
              .layoutWeight(1)
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            }
          } else {
            Column({ space: TgUiTokens.SPACE_8 }) {
              Text(localized($r('app.string.chat_not_selected').id, 'Chat is not selected'))
                .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            }
            .layoutWeight(1)
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }

          TgComposerInput({
            placeholder: localized($r('app.string.message_placeholder').id, 'Message'),
            isDisabled: this.activeChatId === 0,
            onSendPress: (text: string): void => {
              this.handleSendMessage(text);
            }
          })
          .margin({ bottom: this.bottomOverlayInset })
        }
        .width('100%')
        .height('100%')

        // ── Top bar layer (overlays content, translucent + blur) ──
        TgTopBar({
          title: this.title,
          showBackAction: true,
          onBackPress: (): void => {
            this.handleBackPress();
          }
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    }
    .hideTitleBar(true)
    .hideBackButton(true)
    .hideToolBar(true)
  }
}
