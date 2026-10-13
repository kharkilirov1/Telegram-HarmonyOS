// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { ChatTimelineEntryVO } from './ChatTimelineVO';
import { ChatMediaDownloadController } from './ChatMediaDownloadController';
import { PendingMediaOpenIntent } from './PendingMediaOpenIntent';

export interface ChatMediaDownloadCoordinatorPort {
  dataSource: ChatTimelineDataSource;
  mediaDownloadCtrl: ChatMediaDownloadController;
  pageLifecycleToken: number;
  pendingMediaDownloadVersion: number;
  pendingMediaOpenIntent: PendingMediaOpenIntent;
  isMediaDownloadFailed(fileId: number): boolean;
  isMediaDownloadPending(fileId: number): boolean;
}

export function notifyMediaDownloadStateChanged(host: ChatMediaDownloadCoordinatorPort, fileId: number): void {
    if (fileId <= 0) {
      return;
    }
    const entries = host.dataSource.getAllEntries();
    for (let entryIndex = 0; entryIndex < entries.length; entryIndex++) {
      const entry = entries[entryIndex];
      if (entry.kind !== 'message') {
        continue;
      }
      const message = entry.message;
      let ownsFile = message.photoFileId === fileId || message.videoFileId === fileId ||
        message.documentFileId === fileId || message.audioFileId === fileId || message.voiceFileId === fileId;
      if (!ownsFile) {
        for (let albumIndex = 0; albumIndex < message.albumPhotoFileIds.length; albumIndex++) {
          if (message.albumPhotoFileIds[albumIndex] === fileId) {
            ownsFile = true;
            break;
          }
        }
      }
      if (ownsFile) {
        host.dataSource.notifyItemChangedByMessageId(message.messageId);
      }
    }
  }

export function requestMediaDownload(host: ChatMediaDownloadCoordinatorPort, fileId: number, messageId: string = ''): void {
    host.mediaDownloadCtrl.requestMediaDownload(fileId, host.pageLifecycleToken);
    host.pendingMediaDownloadVersion = host.mediaDownloadCtrl.getVersion();
    if (messageId.length > 0) {
      const entries = host.dataSource.getAllEntries();
      for (let i = 0; i < entries.length; i++) {
        if (entries[i].kind === 'message' && entries[i].message.messageId === messageId) {
          entries[i].key = entries[i].stableKey + '_dl' + host.pendingMediaDownloadVersion;
          break;
        }
      }
      host.dataSource.notifyItemChangedByMessageId(messageId);
    }
  }

export function cancelMediaDownload(host: ChatMediaDownloadCoordinatorPort, fileId: number, messageId: string = ''): void {
    host.mediaDownloadCtrl.cancelMediaDownload(fileId);
    if (host.pendingMediaOpenIntent.matchesFile(fileId)) {
      host.pendingMediaOpenIntent.reset();
    }
    host.pendingMediaDownloadVersion = host.mediaDownloadCtrl.getVersion();
    if (messageId.length > 0) {
      const entries = host.dataSource.getAllEntries();
      for (let i = 0; i < entries.length; i++) {
        if (entries[i].kind === 'message' && entries[i].message.messageId === messageId) {
          entries[i].key = entries[i].stableKey + '_dl' + host.pendingMediaDownloadVersion;
          break;
        }
      }
      host.dataSource.notifyItemChangedByMessageId(messageId);
    }
  }

export function clearPendingMediaDownloads(host: ChatMediaDownloadCoordinatorPort): void {
    host.mediaDownloadCtrl.clearPendingDownloads();
    host.pendingMediaOpenIntent.reset();
    host.pendingMediaDownloadVersion = host.mediaDownloadCtrl.getVersion();
  }

export function isMediaDownloadPending(host: ChatMediaDownloadCoordinatorPort, fileId: number): boolean {
    return host.mediaDownloadCtrl.isDownloadPending(fileId);
  }

export function isMediaDownloadFailed(host: ChatMediaDownloadCoordinatorPort, fileId: number): boolean {
    return host.mediaDownloadCtrl.isDownloadFailed(fileId);
  }

export function effectiveAlbumPhotoDownloading(host: ChatMediaDownloadCoordinatorPort, entry: ChatTimelineEntryVO): boolean[] {
    const result: boolean[] = [];
    const count = Math.max(entry.message.albumPhotoPaths.length, entry.message.albumPhotoFileIds.length);
    for (let index = 0; index < count; index++) {
      const fileId = index < entry.message.albumPhotoFileIds.length ? entry.message.albumPhotoFileIds[index] : 0;
      const timelineDownloading = index < entry.message.albumPhotoDownloading.length
        ? entry.message.albumPhotoDownloading[index] : false;
      result.push(timelineDownloading || host.isMediaDownloadPending(fileId));
    }
    return result;
  }

export function effectiveAlbumPhotoDownloadFailed(host: ChatMediaDownloadCoordinatorPort, entry: ChatTimelineEntryVO): boolean[] {
    const result: boolean[] = [];
    const count = Math.max(entry.message.albumPhotoPaths.length, entry.message.albumPhotoFileIds.length);
    for (let index = 0; index < count; index++) {
      const fileId = index < entry.message.albumPhotoFileIds.length ? entry.message.albumPhotoFileIds[index] : 0;
      result.push(host.isMediaDownloadFailed(fileId));
    }
    return result;
  }

export function syncResolvedPendingDownloads(host: ChatMediaDownloadCoordinatorPort, entries: ChatTimelineEntryVO[]): void {
    host.mediaDownloadCtrl.syncResolvedDownloads(entries);
    host.pendingMediaDownloadVersion = host.mediaDownloadCtrl.getVersion();
  }
