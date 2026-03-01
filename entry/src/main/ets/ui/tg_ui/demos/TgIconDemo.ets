import { TgIcon } from '../atoms/TgIcon';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgIconDemo {
  @Builder
  private caseRow(label: string, icon: Resource, size: number, tint: ResourceColor, enabled: boolean = true, supportSvg2: boolean = true) {
    Row() {
      Text(label)
        .layoutWeight(1)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
      TgIcon({
        src: icon,
        iconSize: size,
        tintColor: tint,
        isEnabled: enabled,
        supportSvg2: supportSvg2
      })
    }
    .width('100%')
    .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_8, bottom: TgUiTokens.SPACE_8 })
  }

  build() {
    Column() {
      Text('TgIcon Demo')
        .fontSize(TgUiTokens.FONT_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .width('100%')
        .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_16, bottom: TgUiTokens.SPACE_8 })

      Text('SVG tint note: fillColor applies when SVG paths have fill != none.')
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .width('100%')
        .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, bottom: TgUiTokens.SPACE_8 })

      this.caseRow('01 Primary / chat', TgUiTokens.ICON_RES_CHAT, TgUiTokens.ICON_SIZE_LG, TgUiTokens.COLOR_ICON_PRIMARY)
      this.caseRow('02 Secondary / mute', TgUiTokens.ICON_RES_MUTE, TgUiTokens.ICON_SIZE_LG, TgUiTokens.COLOR_ICON_SECONDARY)
      this.caseRow('03 Accent / sent(single check)', TgUiTokens.ICON_RES_CHECK_SINGLE, TgUiTokens.ICON_SIZE_MD, TgUiTokens.COLOR_ICON_PRIMARY)
      this.caseRow('04 Accent / read(double check)', TgUiTokens.ICON_RES_CHECK_DOUBLE, TgUiTokens.ICON_SIZE_MD, TgUiTokens.COLOR_ICON_PRIMARY)
      this.caseRow('05 Meta / pending(clock)', TgUiTokens.ICON_RES_CLOCK, TgUiTokens.ICON_SIZE_MD, TgUiTokens.COLOR_TEXT_META)
      this.caseRow('06 Pin / inactive', TgUiTokens.ICON_RES_PIN, TgUiTokens.ICON_SIZE_MD, TgUiTokens.COLOR_ICON_SECONDARY)
      this.caseRow('07 Disabled / mute', TgUiTokens.ICON_RES_MUTE, TgUiTokens.ICON_SIZE_LG, TgUiTokens.COLOR_ICON_DISABLED, false)
      this.caseRow('08 No SVG2 tint fallback', TgUiTokens.ICON_RES_CHAT, TgUiTokens.ICON_SIZE_LG, TgUiTokens.COLOR_ICON_PRIMARY, true, false)

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}
