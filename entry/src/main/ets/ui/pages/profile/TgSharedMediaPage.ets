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
import { PendingJumpSignal } from '../chat/PendingJumpSignal';
import { fileUri } from '@kit.CoreFileKit';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0032;
const TAG = 'TgSharedMediaPage';

declare function px2vp(value: number): number;

export class SharedMediaRouteParams {
  chatId: number = 0;
  filterType: string = 'PhotoAndVideo';

  constructor(chatId: number, filterType: string = 'PhotoAndVideo') {
    this.chatId = chatId;
    this.filterType = filterType;
  }
}

function pageTitleFor(filterType: string): string {
  switch (filterType) {
    case 'Document': return 'Files';
    case 'Url': return 'Links';
    case 'VoiceNote': return 'Voice';
    default: return 'Media';
  }
}

function formatSize(bytes: number): string {
  if (bytes >= 1048576) {
    return (bytes / 1048576).toFixed(1) + ' MB';
  }
  if (bytes >= 1024) {
    return Math.round(bytes / 1024).toString() + ' KB';
  }
  return bytes.toString() + ' B';
}

@ObservedV2
export class SharedMediaTileVO {
  readonly messageId: string;
  readonly kind: string;
  readonly isVideo: boolean;
  readonly thumbFileId: number;
  readonly duration: number;
  readonly fileName: string;
  readonly fileSize: number;
  readonly linkText: string;
  @Trace thumbUri: string = '';

  constructor(messageId: string, kind: string, isVideo: boolean, thumbFileId: number,
    duration: number, fileName: string, fileSize: number, linkText: string) {
    this.messageId = messageId;
    this.kind = kind;
    this.isVideo = isVideo;
    this.thumbFileId = thumbFileId;
    this.duration = duration;
    this.fileName = fileName;
    this.fileSize = fileSize;
    this.linkText = linkText;
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
  @Local private filterType: string = 'PhotoAndVideo';
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
    this.useCase.searchChatMedia(chatId, this.filterType).then((items: SharedMediaItem[]) => {
      if (token !== this.lifecycleToken) {
        return;
      }
      const tiles: SharedMediaTileVO[] = [];
      for (const item of items) {
        const tile = new SharedMediaTileVO(item.messageId, item.kind, item.isVideo,
          item.thumbFileId, item.duration, item.fileName, item.fileSize, item.linkText);
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

  // Queue the jump, then unwind Shared Media + Profile back to the chat;
  // the chat consumes the signal in onShown
  private jumpToMessage(messageId: string): void {
    if (messageId === '0' || this.chatId === 0) {
      return;
    }
    PendingJumpSignal.set(this.chatId, messageId);
    try {
      this.pageStack.popToName('TgChatScreenPage');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'popToName failed: %{public}s', String(error));
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
  private buildListRow(tile: SharedMediaTileVO) {
    Column() {
      Row() {
        Column() {
          if (tile.kind === 'file') {
            Text(tile.fileName.length > 0 ? tile.fileName : 'File')
              .fontSize(16)
              .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(formatSize(tile.fileSize))
              .fontSize(13)
              .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
              .margin({ top: 2 })
          } else if (tile.kind === 'voice') {
            Text('Voice message')
              .fontSize(16)
              .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
            Text(formatDuration(tile.duration))
              .fontSize(13)
              .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
              .margin({ top: 2 })
          } else {
            Text(tile.linkText.length > 0 ? tile.linkText : 'Link')
              .fontSize(15)
              .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })

      Divider()
        .strokeWidth(0.5)
        .color(TgUiTokens.COLOR_SEPARATOR)
        .margin({ left: 16 })
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

          Text(pageTitleFor(this.filterType))
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
        } else if (this.filterType === 'PhotoAndVideo') {
          Grid() {
            ForEach(this.tiles, (tile: SharedMediaTileVO) => {
              GridItem() {
                this.buildTile(tile)
              }
              .onClick(() => {
                this.jumpToMessage(tile.messageId);
              })
            }, (tile: SharedMediaTileVO) => 'shm_' + tile.messageId)
          }
          .columnsTemplate('1fr 1fr 1fr')
          .columnsGap(2)
          .rowsGap(2)
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        } else {
          List() {
            ForEach(this.tiles, (tile: SharedMediaTileVO) => {
              ListItem() {
                this.buildListRow(tile)
              }
              .onClick(() => {
                this.jumpToMessage(tile.messageId);
              })
            }, (tile: SharedMediaTileVO) => 'shl_' + tile.messageId)
          }
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
        if (params.filterType && params.filterType.length > 0) {
          this.filterType = params.filterType;
        }
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
