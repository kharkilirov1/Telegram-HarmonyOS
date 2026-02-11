import { Message } from '../../../models/Message';

@ComponentV2
export struct PinnedMessageBar {
  @Param pinnedMessage: Message | null = null;
  @Param showPinnedBar: boolean = true;
  @Event onClose: () => void = () => {};
  @Event onOpenPinnedMessage: () => void = () => {};

  build() {
    if (this.pinnedMessage !== null && this.showPinnedBar) {
      Row() {
        Divider()
          .vertical(true)
          .strokeWidth(2)
          .color($r('app.color.telegram_blue'))
          .height('100%')

        Column() {
          Text($r('app.string.pinned_message'))
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.telegram_blue'))
          Text(this.pinnedMessage.text)
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .margin({ left: 8 })
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Image($r('app.media.ic_close'))
          .width(16)
          .height(16)
          .fillColor($r('app.color.text_secondary'))
          .onClick(() => { this.onClose(); })
      }
      .width('100%')
      .height(36)
      .padding({ left: 12, right: 12 })
      .backgroundColor($r('app.color.glass_nav_bg'))
      .onClick(() => { this.onOpenPinnedMessage(); })
    }
  }
}
