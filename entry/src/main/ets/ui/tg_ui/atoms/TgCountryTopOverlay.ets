import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { StorageKeys } from '../../../app/bridge/AppStoreBridge';

@Component
export struct TgCountryTopOverlay {
  @Prop topInset: number = 0;
  onBackPress: () => void = (): void => {};
  @StorageLink(StorageKeys.GLASS_MODE) glassMode: string = TgGlassPolicy.MODE_AUTO;

  private useRealtimeBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  build() {
    Column() {
      Row()
        .height(this.topInset)
        .width('100%')

      Row() {
        Button({ type: ButtonType.Circle }) {
          Image(TgUiTokens.ICON_RES_BACK)
            .width(TgUiTokens.COUNTRY_TOP_OVERLAY_BACK_ICON_SIZE)
            .height(TgUiTokens.COUNTRY_TOP_OVERLAY_BACK_ICON_SIZE)
            .fillColor(TgUiTokens.COLOR_ICON_PRIMARY)
        }
        .width(TgUiTokens.COUNTRY_TOP_OVERLAY_BACK_SIZE)
        .height(TgUiTokens.COUNTRY_TOP_OVERLAY_BACK_SIZE)
        .backgroundColor(TgUiTokens.COUNTRY_TOP_OVERLAY_BACK_BG)
        .onClick(() => {
          this.onBackPress();
        })
      }
      .width('100%')
      .height(TgUiTokens.COUNTRY_TOP_OVERLAY_BAR_HEIGHT)
      .alignItems(VerticalAlign.Center)
      .padding({ left: TgUiTokens.COUNTRY_TOP_OVERLAY_SIDE_INSET })
    }
    .width('100%')
    .backgroundColor(this.useRealtimeBlur() ? Color.Transparent : TgUiTokens.COUNTRY_TOP_OVERLAY_FALLBACK_BG)
    .backgroundBlurStyle(TgGlassPolicy.topBarBlurStyle())
  }
}
