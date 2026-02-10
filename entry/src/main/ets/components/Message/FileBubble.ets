import { Message } from '../../models/Message';
import { MessageMetaRow } from './MessageMetaRow';

@ComponentV2
export struct FileBubble {
  @Param message: Message = new Message();
  @Local downloadProgress: number = -1;

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          if (this.downloadProgress >= 0 && this.downloadProgress < 100) {
            Progress({ value: this.downloadProgress, total: 100, type: ProgressType.Ring })
              .width(44).height(44)
              .color($r('app.color.telegram_blue'))
              .backgroundColor($r('app.color.background_secondary'))
              .style({ strokeWidth: 3 })

            Image($r('app.media.ic_close'))
              .width(16).height(16)
              .fillColor($r('app.color.telegram_blue'))
          } else {
            Column() {
              Image(this.downloadProgress === 100
                ? $r('app.media.ic_document')
                : $r('app.media.ic_download'))
                .width(24).height(24)
                .fillColor(Color.White)
            }
            .width(44).height(44)
            .borderRadius(8)
            .backgroundColor($r('app.color.telegram_blue'))
            .justifyContent(FlexAlign.Center)
          }
        }
        .width(44).height(44)
        .onClick(() => {
          if (this.downloadProgress < 0) {
            this.simulateDownload();
          }
        })

        Column() {
          Text(this.message.fileName || $r('app.string.document_label'))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.telegram_blue'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row() {
            if (this.downloadProgress >= 0 && this.downloadProgress < 100) {
              Text(`${this.downloadProgress}%`)
                .fontSize(13)
                .fontColor($r('app.color.telegram_blue'))
              Text(' \u2022 ')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
            }
            Text(this.getFileSizeLabel())
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .margin({ left: 10 })
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.downloadProgress < 0) {
          Image($r('app.media.ic_download'))
            .width(22).height(22)
            .fillColor($r('app.color.telegram_blue'))
            .onClick(() => { this.simulateDownload(); })
        }
      }
      .width('100%')

      MessageMetaRow({
        date: this.message.date,
        isOutgoing: this.message.isOutgoing,
        isRead: this.message.isRead,
        tint: $r('app.color.text_secondary'),
        checkTint: $r('app.color.telegram_blue')
      })
    }
  }

  private getFileSizeLabel(): string {
    const ext = (this.message.fileName || '').split('.').pop()?.toLowerCase() || '';
    switch (ext) {
      case 'pdf': return 'PDF';
      case 'doc': case 'docx': return 'Word';
      case 'xls': case 'xlsx': return 'Excel';
      case 'zip': case 'rar': return 'Archive';
      case 'apk': return 'APK';
      case 'mp3': case 'ogg': return 'Audio';
      default: return 'File';
    }
  }

  private simulateDownload(): void {
    this.downloadProgress = 0;
    const timerId = setInterval(() => {
      this.downloadProgress += Math.floor(Math.random() * 15 + 5);
      if (this.downloadProgress >= 100) {
        this.downloadProgress = 100;
        clearInterval(timerId);
      }
    }, 300);
  }
}
