import { promptAction } from '@kit.ArkUI';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';
import { FileController } from '../../controllers/FileController';
import { Message } from '../../models/Message';
import { MessageMetaRow } from './MessageMetaRow';

@ComponentV2
export struct FileBubble {
  @Param message: Message = new Message();
  @Local downloadProgress: number = -1;

  private progressHandler = (args?: Record<string, unknown>): void => {
    const fileId = (args?.['fileId'] as number) || 0;
    if (fileId <= 0 || fileId !== this.message.fileId) return;

    const downloaded = (args?.['downloaded'] as number) || 0;
    const total = (args?.['total'] as number) || 0;
    if (total > 0) {
      this.downloadProgress = Math.min(99, Math.floor((downloaded * 100) / total));
    } else {
      this.downloadProgress = this.downloadProgress < 0 ? 1 : Math.min(99, this.downloadProgress + 1);
    }
  };

  private completedHandler = (args?: Record<string, unknown>): void => {
    const fileId = (args?.['fileId'] as number) || 0;
    if (fileId <= 0 || fileId !== this.message.fileId) return;

    const path = ((args?.['path'] as string) || '').trim();
    if (path.length > 0) {
      this.message.filePath = path;
    }
    this.downloadProgress = 100;
  };

  aboutToAppear(): void {
    NotificationCenter.getInstance().addObserver(EventId.FILE_DOWNLOAD_PROGRESS, this.progressHandler);
    NotificationCenter.getInstance().addObserver(EventId.FILE_DOWNLOAD_COMPLETED, this.completedHandler);
    if (this.message.filePath && this.message.filePath.length > 0) {
      this.downloadProgress = 100;
    }
  }

  aboutToDisappear(): void {
    NotificationCenter.getInstance().removeObserver(EventId.FILE_DOWNLOAD_PROGRESS, this.progressHandler);
    NotificationCenter.getInstance().removeObserver(EventId.FILE_DOWNLOAD_COMPLETED, this.completedHandler);
  }

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
          this.handlePrimaryAction();
        })

        Column() {
          Text(this.message.fileName || $r('app.string.document_label'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.telegram_blue'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row() {
            if (this.downloadProgress >= 0 && this.downloadProgress < 100) {
              Text(`${this.downloadProgress}%`)
                .fontSize(12)
                .fontColor($r('app.color.telegram_blue'))
              Text(' \u2022 ')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
            }
            Text(this.getFileSizeLabel())
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .margin({ left: 10 })
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.downloadProgress < 0 || this.downloadProgress < 100) {
          Image(this.downloadProgress >= 0 && this.downloadProgress < 100
            ? $r('app.media.ic_close')
            : $r('app.media.ic_download'))
            .width(24).height(24)
            .fillColor($r('app.color.telegram_blue'))
            .onClick(() => { this.handlePrimaryAction(); })
        }
      }
      .width('100%')

      MessageMetaRow({
        date: this.message.date,
        isOutgoing: this.message.isOutgoing,
        isRead: this.message.isRead,
        isEdited: this.message.isEdited,
        sendState: this.message.sendState,
        tint: $r('app.color.text_secondary'),
        checkTint: $r('app.color.telegram_blue')
      })
    }
  }

  private handlePrimaryAction(): void {
    if (this.downloadProgress >= 0 && this.downloadProgress < 100) {
      if (this.message.fileId > 0) {
        FileController.getInstance().cancelDownload(this.message.fileId);
      }
      this.downloadProgress = -1;
      return;
    }

    if (this.message.filePath && this.message.filePath.length > 0) {
      promptAction.showToast({
        message: getContext(this).resourceManager.getStringByNameSync('download_complete'),
        duration: 1200,
        bottom: 96
      });
      return;
    }

    if (this.message.fileId <= 0) {
      promptAction.showToast({
        message: getContext(this).resourceManager.getStringByNameSync('action_failed'),
        duration: 1200,
        bottom: 96
      });
      return;
    }

    this.downloadProgress = 0;
    FileController.getInstance().requestFile(this.message.fileId, 16, (path: string) => {
      if (path.length > 0) {
        this.message.filePath = path;
        this.downloadProgress = 100;
      } else {
        this.downloadProgress = -1;
      }
    });
  }

  private getFileSizeLabel(): string {
    if (this.message.fileSize > 0) {
      return this.formatFileSize(this.message.fileSize);
    }

    const ext = (this.message.fileName || '').split('.').pop()?.toLowerCase() || '';
    switch (ext) {
      case 'pdf': return 'PDF';
      case 'doc':
      case 'docx': return 'Word';
      case 'xls':
      case 'xlsx': return 'Excel';
      case 'zip':
      case 'rar': return 'Archive';
      case 'apk': return 'APK';
      case 'mp3':
      case 'ogg': return 'Audio';
      default: return getContext(this).resourceManager.getStringByNameSync('file_label');
    }
  }

  private formatFileSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
  }
}
