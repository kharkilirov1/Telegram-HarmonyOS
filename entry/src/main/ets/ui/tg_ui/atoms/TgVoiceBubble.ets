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
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param maxWidthRatio: number = TgUiTokens.BUBBLE_MAX_WIDTH_RATIO;

  private normalizedProgress(): number {
    return Math.max(0, Math.min(1, this.playbackProgress));
  }

  private computedBubbleWidth(): number {
    const byRatio = Math.floor(this.containerWidth * this.maxWidthRatio);
    const maxAllowed = Math.min(byRatio, TgUiTokens.VOICE_BUBBLE_MAX_WIDTH);
    const minAllowed = Math.min(TgUiTokens.VOICE_BUBBLE_MIN_WIDTH, Math.max(1, Math.floor(this.containerWidth)));
    return Math.max(minAllowed, maxAllowed);
  }

  private bubbleColor(): ResourceColor {
    return this.isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG;
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

  private playIconResource(): Resource {
    return this.isPlaying ? TgUiTokens.ICON_RES_PAUSE : TgUiTokens.ICON_RES_PLAY;
  }

  private waveformBars(): number[] {
    const bars: number[] = [];
    const count = TgUiTokens.VOICE_BUBBLE_WAVE_BARS_COUNT;
    const minH = TgUiTokens.VOICE_BUBBLE_WAVE_MIN_HEIGHT;
    const maxH = TgUiTokens.VOICE_BUBBLE_WAVE_MAX_HEIGHT;
    const range = Math.max(1, maxH - minH + 1);

    if (this.waveform.trim().length > 0) {
      const source = this.waveform;
      for (let i = 0; i < count; i++) {
        const charCode = source.charCodeAt(i % source.length);
        const height = minH + (charCode % range);
        bars.push(height);
      }
      return bars;
    }

    const fallbackPattern: number[] = [5, 7, 10, 8, 12, 9, 6, 11];
    for (let i = 0; i < count; i++) {
      bars.push(fallbackPattern[i % fallbackPattern.length]);
    }
    return bars;
  }

  private waveColor(index: number, total: number): ResourceColor {
    if (total <= 0) {
      return TgUiTokens.VOICE_BUBBLE_WAVE_INACTIVE;
    }
    const activeUntil = Math.floor(this.normalizedProgress() * total);
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
          .backgroundColor(this.waveColor(index, TgUiTokens.VOICE_BUBBLE_WAVE_BARS_COUNT))
      }, (height: number, index: number): string => 'voice_bar_' + index.toString() + '_' + height.toString())
    }
    .height(TgUiTokens.VOICE_BUBBLE_WAVE_AREA_HEIGHT)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildBubble() {
    Row({ space: TgUiTokens.VOICE_BUBBLE_CONTENT_GAP }) {
      Row() {
        TgIcon({
          src: this.playIconResource(),
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

      Row() {
        this.buildWaveform()
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)

      Text(this.formatDuration())
        .fontSize(TgUiTokens.VOICE_BUBBLE_DURATION_SIZE)
        .lineHeight(TgUiTokens.VOICE_BUBBLE_DURATION_LINE_HEIGHT)
        .fontColor(this.durationColor())
        .maxLines(1)
    }
    .width(this.computedBubbleWidth())
    .padding({
      left: TgUiTokens.VOICE_BUBBLE_PADDING_H,
      right: TgUiTokens.VOICE_BUBBLE_PADDING_H,
      top: TgUiTokens.VOICE_BUBBLE_PADDING_V,
      bottom: TgUiTokens.VOICE_BUBBLE_PADDING_V
    })
    .backgroundColor(this.bubbleColor())
    .borderRadius(TgUiTokens.VOICE_BUBBLE_RADIUS)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Row() {
      this.buildBubble()
    }
    .width('100%')
    .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
  }
}

