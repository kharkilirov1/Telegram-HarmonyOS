import { User } from '../../../models/User';

@ComponentV2
export struct SearchContactRow {
  @Param user: User = new User();
  @Event onOpen: (userId: number) => void = (_userId: number) => {};

  build() {
    Row() {
      Text(this.user.firstName.length > 0 ? this.user.firstName.charAt(0) : '?')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor($r('app.color.sender_color_5'))
        .textAlign(TextAlign.Center)
        .margin({ right: 12 })

      Column() {
        Row() {
          Text(`${this.user.firstName} ${this.user.lastName}`.trim())
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.user.isOnline) {
            Circle()
              .width(8)
              .height(8)
              .fill($r('app.color.online_indicator'))
              .margin({ left: 6 })
          }
        }
        .width('100%')

        if (this.user.username.length > 0) {
          Text(`@${this.user.username}`)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        } else if (this.user.phoneNumber.length > 0) {
          Text(`+${this.user.phoneNumber}`)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(60)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.onOpen(this.user.id);
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
