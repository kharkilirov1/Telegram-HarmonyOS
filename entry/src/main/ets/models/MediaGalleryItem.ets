export class MediaGalleryItem {
  type: string = 'photo'; // 'photo' | 'video' | 'animation' | 'videoNote'
  path: string = '';
  thumbnailPath: string = '';
  caption: string = '';
  senderName: string = '';
  timestamp: string = '';
  width: number = 0;
  height: number = 0;
  durationSec: number = 0;
  fileId: number = 0;
  messageId: string = '';
  isDownloading: boolean = false;
  isDownloadFailed: boolean = false;
  downloadProgress: number = -1;
}
