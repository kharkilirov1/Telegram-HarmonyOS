// GIF picker panel with trending and search
// Reference: Telegram iOS GifPanelController, Android GifAdapter

import { TDLibClient } from '../../services/TDLibClient';
import { FileController } from '../../controllers/FileController';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface GifItem {
  id: number;
  previewPath: string;
  title: string;
  aspectRatio: number;
}

@ComponentV2
export struct GifPicker {
  @Event onGifSelected: (gifId: number) => void = () => {};
  @Local searchText: string = '';
  @Local gifs: GifItem[] = [];
  @Local isLoading: boolean = false;

  aboutToAppear(): void {
    this.loadSavedGifs();
  }

  private visibleGifs(): GifItem[] {
    const q = this.searchText.trim().toLowerCase();
    if (q.length === 0) {
      return this.gifs;
    }
    return this.gifs.filter((gif: GifItem) => gif.title.toLowerCase().includes(q));
  }

  private async loadSavedGifs(): Promise<void> {
    this.isLoading = true;
    this.gifs = [];
    try {
      const params: Record<string, Object> = {};
      params['limit'] = 100;
      const result = await TDLibClient.getInstance().send('getSavedAnimations', params);
      const rawAnimations = result['animations'] as Record<string, Object>[] | undefined;
      if (!rawAnimations || rawAnimations.length === 0) {
        this.isLoading = false;
        return;
      }

      const seen: Set<number> = new Set<number>();
      const loaded: GifItem[] = [];
      for (const animation of rawAnimations) {
        const fileRecord = animation['animation'] as Record<string, Object> | undefined;
        const fileId = fileRecord ? ((fileRecord['id'] as number) || 0) : 0;
        if (fileId <= 0 || seen.has(fileId)) {
          continue;
        }
        seen.add(fileId);

        const local = fileRecord ? (fileRecord['local'] as Record<string, Object> | undefined) : undefined;
        const localPath = local && ((local['is_downloading_completed'] as boolean) || false)
          ? ((local['path'] as string) || '')
          : '';
        const width = (animation['width'] as number) || 0;
        const height = (animation['height'] as number) || 0;
        const ratio = (width > 0 && height > 0) ? (width / height) : 1.0;
        const clampedRatio = Math.min(1.6, Math.max(0.7, ratio));
        const title = (animation['emoji'] as string) || `GIF ${fileId}`;

        loaded.push({
          id: fileId,
          previewPath: localPath,
          title: title,
          aspectRatio: clampedRatio
        });

        // Trigger download for GIFs not yet cached
        if (localPath.length === 0 && fileId > 0) {
          const gifIndex = loaded.length - 1;
          FileController.getInstance().requestFile(fileId, 3, (path: string) => {
            if (path.length > 0 && gifIndex < this.gifs.length && this.gifs[gifIndex].id === fileId) {
              const updated = this.gifs.slice();
              updated[gifIndex].previewPath = path;
              this.gifs = updated;
            }
          });
        }
      }
      this.gifs = loaded;
    } catch (e) {
      hilog.warn(0x0001, 'GifPicker', 'Failed to load saved GIFs');
      this.gifs = [];
    }
    this.isLoading = false;
  }

  build() {
    Column() {
      // Search bar
      Row() {
        Search({ placeholder: $r('app.string.search_gifs'), value: this.searchText })
          .layoutWeight(1)
          .height(32)
          .onChange((value: string) => {
            this.searchText = value;
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor($r('app.color.background_primary'))

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(28)
            .height(28)
            .color($r('app.color.telegram_blue'))
        }
        .width('100%')
        .height(180)
        .justifyContent(FlexAlign.Center)
      } else if (this.visibleGifs().length === 0) {
        Column() {
          Text($r('app.string.search_no_results'))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .height(180)
        .justifyContent(FlexAlign.Center)
      } else {
        // GIF grid from real TDLib saved animations
        Grid() {
          ForEach(this.visibleGifs(), (gif: GifItem) => {
            GridItem() {
              Stack({ alignContent: Alignment.BottomStart }) {
                if (gif.previewPath.length > 0) {
                  Image(gif.previewPath)
                    .width('100%')
                    .height(80 + (gif.aspectRatio - 1.0) * 40)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(8)
                    .onError(() => {})
                } else {
                  Column()
                    .width('100%')
                    .height(80 + (gif.aspectRatio - 1.0) * 40)
                    .backgroundColor($r('app.color.placeholder_bg'))
                    .borderRadius(8)
                }

                Text($r('app.string.gif'))
                  .fontSize(10)
                  .fontColor(Color.White)
                  .backgroundColor($r('app.color.time_overlay'))
                  .borderRadius(3)
                  .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                  .margin({ left: 4, bottom: 4 })
              }
              .onClick(() => {
                this.onGifSelected(gif.id);
              })
            }
          }, (gif: GifItem) => gif.id.toString())
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(4)
        .rowsGap(4)
        .width('100%')
        .height(180)
        .padding(4)
        .backgroundColor($r('app.color.background_primary'))
      }
    }
    .width('100%')
  }
}
