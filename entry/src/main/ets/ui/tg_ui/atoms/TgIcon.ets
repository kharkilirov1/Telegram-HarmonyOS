import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgIcon {
  @Param src: Resource = TgUiTokens.ICON_RES_CHAT;
  @Param iconSize: number = TgUiTokens.ICON_SIZE_LG;
  @Param tintColor: ResourceColor = TgUiTokens.COLOR_ICON_SECONDARY;
  @Param isEnabled: boolean = true;
  @Param iconOpacity: number = 1;
  @Param supportSvg2: boolean = true;
  @Param a11yDescription: ResourceStr = '';

  build() {
    if (this.supportSvg2) {
      Image(this.src)
        .width(this.iconSize)
        .height(this.iconSize)
        .objectFit(ImageFit.Contain)
        .fillColor(this.tintColor)
        .opacity(this.isEnabled ? this.iconOpacity : TgUiTokens.ICON_DISABLED_OPACITY)
        .accessibilityGroup(this.a11yDescription !== '')
        .accessibilityDescription(this.a11yDescription !== '' ? this.a11yDescription : undefined)
    } else {
      Image(this.src)
        .width(this.iconSize)
        .height(this.iconSize)
        .objectFit(ImageFit.Contain)
        .opacity(this.isEnabled ? this.iconOpacity : TgUiTokens.ICON_DISABLED_OPACITY)
        .accessibilityGroup(this.a11yDescription !== '')
        .accessibilityDescription(this.a11yDescription !== '' ? this.a11yDescription : undefined)
    }
  }
}
