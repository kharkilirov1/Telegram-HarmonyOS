import { TgMediaGalleryPage } from '../atoms/TgMediaGalleryPage';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { MediaGalleryItem } from '../../../models/MediaGalleryItem';

@Preview({ title: 'TgMediaGalleryPage' })
@ComponentV2
export struct TgMediaGalleryPageDemo {
  private longCaption: string =
    'Long gallery caption that should stay inside the bottom overlay, clamp to four lines, and keep the media viewer readable over dark content.';
  private longSender: string =
    'Very Long Sender Name For Gallery Overlay Stress';

  private makeItem(type: string, messageId: string, path: string, thumbnailPath: string,
    caption: string, senderName: string, timestamp: string, width: number, height: number,
    durationSec: number = 0, fileId: number = 0, isDownloading: boolean = false,
    downloadProgress: number = -1): MediaGalleryItem {
    const item = new MediaGalleryItem();
    item.type = type;
    item.messageId = messageId;
    item.path = path;
    item.thumbnailPath = thumbnailPath;
    item.caption = caption;
    item.senderName = senderName;
    item.timestamp = timestamp;
    item.width = width;
    item.height = height;
    item.durationSec = durationSec;
    item.fileId = fileId;
    item.isDownloading = isDownloading;
    item.downloadProgress = downloadProgress;
    return item;
  }

  private singlePhotoItems(): MediaGalleryItem[] {
    return [
      this.makeItem('photo', 'photo_1', '/demo/gallery/photo_1.jpg', '/demo/gallery/photo_1_thumb.jpg',
        'Single downloaded photo preview', 'Alice', '09:41', 1280, 960, 0, 101)
    ];
  }

  private multiPhotoItems(): MediaGalleryItem[] {
    return [
      this.makeItem('photo', 'album_1', '/demo/gallery/album_1.jpg', '/demo/gallery/album_1_thumb.jpg',
        'Album item 1', 'Rose', '10:02', 1280, 960, 0, 201),
      this.makeItem('photo', 'album_2', '/demo/gallery/album_2.jpg', '/demo/gallery/album_2_thumb.jpg',
        'Album item 2 opened as initial index', 'Rose', '10:03', 960, 1280, 0, 202),
      this.makeItem('photo', 'album_3', '/demo/gallery/album_3.jpg', '/demo/gallery/album_3_thumb.jpg',
        'Album item 3', 'Rose', '10:04', 1280, 720, 0, 203)
    ];
  }

  private videoItems(): MediaGalleryItem[] {
    return [
      this.makeItem('video', 'video_1', '/demo/gallery/video_1.mp4', '/demo/gallery/video_1_thumb.jpg',
        'Video item with duration and caption', 'Alex', '11:15', 720, 1280, 95, 301)
    ];
  }

  private animationItems(): MediaGalleryItem[] {
    return [
      this.makeItem('animation', 'gif_1', '/demo/gallery/animation_1.mp4', '/demo/gallery/animation_1_thumb.jpg',
        'Looping muted animation/GIF item', 'GIF Bot', '12:20', 512, 512, 0, 401)
    ];
  }

  private notDownloadedItems(): MediaGalleryItem[] {
    return [
      this.makeItem('photo', 'missing_photo', '', '/demo/gallery/missing_photo_thumb.jpg',
        'Not-downloaded photo with thumbnail', 'Cloud', '13:01', 1280, 960, 0, 501),
      this.makeItem('video', 'missing_video', '', '/demo/gallery/missing_video_thumb.jpg',
        'Not-downloaded video with thumbnail', 'Cloud', '13:02', 720, 1280, 44, 502)
    ];
  }

  private downloadingItems(): MediaGalleryItem[] {
    return [
      this.makeItem('photo', 'fetching_photo', '', '/demo/gallery/fetching_photo_thumb.jpg',
        'Determinate gallery download state', 'Cloud', '13:05', 1280, 960, 0, 503, false, 0.42),
      this.makeItem('video', 'fetching_video', '', '/demo/gallery/fetching_video_thumb.jpg',
        'Indeterminate gallery download state', 'Cloud', '13:06', 720, 1280, 52, 504, true, -1)
    ];
  }

  private longTextItems(): MediaGalleryItem[] {
    return [
      this.makeItem('photo', 'long_text_photo', '/demo/gallery/long_text.jpg', '/demo/gallery/long_text_thumb.jpg',
        this.longCaption, this.longSender, 'Yesterday at 23:59', 1280, 720, 0, 601)
    ];
  }

  @Builder
  private galleryCase(label: string, description: string, items: MediaGalleryItem[], initialIndex: number = 0) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      Text(description)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .width('100%')

      Stack() {
        TgMediaGalleryPage({
          mediaItems: items,
          initialIndex: initialIndex,
          statusBarHeight: 24,
          onDismiss: () => {},
          onDownloadRequest: (_fileId: number) => {},
          onDownloadCancel: (_fileId: number) => {}
        })
      }
      .width('100%')
      .height(460)
      .clip(true)
      .borderRadius(TgUiTokens.RADIUS_12)
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_16,
      right: TgUiTokens.SPACE_16,
      top: TgUiTokens.SPACE_6,
      bottom: TgUiTokens.SPACE_12
    })
  }

  build() {
    Scroll() {
      Column() {
        Text('TgMediaGalleryPage Demo')
          .fontSize(TgUiTokens.FONT_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            top: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        Text('Full-screen gallery contract: photo, video, animation, not-downloaded media, overlays, and initial index.')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.galleryCase('01 single downloaded photo', 'Photo path present; verifies top/bottom overlay shell.',
          this.singlePhotoItems())
        this.galleryCase('02 multi-photo gallery with initial index', 'Starts at item 2 and should show 2 / 3 counter.',
          this.multiPhotoItems(), 1)
        this.galleryCase('03 video with duration/caption', 'Video item uses TgInlineVideoView with controls and duration badge.',
          this.videoItems())
        this.galleryCase('04 animation/GIF item', 'Animation item loops muted and hides normal video controls.',
          this.animationItems())
        this.galleryCase('05 not-downloaded media', 'Missing full path delegates download through centered affordance.',
          this.notDownloadedItems())
        this.galleryCase('06 downloading media', 'Progress/spinner states render in the gallery and tap cancels via parent.',
          this.downloadingItems())
        this.galleryCase('07 empty gallery fallback', 'No items should show a safe empty state rather than a blank Swiper.',
          [])
        this.galleryCase('08 long caption and sender', 'Overlay stress case for long caption and top sender text.',
          this.longTextItems())
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}
