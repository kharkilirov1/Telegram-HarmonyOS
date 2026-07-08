// TgSharedMediaPage — photo/video grid of a chat (profile → Shared Media → Media).
// Data: searchChatMessages(filter=PhotoAndVideo); thumbnails download
// sequentially (same throttle reasoning as the sticker panel).

import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import {
  SearchChatMessagesUseCase,
  createSearchChatMessagesUseCase,
  SharedMediaItem
} from '../../../domain/usecases/searchChatMessages';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { fileUri } from '@kit.CoreFileKit';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0032;
const TAG = 'TgSharedMediaPage';

declare function px2vp(value: number): number;

export class SharedMediaRouteParams {
  chatId: number = 0;

  constructor(chatId: number) {
    this.chatId = chatId;
  }
}

@ObservedV2
export class SharedMediaTileVO {
  readonly messageId: string;
  readonly isVideo: boolean;
  readonly thumbFileId: number;
  readonly duration: number;
  @Trace thumbUri: string = '';

  constructor(messageId: string, isVideo: boolean, thumbFileId: number, duration: number) {
    this.messageId = messageId;
    this.isVideo = isVideo;
    this.thumbFileId = thumbFileId;
    this.duration = duration;
  }
}

function formatDuration(totalSec: number): string {
  const m = Math.floor(totalSec / 60);
  const s = totalSec % 60;
  return m.toString() + ':' + (s < 10 ? '0' : '') + s.toString();
}

@ComponentV2
export struct TgSharedMediaPage {
  @Local pageStack: NavPathStack = new NavPathStack();
  @Local private chatId: number = 0;
  @Local private tiles: SharedMediaTileVO[] = [];
  @Local private isLoading: boolean = true;
  @Local private topInset: number = 0;

  private useCase?: SearchChatMessagesUseCase;
  private lifecycleToken: number = 0;
  private isClosing: boolean = false;

  aboutToAppear(): void {
    this.lifecycleToken++;
    this.isClosing = false;
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

  aboutToDisappear(): void {
    this.lifecycleToken++;
  }

  private loadMedia(chatId: number): void {
    if (chatId === 0) {
      return;
    }
    this.chatId = chatId;
    this.useCase = createSearchChatMessagesUseCase(getTdGatewayAdapter());
    const token = this.lifecycleToken;
    this.isLoading = true;
    this.useCase.searchChatMedia(chatId).then((items: SharedMediaItem[]) => {
      if (token !== this.lifecycleToken) {
        return;
      }
      const tiles: SharedMediaTileVO[] = [];
      for (const item of items) {
        const tile = new SharedMediaTileVO(item.messageId, item.isVideo, item.thumbFileId, item.duration);
        if (item.thumbPath.length > 0) {
          tile.thumbUri = fileUri.getUriFromPath(item.thumbPath);
        }
        tiles.push(tile);
      }
      this.tiles = tiles;
      this.isLoading = false;
      this.fetchThumbs(tiles);
    }).catch((error: Error) => {
      if (token === this.lifecycleToken) {
        this.isLoading = false;
        hilog.warn(DOMAIN, TAG, 'shared media load failed: %{public}s', error.message);
      }
    });
  }

  // Sequential thumb download — parallel calls would storm TDLib (lesson from
  // the sticker panel); aborts when the page dies
  private async fetchThumbs(tiles: SharedMediaTileVO[]): Promise<void> {
    const useCase = this.useCase;
    if (!useCase) {
      return;
    }
    const token = this.lifecycleToken;
    for (const tile of tiles) {
      if (token !== this.lifecycleToken) {
        return;
      }
      if (tile.thumbUri.length === 0 && tile.thumbFileId > 0) {
        const path = await useCase.downloadThumb(tile.thumbFileId);
        if (path.length > 0) {
          tile.thumbUri = fileUri.getUriFromPath(path);
        }
      }
    }
  }

  private handleBackPress(): void {
    if (this.isClosing) {
      return;
    }
    try {
      if (this.pageStack.size() > 0) {
        this.isClosing = true;
        this.pageStack.pop();
      }
    } catch (error) {
      this.isClosing = false;
      hilog.error(DOMAIN, TAG, 'pop failed: %{public}s', String(error));
    }
  }

  @Builder
  private buildTile(tile: SharedMediaTileVO) {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (tile.thumbUri.length > 0) {
        Image(tile.thumbUri)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
      }

      if (tile.isVideo) {
        Text(formatDuration(tile.duration))
          .fontSize(11)
          .fontColor(Color.White)
          .padding({ left: 5, right: 5, top: 2, bottom: 2 })
          .backgroundColor('rgba(0, 0, 0, 0.55)')
          .borderRadius(4)
          .margin({ right: 4, bottom: 4 })
      }
    }
    .width('100%')
    .aspectRatio(1)
    .clip(true)
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .fillColor(TgUiTokens.COMPOSER_ACTION_ACTIVE)
            .onClick(() => {
              this.handleBackPress();
            })

          Text('Media')
            .fontSize(TgUiTokens.CHAT_TOP_BAR_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
            .margin({ left: 16 })

          Blank()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: this.topInset + 8, bottom: 8 })

        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(36)
              .height(36)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.tiles.length === 0) {
          Column() {
            Text('No media yet')
              .fontSize(15)
              .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Grid() {
            ForEach(this.tiles, (tile: SharedMediaTileVO) => {
              GridItem() {
                this.buildTile(tile)
              }
            }, (tile: SharedMediaTileVO) => 'shm_' + tile.messageId)
          }
          .columnsTemplate('1fr 1fr 1fr')
          .columnsGap(2)
          .rowsGap(2)
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      const params = context.pathInfo.param as SharedMediaRouteParams;
      if (params && params.chatId !== 0) {
        this.loadMedia(params.chatId);
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
export function TgSharedMediaPageBuilder() {
  TgSharedMediaPage()
}
