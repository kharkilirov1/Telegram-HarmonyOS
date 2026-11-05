// I6: fullscreen story viewer. Renders one story at a time with segmented progress, tap-left/tap-right
// navigation, a close button and a long-press pause. Content is loaded through LoadStoryUseCase and its
// media through the regular download command, so no separate media pipeline exists.

import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppState } from '../../../core/model/AppState';
import { createDownloadFileCommand } from '../../../core/model/AppCommand';
import { StoryFullDto } from '../../../core/model/dto/StoryDto';
import { MessageAvailableReactionsSnapshot } from '../../../core/model/dto/MessageDto';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { LoadStoryUseCase, createLoadStoryUseCase } from '../../../domain/usecases/loadStory';
import { GetStoryAvailableReactionsUseCase, createGetStoryAvailableReactionsUseCase } from '../../../domain/usecases/getStoryAvailableReactions';
import { SetStoryReactionUseCase, createSetStoryReactionUseCase } from '../../../domain/usecases/setStoryReaction';
import { AppStore } from '../../../core/store/AppStore';
import { TdGatewayPort } from '../../../domain/ports/TdGatewayPort';
import {
  StoryViewerRouteParams,
  clampStoryIndex,
  isRenderableStory,
  nextStoryIndex,
  previousStoryIndex,
  storyCacheKey,
  storyDisplayDurationMs,
  storyReactionsLabel,
  storySegmentFill,
  storyViewsLabel
} from './StoryViewerModel';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';

const DOMAIN = 0x00B6;
const TAG = 'TgStoryViewerPage';
const STORY_DOWNLOAD_PRIORITY = 3;

@ComponentV2
export struct TgStoryViewerPage {
  @Local private chatId: number = 0;
  @Local private chatTitle: string = '';
  @Local private storyIds: number[] = [];
  @Local private index: number = 0;
  @Local private story: StoryFullDto | undefined = undefined;
  @Local private loading: boolean = false;
  @Local private failed: boolean = false;
  @Local private paused: boolean = false;
  @Local private progress: number = 0;
  @Local private topInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
  @Local private reactionKeys: string[] = [];

  private pageStack: NavPathStack = new NavPathStack();
  private store?: AppStore;
  private gateway?: TdGatewayPort;
  private loadStoryUseCase?: LoadStoryUseCase;
  private availableReactionsUseCase?: GetStoryAvailableReactionsUseCase;
  private setReactionUseCase?: SetStoryReactionUseCase;
  private unsubscribe?: () => void;
  private pageLifecycleToken: number = 0;
  private progressTimerId: number = -1;
  private progressStartedAt: number = 0;
  private downloadedFileIds: Set<number> = new Set<number>();

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.topInset = computeTopBarHeight(context);
    } catch (_error) {
    }
    const runtime = getAppCoreRuntime();
    const store = runtime.getStore();
    this.store = store;
    this.gateway = getTdGatewayAdapter();
    this.loadStoryUseCase = createLoadStoryUseCase(store, getTdGatewayAdapter());
    this.availableReactionsUseCase = createGetStoryAvailableReactionsUseCase(getTdGatewayAdapter());
    this.setReactionUseCase = createSetStoryReactionUseCase(getTdGatewayAdapter());
    this.loadReactionKeys();
    const token = this.pageLifecycleToken;
    let activeUnsubscribe: (() => void) | undefined = undefined;
    activeUnsubscribe = store.subscribe((newState: AppState, prevState: AppState) => {
      if (token !== this.pageLifecycleToken || this.unsubscribe !== activeUnsubscribe) {
        return;
      }
      if (newState.chats !== prevState.chats) {
        this.applyStoryFromState(newState);
      }
    });
    this.unsubscribe = activeUnsubscribe;
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.stopProgress();
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    this.store = undefined;
    this.gateway = undefined;
    this.loadStoryUseCase = undefined;
    this.availableReactionsUseCase = undefined;
    this.setReactionUseCase = undefined;
  }

  // I6: the story reaction row. Chips come from TDLib; keys are the same ones messages use.
  private loadReactionKeys(): void {
    const useCase = this.availableReactionsUseCase;
    if (useCase === undefined) {
      return;
    }
    const token = this.pageLifecycleToken;
    useCase.load().then((snapshot: MessageAvailableReactionsSnapshot) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      this.reactionKeys = snapshot.top.slice(0, 6);
    }).catch((): void => {});
  }

  private reactionLabel(key: string): string {
    if (key.startsWith('emoji:')) {
      return key.substring('emoji:'.length);
    }
    return '★';
  }

  private toggleReaction(key: string): void {
    const useCase = this.setReactionUseCase;
    const story = this.story;
    const storyId = this.currentStoryId();
    if (useCase === undefined || story === undefined || storyId === 0) {
      return;
    }
    const currentKey = story.chosenReactionKey;
    const token = this.pageLifecycleToken;
    useCase.execute(this.chatId, storyId, key, currentKey).then((accepted: boolean) => {
      if (!accepted || token !== this.pageLifecycleToken) {
        return;
      }
      const updated = story;
      updated.chosenReactionKey = key === currentKey ? '' : key;
      this.story = updated;
    }).catch((): void => {});
  }

  private applyParams(params: StoryViewerRouteParams): void {
    this.chatId = params.chatId;
    this.chatTitle = params.chatTitle;
    this.storyIds = params.storyIds.slice();
    this.index = clampStoryIndex(params.startIndex, this.storyIds.length);
    this.loadCurrentStory();
  }

  private currentStoryId(): number {
    if (this.index < 0 || this.index >= this.storyIds.length) {
      return 0;
    }
    return this.storyIds[this.index];
  }

  private applyStoryFromState(state: AppState): void {
    const storyId = this.currentStoryId();
    if (storyId === 0) {
      return;
    }
    const story = state.chats.storyContentsByKey.get(storyCacheKey(this.chatId, storyId));
    if (story === undefined) {
      return;
    }
    this.story = story;
    this.failed = isRenderableStory(story) ? false : story.kind === 'unsupported';
    if (story.localPath.length > 0) {
      this.stopProgress();
      this.startProgress();
    }
  }

  private loadCurrentStory(): void {
    const storyId = this.currentStoryId();
    const store = this.store;
    const useCase = this.loadStoryUseCase;
    if (storyId === 0 || store === undefined || useCase === undefined) {
      this.story = undefined;
      this.failed = true;
      return;
    }
    const cached = store.getState().chats.storyContentsByKey.get(storyCacheKey(this.chatId, storyId));
    if (cached !== undefined) {
      this.story = cached;
    }
    this.loading = true;
    this.failed = false;
    const token = this.pageLifecycleToken;
    useCase.execute(this.chatId, storyId).then((story: StoryFullDto | undefined) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      this.loading = false;
      if (story === undefined) {
        this.failed = true;
        return;
      }
      this.story = story;
      if (!isRenderableStory(story)) {
        this.failed = true;
        return;
      }
      this.requestMedia(story);
    }).catch((error: Object) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      this.loading = false;
      this.failed = true;
      hilog.info(DOMAIN, TAG, 'Story load settled with an error: %{public}s', String(error));
    });
  }

  // The download command is the same one message media uses; the file path returns through the store.
  private requestMedia(story: StoryFullDto): void {
    const gateway = this.gateway;
    if (gateway === undefined || story.mediaFileId === 0) {
      return;
    }
    if (story.localPath.length > 0) {
      this.startProgress();
      return;
    }
    if (this.downloadedFileIds.has(story.mediaFileId)) {
      return;
    }
    this.downloadedFileIds.add(story.mediaFileId);
    gateway.send(createDownloadFileCommand(story.mediaFileId, STORY_DOWNLOAD_PRIORITY, false))
      .catch((error: Object) => {
        hilog.info(DOMAIN, TAG, 'Story media download settled: %{public}s', String(error));
      });
  }

  private startProgress(): void {
    this.stopProgress();
    this.progress = 0;
    this.progressStartedAt = Date.now();
    const duration = storyDisplayDurationMs(this.story);
    const token = this.pageLifecycleToken;
    this.progressTimerId = setInterval((): void => {
      if (token !== this.pageLifecycleToken) {
        this.stopProgress();
        return;
      }
      if (this.paused) {
        return;
      }
      const elapsed = Date.now() - this.progressStartedAt;
      this.progress = elapsed >= duration ? 1 : elapsed / duration;
      if (elapsed >= duration) {
        this.advance();
      }
    }, 50);
  }

  private stopProgress(): void {
    if (this.progressTimerId >= 0) {
      clearInterval(this.progressTimerId);
      this.progressTimerId = -1;
    }
    this.progress = 0;
  }

  private advance(): void {
    const next = nextStoryIndex(this.index, this.storyIds.length);
    if (next < 0) {
      this.close();
      return;
    }
    this.index = next;
    this.story = undefined;
    this.stopProgress();
    this.loadCurrentStory();
  }

  private goBack(): void {
    const previous = previousStoryIndex(this.index, this.storyIds.length);
    if (previous < 0) {
      return;
    }
    if (previous === this.index) {
      this.stopProgress();
      this.startProgress();
      return;
    }
    this.index = previous;
    this.story = undefined;
    this.stopProgress();
    this.loadCurrentStory();
  }

  private close(): void {
    this.stopProgress();
    this.pageStack.pop();
  }

  @Builder
  private buildHeader() {
    Column() {
      Row() {
        ForEach(this.storyIds, (_storyId: number, position: number) => {
          Row() {
            Row()
              .height(TgUiTokens.STORY_PROGRESS_HEIGHT)
              .width((storySegmentFill(position, this.storyIds.length, this.index + this.progress) * 100) + '%')
              .backgroundColor(TgUiTokens.COLOR_TEXT_TITLE)
          }
          .layoutWeight(1)
          .height(TgUiTokens.STORY_PROGRESS_HEIGHT)
          .backgroundColor(TgUiTokens.STORY_PROGRESS_TRACK)
          .borderRadius(TgUiTokens.STORY_PROGRESS_HEIGHT / 2)
          .margin({ right: TgUiTokens.SPACE_4 })
          .clip(true)
        }, (_storyId: number, position: number) => position.toString())

        Text('✕')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .margin({ left: TgUiTokens.SPACE_8 })
          .onClick((): void => {
            this.close();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        if (storyViewsLabel(this.story).length > 0) {
          Text('👁 ' + storyViewsLabel(this.story))
            .fontSize(TgUiTokens.FONT_META_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            .margin({ right: TgUiTokens.SPACE_8 })
        }
        if (storyReactionsLabel(this.story).length > 0) {
          Text('♥ ' + storyReactionsLabel(this.story))
            .fontSize(TgUiTokens.FONT_META_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            .margin({ right: TgUiTokens.SPACE_8 })
        }
        Text(this.chatTitle.length > 0 ? this.chatTitle : '')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.story !== undefined ? new Date(this.story.date * 1000).toLocaleTimeString() : '')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .margin({ left: TgUiTokens.SPACE_8 })
      }
      .width('100%')
      .margin({ top: TgUiTokens.SPACE_8 })
    }
    .width('100%')
    .padding({ left: TgUiTokens.SPACE_12, right: TgUiTokens.SPACE_12 })
  }

  @Builder
  private buildReactionRow() {
    Row() {
      ForEach(this.reactionKeys, (key: string) => {
        Text(this.reactionLabel(key))
          .fontSize(TgUiTokens.STORY_REACTION_EMOJI_SIZE)
          .padding(TgUiTokens.SPACE_4)
          .borderRadius(TgUiTokens.STORY_REACTION_CHIP_RADIUS)
          .backgroundColor(this.story !== undefined && this.story.chosenReactionKey === key
            ? TgUiTokens.STORY_REACTION_CHOSEN_BG
            : TgUiTokens.STORY_REACTION_CHIP_BG)
          .onClick((): void => {
            this.toggleReaction(key);
          })
      }, (key: string) => key)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ bottom: TgUiTokens.SPACE_16 })
  }

  @Builder
  private buildContent() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.story !== undefined && this.story.localPath.length > 0) {
        if (this.story.kind === 'video') {
          Video({ src: this.story.localPath })
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .autoPlay(true)
            .controls(false)
            .loop(false)
        } else {
          Image(this.story.localPath)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
        }
      } else if (this.failed) {
        Text(localizedText('Story unavailable'))
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
      } else {
        LoadingProgress()
          .width(TgUiTokens.STORY_LOADING_SIZE)
          .height(TgUiTokens.STORY_LOADING_SIZE)
          .color(TgUiTokens.COLOR_TEXT_PREVIEW)
      }
    }
    .width('100%')
    .layoutWeight(1)
    // Two transparent zones: left goes back, right advances; long-press pauses without leaving.
    Row() {
      Column()
        .layoutWeight(1)
        .height('100%')
        .onClick((): void => {
          this.goBack();
        })
        .gesture(LongPressGesture({ repeat: false })
          .onAction((): void => {
            this.paused = true;
          })
          .onActionEnd((): void => {
            this.paused = false;
            this.progressStartedAt = Date.now() - this.progress * storyDisplayDurationMs(this.story);
          }))
      Column()
        .layoutWeight(1)
        .height('100%')
        .onClick((): void => {
          this.advance();
        })
        .gesture(LongPressGesture({ repeat: false })
          .onAction((): void => {
            this.paused = true;
          })
          .onActionEnd((): void => {
            this.paused = false;
            this.progressStartedAt = Date.now() - this.progress * storyDisplayDurationMs(this.story);
          }))
    }
    .width('100%')
    .layoutWeight(1)
  }

  build() {
    NavDestination() {
      Column() {
        this.buildHeader()
        this.buildContent()
        if (this.reactionKeys.length > 0) {
          this.buildReactionRow()
        }
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.topInset })
      .backgroundColor(TgUiTokens.STORY_VIEWER_BACKGROUND)
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext): void => {
      this.pageStack = context.pathStack;
      const params = context.pathInfo.param as StoryViewerRouteParams;
      if (params !== undefined) {
        this.applyParams(params);
      }
    })
  }
}

function localizedText(fallback: string): string {
  return fallback;
}

@Builder
export function TgStoryViewerPageBuilder() {
  TgStoryViewerPage()
}
