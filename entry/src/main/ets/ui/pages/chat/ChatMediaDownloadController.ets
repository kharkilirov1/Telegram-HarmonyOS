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
import { ChatTimelineEntryVO } from './ChatTimelineVO';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'ChatMediaDownload';

export class ChatMediaDownloadController {
  private pendingFileIds: Set<number> = new Set<number>();
  private version: number = 0;

  getVersion(): number {
    return this.version;
  }

  requestMediaDownload(fileId: number, lifecycleToken: number): void {
    if (fileId <= 0) return;
    if (this.pendingFileIds.has(fileId)) {
      hilog.info(DOMAIN, TAG, 'Skip duplicate on-demand download: fileId=%{public}d', fileId);
      return;
    }
    this.pendingFileIds.add(fileId);
    this.version++;
    hilog.info(DOMAIN, TAG, 'On-demand media download requested: fileId=%{public}d', fileId);
    const token = lifecycleToken;
    const capturedFileId = fileId;
    const command = createDownloadFileCommand(capturedFileId, 5, false);
    getTdGatewayAdapter().send(command)
      .then((response: Object): void => {
        if (token !== lifecycleToken || !this.pendingFileIds.has(capturedFileId)) {
          return;
        }
        try {
          const tdResponse = response as Record<string, Object>;
          const local = tdResponse['local'] as Record<string, Object>;
          const isComplete = local['is_downloading_completed'] as boolean;
          const path = local['path'] as string;
          if (isComplete && path.length > 0) {
            hilog.info(DOMAIN, TAG, 'On-demand file ready: fileId=%{public}d', capturedFileId);
            const event = new FileDownloadedEvent();
            event.fileId = capturedFileId;
            event.localPath = path;
            event.isComplete = true;
            event.timestamp = Date.now();
            getAppCoreRuntime().getStore().dispatch(event);
            if (this.pendingFileIds.delete(capturedFileId)) {
              this.version++;
            }
          }
        } catch (_e) {
          if (this.pendingFileIds.delete(capturedFileId)) {
            this.version++;
          }
        }
      })
      .catch((error: Error): void => {
        if (token !== lifecycleToken || !this.pendingFileIds.has(capturedFileId)) {
          return;
        }
        hilog.warn(DOMAIN, TAG, 'On-demand download failed: fileId=%{public}d: %{public}s',
          capturedFileId, error.message);
        if (this.pendingFileIds.delete(capturedFileId)) {
          this.version++;
        }
      });
  }

  cancelMediaDownload(fileId: number): void {
    if (fileId <= 0) return;
    const wasPending = this.pendingFileIds.delete(fileId);
    if (wasPending) {
      this.version++;
    }
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
  }

  clearPendingDownloads(): void {
    if (this.pendingFileIds.size === 0) {
      return;
    }
    this.pendingFileIds.clear();
    this.version++;
  }

  isDownloadPending(fileId: number): boolean {
    if (fileId <= 0) {
      return false;
    }
    return this.pendingFileIds.has(fileId);
  }

  syncResolvedDownloads(entries: ChatTimelineEntryVO[]): void {
    if (this.pendingFileIds.size === 0 || entries.length === 0) {
      return;
    }
    const resolved: Set<number> = new Set<number>();
    for (const entry of entries) {
      if (entry.kind !== 'message') {
        continue;
      }
      const msg = entry.message;
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
      if (this.pendingFileIds.delete(fileId)) {
        changed = true;
      }
    });
    if (changed) {
      this.version++;
    }
  }
}
