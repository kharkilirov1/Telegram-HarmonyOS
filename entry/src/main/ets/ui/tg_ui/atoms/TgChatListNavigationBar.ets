import { uiMaterial } from '@kit.ArkUI';
import { Available, deviceInfo } from '@kit.BasicServicesKit';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { TgAvatar } from './TgAvatar';
import { TgChatListFilterBar } from './TgChatListFilterBar';
import { TgIcon } from './TgIcon';

export const TG_CHAT_LIST_SEARCH_INPUT_ID: string = 'tg_chat_list_search_input';

export class TgChatListStoryPreview {
  chatId: number = 0;
  storyId: number = 0;
  imageSrc: Resource | string = $r('app.media.app_icon_transparent');
  useImage: boolean = false;
  initials: string = '';
  backgroundColor: ResourceColor = TgUiTokens.AVATAR_COLOR_5;
  hasUnread: boolean = false;
  isCloseFriends: boolean = false;
}

@ComponentV2
export struct TgChatListNavigationBar {
  @Param title: string = '';
  @Param searchValue: string = '';
  @Param searchPlaceholder: string = 'Search';
  @Param showEditAction: boolean = true;
  @Param editText: string = 'Edit';
  @Param showStoryAction: boolean = true;
  @Param storyActionInteractive: boolean = false;
  @Param showComposeAction: boolean = true;
  @Param storyPreviews: TgChatListStoryPreview[] = [];
  @Param storyStripInteractive: boolean = false;
  @Param searchCollapseProgress: number = 0;
  @Param selectedFilterIndex: number = 0;
  @Param allFilterText: string = 'All';
  @Param unreadFilterText: string = 'Unread';
  @Param personalFilterText: string = 'Personal';
  @Param unreadFilterCount: number = 0;
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;

  @Local private searchFocused: boolean = false;

  @Event onEditPress: () => void = (): void => {};
  @Event onStoryPress: () => void = (): void => {};
  @Event onComposePress: () => void = (): void => {};
  @Event onStoryStripPress: () => void = (): void => {};
  @Event onFilterChange: (index: number) => void = (_: number): void => {};
  @Event onSearchWillFocus: () => void = (): void => {};
  @Event onSearchChange: (value: string) => void = (_: string): void => {};
  @Event onSearchSubmit: (value: string) => void = (_: string): void => {};

  // ChatListPage owns the avoid-area read and passes a single reactive inset.
  @Param topInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;

  private useBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  private useNativeMaterial(): boolean {
    return deviceInfo.apiAvailable('26.0.0') && this.useBlur();
  }

  private collapseProgress(): number {
    return Math.max(0, Math.min(1, this.searchCollapseProgress));
  }

  private searchHitTestMode(): HitTestMode {
    return this.collapseProgress() >= 0.98 ? HitTestMode.None : HitTestMode.Default;
  }

  private focusSearchInput(): void {
    if (this.searchHitTestMode() === HitTestMode.None) {
      return;
    }
    this.onSearchWillFocus();
    setTimeout(() => {
      try {
        this.getUIContext().getFocusController().requestFocus(TG_CHAT_LIST_SEARCH_INPUT_ID);
      } catch (_error) {
      }
    }, 0);
  }

  private updateSearchFocus(focused: boolean): void {
    if (this.searchFocused === focused) {
      return;
    }
    this.searchFocused = focused;
  }

  private actionBackground(): ResourceColor {
    return this.useBlur() ? TgUiTokens.CHAT_TOP_BAR_CAPSULE_BG : TgUiTokens.CHAT_TOP_BAR_CAPSULE_FALLBACK_BG;
  }

  private storyRingTop(story: TgChatListStoryPreview): ResourceColor {
    if (!story.hasUnread) {
      return TgUiTokens.CHAT_LIST_STORY_RING_SEEN;
    }
    if (story.isCloseFriends) {
      return TgUiTokens.CHAT_LIST_STORY_RING_CLOSE_FRIENDS;
    }
    return TgUiTokens.CHAT_LIST_STORY_RING_UNSEEN_TOP;
  }

  private storyRingBottom(story: TgChatListStoryPreview): ResourceColor {
    if (!story.hasUnread) {
      return TgUiTokens.CHAT_LIST_STORY_RING_SEEN;
    }
    if (story.isCloseFriends) {
      return TgUiTokens.CHAT_LIST_STORY_RING_CLOSE_FRIENDS;
    }
    return TgUiTokens.CHAT_LIST_STORY_RING_UNSEEN_BOTTOM;
  }

  private actionBlurStyle(): BlurStyle {
    return this.useBlur() ? BlurStyle.COMPONENT_ULTRA_THIN : BlurStyle.NONE;
  }

  private actionResponseRegionOffset(): number {
    return (TgUiTokens.CHAT_LIST_NAV_ACTION_HEIGHT -
      TgUiTokens.CHAT_LIST_NAV_ACTION_RESPONSE_SIZE) / 2;
  }

  private visibleBackgroundHeight(): number {
    return this.topInset + TgUiTokens.CHAT_LIST_NAV_TOTAL_HEIGHT -
      TgUiTokens.CHAT_LIST_NAV_SEARCH_AREA_HEIGHT * this.collapseProgress();
  }

  @Builder
  private buildEditLabel() {
    Text(this.editText)
      .fontSize(TgUiTokens.CHAT_LIST_NAV_ACTION_FONT_SIZE)
      .fontWeight(FontWeight.Medium)
      .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeEditAction() {
    Row() {
      this.buildEditLabel()
    }
    .constraintSize({
      minWidth: TgUiTokens.CHAT_LIST_NAV_EDIT_MIN_WIDTH,
      maxWidth: TgUiTokens.CHAT_LIST_NAV_EDIT_MAX_WIDTH
    })
    .height(TgUiTokens.CHAT_LIST_NAV_ACTION_HEIGHT)
    .padding({ left: TgUiTokens.SPACE_12, right: TgUiTokens.SPACE_12 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      colorInvert: true,
      applyShadow: true,
      interactive: true
    }))
    .borderRadius(TgUiTokens.CHAT_LIST_NAV_ACTION_RADIUS)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
    .responseRegion({
      x: 0,
      y: this.actionResponseRegionOffset(),
      width: '100%',
      height: TgUiTokens.CHAT_LIST_NAV_ACTION_RESPONSE_SIZE
    })
    .accessibilityText(this.editText)
    .onClick(() => this.onEditPress())
  }

  @Builder
  private buildFallbackEditAction() {
    Row() {
      this.buildEditLabel()
    }
    .constraintSize({
      minWidth: TgUiTokens.CHAT_LIST_NAV_EDIT_MIN_WIDTH,
      maxWidth: TgUiTokens.CHAT_LIST_NAV_EDIT_MAX_WIDTH
    })
    .height(TgUiTokens.CHAT_LIST_NAV_ACTION_HEIGHT)
    .padding({ left: TgUiTokens.SPACE_12, right: TgUiTokens.SPACE_12 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.actionBackground())
    .backgroundBlurStyle(this.actionBlurStyle(), TgGlassPolicy.glassOptions())
    .border({
      width: TgUiTokens.CHAT_LIST_NAV_ACTION_BORDER_WIDTH,
      color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER
    })
    .borderRadius(TgUiTokens.CHAT_LIST_NAV_ACTION_RADIUS)
    .clip(true)
    .renderGroup(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
    .responseRegion({
      x: 0,
      y: this.actionResponseRegionOffset(),
      width: '100%',
      height: TgUiTokens.CHAT_LIST_NAV_ACTION_RESPONSE_SIZE
    })
    .accessibilityText(this.editText)
    .onClick(() => this.onEditPress())
  }

  @Builder
  private buildEditAction() {
    if (this.showEditAction) {
      if (deviceInfo.apiAvailable('26.0.0')) {
        if (this.useNativeMaterial()) {
          this.buildNativeEditAction()
        } else {
          this.buildFallbackEditAction()
        }
      } else {
        this.buildFallbackEditAction()
      }
    }
  }

  @Builder
  private buildRightActionContent() {
    if (this.showStoryAction) {
      Row() {
        TgIcon({
          src: $r('app.media.ic_chatlist_add_story'),
          iconSize: TgUiTokens.CHAT_LIST_NAV_ACTION_ICON_SIZE,
          tintColor: TgUiTokens.COLOR_TEXT_TITLE
        })
      }
      .width(TgUiTokens.CHAT_LIST_NAV_ACTION_CELL_WIDTH)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .responseRegion({
        x: 0,
        y: this.actionResponseRegionOffset(),
        width: TgUiTokens.CHAT_LIST_NAV_ACTION_CELL_WIDTH,
        height: TgUiTokens.CHAT_LIST_NAV_ACTION_RESPONSE_SIZE
      })
      .accessibilityText('Add story')
      .enabled(this.storyActionInteractive)
      .onClick(() => {
        if (this.storyActionInteractive) {
          this.onStoryPress();
        }
      })
    }

    if (this.showComposeAction) {
      Row() {
        TgIcon({
          src: $r('app.media.ic_chatlist_compose'),
          iconSize: TgUiTokens.CHAT_LIST_NAV_ACTION_ICON_SIZE,
          tintColor: TgUiTokens.COLOR_TEXT_TITLE
        })
      }
      .width(TgUiTokens.CHAT_LIST_NAV_ACTION_CELL_WIDTH)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .responseRegion({
        x: 0,
        y: this.actionResponseRegionOffset(),
        width: TgUiTokens.CHAT_LIST_NAV_ACTION_CELL_WIDTH,
        height: TgUiTokens.CHAT_LIST_NAV_ACTION_RESPONSE_SIZE
      })
      .accessibilityText('New message')
      .onClick(() => this.onComposePress())
    }
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeRightActions() {
    Row() {
      this.buildRightActionContent()
    }
    .width(TgUiTokens.CHAT_LIST_NAV_RIGHT_ACTION_WIDTH)
    .height(TgUiTokens.CHAT_LIST_NAV_ACTION_HEIGHT)
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      colorInvert: true,
      applyShadow: true,
      interactive: true
    }))
    .borderRadius(TgUiTokens.CHAT_LIST_NAV_ACTION_RADIUS)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
  }

  @Builder
  private buildFallbackRightActions() {
    Row() {
      this.buildRightActionContent()
    }
    .width(TgUiTokens.CHAT_LIST_NAV_RIGHT_ACTION_WIDTH)
    .height(TgUiTokens.CHAT_LIST_NAV_ACTION_HEIGHT)
    .backgroundColor(this.actionBackground())
    .backgroundBlurStyle(this.actionBlurStyle(), TgGlassPolicy.glassOptions())
    .border({
      width: TgUiTokens.CHAT_LIST_NAV_ACTION_BORDER_WIDTH,
      color: TgUiTokens.CHAT_TOP_BAR_CAPSULE_BORDER
    })
    .borderRadius(TgUiTokens.CHAT_LIST_NAV_ACTION_RADIUS)
    .clip(true)
    .renderGroup(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
  }

  @Builder
  private buildRightActions() {
    if (this.showStoryAction || this.showComposeAction) {
      if (deviceInfo.apiAvailable('26.0.0')) {
        if (this.useNativeMaterial()) {
          this.buildNativeRightActions()
        } else {
          this.buildFallbackRightActions()
        }
      } else {
        this.buildFallbackRightActions()
      }
    }
  }

  @Builder
  private buildStoryPreview(story: TgChatListStoryPreview, index: number) {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(TgUiTokens.CHAT_LIST_NAV_STORY_AVATAR_SIZE)
        .height(TgUiTokens.CHAT_LIST_NAV_STORY_AVATAR_SIZE)
        .linearGradient({
          angle: 180,
          colors: [
            [this.storyRingTop(story), 0],
            [this.storyRingBottom(story), 1]
          ]
        })
        .borderRadius(TgUiTokens.RADIUS_ROUND_MAX)

      TgAvatar({
        avatarSize: TgUiTokens.CHAT_LIST_NAV_STORY_INNER_SIZE,
        initials: story.initials,
        useImage: story.useImage,
        imageSrc: story.imageSrc,
        avatarBackgroundColor: story.backgroundColor
      })
    }
    .width(TgUiTokens.CHAT_LIST_NAV_STORY_AVATAR_SIZE)
    .height(TgUiTokens.CHAT_LIST_NAV_STORY_AVATAR_SIZE)
    .margin({ left: index === 0 ? 0 : -TgUiTokens.CHAT_LIST_NAV_STORY_OVERLAP })
  }

  @Builder
  private buildCenterTitle() {
    Row() {
      if (this.storyPreviews.length > 0) {
        Row() {
          ForEach(this.storyPreviews.slice(0, 3), (story: TgChatListStoryPreview, index: number) => {
            this.buildStoryPreview(story, index)
          })
        }
        .hitTestBehavior(this.storyStripInteractive ? HitTestMode.Default : HitTestMode.None)
        .onClick(() => {
          if (this.storyStripInteractive) {
            this.onStoryStripPress();
          }
        })
      }

      Text(this.title)
        .fontSize(TgUiTokens.CHAT_LIST_NAV_TITLE_FONT_SIZE)
        .fontWeight(TgUiTokens.CHAT_LIST_NAV_TITLE_WEIGHT)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: this.storyPreviews.length > 0 ? TgUiTokens.CHAT_LIST_NAV_STORY_TITLE_GAP : 0 })
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .constraintSize({ maxWidth: '100%' })
  }

  @Builder
  private buildTitleRow() {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        this.buildCenterTitle()
      }
      .width('100%')
      .padding({
        left: TgUiTokens.CHAT_LIST_NAV_CENTER_SIDE_GUARD,
        right: TgUiTokens.CHAT_LIST_NAV_CENTER_SIDE_GUARD
      })
      .justifyContent(FlexAlign.Center)

      Row() {
        this.buildEditAction()
        Blank()
        this.buildRightActions()
      }
      .width('100%')
      .padding({
        left: TgUiTokens.CHAT_LIST_NAV_SIDE_INSET,
        right: TgUiTokens.CHAT_LIST_NAV_SIDE_INSET
      })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(TgUiTokens.CHAT_LIST_NAV_ACTION_HEIGHT)
    .position({
      x: 0,
      y: TgUiTokens.CHAT_LIST_NAV_TITLE_TOP_GAP
    })
  }

  @Builder
  private buildSearchRow() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Search({
          value: this.searchValue,
          placeholder: this.searchFocused ? this.searchPlaceholder : ''
        })
          .id(TG_CHAT_LIST_SEARCH_INPUT_ID)
          .width('100%')
          .height(TgUiTokens.CHAT_LIST_NAV_SEARCH_HEIGHT)
          .focusable(true)
          .focusOnTouch(true)
          .backgroundColor(TgUiTokens.CHAT_LIST_SEARCH_SURFACE_BG)
          .borderRadius(TgUiTokens.CHAT_LIST_NAV_SEARCH_RADIUS)
          .textFont({
            size: TgUiTokens.CHAT_LIST_NAV_SEARCH_FONT_SIZE,
            weight: FontWeight.Regular
          })
          .textAlign(TextAlign.Start)
          .fontColor(TgUiTokens.SEARCH_BAR_TEXT_COLOR)
          .searchIcon({
            src: TgUiTokens.ICON_RES_SEARCH,
            size: this.searchValue.length === 0 && !this.searchFocused
              ? 0
              : TgUiTokens.CHAT_LIST_NAV_SEARCH_ICON_SIZE,
            color: this.searchValue.length === 0 && !this.searchFocused
              ? Color.Transparent
              : TgUiTokens.SEARCH_BAR_ICON_COLOR
          })
          .cancelButton({ style: CancelButtonStyle.INPUT })
          .onClick(() => this.focusSearchInput())
          .onFocus(() => {
            this.onSearchWillFocus();
            this.updateSearchFocus(true);
          })
          .onBlur(() => {
            this.updateSearchFocus(false);
          })
          .onChange((value: string) => this.onSearchChange(value))
          .onSubmit((value: string) => this.onSearchSubmit(value))

        if (this.searchValue.length === 0 && !this.searchFocused) {
          Row({ space: TgUiTokens.SPACE_6 }) {
            TgIcon({
              src: TgUiTokens.ICON_RES_SEARCH,
              iconSize: TgUiTokens.CHAT_LIST_NAV_SEARCH_ICON_SIZE,
              tintColor: TgUiTokens.SEARCH_BAR_ICON_COLOR
            })
            Text(this.searchPlaceholder)
              .fontSize(TgUiTokens.CHAT_LIST_NAV_SEARCH_FONT_SIZE)
              .fontWeight(FontWeight.Regular)
              .fontColor(TgUiTokens.SEARCH_BAR_PLACEHOLDER_COLOR)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .hitTestBehavior(HitTestMode.Block)
          .onClick(() => this.focusSearchInput())
        }
      }
      .width('100%')
      .height(TgUiTokens.CHAT_LIST_NAV_SEARCH_HEIGHT)
    }
    .width('100%')
    .height(TgUiTokens.CHAT_LIST_NAV_SEARCH_AREA_HEIGHT)
    .padding({
      left: TgUiTokens.CHAT_LIST_NAV_SIDE_INSET,
      right: TgUiTokens.CHAT_LIST_NAV_SIDE_INSET,
      top: TgUiTokens.SPACE_4,
      bottom: TgUiTokens.SPACE_6
    })
    .opacity(1 - this.collapseProgress())
    .translate({ y: -TgUiTokens.SPACE_8 * this.collapseProgress() })
    .hitTestBehavior(this.searchHitTestMode())
    .position({
      x: 0,
      y: TgUiTokens.CHAT_LIST_NAV_TITLE_AREA_HEIGHT
    })
  }

  @Builder
  private buildFilterRow() {
    Row() {
      TgChatListFilterBar({
        selectedIndex: this.selectedFilterIndex,
        allText: this.allFilterText,
        unreadText: this.unreadFilterText,
        personalText: this.personalFilterText,
        unreadCount: this.unreadFilterCount,
        glassMode: this.glassMode,
        onSelectedIndexChange: (index: number): void => this.onFilterChange(index)
      })
    }
    .width('100%')
    .height(TgUiTokens.CHAT_LIST_NAV_FILTER_AREA_HEIGHT)
    .padding({
      left: TgUiTokens.CHAT_LIST_NAV_SIDE_INSET,
      right: TgUiTokens.CHAT_LIST_NAV_SIDE_INSET,
      top: TgUiTokens.SPACE_4,
      bottom: TgUiTokens.SPACE_6
    })
    .position({
      x: 0,
      y: TgUiTokens.CHAT_LIST_NAV_TITLE_AREA_HEIGHT +
        TgUiTokens.CHAT_LIST_NAV_SEARCH_AREA_HEIGHT * (1 - this.collapseProgress())
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row()
        .width('100%')
        .height(this.visibleBackgroundHeight())
        .backgroundColor(TgUiTokens.CHAT_LIST_PINNED_SURFACE_BG)

      Column() {
        Row()
          .width('100%')
          .height(this.topInset)

        Stack({ alignContent: Alignment.TopStart }) {
          this.buildTitleRow()
          this.buildSearchRow()
          this.buildFilterRow()
        }
        .width('100%')
        .height(TgUiTokens.CHAT_LIST_NAV_TOTAL_HEIGHT)
        .clip(true)
      }
      .width('100%')
      .height(this.topInset + TgUiTokens.CHAT_LIST_NAV_TOTAL_HEIGHT)
    }
    .width('100%')
    .height(this.topInset + TgUiTokens.CHAT_LIST_NAV_TOTAL_HEIGHT)
  }
}
