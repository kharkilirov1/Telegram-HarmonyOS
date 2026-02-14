import { GroupBannedMember } from './GroupAdminModels';

@ComponentV2
export struct GroupAdminBannedSection {
  @Param bannedUsers: GroupBannedMember[] = [];

  build() {
    Column() {
      Text($r('app.string.banned_users_label'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 8 })

      Column() {
        if (this.bannedUsers.length === 0) {
          Text($r('app.string.no_banned_users'))
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding(20)
        } else {
          ForEach(this.bannedUsers, (banned: GroupBannedMember, index: number) => {
            if (index > 0) {
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 68 })
            }
            this.bannedRow(banned)
          }, (banned: GroupBannedMember) => banned.userId.toString())
        }
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(24)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private bannedRow(banned: GroupBannedMember) {
    Row() {
      Text(banned.name.length > 0 ? banned.name.charAt(0) : '?')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor($r('app.color.error_red'))
        .textAlign(TextAlign.Center)

      Column() {
        Text(banned.name)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)

        Text(`Banned: ${banned.bannedUntil}`)
          .fontSize(14)
          .fontColor($r('app.color.error_red'))
          .margin({ top: 1 })
      }
      .margin({ left: 12 })
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
  }
}
