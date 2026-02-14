// Attachment panel — bottom sheet with action options (reference: Telegram Android ChatAttachAlert)

interface AttachOption {
  icon: Resource;
  label: Resource;
  color: ResourceColor;
}

@ComponentV2
export struct AttachmentPanel {
  @Event onCamera: () => void = () => {};
  @Event onGallery: () => void = () => {};
  @Event onFile: () => void = () => {};
  @Event onLocation: () => void = () => {};
  @Event onContact: () => void = () => {};
  @Event onPoll: () => void = () => {};
  @Event onClose: () => void = () => {};

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
        GridItem() { this.attachItem($r('app.media.ic_camera'), $r('app.string.attach_camera'), $r('app.color.attach_camera_color')) }
          .onClick(() => { this.onCamera(); })
        GridItem() { this.attachItem($r('app.media.ic_photo'), $r('app.string.attach_gallery'), $r('app.color.attach_gallery_color')) }
          .onClick(() => { this.onGallery(); })
        GridItem() { this.attachItem($r('app.media.ic_document'), $r('app.string.attach_file'), $r('app.color.attach_file_color')) }
          .onClick(() => { this.onFile(); })
        GridItem() { this.attachItem($r('app.media.ic_location'), $r('app.string.attach_location'), $r('app.color.attach_location_color')) }
          .onClick(() => { this.onLocation(); })
        GridItem() { this.attachItem($r('app.media.ic_contact'), $r('app.string.attach_contact'), $r('app.color.telegram_blue')) }
          .onClick(() => { this.onContact(); })
        GridItem() { this.attachItem($r('app.media.ic_more'), $r('app.string.attach_poll'), $r('app.color.attach_poll_color')) }
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
        .fontSize(20)
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
  attachItem(icon: Resource, label: Resource, bgColor: ResourceColor) {
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
