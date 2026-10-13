// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { mergeGalleryItemsInPlace, resolveRefreshedMediaGalleryState } from './MediaGalleryState';
import { MediaGalleryItem } from '../../../models/MediaGalleryItem';
import { albumMediaSourceId } from '../../tg_ui/utils/TgMediaGeometryTransition';
import { curves } from '@kit.ArkUI';

export interface ChatMediaGalleryCoordinatorPort {
  dataSource: ChatTimelineDataSource;
  galleryCurrentIndex: number;
  galleryInitialIndex: number;
  galleryItems: MediaGalleryItem[];
  gallerySourceMessageId: string;
  showMediaGallery: boolean;
  animateMediaGalleryState(isVisible: boolean, sourceMessageId?: string): void;
  buildMediaGalleryItems(): MediaGalleryItem[];
  isMediaDownloadFailed(fileId: number): boolean;
  isMediaDownloadPending(fileId: number): boolean;
  getUIContext(): UIContext;
}

export function buildMediaGalleryItems(host: ChatMediaGalleryCoordinatorPort): MediaGalleryItem[] {
    const items: MediaGalleryItem[] = [];
    const entries = host.dataSource.getAllEntries();
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      if (entry.kind !== 'message') continue;
      const ct = entry.message.contentType;
      if (ct === 'photo' || ct === 'video' || ct === 'animation' || ct === 'videoNote' || ct === 'photoAlbum') {
        if (ct === 'photoAlbum') {
          for (let j = 0; j < entry.message.albumPhotoPaths.length; j++) {
            const albumItem = new MediaGalleryItem();
            const albumFileId = j < entry.message.albumPhotoFileIds.length ? entry.message.albumPhotoFileIds[j] : 0;
            const albumHasLocal = j < entry.message.albumPhotoHasLocal.length ? entry.message.albumPhotoHasLocal[j] : false;
            albumItem.type = 'photo';
            albumItem.path = albumHasLocal ? entry.message.albumPhotoPaths[j] : '';
            albumItem.thumbnailPath = entry.message.albumPhotoPaths[j];
            albumItem.minithumb = j < entry.message.albumPhotoMinithumbs.length
              ? entry.message.albumPhotoMinithumbs[j] : '';
            albumItem.caption = j === 0 ? entry.message.caption : '';
            albumItem.senderName = entry.message.senderName;
            albumItem.timestamp = entry.message.timeText;
            albumItem.width = j < entry.message.albumPhotoWidths.length ? entry.message.albumPhotoWidths[j] : 0;
            albumItem.height = j < entry.message.albumPhotoHeights.length ? entry.message.albumPhotoHeights[j] : 0;
            albumItem.fileId = albumFileId;
            const memberMessageId = j < entry.message.sourceMessageIds.length
              ? entry.message.sourceMessageIds[j] : '';
            albumItem.messageId = albumMediaSourceId(entry.message.messageId, memberMessageId, j);
            albumItem.sourceMessageId = albumItem.messageId;
            albumItem.isDownloading =
              (j < entry.message.albumPhotoDownloading.length ? entry.message.albumPhotoDownloading[j] : false) ||
                host.isMediaDownloadPending(albumFileId);
            albumItem.isDownloadFailed = host.isMediaDownloadFailed(albumFileId);
            albumItem.downloadProgress =
              j < entry.message.albumPhotoDownloadProgress.length ? entry.message.albumPhotoDownloadProgress[j] : -1;
            items.push(albumItem);
          }
        } else {
          const item = new MediaGalleryItem();
          const fileId = ct === 'photo' ? entry.message.photoFileId : entry.message.videoFileId;
          item.type = ct;
          item.path = ct === 'photo'
            ? (entry.message.hasLocalPhoto ? entry.message.photoPath : '')
            : entry.message.videoPath;
          item.thumbnailPath = ct === 'photo' ? entry.message.photoPath : entry.message.videoThumbPath;
          item.minithumb = ct === 'photo' ? entry.message.photoMinithumb : entry.message.videoMinithumb;
          item.caption = entry.message.caption;
          item.senderName = entry.message.senderName;
          item.timestamp = entry.message.timeText;
          item.width = ct === 'photo' ? entry.message.photoWidth : entry.message.videoWidth;
          item.height = ct === 'photo' ? entry.message.photoHeight : entry.message.videoHeight;
          item.durationSec = entry.message.videoDuration;
          item.fileId = fileId;
          item.messageId = entry.message.messageId;
          item.sourceMessageId = entry.message.messageId;
          item.isDownloading = (ct === 'photo' ? entry.message.isPhotoDownloading : entry.message.isVideoDownloading) ||
            host.isMediaDownloadPending(fileId);
          item.isDownloadFailed = host.isMediaDownloadFailed(fileId);
          item.downloadProgress = ct === 'photo' ? entry.message.photoDownloadProgress : entry.message.videoDownloadProgress;
          items.push(item);
        }
      }
    }
    return items;
  }

export function handleMediaGalleryOpen(host: ChatMediaGalleryCoordinatorPort, messageId: string): void {
    const items = host.buildMediaGalleryItems();
    if (items.length === 0) return;
    let targetIndex = 0;
    const entries = host.dataSource.getAllEntries();
    let mediaIndex = 0;
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      if (entry.kind !== 'message') continue;
      const ct = entry.message.contentType;
      if (ct === 'photo' || ct === 'video' || ct === 'animation' || ct === 'videoNote') {
        if (entry.message.messageId === messageId) {
          targetIndex = mediaIndex;
          break;
        }
        mediaIndex++;
      } else if (ct === 'photoAlbum') {
        let memberIndex = -1;
        for (let j = 0; j < entry.message.albumPhotoPaths.length; j++) {
          const memberMessageId = j < entry.message.sourceMessageIds.length
            ? entry.message.sourceMessageIds[j] : '';
          if (albumMediaSourceId(entry.message.messageId, memberMessageId, j) === messageId) {
            memberIndex = j;
            break;
          }
        }
        if (entry.message.messageId === messageId || memberIndex >= 0) {
          targetIndex = mediaIndex + Math.max(0, memberIndex);
          break;
        }
        mediaIndex += entry.message.albumPhotoPaths.length;
      }
    }
    host.galleryItems = items;
    host.galleryInitialIndex = Math.min(targetIndex, items.length - 1);
    host.galleryCurrentIndex = host.galleryInitialIndex;
    const sourceMessageId = items[host.galleryInitialIndex].sourceMessageId;
    host.animateMediaGalleryState(true, sourceMessageId);
  }

export function animateMediaGalleryState(host: ChatMediaGalleryCoordinatorPort, isVisible: boolean, sourceMessageId: string = '0'): void {
    const normalizedSourceMessageId = isVisible && sourceMessageId.trim().length > 0 ? sourceMessageId : '0';
    host.getUIContext().animateTo({
      curve: curves.responsiveSpringMotion(
        TgUiTokens.MEDIA_GALLERY_GEOMETRY_RESPONSE,
        TgUiTokens.MEDIA_GALLERY_GEOMETRY_DAMPING,
        TgUiTokens.MEDIA_GALLERY_GEOMETRY_OVERLAP
      )
    }, () => {
      host.gallerySourceMessageId = normalizedSourceMessageId;
      host.showMediaGallery = isVisible;
    });
  }

export function refreshOpenMediaGalleryItems(host: ChatMediaGalleryCoordinatorPort): void {
    if (!host.showMediaGallery) {
      return;
    }
    const nextItems = host.buildMediaGalleryItems();
    if (mergeGalleryItemsInPlace(host.galleryItems, nextItems)) {
      // Состав не изменился: @Trace-поля уже донесли файловую дельту до
      // переиспользованных узлов галереи, замена массива не нужна.
      return;
    }
    const result = resolveRefreshedMediaGalleryState(
      host.galleryItems,
      host.galleryCurrentIndex,
      nextItems
    );
    if (result.shouldClose) {
      host.galleryItems = [];
      host.galleryInitialIndex = 0;
      host.galleryCurrentIndex = 0;
      host.animateMediaGalleryState(false);
      return;
    }
    host.gallerySourceMessageId = result.sourceMessageId.trim().length > 0 ? result.sourceMessageId : '0';
    host.galleryItems = result.items;
    host.galleryCurrentIndex = result.currentIndex;
    host.galleryInitialIndex = result.currentIndex;
  }
