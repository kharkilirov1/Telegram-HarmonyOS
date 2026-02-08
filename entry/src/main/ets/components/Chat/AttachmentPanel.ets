// Attachment panel — bottom sheet with action options (reference: Telegram Android ChatAttachAlert)

interface AttachOption {
  icon: Resource;
  label: Resource;
  color: ResourceColor;
}

@ComponentV2
export struct AttachmentPanel {
  @Param onCamera: () => void = () => {};
  @Param onGallery: () => void = () => {};
  @Param onFile: () => void = () => {};
  @Param onLocation: () => void = () => {};
  @Param onContact: () => void = () => {};
  @Param onPoll: () => void = () => {};
  @Param onClose: () => void = () => {};

  build() {
    Column() {
      // Handle bar (like iOS/Android bottom sheet)
      Row() {
        Column()
          .width(36)
          .height(4)
          .borderRadius(2)
          .backgroundColor($r('app.color.text_secondary'))
          .opacity(0.4)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 8, bottom: 12 })

      // Action grid — 2 rows x 3 columns (like Telegram Android)
      Grid() {
        GridItem() { this.attachItem($r('app.media.ic_camera'), $r('app.string.attach_camera'), '#FF6B35') }
          .onClick(() => { this.onCamera(); })
        GridItem() { this.attachItem($r('app.media.ic_photo'), $r('app.string.attach_gallery'), '#A855F7') }
          .onClick(() => { this.onGallery(); })
        GridItem() { this.attachItem($r('app.media.ic_document'), $r('app.string.attach_file'), '#3B82F6') }
          .onClick(() => { this.onFile(); })
        GridItem() { this.attachItem($r('app.media.ic_location'), $r('app.string.attach_location'), '#22C55E') }
          .onClick(() => { this.onLocation(); })
        GridItem() { this.attachItem($r('app.media.ic_contact'), $r('app.string.attach_contact'), '#0088CC') }
          .onClick(() => { this.onContact(); })
        GridItem() { this.attachItem($r('app.media.ic_more'), $r('app.string.attach_poll'), '#F59E0B') }
          .onClick(() => { this.onPoll(); })
      }
      .columnsTemplate('1fr 1fr 1fr')
      .rowsTemplate('1fr 1fr')
      .rowsGap(16)
      .columnsGap(0)
      .width('100%')
      .height(180)
      .padding({ left: 16, right: 16 })

      // Cancel button
      Button($r('app.string.cancel'))
        .width('90%')
        .height(44)
        .fontSize(17)
        .fontColor($r('app.color.telegram_blue'))
        .backgroundColor($r('app.color.background_secondary'))
        .borderRadius(12)
        .margin({ top: 12, bottom: 16 })
        .onClick(() => this.onClose())
    }
    .width('100%')
    .backgroundColor($r('app.color.background_primary'))
    .borderRadius({ topLeft: 16, topRight: 16 })
    .shadow({ radius: 12, color: $r('app.color.shadow_color'), offsetY: -4 })
  }

  @Builder
  attachItem(icon: Resource, label: Resource, bgColor: string) {
    Column() {
      Column() {
        Image(icon)
          .width(28)
          .height(28)
          .fillColor(Color.White)
      }
      .width(56)
      .height(56)
      .borderRadius(28)
      .backgroundColor(bgColor)
      .justifyContent(FlexAlign.Center)

      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 6 })
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
