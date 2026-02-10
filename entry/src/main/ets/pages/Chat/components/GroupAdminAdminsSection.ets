import { GroupAdminMember } from './GroupAdminModels';

@ComponentV2
export struct GroupAdminAdminsSection {
  @Param administrators: GroupAdminMember[] = [];
  @Event onOpenUser: (userId: number) => void = (_userId: number) => {};

  build() {
    Column() {
      Text($r('app.string.administrators_label'))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 8 })

      Column() {
        if (this.administrators.length === 0) {
          Text($r('app.string.no_administrators'))
            .fontSize(15)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding(20)
        } else {
          ForEach(this.administrators, (admin: GroupAdminMember, index: number) => {
            if (index > 0) {
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 68 })
            }
            this.adminRow(admin)
          }, (admin: GroupAdminMember) => admin.userId.toString())
        }
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(16)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private adminRow(admin: GroupAdminMember) {
    Row() {
      if (admin.photoUrl) {
        Image(admin.photoUrl)
          .alt($r('app.media.app_icon'))
          .autoResize(true)
          .onError(() => {})
          .width(40)
          .height(40)
          .borderRadius(20)
      } else {
        Text(admin.name.length > 0 ? admin.name.charAt(0) : '?')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('app.color.telegram_blue'))
          .textAlign(TextAlign.Center)
      }

      Column() {
        Text(admin.name)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)

        Text(admin.role)
          .fontSize(13)
          .fontColor($r('app.color.telegram_blue'))
          .margin({ top: 1 })
      }
      .margin({ left: 12 })
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.onOpenUser(admin.userId);
    })
  }
}
