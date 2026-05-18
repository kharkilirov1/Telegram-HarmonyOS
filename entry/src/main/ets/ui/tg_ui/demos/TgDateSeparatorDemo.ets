import { TgDateSeparator, TgUnreadMarker } from '../atoms/TgDateSeparator';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgDateSeparator' })
@ComponentV2
export struct TgDateSeparatorDemo {
  private longDateText: string = 'Wednesday, February 25, 2026';
  private unreadLongText: string = 'Unread messages above this line with long localized marker text';

  @Builder
  private separatorCase(label: string, text: string, containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      Row() {
        TgDateSeparator({
          text: text,
          containerWidth: containerWidth
        })
        .width(containerWidth)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_16,
      right: TgUiTokens.SPACE_16,
      top: TgUiTokens.SPACE_6,
      bottom: TgUiTokens.SPACE_6
    })
  }

  @Builder
  private unreadCase(label: string, text: string, containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      Row() {
        TgUnreadMarker({
          text: text,
          containerWidth: containerWidth
        })
        .width(containerWidth)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_16,
      right: TgUiTokens.SPACE_16,
      top: TgUiTokens.SPACE_6,
      bottom: TgUiTokens.SPACE_6
    })
  }

  build() {
    Scroll() {
      Column() {
        Text('TgDateSeparator + TgUnreadMarker Demo')
          .fontSize(TgUiTokens.FONT_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            top: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        Text('Phase C / Step 4: date capsule separator and unread marker bar')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.separatorCase('01 date: Today', 'Today')
        this.separatorCase('02 date: Yesterday', 'Yesterday')
        this.separatorCase('03 date: explicit short', '25 Feb')
        this.separatorCase('04 date: explicit long', this.longDateText)
        this.separatorCase('05 date: narrow container', this.longDateText, TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH)
        this.separatorCase('06 date: wide container', this.longDateText, TgUiTokens.MSG_DEMO_WIDE_CONTAINER_WIDTH)

        this.unreadCase('07 unread: default', 'Unread messages')
        this.unreadCase('08 unread: long text', this.unreadLongText)
        this.unreadCase('09 unread: narrow container', this.unreadLongText, TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH)
        this.unreadCase('10 unread: wide container', this.unreadLongText, TgUiTokens.MSG_DEMO_WIDE_CONTAINER_WIDTH)

        Text('11 sequence probe: date → unread → date')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            top: TgUiTokens.SPACE_8,
            bottom: TgUiTokens.SPACE_6
          })

        TgDateSeparator({ text: 'Today', containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH })
          .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
        TgUnreadMarker({ text: 'Unread messages', containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH })
          .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_8, bottom: TgUiTokens.SPACE_8 })
        TgDateSeparator({ text: 'Yesterday', containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH })
          .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, bottom: TgUiTokens.SPACE_16 })
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}
