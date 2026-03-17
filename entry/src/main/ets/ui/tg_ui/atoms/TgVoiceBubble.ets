import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgIcon } from './TgIcon';

@ComponentV2
export struct TgVoiceBubble {
  @Param durationSec: number = 0;
  @Param waveform: string = '';
  @Param isOutgoing: boolean = false;
  @Param isPlaying: boolean = false;
  @Param playbackProgress: number = 0;
  @Param isListened: boolean = false;
  @Param hasLocalFile: boolean = true;
  @Param isDownloading: boolean = false;
  @Param downloadProgress: number = -1;
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param maxWidthRatio: number = TgUiTokens.BUBBLE_MAX_WIDTH_RATIO;
  @Param groupingFlags: string = 'none'; // none, top, bottom, both
  @Param noBubbleWrap: boolean = false;
  @Event onTap: () => void = () => {};
  @Event onPlayToggle: () => void = () => {};
  @Event onSeek: (progress: number) => void = (_: number) => {};
  @Local private buttonScale: number = 1.0;

  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D();

  private normalizedProgress(): number {
    return Math.max(0, Math.min(1, this.playbackProgress));
  }

  private hasDownloadProgress(): boolean {
    return this.downloadProgress >= 0 && this.downloadProgress < 1;
  }

  private normalizedDownloadProgress(): number {
    return Math.max(0, Math.min(1, this.downloadProgress));
  }

  private bubbleColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG;
  }

  private computedBubbleWidth(): number {
    return TgUiTokens.resolveVoiceBubbleWidth(this.containerWidth, this.maxWidthRatio, this.durationSec);
  }

  private durationColor(): ResourceColor {
    if (!this.hasLocalFile || this.isDownloading) {
      return this.isOutgoing ? TgUiTokens.VOICE_BUBBLE_DURATION_OUTGOING : TgUiTokens.VOICE_BUBBLE_DURATION_INCOMING;
    }
    if (!this.isListened && !this.isOutgoing) {
      return TgUiTokens.COLOR_ICON_PRIMARY;
    }
    return this.isOutgoing ? TgUiTokens.VOICE_BUBBLE_DURATION_OUTGOING : TgUiTokens.VOICE_BUBBLE_DURATION_INCOMING;
  }

  private formatDuration(): string {
    const seconds = Math.max(0, Math.floor(this.durationSec));
    const minutes = Math.floor(seconds / 60);
    const remain = seconds % 60;
    const ss = remain < 10 ? '0' + remain.toString() : remain.toString();
    return minutes.toString() + ':' + ss;
  }

  private trailingLabel(): string {
    if (this.hasDownloadProgress()) {
      const percent = Math.floor(this.normalizedDownloadProgress() * 100);
      return Math.max(1, Math.min(99, percent)).toString() + '%';
    }
    if (this.isDownloading) {
      return '...';
    }
    return this.formatDuration();
  }

  private buttonIconResource(): Resource {
    if (!this.hasLocalFile) {
      return TgUiTokens.ICON_RES_DOWNLOAD;
    }
    return this.isPlaying ? TgUiTokens.ICON_RES_PAUSE : TgUiTokens.ICON_RES_PLAY;
  }

  private fallbackBars(): number[] {
    const fallbackPattern: number[] = [5, 7, 10, 8, 12, 9, 6, 11];
    const bars: number[] = [];
    for (let i = 0; i < TgUiTokens.VOICE_BUBBLE_WAVE_BARS_COUNT; i++) {
      bars.push(fallbackPattern[i % fallbackPattern.length]);
    }
    return bars;
  }

  private parseLegacyWaveform(): number[] {
    const parsed: number[] = [];
    const parts = this.waveform.split(',');
    for (const part of parts) {
      const value = Number(part.trim());
      if (!isNaN(value)) {
        parsed.push(Math.max(0, Math.min(31, Math.floor(value))));
      }
    }
    return parsed;
  }

  private decodeBase64Bytes(input: string): number[] {
    const cleaned = input.replace(/\s+/g, '');
    if (cleaned.length === 0) {
      return [];
    }
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    const bytes: number[] = [];
    let buffer = 0;
    let bitsCollected = 0;

    for (let i = 0; i < cleaned.length; i++) {
      const char = cleaned.charAt(i);
      if (char === '=') {
        break;
      }
      const index = alphabet.indexOf(char);
      if (index < 0) {
        return [];
      }
      buffer = (buffer << 6) | index;
      bitsCollected += 6;
      while (bitsCollected >= 8) {
        bitsCollected -= 8;
        bytes.push((buffer >> bitsCollected) & 0xFF);
      }
    }
    return bytes;
  }

  private unpackWaveformSamples(bytes: number[]): number[] {
    if (bytes.length === 0) {
      return [];
    }
    const samples: number[] = [];
    const numSamples = Math.floor(bytes.length * 8 / 5);
    for (let i = 0; i < numSamples; i++) {
      const bitOffset = i * 5;
      const byteOffset = Math.floor(bitOffset / 8);
      const localBitOffset = bitOffset % 8;
      let value = 0;
      for (let j = 0; j < 4; j++) {
        const sourceIndex = byteOffset + j;
        if (sourceIndex < bytes.length) {
          value |= bytes[sourceIndex] << (j * 8);
        }
      }
      samples.push((value >> localBitOffset) & 31);
    }
    return samples;
  }

  private rawWaveformSamples(): number[] {
    const trimmed = this.waveform.trim();
    if (trimmed.length === 0) {
      return [];
    }
    if (trimmed.indexOf(',') >= 0) {
      return this.parseLegacyWaveform();
    }
    const bytes = this.decodeBase64Bytes(trimmed);
    return this.unpackWaveformSamples(bytes);
  }

  private waveformBars(): number[] {
    const samples = this.rawWaveformSamples();
    if (samples.length === 0) {
      return this.fallbackBars();
    }

    const bars: number[] = [];
    const minHeight = TgUiTokens.VOICE_BUBBLE_WAVE_MIN_HEIGHT;
    const maxHeight = TgUiTokens.VOICE_BUBBLE_WAVE_MAX_HEIGHT;
    const heightRange = Math.max(1, maxHeight - minHeight);

    for (let i = 0; i < TgUiTokens.VOICE_BUBBLE_WAVE_BARS_COUNT; i++) {
      const start = Math.floor(i * samples.length / TgUiTokens.VOICE_BUBBLE_WAVE_BARS_COUNT);
      const end = Math.max(start + 1,
        Math.floor((i + 1) * samples.length / TgUiTokens.VOICE_BUBBLE_WAVE_BARS_COUNT));
      let peak = 0;
      for (let j = start; j < end && j < samples.length; j++) {
        if (samples[j] > peak) {
          peak = samples[j];
        }
      }
      bars.push(minHeight + Math.floor(peak * heightRange / 31));
    }
    return bars;
  }

  private inactiveColorHex(): string {
    return this.isOutgoing ? '#4DFFFFFF' : '#333390EC'; // Faded white / faded blue
  }
  
  private activeColorHex(): string {
    return this.isOutgoing ? '#FFFFFF' : '#3390EC';
  }

  @Builder
  private buildWaveform() {
    Canvas(this.canvasContext)
      .width('100%')
      .height(TgUiTokens.VOICE_BUBBLE_WAVE_AREA_HEIGHT)
      .onReady(() => {
        const context = this.canvasContext;
        const bars = this.waveformBars();
        if (bars.length === 0) return;

        // Dynamically calculate width instead of hardcoding
        const totalCanvasWidth = context.width;
        // Total parts = (bars.length * barWidth) + ((bars.length - 1) * gapWidth)
        // Let gapWidth = barWidth * 0.6 to keep aspect ratio
        const partsPerBar = 1.6; 
        const totalParts = (bars.length * partsPerBar) - 0.6;
        const barWidth = Math.max(1, totalCanvasWidth / totalParts);
        const barGap = barWidth * 0.6;

        const totalDrawWidth = bars.length * (barWidth + barGap);
        const activeWidth = totalDrawWidth * this.normalizedProgress();
        const areaHeight = TgUiTokens.VOICE_BUBBLE_WAVE_AREA_HEIGHT;

        context.clearRect(0, 0, totalCanvasWidth, areaHeight);

        const isReady = this.hasLocalFile && !this.isDownloading;

        // Draw Inactive
        context.fillStyle = this.inactiveColorHex();
        context.beginPath();
        for (let i = 0; i < bars.length; i++) {
          const h = bars[i];
          const x = i * (barWidth + barGap);
          const y = (areaHeight - h) / 2;
          context.rect(x, y, barWidth, h);
        }
        context.fill();

        // Draw Active (clipped)
        if (isReady && activeWidth > 0) {
          context.save();
          context.beginPath();
          context.rect(0, 0, activeWidth, areaHeight);
          context.clip();

          context.fillStyle = this.activeColorHex();
          context.beginPath();
          for (let i = 0; i < bars.length; i++) {
            const h = bars[i];
            const x = i * (barWidth + barGap);
            const y = (areaHeight - h) / 2;
            context.rect(x, y, barWidth, h);
          }
          context.fill();
          context.restore();
        }
      })
  }
  @Builder
  private buildInnerContent() {
    Row({ space: TgUiTokens.VOICE_BUBBLE_CONTENT_GAP }) {
      Row() {
        if (this.isDownloading) {
          LoadingProgress()
            .width(TgUiTokens.VOICE_BUBBLE_BUTTON_ICON_SIZE)
            .height(TgUiTokens.VOICE_BUBBLE_BUTTON_ICON_SIZE)
            .color(TgUiTokens.VOICE_BUBBLE_BUTTON_ICON)
        } else {
          TgIcon({
            src: this.buttonIconResource(),
            iconSize: TgUiTokens.VOICE_BUBBLE_BUTTON_ICON_SIZE,
            tintColor: TgUiTokens.VOICE_BUBBLE_BUTTON_ICON
          })
        }
      }
      .width(TgUiTokens.VOICE_BUBBLE_BUTTON_SIZE)
      .height(TgUiTokens.VOICE_BUBBLE_BUTTON_SIZE)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(TgUiTokens.VOICE_BUBBLE_BUTTON_BG)
      .borderRadius(TgUiTokens.RADIUS_ROUND_MAX)
      .onClick((event: ClickEvent) => {
        this.onPlayToggle();
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.buttonScale = 0.9;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.buttonScale = 1.0;
        }
      })
      .scale({ x: this.buttonScale, y: this.buttonScale })
      .animation({ duration: 200, curve: Curve.EaseOut })

      Row() {
        this.buildWaveform()
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)
      .constraintSize({ minWidth: TgUiTokens.VOICE_BUBBLE_MIN_WAVEFORM_WIDTH })
      .onClick(() => {})
      .gesture(
        PanGesture({ direction: PanDirection.Horizontal })
          .onActionUpdate((event: GestureEvent) => {
            const width = Math.max(1, TgUiTokens.VOICE_BUBBLE_WAVE_BARS_COUNT * (TgUiTokens.VOICE_BUBBLE_WAVE_BAR_WIDTH + TgUiTokens.VOICE_BUBBLE_WAVE_BAR_GAP));
            const progress = Math.max(0, Math.min(1, event.offsetX / width));
            this.onSeek(progress);
          })
      )

      Text(this.trailingLabel())
        .fontSize(TgUiTokens.VOICE_BUBBLE_DURATION_SIZE)
        .lineHeight(TgUiTokens.VOICE_BUBBLE_DURATION_LINE_HEIGHT)
        .fontColor(this.durationColor())
        .fontWeight(FontWeight.Regular)
        .maxLines(1)
        .constraintSize({ minWidth: TgUiTokens.VOICE_BUBBLE_DURATION_MIN_WIDTH })
        .textAlign(TextAlign.End)
        .onClick(() => {
          this.onTap();
        })
    }
    .width(this.computedBubbleWidth())
    .padding({
      left: TgUiTokens.VOICE_BUBBLE_PADDING_H,
      right: TgUiTokens.VOICE_BUBBLE_PADDING_H,
      top: TgUiTokens.VOICE_BUBBLE_PADDING_V,
      bottom: TgUiTokens.VOICE_BUBBLE_PADDING_V
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
    .borderRadius(TgUiTokens.VOICE_BUBBLE_RADIUS)
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
