// Sticker picker panel — displays sticker packs with search
// Reference: Telegram iOS StickerPanelController, Android StickersAlert
// TDLib-backed: loads installed sticker sets, recent stickers, trending sets

import { TDLibClient } from '../../services/TDLibClient';
import { FileController } from '../../controllers/FileController';

// --- Data models ---

interface TelegramSticker {
  id: number;
  emoji: string;
  fileId: number;
  localPath: string;
  isAnimated: boolean;
}

interface StickerSetInfo {
  id: string; // TDLib sticker set IDs are int64, use string for safety
  title: string;
  name: string;
  thumbnailEmoji: string;
  count: number;
  isLoaded: boolean;
  stickers: TelegramSticker[];
}

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
    this.loadRecentStickers();
    this.loadInstalledSets();
  }

  // --- TDLib data loading ---

  private async loadRecentStickers(): Promise<void> {
    try {
      const recentParams: Record<string, Object> = {};
      recentParams['is_attached'] = false;
      const result = await TDLibClient.getInstance().send('getRecentStickers', recentParams);
      const data = result as Record<string, Object>;
      const stickersRaw = data['stickers'] as Record<string, Object>[];
      if (stickersRaw) {
        const parsed: TelegramSticker[] = [];
        for (const raw of stickersRaw) {
          parsed.push(this.parseStickerObject(raw));
        }
        this.recentStickers = parsed;
        // Trigger file downloads for recent stickers
        for (const sticker of this.recentStickers) {
          if (sticker.fileId > 0 && sticker.localPath.length === 0) {
            this.downloadStickerFile(sticker);
          }
        }
      }
    } catch (_e) {
      // Recent stickers may not be available yet
    }
  }

  private async loadInstalledSets(): Promise<void> {
    this.isLoading = true;
    try {
      const stickerType: Record<string, Object> = {};
      stickerType['@type'] = 'stickerTypeRegular';
      const installedParams: Record<string, Object> = {};
      installedParams['sticker_type'] = stickerType;
      const result = await TDLibClient.getInstance().send('getInstalledStickerSets', installedParams);
      const data = result as Record<string, Object>;
      const setsRaw = data['sets'] as Record<string, Object>[];
      if (setsRaw) {
        const sets: StickerSetInfo[] = [];
        for (const raw of setsRaw) {
          const setInfo = this.parseStickerSetInfoObject(raw);
          sets.push(setInfo);
        }
        this.installedSets = sets;

        // Load stickers for the first visible set if any
        if (this.installedSets.length > 0) {
          this.loadStickerSetStickers(0);
        }
      }
    } catch (_e) {
      // Handle error silently
    }
    this.isLoading = false;
  }

  private async loadStickerSetStickers(setIndex: number): Promise<void> {
    if (setIndex < 0 || setIndex >= this.installedSets.length) {
      return;
    }
    const setInfo = this.installedSets[setIndex];
    if (setInfo.isLoaded) {
      return;
    }
    try {
      const getSetParams: Record<string, Object> = {};
      getSetParams['set_id'] = setInfo.id;
      const result = await TDLibClient.getInstance().send('getStickerSet', getSetParams);
      const data = result as Record<string, Object>;
      const stickersRaw = data['stickers'] as Record<string, Object>[];
      if (stickersRaw) {
        const stickers: TelegramSticker[] = [];
        for (const raw of stickersRaw) {
          stickers.push(this.parseStickerObject(raw));
        }
        // Mutate the set in place and reassign array to trigger reactivity
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
        // Trigger file downloads for visible stickers
        for (const sticker of stickers) {
          if (sticker.fileId > 0 && sticker.localPath.length === 0) {
            this.downloadStickerFile(sticker);
          }
        }
      }
    } catch (_e) {
      // Handle error silently
    }
  }

  private async loadTrendingSets(): Promise<void> {
    try {
      const trendingType: Record<string, Object> = {};
      trendingType['@type'] = 'stickerTypeRegular';
      const trendingParams: Record<string, Object> = {};
      trendingParams['sticker_type'] = trendingType;
      trendingParams['offset'] = 0;
      trendingParams['limit'] = 20;
      const result = await TDLibClient.getInstance().send('getTrendingStickerSets', trendingParams);
      const data = result as Record<string, Object>;
      const setsRaw = data['sets'] as Record<string, Object>[];
      if (setsRaw) {
        const sets: StickerSetInfo[] = [];
        for (const raw of setsRaw) {
          const setInfo = this.parseStickerSetInfoObject(raw);
          sets.push(setInfo);
        }
        this.trendingSets = sets;
      }
    } catch (_e) {
      // Handle error silently
    }
  }

  private async installStickerSet(setId: string): Promise<void> {
    try {
      const installParams: Record<string, Object> = {};
      installParams['set_id'] = setId;
      installParams['is_installed'] = true;
      await TDLibClient.getInstance().send('changeStickerSet', installParams);
      // Reload installed sets to reflect changes
      this.showTrending = false;
      this.loadInstalledSets();
    } catch (_e) {
      // Handle error silently
    }
  }

  private async removeStickerSet(setId: string): Promise<void> {
    try {
      const removeParams: Record<string, Object> = {};
      removeParams['set_id'] = setId;
      removeParams['is_installed'] = false;
      await TDLibClient.getInstance().send('changeStickerSet', removeParams);
      // Reload installed sets
      this.loadInstalledSets();
      this.activeTabIndex = 0;
    } catch (_e) {
      // Handle error silently
    }
  }

  // --- Parsing helpers ---

  private parseStickerObject(raw: Record<string, Object>): TelegramSticker {
    const stickerId = (raw['id'] as number) || 0;
    const emoji = (raw['emoji'] as string) || '';
    const stickerFile = raw['sticker'] as Record<string, Object>;
    let fileId = 0;
    let localPath = '';
    let isAnimated = false;

    if (stickerFile) {
      const file = stickerFile['file'] as Record<string, Object>;
      if (file) {
        fileId = (file['id'] as number) || 0;
        const local = file['local'] as Record<string, Object>;
        if (local) {
          const isComplete = local['is_downloading_completed'] as boolean;
          if (isComplete) {
            localPath = (local['path'] as string) || '';
          }
        }
      }
    }

    const format = raw['format'] as Record<string, Object>;
    if (format) {
      const formatType = format['@type'] as string;
      if (formatType === 'stickerFormatTgs' || formatType === 'stickerFormatWebm') {
        isAnimated = true;
      }
    }

    // Also check the type field which some TDLib versions use
    const typeField = raw['type'] as Record<string, Object>;
    if (typeField) {
      const typeStr = typeField['@type'] as string;
      if (typeStr === 'stickerTypeAnimated' || typeStr === 'stickerTypeVideo') {
        isAnimated = true;
      }
    }

    return {
      id: stickerId,
      emoji: emoji,
      fileId: fileId,
      localPath: localPath,
      isAnimated: isAnimated
    } as TelegramSticker;
  }

  private parseStickerSetInfoObject(raw: Record<string, Object>): StickerSetInfo {
    const id = String(raw['id'] || '0');
    const title = (raw['title'] as string) || '';
    const name = (raw['name'] as string) || '';
    const stickerCount = (raw['size'] as number) || 0;

    // Extract thumbnail emoji from covers or first sticker
    let thumbnailEmoji = '';
    const covers = raw['covers'] as Record<string, Object>[];
    if (covers && covers.length > 0) {
      thumbnailEmoji = (covers[0]['emoji'] as string) || '';
    }
    if (thumbnailEmoji.length === 0) {
      // Use first character of title as fallback
      thumbnailEmoji = title.length > 0 ? title.charAt(0) : '';
    }

    return {
      id: id,
      title: title,
      name: name,
      thumbnailEmoji: thumbnailEmoji,
      count: stickerCount,
      isLoaded: false,
      stickers: []
    } as StickerSetInfo;
  }

  private downloadStickerFile(sticker: TelegramSticker): void {
    FileController.getInstance().requestFile(sticker.fileId, 5, (path: string) => {
      // Update local path for this sticker across all sets and recent
      this.updateStickerPath(sticker.fileId, path);
    });
  }

  private updateStickerPath(fileId: number, path: string): void {
    // Update recent stickers
    let updatedRecent = false;
    const newRecent = this.recentStickers.map((s: TelegramSticker): TelegramSticker => {
      if (s.fileId === fileId) {
        updatedRecent = true;
        return {
          id: s.id,
          emoji: s.emoji,
          fileId: s.fileId,
          localPath: path,
          isAnimated: s.isAnimated
        } as TelegramSticker;
      }
      return s;
    });
    if (updatedRecent) {
      this.recentStickers = newRecent;
    }

    // Update installed sets
    let updatedSets = false;
    const newSets = this.installedSets.map((set: StickerSetInfo): StickerSetInfo => {
      let setChanged = false;
      const newStickers = set.stickers.map((s: TelegramSticker): TelegramSticker => {
        if (s.fileId === fileId) {
          setChanged = true;
          return {
            id: s.id,
            emoji: s.emoji,
            fileId: s.fileId,
            localPath: path,
            isAnimated: s.isAnimated
          } as TelegramSticker;
        }
        return s;
      });
      if (setChanged) {
        updatedSets = true;
        return {
          id: set.id,
          title: set.title,
          name: set.name,
          thumbnailEmoji: set.thumbnailEmoji,
          count: set.count,
          isLoaded: set.isLoaded,
          stickers: newStickers
        } as StickerSetInfo;
      }
      return set;
    });
    if (updatedSets) {
      this.installedSets = newSets;
    }
  }

  // --- Computed tab data ---

  private getTabCount(): number {
    // Recent + installed sets + "+" button
    return 1 + this.installedSets.length + 1;
  }

  private getTabId(index: number): string {
    if (index === 0) {
      return TAB_RECENT;
    }
    const lastIndex = this.getTabCount() - 1;
    if (index === lastIndex) {
      return TAB_TRENDING;
    }
    const setIndex = index - 1;
    if (setIndex >= 0 && setIndex < this.installedSets.length) {
      return this.installedSets[setIndex].id;
    }
    return '';
  }

  private getCurrentStickers(): TelegramSticker[] {
    if (this.showTrending) {
      return [];
    }
    const tabId = this.getTabId(this.activeTabIndex);
    if (tabId === TAB_RECENT) {
      return this.recentStickers;
    }
    if (tabId === TAB_TRENDING) {
      return [];
    }
    // Installed set
    const setIndex = this.activeTabIndex - 1;
    if (setIndex >= 0 && setIndex < this.installedSets.length) {
      return this.installedSets[setIndex].stickers;
    }
    return [];
  }

  private getFilteredStickers(): TelegramSticker[] {
    const stickers = this.getCurrentStickers();
    if (this.searchText.length === 0) {
      return stickers;
    }
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
          .borderRadius(18)
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
          // Recent tab
          this.PackTab('\u{1F551}', $r('app.string.sticker_packs_recent'), 0)

          // Installed set tabs
          ForEach(this.installedSets, (set: StickerSetInfo, index: number) => {
            this.PackTab(
              set.thumbnailEmoji.length > 0 ? set.thumbnailEmoji : set.title.charAt(0),
              set.title,
              index + 1
            )
          }, (set: StickerSetInfo) => set.id)

          // "+" Add stickers tab
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
            this.loadTrendingSets();
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
        // Trending sticker sets view
        this.TrendingContent()
      } else if (this.showRemoveDialog && this.longPressSetIndex >= 0) {
        // Remove dialog overlay
        this.RemoveConfirmation()
      } else {
        // Sticker grid
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
      // Load stickers for the selected set if not yet loaded
      if (tabIndex > 0) {
        const setIndex = tabIndex - 1;
        this.loadStickerSetStickers(setIndex);
      }
    })
    .gesture(
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction(() => {
          // Long press on installed set tab -> offer removal
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
                .onError(() => {
                  // Fallback handled by alt text
                })
                .accessibilityText(sticker.emoji)
            } else {
              // Fallback: show emoji while file downloads
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
              // Set icon / emoji
              Text(set.thumbnailEmoji)
                .fontSize(28)
                .width(44)
                .height(44)
                .textAlign(TextAlign.Center)
                .accessibilityText(set.title)

              // Set info
              Column() {
                Text(set.title)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(getContext(this).resourceManager.getStringByNameSync('sticker_pack_count_format').replace('%s', set.count.toString()))
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 2 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .padding({ left: 12 })

              // Install button
              Button($r('app.string.sticker_pack_install'))
                .fontSize(14)
                .fontColor($r('app.color.icon_on_primary'))
                .backgroundColor($r('app.color.telegram_blue'))
                .borderRadius(16)
                .height(32)
                .padding({ left: 16, right: 16 })
                .onClick(() => {
                  this.installStickerSet(set.id);
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
            .fontSize(13)
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
                this.removeStickerSet(setId);
              })
              .accessibilityText(getContext(this).resourceManager.getStringSync($r('app.string.sticker_pack_remove')))
          }
          .width('100%')
        }
        .padding(20)
        .borderRadius(16)
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
