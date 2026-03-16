// DownloadMessageMedia use case — triggers TDLib downloadFile for message media
//
// Subscribes to store changes. When a message has a fileId > 0 but empty path,
// enqueues a download. Priority: thumbnails first (10), selective small-media second (5).
// TDLib responds with updateFile → FileNormalizer → FileDownloadedEvent → filesReducer.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStore } from '../../core/store/AppStore';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { AppState, Message, MessageContent } from '../../core/model/AppState';
import { createDownloadFileCommand } from '../../core/model/AppCommand';
import { FileDownloadedEvent } from '../../core/model/AppEvent';
import { TdObject } from '../../models/td/common/index';

const TAG = 'DownloadMedia';
const DOMAIN = 0x0009;
const THUMB_PRIORITY = 10;  // Thumbnails load first
const MEDIA_PRIORITY = 5;   // Full media after thumbnails

export class DownloadMessageMediaUseCase {
  private store: AppStore;
  private gateway: TdGatewayPort;
  private pendingFileIds: Set<number> = new Set<number>();
  private unsubscribe: (() => void) | null = null;

  constructor(store: AppStore, gateway: TdGatewayPort) {
    this.store = store;
    this.gateway = gateway;
  }

  start(): void {
    if (this.unsubscribe) return;

    hilog.info(DOMAIN, TAG, 'Starting message media download watcher');

    // Scan current state
    this.scanAndDownload(this.store.getState());

    // Subscribe for future changes
    this.unsubscribe = this.store.subscribe((newState: AppState, prevState: AppState): void => {
      if (newState.messages !== prevState.messages) {
        this.scanAndDownload(newState);
      }
    });
  }

  stop(): void {
    if (this.unsubscribe) {
      this.unsubscribe();
      this.unsubscribe = null;
    }
    this.pendingFileIds.clear();
  }

  private scanAndDownload(state: AppState): void {
    let enqueued = 0;

    state.messages.messages.forEach((chatMessages: Map<string, Message>) => {
      chatMessages.forEach((message: Message) => {
        enqueued += this.scanContent(message.content);
      });
    });

    if (enqueued > 0) {
      hilog.info(DOMAIN, TAG, 'Enqueued %{public}d media downloads', enqueued);
    }
  }

  private scanContent(content: MessageContent): number {
    let count = 0;

    // Photo — keep thumbnail + full photo auto-download so fullscreen photo viewing
    // can still open the real asset without an extra photo-specific transfer state machine.
    if (content.photoThumbFileId > 0 && content.photoThumbPath.length === 0) {
      this.enqueueDownload(content.photoThumbFileId, THUMB_PRIORITY);
      count++;
    }
    if (content.photoFileId > 0 && content.photoPath.length === 0) {
      this.enqueueDownload(content.photoFileId, MEDIA_PRIORITY);
      count++;
    }

    // Video — download thumbnail only (full video on demand)
    if (content.videoThumbFileId > 0 && content.videoThumbPath.length === 0) {
      this.enqueueDownload(content.videoThumbFileId, THUMB_PRIORITY);
      count++;
    }

    // Sticker — auto-download (small files)
    if (content.stickerFileId > 0 && content.stickerPath.length === 0) {
      this.enqueueDownload(content.stickerFileId, MEDIA_PRIORITY);
      count++;
    }

    // Voice — auto-download (small files, Telegram iOS/Android always auto-download voice)
    if (content.voiceFileId > 0 && content.voicePath.length === 0) {
      this.enqueueDownload(content.voiceFileId, MEDIA_PRIORITY);
      count++;
    }

    // Animation (GIF) — auto-download (Telegram auto-downloads GIFs)
    if (content.animationFileId > 0 && content.animationPath.length === 0) {
      this.enqueueDownload(content.animationFileId, MEDIA_PRIORITY);
      count++;
    }

    // Video note (circles) — auto-download (small, Telegram always auto-downloads)
    if (content.videoNoteFileId > 0 && content.videoNotePath.length === 0) {
      this.enqueueDownload(content.videoNoteFileId, MEDIA_PRIORITY);
      count++;
    }

    // Document / Audio / full Video stay on-demand — user taps to download.

    return count;
  }

  private enqueueDownload(fileId: number, priority: number): void {
    if (this.pendingFileIds.has(fileId)) return;
    this.pendingFileIds.add(fileId);

    const command = createDownloadFileCommand(fileId, priority, false);
    const store = this.store;

    this.gateway.send(command)
      .then((response: Object): void => {
        try {
          const tdResponse = response as TdObject;
          const local = tdResponse.getObject('local');
          const isComplete = local.getBool('is_downloading_completed');
          const path = local.getString('path');

          if (isComplete && path.length > 0) {
            hilog.info(DOMAIN, TAG, 'File %{public}d ready: %{public}s', fileId, path);
            this.pendingFileIds.delete(fileId);
            const event = new FileDownloadedEvent();
            event.fileId = fileId;
            event.localPath = path;
            event.isComplete = true;
            event.timestamp = Date.now();
            store.dispatch(event);
          }
          // If not complete yet, TDLib will send updateFile callbacks → FileNormalizer handles progress.
          // pendingFileIds stays set to prevent duplicate enqueue; syncResolvedPendingDownloads cleans up.
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'Parse error fileId=%{public}d: %{public}s', fileId, String(e));
          this.pendingFileIds.delete(fileId);
        }
      })
      .catch((error: Error): void => {
        hilog.warn(DOMAIN, TAG, 'Download failed fileId=%{public}d: %{public}s', fileId, error.message);
        this.pendingFileIds.delete(fileId);
      });
  }
}

// Singleton
let instance: DownloadMessageMediaUseCase | null = null;

export function createDownloadMessageMediaUseCase(
  store: AppStore,
  gateway: TdGatewayPort
): DownloadMessageMediaUseCase {
  if (!instance) {
    instance = new DownloadMessageMediaUseCase(store, gateway);
  }
  return instance;
}

export function resetDownloadMessageMediaUseCase(): void {
  if (instance) {
    instance.stop();
  }
  instance = null;
}
