import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgPinnedMessagePanel } from './TgPinnedMessagePanel';

export class TgPinnedMessageListItem {
  messageId: string = '0';
  title: string = '';
  preview: string = '';
  stripeIndex: number = 0;
  totalCount: number = 1;
  hasThumbnail: boolean = false;
  thumbnailSrc: Resource | string = $r('app.media.app_icon_transparent');
}

@ComponentV2
export struct TgPinnedMessageList {
  @Param items: TgPinnedMessageListItem[] = [];
  @Param contentStartOffset: number = 0;
  @Param bottomInset: number = 0;
  @Param isLoading: boolean = false;
  @Param emptyText: string = 'No pinned messages';

  @Event onItemPress: (index: number) => void = (_index: number): void => {};
  @Event onLoadMore: () => void = (): void => {};

  build() {
    List() {
      ForEach(this.items, (item: TgPinnedMessageListItem, index: number) => {
        ListItem() {
          TgPinnedMessagePanel({
            title: item.title,
            preview: item.preview,
            index: item.stripeIndex,
            totalCount: item.totalCount,
            hasThumbnail: item.hasThumbnail,
            thumbnailSrc: item.thumbnailSrc,
            showTrailingAction: false,
            onPress: (): void => {
              this.onItemPress(index);
            }
          })
        }
        .padding({ top: TgUiTokens.SPACE_4, bottom: TgUiTokens.SPACE_4 })
      }, (item: TgPinnedMessageListItem) => item.messageId)

      if (this.isLoading) {
        ListItem() {
          Row() {
            LoadingProgress()
              .width(TgUiTokens.CHATLIST_STATUS_ICON_SIZE)
              .height(TgUiTokens.CHATLIST_STATUS_ICON_SIZE)
              .color(TgUiTokens.COLOR_ICON_PRIMARY)
          }
          .width('100%')
          .height(TgUiTokens.PINNED_PANEL_HEIGHT)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
        }
      } else if (this.items.length === 0) {
        ListItem() {
          Text(this.emptyText)
            .width('100%')
            .height(TgUiTokens.PINNED_PANEL_HEIGHT * 2)
            .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            .textAlign(TextAlign.Center)
        }
      }

      ListItem() {
        Row()
          .width('100%')
          .height(this.bottomInset)
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .contentStartOffset(this.contentStartOffset)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .onReachEnd(() => {
      this.onLoadMore();
    })
  }
}
