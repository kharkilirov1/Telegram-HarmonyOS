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
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param maxWidthRatio: number = TgUiTokens.BUBBLE_MAX_WIDTH_RATIO;
  @Param noBubbleWrap: boolean = false;
  @Event onTap: () => void = () => {};

  private normalizedProgress(): number {
    return Math.max(0, Math.min(1, this.playbackProgress));
  }

  private bubbleColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG;
  }

  private computedBubbleWidth(): number {
    return TgUiTokens.resolveVoiceBubbleWidth(this.containerWidth, this.maxWidthRatio, this.durationSec);
  }

  private durationColor(): ResourceColor {
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

  private waveColor(index: number): ResourceColor {
    const activeUntil = Math.floor(this.normalizedProgress() * TgUiTokens.VOICE_BUBBLE_WAVE_BARS_COUNT);
    if (index < activeUntil) {
      return this.isOutgoing ? TgUiTokens.VOICE_BUBBLE_WAVE_ACTIVE_OUTGOING : TgUiTokens.VOICE_BUBBLE_WAVE_ACTIVE;
    }
    return TgUiTokens.VOICE_BUBBLE_WAVE_INACTIVE;
  }

  @Builder
  private buildWaveform() {
    Row({ space: TgUiTokens.VOICE_BUBBLE_WAVE_BAR_GAP }) {
      ForEach(this.waveformBars(), (height: number, index: number) => {
        Row()
          .width(TgUiTokens.VOICE_BUBBLE_WAVE_BAR_WIDTH)
          .height(height)
          .borderRadius(TgUiTokens.RADIUS_ROUND_MAX)
          .backgroundColor(this.waveColor(index))
      }, (height: number, index: number): string => 'voice_bar_' + index.toString() + '_' + height.toString())
    }
    .height(TgUiTokens.VOICE_BUBBLE_WAVE_AREA_HEIGHT)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildInnerContent() {
    Row({ space: TgUiTokens.VOICE_BUBBLE_CONTENT_GAP }) {
      Row() {
        TgIcon({
          src: this.buttonIconResource(),
          iconSize: TgUiTokens.VOICE_BUBBLE_BUTTON_ICON_SIZE,
          tintColor: TgUiTokens.VOICE_BUBBLE_BUTTON_ICON
        })
      }
      .width(TgUiTokens.VOICE_BUBBLE_BUTTON_SIZE)
      .height(TgUiTokens.VOICE_BUBBLE_BUTTON_SIZE)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(TgUiTokens.VOICE_BUBBLE_BUTTON_BG)
      .borderRadius(TgUiTokens.RADIUS_ROUND_MAX)
      .onClick(() => {
        this.onTap();
      })

      Row() {
        this.buildWaveform()
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)
      .constraintSize({ minWidth: TgUiTokens.VOICE_BUBBLE_MIN_WAVEFORM_WIDTH })
      .onClick(() => {
        this.onTap();
      })

      Text(this.formatDuration())
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
