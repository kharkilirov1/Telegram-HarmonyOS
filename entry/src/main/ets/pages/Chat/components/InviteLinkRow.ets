import { InviteLinkModel } from './InviteLinkModel';

@ComponentV2
export struct InviteLinkRow {
  @Param item: InviteLinkModel = new InviteLinkModel();
  @Param copiedLink: string = '';
  @Param expirationText: string = '';
  @Event onCopy: (link: string) => void = (_link: string) => {};
  @Event onRevoke: (link: string) => void = (_link: string) => {};

  build() {
    Column() {
      Row() {
        Column() {
          Row() {
            Text(this.item.link)
              .fontSize(15)
              .fontColor(this.item.isRevoked ? $r('app.color.text_secondary') : $r('app.color.telegram_blue'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
              .decoration(this.item.isRevoked
                ? { type: TextDecorationType.LineThrough, color: $r('app.color.text_secondary') }
                : { type: TextDecorationType.None })

            if (this.item.isPrimary) {
              Text($r('app.string.primary_badge'))
                .fontSize(12)
                .fontColor(Color.White)
                .backgroundColor($r('app.color.telegram_blue'))
                .borderRadius(14)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .margin({ left: 8 })
            }

            if (this.item.isRevoked) {
              Text($r('app.string.revoked_badge'))
                .fontSize(12)
                .fontColor(Color.White)
                .backgroundColor($r('app.color.error_red'))
                .borderRadius(14)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .margin({ left: 8 })
            }
          }
          .width('100%')

          Row({ space: 16 }) {
            Text(`${this.item.memberCount} joined`)
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))

            Text(this.expirationText)
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .margin({ top: 4 })
        }
        .layoutWeight(1)
      }
      .width('100%')

      if (!this.item.isRevoked) {
        Row({ space: 12 }) {
          Text(this.copiedLink === this.item.link ? $r('app.string.copied') : $r('app.string.copy'))
            .fontSize(14)
            .fontColor($r('app.color.telegram_blue'))
            .onClick(() => {
              this.onCopy(this.item.link);
            })

          if (!this.item.isPrimary) {
            Text($r('app.string.revoke'))
              .fontSize(14)
              .fontColor($r('app.color.error_red'))
              .onClick(() => {
                this.onRevoke(this.item.link);
              })
          }
        }
        .width('100%')
        .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }
}
