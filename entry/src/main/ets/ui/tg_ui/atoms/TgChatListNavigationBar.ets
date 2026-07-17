import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { TgIcon } from './TgIcon';
import { TgTopChromeBackground } from './TgTopChromeBackground';

@ComponentV2
export struct TgChatListNavigationBar {
  @Param title: string = '';
  @Param searchValue: string = '';
  @Param searchPlaceholder: string = 'Search';
  @Param showEditAction: boolean = true;
  @Param editText: string = 'Edit';
  @Param showComposeAction: boolean = true;
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;

  @Event onEditPress: () => void = (): void => {};
  @Event onComposePress: () => void = (): void => {};
  @Event onSearchChange: (value: string) => void = (_: string): void => {};
  @Event onSearchSubmit: (value: string) => void = (_: string): void => {};

  // Single source of truth: ChatListPage computes the status-bar inset (with
  // avoidAreaChange reactivity) and passes it down. No independent read here.
  @Param topInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;

  private useRealtimeBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  @Builder
  private buildEditAction() {
    if (this.showEditAction) {
      Row() {
        Text(this.editText)
          .fontSize(TgUiTokens.TOP_BAR_TITLE_SIZE)
          .fontColor(TgUiTokens.COLOR_ICON_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .constraintSize({ minWidth: TgUiTokens.TOP_BAR_ACTION_TOUCH })
      .height(TgUiTokens.TOP_BAR_ACTION_TOUCH)
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .accessibilityGroup(true)
      .onClick(() => {
        this.onEditPress();
      })
    } else {
      Row()
        .width(TgUiTokens.TOP_BAR_ACTION_TOUCH)
        .height(TgUiTokens.TOP_BAR_ACTION_TOUCH)
    }
  }

  @Builder
  private buildComposeAction() {
    if (this.showComposeAction) {
      Row() {
        TgIcon({
          src: TgUiTokens.ICON_RES_EDIT,
          iconSize: TgUiTokens.TOP_BAR_ACTION_ICON_SIZE,
          tintColor: TgUiTokens.COLOR_ICON_PRIMARY
        })
      }
      .width(TgUiTokens.TOP_BAR_ACTION_TOUCH)
      .height(TgUiTokens.TOP_BAR_ACTION_TOUCH)
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Center)
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .accessibilityGroup(true)
      .accessibilityDescription('Compose')
      .onClick(() => {
        this.onComposePress();
      })
    } else {
      Row()
        .width(TgUiTokens.TOP_BAR_ACTION_TOUCH)
        .height(TgUiTokens.TOP_BAR_ACTION_TOUCH)
    }
  }

  @Builder
  private buildTitleRow() {
    Stack({ alignContent: Alignment.Center }) {
      Text(this.title)
        .fontSize(TgUiTokens.TOP_BAR_TITLE_SIZE)
        .fontWeight(TgUiTokens.CHAT_LIST_NAV_TITLE_WEIGHT)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .padding({
          left: TgUiTokens.TOP_BAR_ACTION_TOUCH + TgUiTokens.SPACE_12,
          right: TgUiTokens.TOP_BAR_ACTION_TOUCH + TgUiTokens.SPACE_12
        })

      Row() {
        this.buildEditAction()
        Blank().layoutWeight(1)
        this.buildComposeAction()
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(TgUiTokens.TOP_BAR_HEIGHT)
    .padding({
      left: TgUiTokens.TOP_BAR_SIDE_PADDING,
      right: TgUiTokens.TOP_BAR_SIDE_PADDING
    })
  }

  @Builder
  private buildSearchRow() {
    Row() {
      Search({ value: this.searchValue, placeholder: this.searchPlaceholder })
        .width('100%')
        .height(TgUiTokens.SEARCH_BAR_HEIGHT)
        .backgroundColor(TgUiTokens.SEARCH_BAR_BG)
        .borderRadius(TgUiTokens.SEARCH_BAR_RADIUS)
        .placeholderColor(TgUiTokens.SEARCH_BAR_PLACEHOLDER_COLOR)
        .placeholderFont({
          size: TgUiTokens.SEARCH_BAR_FONT_SIZE,
          weight: FontWeight.Regular
        })
        .textFont({
          size: TgUiTokens.SEARCH_BAR_FONT_SIZE,
          weight: FontWeight.Regular
        })
        .fontColor(TgUiTokens.SEARCH_BAR_TEXT_COLOR)
        .searchIcon({
          src: TgUiTokens.ICON_RES_SEARCH,
          size: TgUiTokens.SEARCH_BAR_ICON_SIZE,
          color: TgUiTokens.SEARCH_BAR_ICON_COLOR
        })
        .cancelButton({ style: CancelButtonStyle.INPUT })
        .onChange((value: string) => {
          this.onSearchChange(value);
        })
        .onSubmit((value: string) => {
          this.onSearchSubmit(value);
        })
    }
    .width('100%')
    .height(TgUiTokens.CHAT_LIST_NAV_SEARCH_AREA_HEIGHT)
    .padding({
      left: TgUiTokens.SEARCH_BAR_SIDE_INSET,
      right: TgUiTokens.SEARCH_BAR_SIDE_INSET
    })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      TgTopChromeBackground({
        topInset: this.topInset,
        contentHeight: TgUiTokens.CHAT_LIST_NAV_TOTAL_HEIGHT,
        glassMode: this.glassMode,
        showBottomSeparator: true,
        showTopEdgeEmphasis: this.useRealtimeBlur()
      })

      Column() {
        Row()
          .width('100%')
          .height(this.topInset)

        this.buildTitleRow()
        this.buildSearchRow()
      }
      .height(this.topInset + TgUiTokens.CHAT_LIST_NAV_TOTAL_HEIGHT)
      .width('100%')
    }
    .height(this.topInset + TgUiTokens.CHAT_LIST_NAV_TOTAL_HEIGHT)
    .width('100%')
  }
}
