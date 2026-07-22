// TgIslandPlayerCard — full music player card shown as a native sheet when
// the island player body is tapped with audio playing (v3 of the island
// player suite). Voice keeps the jump-to-message tap; this card is audio-only.
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgIcon } from '../atoms/TgIcon';

function formatTrackTime(ms: number): string {
  const totalSec = Math.max(0, Math.floor(ms / 1000));
  const minutes = Math.floor(totalSec / 60);
  const seconds = totalSec % 60;
  return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
}

@ComponentV2
export struct TgIslandPlayerCard {
  @Param title: string = '';
  @Param subtitle: string = '';
  @Param coverPath: string = '';
  @Param isPlaying: boolean = false;
  @Param progress: number = 0;
  @Param durationMs: number = 0;
  @Param speed: number = 1;

  @Event onTogglePlay: () => void = (): void => {};
  @Event onNext: () => void = (): void => {};
  @Event onPrev: () => void = (): void => {};
  @Event onSeek: (progress: number) => void = (): void => {};
  @Event onCycleSpeed: () => void = (): void => {};

  // While the user drags the slider we render the drag value, not playback.
  @Local private dragProgress: number = -1;

  private shownProgress(): number {
    return this.dragProgress >= 0 ? this.dragProgress : Math.max(0, Math.min(1, this.progress));
  }

  private speedLabel(): string {
    if (this.speed >= 1.99) {
      return '2x';
    }
    return this.speed >= 1.49 ? '1.5x' : '1x';
  }

  @Builder
  private buildControl(icon: Resource, size: number, action: () => void) {
    Stack({ alignContent: Alignment.Center }) {
      TgIcon({
        src: icon,
        iconSize: size,
        tintColor: TgUiTokens.COLOR_TEXT_TITLE
      })
    }
    .width(64)
    .height(64)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
    .onClick(() => action())
  }

  build() {
    Column() {
      // Cover / placeholder
      Stack({ alignContent: Alignment.Center }) {
        if (this.coverPath.length > 0) {
          Image('file://' + this.coverPath)
            .width(220)
            .height(220)
            .borderRadius(16)
            .objectFit(ImageFit.Cover)
        } else {
          Stack({ alignContent: Alignment.Center }) {
            TgIcon({
              src: TgUiTokens.ICON_RES_PLAY,
              iconSize: 72,
              tintColor: TgUiTokens.TAB_ITEM_UNSELECTED
            })
          }
          .width(220)
          .height(220)
          .borderRadius(16)
          .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
        }
      }
      .margin({ top: 20, bottom: 20 })

      Text(this.title.length > 0 ? this.title : ' ')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.subtitle.length > 0) {
        Text(this.subtitle)
          .fontSize(15)
          .fontColor(TgUiTokens.TAB_ITEM_UNSELECTED)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
      }

      Slider({ value: this.shownProgress() * 100, min: 0, max: 100, style: SliderStyle.OutSet })
        .selectedColor(TgUiTokens.COMPOSER_ACTION_ACTIVE)
        .width('88%')
        .margin({ top: 18 })
        .onChange((value: number, mode: SliderChangeMode) => {
          if (mode === SliderChangeMode.End) {
            this.dragProgress = -1;
            this.onSeek(value / 100);
            return;
          }
          this.dragProgress = value / 100;
        })

      Row() {
        Text(formatTrackTime(this.shownProgress() * this.durationMs))
          .fontSize(12)
          .fontColor(TgUiTokens.TAB_ITEM_UNSELECTED)
        Blank()
        Text(formatTrackTime(this.durationMs))
          .fontSize(12)
          .fontColor(TgUiTokens.TAB_ITEM_UNSELECTED)
      }
      .width('88%')

      Row({ space: 22 }) {
        Text(this.speedLabel())
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .width(64)
          .height(64)
          .textAlign(TextAlign.Center)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .onClick(() => this.onCycleSpeed())
        this.buildControl(TgUiTokens.ICON_RES_SKIP_PREVIOUS, 34, (): void => this.onPrev())
        this.buildControl(this.isPlaying ? TgUiTokens.ICON_RES_PAUSE : TgUiTokens.ICON_RES_PLAY,
          40, (): void => this.onTogglePlay())
        this.buildControl(TgUiTokens.ICON_RES_SKIP_NEXT, 34, (): void => this.onNext())
        // Symmetry spacer opposite the speed button
        Row().width(64).height(64)
      }
      .margin({ top: 10 })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
