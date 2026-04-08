import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';

@ComponentV2
export struct TgTopChromeBackground {
  @Param topInset: number = 0;
  @Param contentHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;
  @Param showBottomSeparator: boolean = true;
  @Param showTopEdgeEmphasis: boolean = true;

  private useRealtimeBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  private totalHeight(): number {
    return this.topInset + this.contentHeight;
  }

  @Builder
  private buildTopEdgeEmphasis() {
    if (this.useRealtimeBlur() && this.showTopEdgeEmphasis) {
      Column()
        .width('100%')
        .height(Math.min(this.totalHeight(), TgUiTokens.TOP_CHROME_EDGE_HEIGHT))
        .linearGradient({
          angle: 180,
          colors: [
            [TgUiTokens.TOP_CHROME_EDGE_TOP, 0.0],
            [TgUiTokens.TOP_CHROME_EDGE_BOTTOM, 1.0]
          ]
        })
        .hitTestBehavior(HitTestMode.Transparent)
    }
  }

  @Builder
  private buildGlassSpecular() {
    if (this.useRealtimeBlur()) {
      Column()
        .width('100%')
        .height(this.totalHeight())
        .linearGradient({
          angle: 110,
          colors: [
            [TgUiTokens.GLASS_SPECULAR_TOP, 0.0],
            [TgUiTokens.GLASS_SPECULAR_MID, 0.38],
            [TgUiTokens.GLASS_SPECULAR_BOTTOM, 1.0]
          ]
        })
        .hitTestBehavior(HitTestMode.Transparent)
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height(this.totalHeight())
        .backgroundColor(this.useRealtimeBlur() ? TgUiTokens.TOP_BAR_GLASS_BG : TgUiTokens.TOP_BAR_GLASS_FALLBACK_BG)
        .backgroundBlurStyle(TgGlassPolicy.topBarBlurStyle(), TgGlassPolicy.glassOptions())
        .border({
          width: { bottom: this.showBottomSeparator ? TgUiTokens.TOP_BAR_SEPARATOR_STROKE : 0 },
          color: TgUiTokens.TOP_BAR_SEPARATOR
        })

      this.buildTopEdgeEmphasis()
      this.buildGlassSpecular()
    }
    .width('100%')
    .height(this.totalHeight())
  }
}
