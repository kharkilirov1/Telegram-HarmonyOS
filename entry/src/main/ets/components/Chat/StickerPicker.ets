// Sticker picker panel — displays sticker packs with search
// Reference: Telegram iOS StickerPanelController, Android StickersAlert
// Data logic extracted to StickerService.ets

import {
  TelegramSticker,
  StickerSetInfo,
  loadRecentStickers,
  loadInstalledSets,
  loadStickerSetStickers,
  loadTrendingSets,
  installStickerSet,
  removeStickerSet,
  downloadStickerFile,
  updateStickerPathInList,
  updateStickerPathInSets
} from '../../services/StickerService';

// Special tab identifiers
const TAB_RECENT: string = '__recent__';
const TAB_TRENDING: string = '__trending__';

@ComponentV2
export struct StickerPicker {
  @Event onStickerSelected: (emoji: string) => void = () => {};
  @Local activeTabIndex: number = 0;
  @Local searchText: string = '';
  @Local isLoading: boolean = true;
  @Local recentStickers: TelegramSticker[] = [];
  @Local installedSets: StickerSetInfo[] = [];
  @Local trendingSets: StickerSetInfo[] = [];
  @Local showTrending: boolean = false;
  @Local longPressSetIndex: number = -1;
  @Local showRemoveDialog: boolean = false;

  aboutToAppear(): void {
    this.loadRecent();
    this.loadInstalled();
  }

  // --- Data loading (delegates to StickerService) ---

  private async loadRecent(): Promise<void> {
    const stickers = await loadRecentStickers();
    this.recentStickers = stickers;
    for (const sticker of this.recentStickers) {
      if (sticker.fileId > 0 && sticker.localPath.length === 0) {
        this.triggerDownload(sticker);
      }
    }
  }

  private async loadInstalled(): Promise<void> {
    this.isLoading = true;
    this.installedSets = await loadInstalledSets();
    if (this.installedSets.length > 0) {
      this.loadSetStickers(0);
    }
    this.isLoading = false;
  }

  private async loadSetStickers(setIndex: number): Promise<void> {
    if (setIndex < 0 || setIndex >= this.installedSets.length) return;
    const setInfo = this.installedSets[setIndex];
    if (setInfo.isLoaded) return;

    const stickers = await loadStickerSetStickers(setInfo);
    const updatedSets = this.installedSets.slice();
    updatedSets[setIndex] = {
      id: setInfo.id,
      title: setInfo.title,
      name: setInfo.name,
      thumbnailEmoji: setInfo.thumbnailEmoji,
      count: setInfo.count,
      isLoaded: true,
      stickers: stickers
    };
    this.installedSets = updatedSets;

    for (const sticker of stickers) {
      if (sticker.fileId > 0 && sticker.localPath.length === 0) {
        this.triggerDownload(sticker);
      }
    }
  }

  private async loadTrending(): Promise<void> {
    this.trendingSets = await loadTrendingSets();
  }

  private async doInstall(setId: string): Promise<void> {
    try {
      await installStickerSet(setId);
      this.showTrending = false;
      this.loadInstalled();
    } catch (e) {
      // Sticker set install failed — UI stays in current state
    }
  }

  private async doRemove(setId: string): Promise<void> {
    try {
      await removeStickerSet(setId);
      this.loadInstalled();
      this.activeTabIndex = 0;
    } catch (e) {
      // Sticker set removal failed — UI stays in current state
    }
  }

  private triggerDownload(sticker: TelegramSticker): void {
    downloadStickerFile(sticker, (fileId: number, path: string) => {
      this.onStickerPathReady(fileId, path);
    });
  }

  private onStickerPathReady(fileId: number, path: string): void {
    const recentResult = updateStickerPathInList(this.recentStickers, fileId, path);
    if (recentResult.updated) {
      this.recentStickers = recentResult.list;
    }
    const setsResult = updateStickerPathInSets(this.installedSets, fileId, path);
    if (setsResult.updated) {
      this.installedSets = setsResult.list;
    }
  }

  // --- Computed tab data ---

  private getTabCount(): number {
    return 1 + this.installedSets.length + 1;
  }

  private getTabId(index: number): string {
    if (index === 0) return TAB_RECENT;
    const lastIndex = this.getTabCount() - 1;
    if (index === lastIndex) return TAB_TRENDING;
    const setIndex = index - 1;
    if (setIndex >= 0 && setIndex < this.installedSets.length) {
      return this.installedSets[setIndex].id;
    }
    return '';
  }

  private getCurrentStickers(): TelegramSticker[] {
    if (this.showTrending) return [];
    const tabId = this.getTabId(this.activeTabIndex);
    if (tabId === TAB_RECENT) return this.recentStickers;
    if (tabId === TAB_TRENDING) return [];
    const setIndex = this.activeTabIndex - 1;
    if (setIndex >= 0 && setIndex < this.installedSets.length) {
      return this.installedSets[setIndex].stickers;
    }
    return [];
  }

  private getFilteredStickers(): TelegramSticker[] {
    const stickers = this.getCurrentStickers();
    if (this.searchText.length === 0) return stickers;
    const query = this.searchText.toLowerCase();
    return stickers.filter((s: TelegramSticker) => s.emoji.includes(query));
  }

  // --- Build ---

  build() {
    Column() {
      // Search bar
      Row() {
        TextInput({ placeholder: $r('app.string.sticker_search_placeholder'), text: this.searchText })
          .onChange((value: string) => {
            this.searchText = value;
          })
          .height(36)
          .layoutWeight(1)
          .borderRadius(20)
          .backgroundColor($r('app.color.background_secondary'))
          .padding({ left: 12, right: 12 })
          .fontSize(14)
          .accessibilityText($r('app.string.sticker_search_placeholder'))
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor($r('app.color.background_primary'))

      // Pack tabs
      Scroll() {
        Row({ space: 0 }) {
          this.PackTab('\u{1F551}', $r('app.string.sticker_packs_recent'), 0)

          ForEach(this.installedSets, (set: StickerSetInfo, index: number) => {
            this.PackTab(
              set.thumbnailEmoji.length > 0 ? set.thumbnailEmoji : set.title.charAt(0),
              set.title,
              index + 1
            )
          }, (set: StickerSetInfo) => set.id)

          Column() {
            Text('+')
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.telegram_blue'))
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .accessibilityText(getContext(this).resourceManager.getStringSync($r('app.string.sticker_packs_add')))

            Divider()
              .strokeWidth(2)
              .color(this.showTrending
                ? $r('app.color.telegram_blue')
                : Color.Transparent)
              .width('80%')
          }
          .onClick(() => {
            this.showTrending = true;
            this.activeTabIndex = this.getTabCount() - 1;
            this.loadTrending();
          })
          .accessibilityText(getContext(this).resourceManager.getStringSync($r('app.string.sticker_packs_add')))
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(48)
      .backgroundColor($r('app.color.background_primary'))

      Divider().strokeWidth(0.5).color($r('app.color.separator'))

      // Content area
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color($r('app.color.telegram_blue'))
          Text($r('app.string.loading'))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 8 })
        }
        .width('100%')
        .height(200)
        .justifyContent(FlexAlign.Center)
      } else if (this.showTrending) {
        this.TrendingContent()
      } else if (this.showRemoveDialog && this.longPressSetIndex >= 0) {
        this.RemoveConfirmation()
      } else {
        this.StickerGrid()
      }
    }
    .width('100%')
  }

  @Builder
  PackTab(emoji: string, label: string | Resource, tabIndex: number) {
    Column() {
      Text(emoji)
        .fontSize(24)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .accessibilityText(typeof label === 'string' ? label : '')

      Divider()
        .strokeWidth(2)
        .color(!this.showTrending && this.activeTabIndex === tabIndex
          ? $r('app.color.telegram_blue')
          : Color.Transparent)
        .width('80%')
    }
    .onClick(() => {
      this.showTrending = false;
      this.activeTabIndex = tabIndex;
      if (tabIndex > 0) {
        this.loadSetStickers(tabIndex - 1);
      }
    })
    .gesture(
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction(() => {
          if (tabIndex > 0 && tabIndex <= this.installedSets.length) {
            this.longPressSetIndex = tabIndex - 1;
            this.showRemoveDialog = true;
          }
        })
    )
  }

  @Builder
  StickerGrid() {
    Grid() {
      ForEach(this.getFilteredStickers(), (sticker: TelegramSticker) => {
        GridItem() {
          Stack() {
            if (sticker.localPath.length > 0) {
              Image(sticker.localPath)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Contain)
                .alt(sticker.emoji)
                .autoResize(true)
                .onError(() => {})
                .accessibilityText(sticker.emoji)
            } else {
              Text(sticker.emoji)
                .fontSize(36)
                .accessibilityText(sticker.emoji)
            }

            if (sticker.isAnimated) {
              Text('\u{2728}')
                .fontSize(10)
                .position({ right: 2, bottom: 2 })
            }
          }
          .width('100%')
          .height('100%')
          .alignContent(Alignment.Center)
        }
        .onClick(() => {
          this.onStickerSelected(sticker.emoji);
        })
        .accessibilityText(sticker.emoji)
      }, (sticker: TelegramSticker) => `${sticker.id}_${sticker.fileId}`)
    }
    .columnsTemplate('1fr 1fr 1fr 1fr 1fr')
    .rowsGap(4)
    .columnsGap(4)
    .width('100%')
    .height(200)
    .padding(8)
    .backgroundColor($r('app.color.background_primary'))
  }

  @Builder
  TrendingContent() {
    if (this.trendingSets.length === 0) {
      Column() {
        LoadingProgress()
          .width(32)
          .height(32)
          .color($r('app.color.telegram_blue'))
        Text($r('app.string.loading'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 8 })
      }
      .width('100%')
      .height(200)
      .justifyContent(FlexAlign.Center)
    } else {
      Scroll() {
        Column() {
          Text($r('app.string.sticker_packs_trending'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .padding({ left: 16, top: 12, bottom: 8 })

          ForEach(this.trendingSets, (set: StickerSetInfo) => {
            Row() {
              Text(set.thumbnailEmoji)
                .fontSize(28)
                .width(44)
                .height(44)
                .textAlign(TextAlign.Center)
                .accessibilityText(set.title)

              Column() {
                Text(set.title)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(getContext(this).resourceManager.getStringByNameSync('sticker_pack_count_format').replace('%s', set.count.toString()))
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 2 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .padding({ left: 12 })

              Button($r('app.string.sticker_pack_install'))
                .fontSize(14)
                .fontColor($r('app.color.icon_on_primary'))
                .backgroundColor($r('app.color.telegram_blue'))
                .borderRadius(16)
                .height(32)
                .padding({ left: 16, right: 16 })
                .onClick(() => {
                  this.doInstall(set.id);
                })
                .accessibilityText(getContext(this).resourceManager.getStringSync($r('app.string.sticker_pack_install')))
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .alignItems(VerticalAlign.Center)
          }, (set: StickerSetInfo) => set.id)
        }
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Auto)
      .width('100%')
      .height(200)
      .backgroundColor($r('app.color.background_primary'))
    }
  }

  @Builder
  RemoveConfirmation() {
    Column() {
      if (this.longPressSetIndex >= 0 && this.longPressSetIndex < this.installedSets.length) {
        Column() {
          Text(this.installedSets[this.longPressSetIndex].title)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ bottom: 12 })

          Text(getContext(this).resourceManager.getStringByNameSync('sticker_pack_count_format').replace('%s', this.installedSets[this.longPressSetIndex].count.toString()))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ bottom: 16 })

          Row({ space: 12 }) {
            Button($r('app.string.cancel'))
              .fontSize(14)
              .fontColor($r('app.color.telegram_blue'))
              .backgroundColor($r('app.color.background_secondary'))
              .borderRadius(16)
              .height(36)
              .layoutWeight(1)
              .onClick(() => {
                this.showRemoveDialog = false;
                this.longPressSetIndex = -1;
              })
              .accessibilityText(getContext(this).resourceManager.getStringSync($r('app.string.cancel')))

            Button($r('app.string.sticker_pack_remove'))
              .fontSize(14)
              .fontColor($r('app.color.icon_on_primary'))
              .backgroundColor($r('app.color.error_red'))
              .borderRadius(16)
              .height(36)
              .layoutWeight(1)
              .onClick(() => {
                const setId = this.installedSets[this.longPressSetIndex].id;
                this.showRemoveDialog = false;
                this.longPressSetIndex = -1;
                this.doRemove(setId);
              })
              .accessibilityText(getContext(this).resourceManager.getStringSync($r('app.string.sticker_pack_remove')))
          }
          .width('100%')
        }
        .padding(20)
        .borderRadius(24)
        .backgroundColor($r('app.color.background_primary'))
        .shadow({
          radius: 16,
          color: $r('app.color.shadow_color'),
          offsetX: 0,
          offsetY: 4
        })
      }
    }
    .width('100%')
    .height(200)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 32, right: 32 })
    .backgroundColor($r('app.color.background_secondary'))
  }
}
