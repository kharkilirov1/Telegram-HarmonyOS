import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { StorageKeys } from '../../../app/bridge/AppStoreBridge';

@Component
export struct TgCountryBottomSearchOverlay {
  @Prop query: string = '';
  @Prop bottomInset: number = 0;
  @Prop placeholder: string = 'Search';
  onQueryChange: (value: string) => void = (_value: string): void => {};
  @StorageLink(StorageKeys.GLASS_MODE) glassMode: string = TgGlassPolicy.MODE_AUTO;

  private useRealtimeBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  build() {
    Column() {
      Search({ placeholder: this.placeholder, value: this.query })
        .width('100%')
        .height(TgUiTokens.COUNTRY_SEARCH_CAPSULE_HEIGHT)
        .backgroundBlurStyle(TgGlassPolicy.searchBlurStyle())
        .backgroundColor(this.useRealtimeBlur() ? Color.Transparent : TgUiTokens.COUNTRY_SEARCH_CAPSULE_FALLBACK_BG)
        .margin({
          left: TgUiTokens.COUNTRY_SEARCH_SIDE_INSET,
          right: TgUiTokens.COUNTRY_SEARCH_SIDE_INSET,
          top: TgUiTokens.COUNTRY_SEARCH_VERTICAL_INSET,
          bottom: TgUiTokens.COUNTRY_SEARCH_VERTICAL_INSET
        })
        .onChange((value: string) => {
          this.onQueryChange(value);
        })

      Row()
        .width('100%')
        .height(this.bottomInset > 0 ? this.bottomInset : TgUiTokens.SPACE_8)
        .backdropBlur(TgGlassPolicy.edgeBlurRadius(TgUiTokens.COUNTRY_SEARCH_EDGE_BLUR_RADIUS))
    }
    .width('100%')
  }
}
