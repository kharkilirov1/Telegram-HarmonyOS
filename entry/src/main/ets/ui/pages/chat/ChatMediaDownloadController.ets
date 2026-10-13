// ChatMediaDownloadController — extracted from TgChatScreenPage
// Encapsulates on-demand media download state and TDLib command dispatch.
// The component keeps @Local pendingMediaDownloadVersion and bumps it when
// the controller signals changes.

import { FileDownloadedEvent, FileTransferUpdatedEvent } from '../../../core/model/AppEvent';
import {
  createCancelDownloadFileCommand,
  createDownloadFileCommand
} from '../../../core/model/AppCommand';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { TdObject } from '../../../models/TdTypes';
import { ChatTimelineEntryVO } from './ChatTimelineVO';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'ChatMediaDownload';

export class MediaDownloadStatus {
  isPending: boolean = false;
  isFailed: boolean = false;
  errorMessage: string = '';
}

export class ChatMediaDownloadController {
  private pendingAttempts: Map<number, number> = new Map<number, number>();
  // Never reset: a retry after cancel/clear must not reuse an old attempt's identity.
  private nextAttemptId: number = 0;
  private failedFileMessages: Map<number, string> = new Map<number, string>();
  private version: number = 0;
  private changeListener?: (version: number, fileId: number) => void;

  setChangeListener(listener?: (version: number, fileId: number) => void): void {
    this.changeListener = listener;
  }

  private bumpVersion(fileId: number = 0): void {
    this.version++;
    if (this.changeListener) {
      this.changeListener(this.version, fileId);
    }
  }

  getVersion(): number {
    return this.version;
  }

  // Keep the caller signature; clearPendingDownloads is the lifecycle boundary.
  requestMediaDownload(fileId: number, _lifecycleToken: number): void {
    if (fileId <= 0) return;
    if (this.pendingAttempts.has(fileId)) {
      hilog.info(DOMAIN, TAG, 'Skip duplicate on-demand download: fileId=%{public}d', fileId);
      return;
    }
    // Capture account capabilities before listeners or async continuations can
    // cross a logout boundary. Never fetch a fresh account store on completion.
    const store = getAppCoreRuntime().getStore();
    const gateway = getTdGatewayAdapter();
    const wasFailed = this.failedFileMessages.delete(fileId);
    const attemptId = ++this.nextAttemptId;
    this.pendingAttempts.set(fileId, attemptId);
    // Publish ownership before notifying listeners, which may synchronously cancel/retry.
    if (wasFailed) {
      this.bumpVersion(fileId);
      if (this.pendingAttempts.get(fileId) !== attemptId) return;
    }
    this.bumpVersion(fileId);
    if (this.pendingAttempts.get(fileId) !== attemptId) return;
    hilog.info(DOMAIN, TAG, 'On-demand media download requested: fileId=%{public}d', fileId);
    const capturedFileId = fileId;
    const command = createDownloadFileCommand(capturedFileId, 5, false);
    gateway.send(command)
      .then((response: Object): void => {
        if (this.pendingAttempts.get(capturedFileId) !== attemptId) {
          return;
        }
        try {
          const tdResponse = response as TdObject;
          const local = tdResponse.getObject('local');
          const isComplete = local.getBool('is_downloading_completed');
          const path = local.getString('path');
          if (isComplete && path.length > 0) {
            hilog.info(DOMAIN, TAG, 'On-demand file ready: fileId=%{public}d', capturedFileId);
            const event = new FileDownloadedEvent();
            event.fileId = capturedFileId;
            event.localPath = path;
            event.isComplete = true;
            event.timestamp = Date.now();
            store.dispatch(event);
            const wasPending = this.pendingAttempts.delete(capturedFileId);
            const wasFailed = this.failedFileMessages.delete(capturedFileId);
            // Finish this attempt's cleanup before a listener can start the next.
            if (wasPending || wasFailed) {
              this.bumpVersion(capturedFileId);
            }
          }
        } catch (error) {
          this.recordDownloadFailure(capturedFileId, 'Invalid download response: ' + String(error));
        }
      })
      .catch((error: Error): void => {
        if (this.pendingAttempts.get(capturedFileId) !== attemptId) {
          return;
        }
        hilog.warn(DOMAIN, TAG, 'On-demand download failed: fileId=%{public}d: %{public}s',
          capturedFileId, error.message);
        this.recordDownloadFailure(capturedFileId, error.message);
      });
  }

  cancelMediaDownload(fileId: number): void {
    if (fileId <= 0) return;
    const wasPending = this.pendingAttempts.delete(fileId);
    const wasFailed = this.failedFileMessages.delete(fileId);
    const event = new FileTransferUpdatedEvent();
    event.fileId = fileId;
    event.localPath = '';
    event.isDownloadingActive = false;
    event.isComplete = false;
    event.size = 0;
    event.expectedSize = 0;
    event.downloadOffset = 0;
    event.downloadedPrefixSize = 0;
    event.downloadedSize = 0;
    getAppCoreRuntime().getStore().dispatch(event);
    hilog.info(DOMAIN, TAG, 'On-demand media download cancel: fileId=%{public}d', fileId);
    getTdGatewayAdapter().send(createCancelDownloadFileCommand(fileId, false))
      .catch((error: Error): void => {
        hilog.warn(DOMAIN, TAG, 'Cancel media download failed: fileId=%{public}d: %{public}s',
          fileId, error.message);
      });
    // Send cancel before notifying: a listener's retry must follow, not precede it.
    if (wasPending || wasFailed) {
      this.bumpVersion(fileId);
    }
  }

  clearPendingDownloads(): void {
    if (this.pendingAttempts.size === 0 && this.failedFileMessages.size === 0) {
      return;
    }
    this.pendingAttempts.clear();
    this.failedFileMessages.clear();
    this.bumpVersion();
  }

  isDownloadPending(fileId: number): boolean {
    if (fileId <= 0) {
      return false;
    }
    return this.pendingAttempts.has(fileId);
  }

  isDownloadFailed(fileId: number): boolean {
    if (fileId <= 0) {
      return false;
    }
    return this.failedFileMessages.has(fileId);
  }

  getDownloadFailureMessage(fileId: number): string {
    if (fileId <= 0) {
      return '';
    }
    return this.failedFileMessages.get(fileId) || '';
  }

  getDownloadStatus(fileId: number): MediaDownloadStatus {
    const status = new MediaDownloadStatus();
    if (fileId <= 0) {
      return status;
    }
    status.isPending = this.pendingAttempts.has(fileId);
    status.isFailed = this.failedFileMessages.has(fileId);
    status.errorMessage = this.failedFileMessages.get(fileId) || '';
    return status;
  }

  recordDownloadFailure(fileId: number, message: string): void {
    if (fileId <= 0) {
      return;
    }
    const normalizedMessage = message.trim().length > 0 ? message.trim() : 'Download failed';
    const wasPending = this.pendingAttempts.delete(fileId);
    const previousMessage = this.failedFileMessages.get(fileId) || '';
    this.failedFileMessages.set(fileId, normalizedMessage);
    if (wasPending || previousMessage !== normalizedMessage) {
      this.bumpVersion(fileId);
    }
  }

  syncResolvedDownloads(entries: ChatTimelineEntryVO[]): void {
    if ((this.pendingAttempts.size === 0 && this.failedFileMessages.size === 0) || entries.length === 0) {
      return;
    }
    const resolved: Set<number> = new Set<number>();
    for (const entry of entries) {
      if (entry.kind !== 'message') {
        continue;
      }
      const msg = entry.message;
      if (msg.photoFileId > 0 && msg.hasLocalPhoto && msg.photoPath.length > 0) {
        resolved.add(msg.photoFileId);
      }
      for (let i = 0; i < msg.albumPhotoFileIds.length; i++) {
        const albumFileId = msg.albumPhotoFileIds[i];
        const albumHasLocal = i < msg.albumPhotoHasLocal.length ? msg.albumPhotoHasLocal[i] : false;
        const albumPath = i < msg.albumPhotoPaths.length ? msg.albumPhotoPaths[i] : '';
        if (albumFileId > 0 && albumHasLocal && albumPath.length > 0) {
          resolved.add(albumFileId);
        }
      }
      if (msg.documentFileId > 0 && msg.documentPath.length > 0) {
        resolved.add(msg.documentFileId);
      }
      if (msg.audioFileId > 0 && msg.audioPath.length > 0) {
        resolved.add(msg.audioFileId);
      }
      if (msg.voiceFileId > 0 && msg.voicePath.length > 0) {
        resolved.add(msg.voiceFileId);
      }
      if (msg.videoFileId > 0 && msg.videoPath.length > 0) {
        resolved.add(msg.videoFileId);
      }
    }
    if (resolved.size === 0) {
      return;
    }
    let changed = false;
    resolved.forEach((fileId: number) => {
      if (this.pendingAttempts.delete(fileId)) {
        changed = true;
      }
      if (this.failedFileMessages.delete(fileId)) {
        changed = true;
      }
    });
    if (changed) {
      this.bumpVersion();
    }
  }
}
