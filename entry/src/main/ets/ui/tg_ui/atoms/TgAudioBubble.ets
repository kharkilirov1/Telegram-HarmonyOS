import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgIcon } from './TgIcon';

@ComponentV2
export struct TgAudioBubble {
  @Param title: string = '';
  @Param performer: string = '';
  @Param durationSec: number = 0;
  @Param fileSize: number = 0;
  @Param mimeType: string = '';
  @Param audioPath: string = '';
  @Param isDownloading: boolean = false;
  @Param downloadProgress: number = -1;
  @Param isOutgoing: boolean = false;
  @Param isPlaying: boolean = false;
  @Param playbackProgress: number = 0;
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param maxWidthRatio: number = TgUiTokens.BUBBLE_MAX_WIDTH_RATIO;
  @Param noBubbleWrap: boolean = false;
  @Event onTap: () => void = () => {};
  @Event onPlayToggle: () => void = () => {};
  @Event onSeek: (progress: number) => void = (_: number) => {};

  private bubbleColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG;
  }

  private titleColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.DOCUMENT_ROW_TITLE_OUTGOING : TgUiTokens.DOCUMENT_ROW_TITLE_INCOMING;
  }

  private metaColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.DOCUMENT_ROW_META_OUTGOING : TgUiTokens.DOCUMENT_ROW_META_INCOMING;
  }

  private computedBubbleWidth(): number {
    return TgUiTokens.resolveAudioBubbleWidth(this.containerWidth, this.maxWidthRatio);
  }

  private safeTitle(): string {
    const trimmed = this.title.trim();
    return trimmed.length > 0 ? trimmed : 'Audio';
  }

  private isDownloaded(): boolean {
    return this.audioPath.trim().length > 0;
  }

  private hasDownloadProgress(): boolean {
    return this.downloadProgress >= 0 && this.downloadProgress < 1;
  }

  private normalizedDownloadProgress(): number {
    return Math.max(0, Math.min(1, this.downloadProgress));
  }

  private normalizedPlaybackProgress(): number {
    return Math.max(0, Math.min(1, this.playbackProgress));
  }

  private progressPercentLabel(): string {
    const percent = Math.floor(this.normalizedDownloadProgress() * 100);
    return Math.max(1, Math.min(99, percent)).toString() + '%';
  }

  private formatDuration(): string {
    const seconds = Math.max(0, Math.floor(this.durationSec));
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const remainSeconds = seconds % 60;
    const mm = minutes < 10 ? '0' + minutes.toString() : minutes.toString();
    const ss = remainSeconds < 10 ? '0' + remainSeconds.toString() : remainSeconds.toString();
    if (hours > 0) {
      return hours.toString() + ':' + mm + ':' + ss;
    }
    return minutes.toString() + ':' + ss;
  }

  private formatFileSize(bytes: number): string {
    if (bytes <= 0) {
      return '';
    }
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;

    if (bytes >= gb) {
      return (bytes / gb).toFixed(1) + ' GB';
    }
    if (bytes >= mb) {
      return (bytes / mb).toFixed(1) + ' MB';
    }
    if (bytes >= kb) {
      return (bytes / kb).toFixed(1) + ' KB';
    }
    return bytes.toString() + ' B';
  }

  private secondaryLine(): string {
    const performer = this.performer.trim();
    if (performer.length > 0) {
      return performer;
    }
    const mime = this.mimeType.trim();
    if (mime.length > 0) {
      return mime;
    }
    return 'Audio';
  }

  private durationMetaLine(): string {
    if (this.hasDownloadProgress()) {
      const sizeLabel = this.formatFileSize(this.fileSize);
      if (sizeLabel.length > 0) {
        return this.progressPercentLabel() + ' • ' + sizeLabel;
      }
      return this.progressPercentLabel();
    }
    if (this.isDownloading) {
      const sizeLabel = this.formatFileSize(this.fileSize);
      return sizeLabel.length > 0 ? sizeLabel : '...';
    }

    const parts: string[] = [];
    if (this.durationSec > 0) {
      parts.push(this.formatDuration());
    }
    const sizeLabel = this.formatFileSize(this.fileSize);
    if (sizeLabel.length > 0) {
      parts.push(sizeLabel);
    }
    if (parts.length === 0) {
      return 'Audio';
    }
    return parts.join(' • ');
  }

  // ── Art tile: gradient bg + music note (or play/pause overlay) ──
  @Builder
  private buildArtTile() {
    Stack({ alignContent: Alignment.Center }) {
      // Gradient background
      Column()
        .width(TgUiTokens.AUDIO_BUBBLE_ART_SIZE)
        .height(TgUiTokens.AUDIO_BUBBLE_ART_SIZE)
        .borderRadius(TgUiTokens.AUDIO_BUBBLE_ART_RADIUS)
        .linearGradient({
          angle: 135,
          colors: [
            [TgUiTokens.AUDIO_BUBBLE_ART_GRADIENT_START, 0],
            [TgUiTokens.AUDIO_BUBBLE_ART_GRADIENT_END, 1]
          ]
        })

      if (this.hasDownloadProgress()) {
        // Ring progress over art tile during download
        Progress({
          value: this.normalizedDownloadProgress() * 100,
          total: 100,
          type: ProgressType.Ring
        })
          .width(TgUiTokens.AUDIO_BUBBLE_ART_SIZE - 6)
          .height(TgUiTokens.AUDIO_BUBBLE_ART_SIZE - 6)
          .color(Color.White)
          .style({ strokeWidth: TgUiTokens.AUDIO_BUBBLE_BUTTON_RING_STROKE })
      } else if (this.isDownloading) {
        // Spinner during indeterminate download
        LoadingProgress()
          .width(TgUiTokens.AUDIO_BUBBLE_BUTTON_ICON_SIZE)
          .height(TgUiTokens.AUDIO_BUBBLE_BUTTON_ICON_SIZE)
          .color(TgUiTokens.AUDIO_BUBBLE_ART_ICON)
      } else if (this.isDownloaded() && this.isPlaying) {
        // Pause icon when playing
        TgIcon({
          src: TgUiTokens.ICON_RES_PAUSE,
          iconSize: TgUiTokens.AUDIO_BUBBLE_BUTTON_ICON_SIZE,
          tintColor: TgUiTokens.AUDIO_BUBBLE_ART_ICON
        })
      } else if (this.isDownloaded()) {
        // Play icon when downloaded and not playing
        TgIcon({
          src: TgUiTokens.ICON_RES_PLAY,
          iconSize: TgUiTokens.AUDIO_BUBBLE_BUTTON_ICON_SIZE,
          tintColor: TgUiTokens.AUDIO_BUBBLE_ART_ICON
        })
      } else {
        // Download arrow when not downloaded (iOS idle state)
        TgIcon({
          src: TgUiTokens.ICON_RES_DOWNLOAD,
          iconSize: TgUiTokens.AUDIO_BUBBLE_BUTTON_ICON_SIZE,
          tintColor: TgUiTokens.AUDIO_BUBBLE_ART_ICON
        })
      }
    }
    .width(TgUiTokens.AUDIO_BUBBLE_ART_SIZE)
    .height(TgUiTokens.AUDIO_BUBBLE_ART_SIZE)
    .borderRadius(TgUiTokens.AUDIO_BUBBLE_ART_RADIUS)
    .clip(true)
    .onClick((event: ClickEvent) => {
      this.onPlayToggle();
    })
  }

  // ── Seek bar: playback progress (horizontal bar — always visible) ──
  @Builder
  private buildSeekBar() {
    Column() {
      Slider({
        value: this.normalizedPlaybackProgress() * 100,
        min: 0,
        max: 100,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .height(TgUiTokens.AUDIO_BUBBLE_SEEK_HEIGHT * 3) // slightly taller for touch area
        .trackThickness(TgUiTokens.AUDIO_BUBBLE_SEEK_HEIGHT)
        .blockColor(TgUiTokens.AUDIO_BUBBLE_SEEK_FILL)
        .selectedColor(TgUiTokens.AUDIO_BUBBLE_SEEK_FILL)
        .trackColor(TgUiTokens.AUDIO_BUBBLE_SEEK_BG)
        .onChange((value: number, mode: SliderChangeMode) => {
          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Moving) {
            this.onSeek(value / 100.0);
          }
        })
    }
    .width('100%')
    .onClick(() => {}) // isolate click
  }

  // ── Download progress bar (replaces seek bar during download) ──
  @Builder
  private buildDownloadProgressBar() {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width('100%')
        .height(TgUiTokens.AUDIO_BUBBLE_SEEK_HEIGHT)
        .backgroundColor(TgUiTokens.DOCUMENT_ROW_PROGRESS_BG)
        .borderRadius(TgUiTokens.AUDIO_BUBBLE_SEEK_RADIUS)

      Row()
        .width(Math.max(2, this.normalizedDownloadProgress() * 100).toString() + '%')
        .height(TgUiTokens.AUDIO_BUBBLE_SEEK_HEIGHT)
        .backgroundColor(TgUiTokens.DOCUMENT_ROW_PROGRESS_FILL)
        .borderRadius(TgUiTokens.AUDIO_BUBBLE_SEEK_RADIUS)
    }
    .width('100%')
    .height(TgUiTokens.AUDIO_BUBBLE_SEEK_HEIGHT)
  }

  @Builder
  private buildInnerContent() {
    Row({ space: TgUiTokens.AUDIO_BUBBLE_CONTENT_GAP }) {
      this.buildArtTile()

      Column({ space: TgUiTokens.SPACE_2 }) {
        // Title (track name)
        Text(this.safeTitle())
          .fontSize(TgUiTokens.AUDIO_BUBBLE_TITLE_SIZE)
          .lineHeight(TgUiTokens.AUDIO_BUBBLE_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.titleColor())
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        // Performer / secondary info
        Text(this.secondaryLine())
          .fontSize(TgUiTokens.AUDIO_BUBBLE_META_SIZE)
          .lineHeight(TgUiTokens.AUDIO_BUBBLE_META_LINE_HEIGHT)
          .fontColor(this.metaColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        // Seek bar or download progress bar
        Column() {
          if (this.hasDownloadProgress()) {
            this.buildDownloadProgressBar()
          } else {
            this.buildSeekBar()
          }
        }
        .width('100%')
        .margin({ top: TgUiTokens.AUDIO_BUBBLE_SEEK_TOP_GAP - TgUiTokens.SPACE_2 })

        // Duration / size / download meta
        Text(this.durationMetaLine())
          .fontSize(TgUiTokens.AUDIO_BUBBLE_BOTTOM_META_SIZE)
          .lineHeight(TgUiTokens.AUDIO_BUBBLE_BOTTOM_META_LINE_HEIGHT)
          .fontColor(this.metaColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        this.onTap();
      })
    }
    .width(this.computedBubbleWidth())
    .padding({
      left: TgUiTokens.AUDIO_BUBBLE_PADDING_H,
      right: TgUiTokens.AUDIO_BUBBLE_PADDING_H,
      top: TgUiTokens.AUDIO_BUBBLE_PADDING_V,
      bottom: TgUiTokens.AUDIO_BUBBLE_PADDING_V
    })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildBubble() {
    Column() {
      this.buildInnerContent()
    }
    .width(this.computedBubbleWidth())
    .backgroundColor(this.bubbleColor())
    .borderRadius(TgUiTokens.AUDIO_BUBBLE_RADIUS)
  }

  build() {
    if (this.noBubbleWrap) {
      this.buildInnerContent()
    } else {
      Row() {
        this.buildBubble()
      }
      .width('100%')
      .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
    }
  }
}
