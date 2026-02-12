import { GroupInfoMember } from './GroupInfoModels';

@ComponentV2
export struct GroupInfoMemberRow {
  @Param member: GroupInfoMember = new GroupInfoMember();
  @Event onOpenUser: (userId: number) => void = (_userId: number) => {};

  build() {
    Row() {
      Text(this.member.name.charAt(0))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor($r('app.color.telegram_blue'))
        .textAlign(TextAlign.Center)

      Column() {
        Row() {
          Text(this.member.name)
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)

          if (this.member.isAdmin) {
            Text($r('app.string.admin_label'))
              .fontSize(12)
              .fontColor($r('app.color.telegram_blue'))
          }
        }
        .width('100%')

        Text(this.member.status)
          .fontSize(12)
          .fontColor(this.member.status === 'online'
            ? $r('app.color.online_indicator')
            : $r('app.color.text_secondary'))
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
      this.onOpenUser(this.member.userId);
    })
    .hoverEffect(HoverEffect.Highlight)
    .opacity(1.0)
    .stateStyles({
      pressed: {
        .opacity(0.6)
      },
      normal: {
        .opacity(1.0)
      }
    })
  }
}
