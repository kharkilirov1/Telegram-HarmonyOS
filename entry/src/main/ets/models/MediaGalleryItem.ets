// File-transfer fields are @Trace so that gallery nodes reused by ForEach
// (stable key = index + messageId) still repaint when a download starts,
// progresses, fails or completes while the gallery stays open.
@ObservedV2
export class MediaGalleryItem {
  type: string = 'photo'; // 'photo' | 'video' | 'animation' | 'videoNote'
  @Trace path: string = '';
  @Trace thumbnailPath: string = '';
  @Trace minithumb: string = '';
  caption: string = '';
  senderName: string = '';
  timestamp: string = '';
  width: number = 0;
  height: number = 0;
  durationSec: number = 0;
  fileId: number = 0;
  messageId: string = '';
  sourceMessageId: string = '';
  @Trace isDownloading: boolean = false;
  @Trace isDownloadFailed: boolean = false;
  @Trace downloadProgress: number = -1;
}
